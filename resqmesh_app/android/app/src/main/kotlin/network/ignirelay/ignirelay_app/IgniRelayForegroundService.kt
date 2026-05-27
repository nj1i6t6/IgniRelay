package network.ignirelay.ignirelay_app

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap

/**
 * IgniRelay 後台 Foreground Service
 *
 * Bug 2 Fix: 這是唯一的 GATT Server 來源。
 * MainActivity 不再開 GATT Server，避免 Android 只允許一個 GATT Server 的衝突。
 *
 * Bug 3 Fix: onCharacteristicWriteRequest 收到資料後，
 * 透過 MainActivity.sharedEventSink 轉發到 Flutter EventChannel。
 */
class IgniRelayForegroundService : Service() {

    companion object {
        private const val TAG = "IgniRelayService"
        private const val CHANNEL_ID = "ignirelay_data_mule"
        private const val NOTIFICATION_ID = 1001

        // 共享 Bloom Filter 快取（由 MainActivity 透過 MethodChannel 更新）
        @Volatile
        @JvmStatic
        var sharedBloomBytes: ByteArray = ByteArray(0)

        // Bug 7 Fix: 預快取的事件 outbox（由 Dart 推送，供 Notify 反向推送）
        // 當 Central 連上並 subscribe Event Char 通知時，Server 主動推送這些事件。
        // 解決 OPPO GATT Server 壞掉導致 OPPO 無法接收資料的問題。
        @Volatile
        @JvmStatic
        var sharedOutboxEvents: List<ByteArray> = emptyList()

        // 持久 GATT Server 狀態（供 Dart 查詢，不依賴 log buffer）
        @Volatile
        @JvmStatic
        var gattServiceReady: Boolean = false

        @Volatile
        @JvmStatic
        var gattServiceStatus: Int = -999  // 尚未回報

        // v0.3 Stage 0c wave 3B — instance handle so MainActivity can reach
        // into the live service for capability-aware single-chunk notify.
        // Set in onCreate, cleared in onDestroy.
        @Volatile
        @JvmStatic
        var instance: IgniRelayForegroundService? = null

        // Bloom filter bit-vector 參數：2048 bytes (16384 bits), 7 hash functions
        const val BLOOM_SIZE_BYTES = 2048
        const val BLOOM_HASH_COUNT = 7
        val BLOOM_MAGIC = byteArrayOf(0xFF.toByte(), 0xBF.toByte(), 0x02, 0x00)

        // ── v0.3 Stage 0c wave 3E — adapter health + debug hooks ─────────
        //
        // Spec: docs/specs/native_transport_v1_2026-05-13.md §8 (adapter
        // recovery) + §7.4 (force MTU) + §8.5 (force idle).
        //
        // These are companion-level so MainActivity (MethodChannel handler)
        // and NordicMeshManager (scan / central-side callbacks) can hit
        // the same emit gate without holding a live service reference.

        /** End time (epoch ms) of the current `debugForceAdapterIdle`
         *  suppression window. 0 = no suppression. */
        @Volatile
        @JvmStatic
        var adapterIdleSuppressedUntilMs: Long = 0L

        /** Per-device MTU clamp set by `debugForceTargetMtu`. The clamp is
         *  applied to BOTH peripheral-side onMtuChanged AND central-side
         *  Nordic done{} reporting, so the higher layers behave as if the
         *  link negotiated the lower value. */
        @JvmStatic
        val debugMtuOverrideByDevice: ConcurrentHashMap<String, Int> = ConcurrentHashMap()

        /** Tick kinds the Dart-side AdapterHealthMonitor consumes. Must
         *  match the strings in
         *  `lib/app/services/adapter_health_monitor.dart` `_onNativeEvent`. */
        const val TICK_SCAN = "scan"
        const val TICK_ADVERTISE = "advertise"
        const val TICK_GATT_OP = "gatt_op"

        // v0.3 Stage 0c wave 3F — per-kind last-tick timestamps used by the
        // native-side recovery watchdog (spec §8.3). emitAdapterTick keeps
        // these fresh; the periodic adapterRecoveryRunnable inside the
        // service instance reads them to decide soft/hard restart.
        //
        // 0L means "never observed" — startup is intentionally lenient so a
        // freshly booted service doesn't trip the §8.2 stale gate before
        // any BLE callbacks have had a chance to fire.
        @Volatile @JvmStatic var lastScanTickAtMs: Long = 0L
        @Volatile @JvmStatic var lastAdvertiseTickAtMs: Long = 0L
        @Volatile @JvmStatic var lastGattOpTickAtMs: Long = 0L

        /**
         * Single source of truth for adapter health ticks. Sends an
         * `adapter_health_tick` event into the shared Dart event sink
         * UNLESS [debugForceAdapterIdle] has suppressed emissions.
         *
         * Public + static so callers outside the service (NordicMeshManager
         * scan callback, MainActivity for diagnostic pings) can reach it
         * without holding an instance reference.
         *
         * Wave 3F — also updates the per-kind `lastXxxTickAtMs` companion
         * fields the recovery watchdog reads. Suppression skips BOTH the
         * Dart event AND the timestamp update on purpose so that
         * `debugForceAdapterIdle` exercises the §8.3 recovery path end to
         * end (the watchdog sees the timestamps go stale exactly the way
         * a real wedged adapter would).
         */
        @JvmStatic
        fun emitAdapterTick(kind: String) {
            val now = System.currentTimeMillis()
            if (adapterIdleSuppressedUntilMs > now) return
            when (kind) {
                TICK_SCAN -> lastScanTickAtMs = now
                TICK_ADVERTISE -> lastAdvertiseTickAtMs = now
                TICK_GATT_OP -> lastGattOpTickAtMs = now
            }
            val sink = MainActivity.sharedEventSink ?: return
            // Post to the main looper because EventSink.success() MUST be
            // called from the main thread; many tick call sites are on
            // BLE binder callback threads.
            Handler(Looper.getMainLooper()).post {
                sink.success(mapOf(
                    "type" to "adapter_health_tick",
                    "kind" to kind,
                    "ts_ms" to now
                ))
            }
        }

        /**
         * Apply the [debugForceTargetMtu] override (if any) to a freshly
         * negotiated MTU. Pure function — no side effects. Returns the
         * clamped value: `min(actual, override)` when an override exists,
         * else the original value.
         */
        @JvmStatic
        fun applyMtuOverride(deviceAddress: String, actualMtu: Int): Int {
            val override = debugMtuOverrideByDevice[deviceAddress] ?: return actualMtu
            return minOf(actualMtu, override)
        }
    }

    private var bleAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var serviceAddRetryCount = 0
    private var isAdvertising = false

    // Bug 7: Notify 反向推送 — 追蹤已 subscribe 通知的 Central 裝置
    private val notifySubscribers = ConcurrentHashMap<String, BluetoothDevice>()
    // v0.3 Stage 0c2: per-device negotiated MTU (set in onMtuChanged).
    // Used by safeSingleNotify() to size notify payloads dynamically rather
    // than truncating to a hard-coded constant. Spec: docs/specs/native_transport_v1_2026-05-13.md §2.
    private val deviceMtuMap = ConcurrentHashMap<String, Int>()
    // v0.3 Stage 0c wave 3A: peers we've already emitted peer_ready_for_hello for.
    // Avoids duplicate emissions when MTU is renegotiated mid-session.
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §5.2.
    private val helloReadyDevices = ConcurrentHashMap.newKeySet<String>()
    /** Conservative MTU baseline for peers whose MTU upcall has not arrived yet. */
    private val defaultMtuFallback = 185
    private var eventCharRef: BluetoothGattCharacteristic? = null
    // Bug 10: 追蹤已收到 Bloom Write 的裝置（區分新舊版 Central）
    private val bloomReceivedDevices = ConcurrentHashMap.newKeySet<String>()
    // Prepared Write buffers (Long Write support for data > MTU)
    private val preparedWriteBuffers = ConcurrentHashMap<String, ByteArrayOutputStream>()
    // 每個 buffer 上次寫入時間（millis），用於 TTL 清理
    private val preparedWriteTimestamps = ConcurrentHashMap<String, Long>()
    // 超過此時間仍未 ExecuteWrite/Cancel 視為棄置，避免惡意/異常裝置撐爆記憶體
    private val PREPARED_WRITE_TTL_MS = 60_000L
    // 定期掃描清理間隔
    private val PREPARED_WRITE_SWEEP_INTERVAL_MS = 30_000L
    private val preparedWriteSweepRunnable = object : Runnable {
        override fun run() {
            sweepStalePreparedWrites()
            mainHandler.postDelayed(this, PREPARED_WRITE_SWEEP_INTERVAL_MS)
        }
    }

    // v0.3 Stage 0c wave 3E — periodic adapter health emitter.
    //
    // Advertising on Android has no per-tick callback ("set and forget"),
    // and scanning emits onScanResult only when peers are visible. To
    // keep the Dart-side AdapterHealthMonitor honest, this runnable wakes
    // every 30 s and emits a TICK_ADVERTISE while isAdvertising = true,
    // plus a TICK_GATT_OP when GATT server has at least one notify
    // subscriber (proxy for "GATT layer is healthy"). Both ticks are
    // gated by `debugForceAdapterIdle` suppression.
    //
    // 30 s is half the spec §8.2 60 s evaluation cadence so the §8.2
    // 5-minute "both stale" threshold has ~10 chances to refresh before
    // tripping.
    private val ADAPTER_HEALTH_TICK_INTERVAL_MS = 30_000L
    private val adapterHealthTickRunnable = object : Runnable {
        override fun run() {
            try {
                if (isAdvertising) {
                    emitAdapterTick(TICK_ADVERTISE)
                }
                if (notifySubscribers.isNotEmpty()) {
                    emitAdapterTick(TICK_GATT_OP)
                }
            } catch (e: Exception) {
                Log.w(TAG, "adapterHealthTick error: ${e.message}")
            }
            mainHandler.postDelayed(this, ADAPTER_HEALTH_TICK_INTERVAL_MS)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // v0.3 Stage 0c wave 3F — native-side adapter recovery action.
    //
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §8.3 (recovery
    // story). Wave 3E only landed the OBSERVATION half (emitAdapterTick +
    // per-kind timestamps). This wave adds the ACTION half so 0d gate
    // scenario #11 ("mesh recovers within 60 s of automatic soft restart")
    // can complete WITHOUT a manual reboot or BT-toggle.
    //
    // State machine (per §8.3 steps 1–4):
    //
    //   step 1  soft restart  — stop+restart BLE advertising. Cheap,
    //                            non-disruptive to existing GATT connections.
    //                            We attempt it up to 2 consecutive evaluation
    //                            cycles before escalating.
    //   step 2  hard restart  — full GATT server teardown + rebuild
    //                            (stopBlePeripheral + startBlePeripheral).
    //                            Existing connections are dropped; centrals
    //                            reconnect via the normal scan path.
    //   step 3  UI banner     — emitted as `adapter_native_*` events here;
    //                            the actual banner is owned by the Dart
    //                            AdapterHealthMonitor → UI provider chain
    //                            (unchanged this wave).
    //   step 4  permanent err — after 2 consecutive hard restart attempts
    //                            also fail to refresh ticks, emit
    //                            `adapter_native_permanent_error` and stop
    //                            re-trying until a tick eventually arrives
    //                            (which auto-resets the counters in
    //                            evaluateAndRecover).
    //
    // Gate (§8.2): we only act when BOTH scan AND advertise are stale for
    // more than kAdapterStaleThresholdMs AND we have at least one notify
    // subscriber (proxy for "we have something to relay to"). gattOp ticks
    // are informational only — they alone never prove the radio is healthy.
    //
    // Why advertise-only soft restart on the FS side (no scan restart):
    //   BLE scan on Android is owned by NordicMeshManager (held by
    //   MainActivity), NOT by this foreground service. If the Activity is
    //   alive, the Dart-side AdapterHealthMonitor sees the same tick stream
    //   and can call startNordicScan via NativeBridge. If the Activity is
    //   dead, scan is already stopped — there is nothing for the FS to
    //   restart. So advertise restart is the only action the FS can take
    //   unilaterally. Cross-platform parity: iOS BlePlugin does the same.
    private val ADAPTER_RECOVERY_CHECK_INTERVAL_MS = 60_000L
    private val ADAPTER_STALE_THRESHOLD_MS = 5L * 60_000L
    private val ADAPTER_SOFT_RESTART_DELAY_MS = 500L
    private val ADAPTER_HARD_RESTART_DELAY_MS = 1_000L
    private var consecutiveSoftRestartFailures = 0
    private var consecutiveHardRestartFailures = 0

    private val adapterRecoveryRunnable = object : Runnable {
        override fun run() {
            try {
                evaluateAndRecover()
            } catch (e: Exception) {
                Log.w(TAG, "adapter recovery error: ${e.message}")
            }
            mainHandler.postDelayed(this, ADAPTER_RECOVERY_CHECK_INTERVAL_MS)
        }
    }

    private fun evaluateAndRecover() {
        val now = System.currentTimeMillis()
        // §8.2 staleness gate. A 0L timestamp means "never observed" — treat
        // as NOT stale during boot (lenient) rather than tripping on startup.
        val scanStale = lastScanTickAtMs > 0L &&
            (now - lastScanTickAtMs) > ADAPTER_STALE_THRESHOLD_MS
        val advStale = lastAdvertiseTickAtMs > 0L &&
            (now - lastAdvertiseTickAtMs) > ADAPTER_STALE_THRESHOLD_MS
        if (!(scanStale && advStale)) {
            // Healthy — reset escalation counters so a future failure
            // restarts the soft → hard → permanent ladder from step 1.
            if (consecutiveSoftRestartFailures > 0 ||
                consecutiveHardRestartFailures > 0) {
                Log.i(TAG, "adapter healthy; reset recovery counters")
                consecutiveSoftRestartFailures = 0
                consecutiveHardRestartFailures = 0
            }
            return
        }
        // §8.2: only act when we have a foreground service AND subscribed
        // peers (there's a reason to be advertising / relaying).
        if (!isAdvertising) return
        if (notifySubscribers.isEmpty()) return

        when {
            consecutiveSoftRestartFailures < 2 -> attemptSoftRestart()
            consecutiveHardRestartFailures < 2 -> attemptHardRestart()
            else -> emitPermanentError()
        }
    }

    private fun attemptSoftRestart() {
        consecutiveSoftRestartFailures += 1
        Log.w(TAG, "adapter soft restart (attempt $consecutiveSoftRestartFailures)")
        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "adapter_native_soft_restart",
                "attempt" to consecutiveSoftRestartFailures
            ))
        }
        try {
            if (ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.BLUETOOTH_ADVERTISE
                ) == PackageManager.PERMISSION_GRANTED) {
                advertiseCallback?.let { bleAdvertiser?.stopAdvertising(it) }
            }
            isAdvertising = false
            advertiseCallback = null
        } catch (e: Exception) {
            Log.w(TAG, "soft restart stop failed: ${e.message}")
        }
        // Re-arm advertising after a short pause. The next periodic
        // adapterHealthTickRunnable cycle (≤30 s) will pick up the fresh
        // ADVERTISE tick; the next evaluateAndRecover (≤60 s) will see
        // bothStale==false and reset the counters.
        mainHandler.postDelayed({
            try {
                startAdvertisingInternal()
            } catch (e: Exception) {
                Log.w(TAG, "soft restart start failed: ${e.message}")
            }
        }, ADAPTER_SOFT_RESTART_DELAY_MS)
    }

    private fun attemptHardRestart() {
        consecutiveHardRestartFailures += 1
        Log.w(TAG, "adapter hard restart (attempt $consecutiveHardRestartFailures)")
        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "adapter_native_hard_restart",
                "attempt" to consecutiveHardRestartFailures
            ))
        }
        try {
            stopBlePeripheral()
        } catch (e: Exception) {
            Log.w(TAG, "hard restart stop failed: ${e.message}")
        }
        // Allow the BLE stack a moment to settle before reopening the GATT
        // server (some vendor stacks reject openGattServer if called
        // immediately after close).
        mainHandler.postDelayed({
            try {
                startBlePeripheral()
            } catch (e: Exception) {
                Log.e(TAG, "hard restart start failed: ${e.message}")
            }
        }, ADAPTER_HARD_RESTART_DELAY_MS)
    }

    private fun emitPermanentError() {
        Log.e(TAG, "adapter permanent error after " +
            "$consecutiveHardRestartFailures hard-restart attempts")
        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "adapter_native_permanent_error",
                "failures" to consecutiveHardRestartFailures
            ))
        }
        // Reset counters so a future recovered tick (real or via
        // `debugForceAdapterIdle` window expiry) gives us another shot at
        // the soft → hard ladder rather than wedging forever.
        consecutiveSoftRestartFailures = 0
        consecutiveHardRestartFailures = 0
    }

    private fun sweepStalePreparedWrites() {
        val cutoff = System.currentTimeMillis() - PREPARED_WRITE_TTL_MS
        val stale = preparedWriteTimestamps.entries
            .filter { it.value < cutoff }
            .map { it.key }
        for (key in stale) {
            preparedWriteBuffers.remove(key)
            preparedWriteTimestamps.remove(key)
        }
        if (stale.isNotEmpty()) {
            Log.w(TAG, "Swept ${stale.size} stale preparedWrite buffers")
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Bug 9 Fix: 只在第一次啟動時初始化 GATT Server，避免重複 openGattServer + addService
        // 造成 service 真空期（clearServices → addService 之間 characteristics 全是 null）。
        // Dart 層有 5 個入口會觸發 startDataMuleService()，每次都會走到這裡。
        if (gattServer == null) {
            startBlePeripheral()
            // 啟動 preparedWrite TTL 掃描（idempotent：onCreate 後只會生效一次）
            mainHandler.removeCallbacks(preparedWriteSweepRunnable)
            mainHandler.postDelayed(preparedWriteSweepRunnable, PREPARED_WRITE_SWEEP_INTERVAL_MS)
            // v0.3 Stage 0c wave 3E — start periodic adapter_health_tick
            // emitter. Idempotent.
            mainHandler.removeCallbacks(adapterHealthTickRunnable)
            mainHandler.postDelayed(adapterHealthTickRunnable, ADAPTER_HEALTH_TICK_INTERVAL_MS)
            // v0.3 Stage 0c wave 3F — start native-side recovery watchdog
            // (§8.3). Idempotent. First fire is one full interval out so the
            // tick emitter has a chance to register a baseline tick before
            // the watchdog reads the staleness clock.
            mainHandler.removeCallbacks(adapterRecoveryRunnable)
            mainHandler.postDelayed(adapterRecoveryRunnable, ADAPTER_RECOVERY_CHECK_INTERVAL_MS)
        } else {
            Log.d(TAG, "GATT Server already running, skip re-init")
        }
        Log.i(TAG, "IgniRelay Data Mule service started")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        mainHandler.removeCallbacks(preparedWriteSweepRunnable)
        mainHandler.removeCallbacks(adapterHealthTickRunnable)
        mainHandler.removeCallbacks(adapterRecoveryRunnable)
        preparedWriteBuffers.clear()
        preparedWriteTimestamps.clear()
        stopBlePeripheral()
        if (instance === this) instance = null
        Log.i(TAG, "IgniRelay Data Mule service stopped")
        super.onDestroy()
    }

    /**
     * v0.3 Stage 0c wave 3B — public entry point for Dart-side v2 chunked
     * notify pushes. Called by MainActivity's `notifyEventChunk` MethodChannel
     * handler. Returns true on accept by the BLE stack (size <= per-device
     * MTU); false on reject (oversize / unknown peer / GATT server down).
     *
     * Spec: docs/specs/native_transport_v1_2026-05-13.md §4.5 — every byte
     * written here is a single 18B-header-framed chunk; the chunker that
     * produced these bytes lives in Dart.
     */
    fun notifyEventChunkToCentral(deviceAddress: String, chunkBytes: ByteArray): Boolean {
        val device = notifySubscribers[deviceAddress]
        if (device == null) {
            Log.w(TAG, "notifyEventChunkToCentral: no subscriber for $deviceAddress")
            return false
        }
        val char = eventCharRef
        if (char == null) {
            Log.w(TAG, "notifyEventChunkToCentral: eventCharRef is null")
            return false
        }
        return safeSingleNotify(device, char, chunkBytes, kind = "v2_chunk")
    }

    // ── Notification ──────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "IgniRelay 資料騾模式",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "持續在背景廣播 Mesh 節點以轉送救援資訊"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, openIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("IgniRelay 資料騾運作中")
            .setContentText("正在廣播 Mesh 節點，協助轉送救援資訊")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    // ── BLE Peripheral (GATT Server + Advertising) ───────────────────────

    /** 建構 IgniRelay GATT Service（提取為獨立函式供重試使用） */
    private fun buildIgniRelayService(): BluetoothGattService {
        val service = BluetoothGattService(
            IgniRelayConstants.SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        // Event characteristic (read/write/notify)
        val eventChar = BluetoothGattCharacteristic(
            IgniRelayConstants.EVENT_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
                BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        eventChar.addDescriptor(BluetoothGattDescriptor(
            IgniRelayConstants.CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or
                BluetoothGattDescriptor.PERMISSION_WRITE
        ))
        service.addCharacteristic(eventChar)

        // Bloom filter characteristic (read + write)
        // Bug 10 Fix: 加 PROPERTY_WRITE，讓 Central 可以寫入自己的 Bloom Filter，
        // Server 比對後只 Notify 推 Central 缺少的事件（差量推送），取代盲推全部。
        service.addCharacteristic(BluetoothGattCharacteristic(
            IgniRelayConstants.BLOOM_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_READ or
                BluetoothGattCharacteristic.PERMISSION_WRITE
        ))

        // Handshake characteristic (read/write)
        service.addCharacteristic(BluetoothGattCharacteristic(
            IgniRelayConstants.HANDSHAKE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_READ or
                BluetoothGattCharacteristic.PERMISSION_WRITE
        ))

        return service
    }

    private fun startBlePeripheral() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT)
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "BLUETOOTH_CONNECT not granted")
            return
        }

        val btManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter ?: return
        if (!adapter.isEnabled) {
            Log.w(TAG, "Bluetooth is off")
            return
        }

        // ── GATT Server（唯一實例，Bug 2 Fix）──
        gattServer = btManager.openGattServer(this, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                val stateStr = if (newState == BluetoothProfile.STATE_CONNECTED) "connected" else "disconnected"
                Log.d(TAG, "GATT: ${device.address} -> $stateStr (status=$status)")
                // Stage 0c wave 3E — connection state churn is a clear GATT
                // op signal; refresh the adapter health clock.
                emitAdapterTick(TICK_GATT_OP)
                // 清除已斷線裝置的狀態
                if (newState != BluetoothProfile.STATE_CONNECTED) {
                    notifySubscribers.remove(device.address)
                    bloomReceivedDevices.remove(device.address)
                    helloReadyDevices.remove(device.address)
                    deviceMtuMap.remove(device.address)
                    preparedWriteBuffers.keys.filter { it.startsWith(device.address) }.forEach {
                        preparedWriteBuffers.remove(it)
                        preparedWriteTimestamps.remove(it)
                    }
                }
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "ble_peer",
                        "state" to stateStr,
                        "device" to device.address
                    ))
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice, requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean, responseNeeded: Boolean,
                offset: Int, value: ByteArray
            ) {
                Log.d(TAG, "onWriteReq: dev=${device.address} char=${characteristic.uuid} prep=$preparedWrite resp=$responseNeeded off=$offset len=${value.size}")
                emitAdapterTick(TICK_GATT_OP)

                if (preparedWrite) {
                    // Buffer chunks for Execute Write (Long Write support)
                    val key = "${device.address}:${characteristic.uuid}"
                    val buffer = preparedWriteBuffers.getOrPut(key) { ByteArrayOutputStream() }
                    if (offset == 0) buffer.reset()
                    buffer.write(value)
                    preparedWriteTimestamps[key] = System.currentTimeMillis()
                    if (responseNeeded) {
                        gattServer?.sendResponse(device, requestId,
                            BluetoothGatt.GATT_SUCCESS, offset, value)
                    }
                } else {
                    // Stage 6-fix：HANDSHAKE_CHAR 必須先驗證再回 response，response status
                    // 即承載驗證結果（GATT_SUCCESS = PIN 正確；GATT_FAILURE = 不對）。
                    // 其他 char 維持「先回 success 再處理」的原有行為以避免影響 outbox 路徑。
                    if (characteristic.uuid == IgniRelayConstants.HANDSHAKE_CHAR_UUID) {
                        val verified = processCharacteristicWriteWithResult(device, value)
                        if (responseNeeded) {
                            val status = if (verified) BluetoothGatt.GATT_SUCCESS
                                         else BluetoothGatt.GATT_FAILURE
                            gattServer?.sendResponse(device, requestId, status, offset, value)
                        }
                    } else {
                        if (responseNeeded) {
                            gattServer?.sendResponse(device, requestId,
                                BluetoothGatt.GATT_SUCCESS, offset, value)
                        }
                        processCharacteristicWrite(device, characteristic.uuid, value)
                    }
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice, requestId: Int,
                offset: Int, characteristic: BluetoothGattCharacteristic
            ) {
                Log.d(TAG, "onReadReq: dev=${device.address} char=${characteristic.uuid} off=$offset")
                emitAdapterTick(TICK_GATT_OP)
                val responseBytes = when (characteristic.uuid) {
                    IgniRelayConstants.BLOOM_CHAR_UUID -> {
                        val bloom = sharedBloomBytes
                        Log.d(TAG, "Bloom read: bloomLen=${bloom.size} offset=$offset")
                        if (offset < bloom.size) bloom.copyOfRange(offset, bloom.size) else ByteArray(0)
                    }
                    else -> ByteArray(0)
                }
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, responseBytes)
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice, requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean, responseNeeded: Boolean,
                offset: Int, value: ByteArray
            ) {
                Log.d(TAG, "onDescWriteReq: dev=${device.address} desc=${descriptor.uuid}")
                // Bug 8 Fix: 必須儲存 descriptor value，否則 BLE stack 不知道 Central 已 subscribe，
                // notifyCharacteristicChanged 會靜默失敗（API 33+ 永遠回傳 SUCCESS 但不送通知）
                @Suppress("DEPRECATION")
                descriptor.value = value
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
                }

                // Bug 10 Fix: subscribe 時只記錄訂閱者，不再盲推全部事件。
                // 推送改由 Bloom Write 觸發（pushDiffToDevice），做差量比對後才推。
                // 如果 Central 10 秒內沒寫 Bloom（舊版 client），才降級盲推。
                if (descriptor.uuid == IgniRelayConstants.CCCD_UUID &&
                    descriptor.characteristic?.uuid == IgniRelayConstants.EVENT_CHAR_UUID
                ) {
                    val isEnableNotify = value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                    if (isEnableNotify) {
                        Log.i(TAG, "Notify subscribed by ${device.address} (waiting for Bloom write to trigger diff push)")
                        notifySubscribers[device.address] = device
                        // v0.3 Stage 0c wave 3A — peripheral-side service-discovery-complete
                        // proxy: when the central has subscribed to our notify, it has
                        // discovered our service. Combined with MTU (already on or arriving
                        // via onMtuChanged), this is the §5.2 trigger to send HELLO.
                        emitPeerReadyForHelloIfReady(device.address, role = "peripheral")
                        // 10 秒後若還沒收到 Bloom Write，降級盲推（向下相容舊版 Central）
                        mainHandler.postDelayed({
                            if (notifySubscribers.containsKey(device.address) &&
                                !bloomReceivedDevices.contains(device.address)) {
                                Log.w(TAG, "No Bloom received from ${device.address} after 10s → fallback blind push")
                                pushOutboxToDevice(device)
                            }
                        }, 10_000)
                    } else {
                        Log.d(TAG, "Notify unsubscribed by ${device.address}")
                        notifySubscribers.remove(device.address)
                        bloomReceivedDevices.remove(device.address)
                    }
                }
            }

            // Prepared Write Execute: assemble buffered chunks and process
            override fun onExecuteWrite(device: BluetoothDevice, requestId: Int, execute: Boolean) {
                Log.d(TAG, "onExecuteWrite: dev=${device.address} execute=$execute")
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)

                val keysForDevice = preparedWriteBuffers.keys.filter { it.startsWith(device.address) }
                if (execute) {
                    for (key in keysForDevice) {
                        val buffer = preparedWriteBuffers.remove(key) ?: continue
                        preparedWriteTimestamps.remove(key)
                        val data = buffer.toByteArray()
                        val charUuidStr = key.substringAfter(":")
                        try {
                            val charUuid = java.util.UUID.fromString(charUuidStr)
                            Log.i(TAG, "ExecuteWrite: assembled ${data.size} bytes for char=$charUuidStr")
                            mainHandler.post { processCharacteristicWrite(device, charUuid, data) }
                        } catch (e: Exception) {
                            Log.e(TAG, "ExecuteWrite parse error: ${e.message}")
                        }
                    }
                } else {
                    // Cancel: discard buffers
                    for (key in keysForDevice) {
                        preparedWriteBuffers.remove(key)
                        preparedWriteTimestamps.remove(key)
                    }
                }
            }

            // Bug 4 Fix: addService 是非同步的，必須等 onServiceAdded 成功後才能開始廣播
            // 否則 Central 連進來時 service 尚未註冊，characteristics 全是 null
            override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
                val ok = status == BluetoothGatt.GATT_SUCCESS
                gattServiceReady = ok
                gattServiceStatus = status
                Log.i(TAG, "onServiceAdded: status=$status ok=$ok uuid=${service?.uuid}")
                // Bug 7: 儲存 Event Characteristic 參考（供 Notify 推送使用）
                if (ok && service != null) {
                    eventCharRef = service.getCharacteristic(IgniRelayConstants.EVENT_CHAR_UUID)
                    Log.d(TAG, "eventCharRef saved: ${eventCharRef != null}")
                }
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "gatt_service_added",
                        "status" to status,
                        "success" to ok
                    ))
                }
                if (ok) {
                    // Service 註冊成功，現在才可以安全地開始廣播
                    Log.i(TAG, "Service registered OK, starting advertising...")
                    startAdvertisingInternal()
                } else if (serviceAddRetryCount < 3) {
                    serviceAddRetryCount++
                    Log.w(TAG, "addService FAILED (status=$status), retrying (attempt $serviceAddRetryCount)...")
                    mainHandler.postDelayed({
                        try {
                            gattServer?.clearServices()
                            gattServer?.addService(buildIgniRelayService())
                        } catch (e: Exception) {
                            Log.e(TAG, "Retry addService error: ${e.message}")
                        }
                    }, 1000L * serviceAddRetryCount)  // 更長的延遲，給 BLE stack 恢復時間
                } else {
                    Log.e(TAG, "addService FAILED after ${serviceAddRetryCount} retries, giving up")
                    mainHandler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "gatt_server_error",
                            "error" to "addService_failed_after_retries",
                            "status" to status
                        ))
                    }
                }
            }

            // Bug 8 Fix: 追蹤 notification 是否真的送達 BLE 層
            // 之前只靠 timer 判斷 NOTIFY_PUSH_DONE，但 notifyCharacteristicChanged
            // 在 API 33+ 永遠回傳 SUCCESS，即使實際沒送出。
            // onNotificationSent 是唯一可靠的送達確認。
            override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
                val ok = status == BluetoothGatt.GATT_SUCCESS
                Log.d(TAG, "onNotificationSent: dev=${device?.address} status=$status ok=$ok")
                emitAdapterTick(TICK_GATT_OP)
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "notify_sent",
                        "device" to (device?.address ?: ""),
                        "status" to status,
                        "ok" to ok
                    ))
                }
            }

            // 診斷: MTU 協商結果
            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
                // v0.3 Stage 0c wave 3E — apply debugForceTargetMtu clamp
                // BEFORE storing / surfacing the value so all downstream
                // sizing (safeSingleNotify, gatt_mtu Dart event,
                // peer_ready_for_hello) sees the clamped MTU. Spec §7.4.
                val effectiveMtu = if (device != null) {
                    applyMtuOverride(device.address, mtu)
                } else {
                    mtu
                }
                if (effectiveMtu != mtu) {
                    Log.i(TAG, "MTU clamped by debug override: dev=${device?.address} actual=$mtu effective=$effectiveMtu")
                } else {
                    Log.d(TAG, "MTU changed: dev=${device?.address} mtu=$mtu")
                }
                emitAdapterTick(TICK_GATT_OP)
                // v0.3 Stage 0c2: track per-device MTU so safeSingleNotify() can
                // size notify payloads dynamically rather than via a hard-coded cap.
                if (device != null) {
                    deviceMtuMap[device.address] = effectiveMtu
                }
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "gatt_mtu",
                        "device" to (device?.address ?: ""),
                        "mtu" to effectiveMtu
                    ))
                }
                // v0.3 Stage 0c wave 3A — MTU side of the HELLO trigger.
                // If the central had already subscribed, this is the second
                // half of the §5.2 trigger pair; emit now.
                if (device != null) {
                    emitPeerReadyForHelloIfReady(device.address, role = "peripheral")
                }
            }
        })

        // ── 檢查 openGattServer 結果 ──
        if (gattServer == null) {
            Log.e(TAG, "openGattServer returned NULL!")
            mainHandler.post {
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "gatt_server_error",
                    "error" to "openGattServer_null"
                ))
            }
            return
        }

        // ── Build & Register IgniRelay GATT Service ──
        // Bug 4 Fix: addService 是非同步的！不能在這裡立即開始廣播。
        // 必須等 onServiceAdded callback 確認成功後才能廣播。
        // 否則 Central 連進來時 service/characteristics 尚未註冊完成。
        serviceAddRetryCount = 0
        gattServiceReady = false
        gattServiceStatus = -999

        // 先快取 adapter，供 startAdvertisingInternal 使用
        bleAdvertiser = adapter.bluetoothLeAdvertiser

        val service = buildIgniRelayService()
        val addResult = gattServer?.addService(service)
        Log.d(TAG, "addService initiated: result=$addResult (waiting for onServiceAdded callback...)")
        if (addResult != true) {
            Log.e(TAG, "addService returned false!")
            mainHandler.post {
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "gatt_server_error",
                    "error" to "addService_false"
                ))
            }
        }
        // 注意：廣播在 onServiceAdded 成功後才啟動，不在這裡！
    }

    /**
     * 啟動 BLE 廣播（僅在 onServiceAdded 成功後呼叫）
     *
     * Bug 4 Fix: 這個方法從 onServiceAdded callback 中呼叫，
     * 確保 GATT Service 已完全註冊後才開始廣播。
     */
    private fun startAdvertisingInternal() {
        if (isAdvertising) return

        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_ADVERTISE)
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "BLUETOOTH_ADVERTISE not granted")
            return
        }

        if (bleAdvertiser == null) {
            Log.e(TAG, "bleAdvertiser is null, cannot advertise")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(android.os.ParcelUuid(IgniRelayConstants.SERVICE_UUID))
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                isAdvertising = true
                Log.i(TAG, "BLE advertising started (after service confirmed ready)")
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "ble_advertising",
                        "state" to "started"
                    ))
                }
            }
            override fun onStartFailure(errorCode: Int) {
                isAdvertising = false
                Log.e(TAG, "BLE advertising failed: errorCode=$errorCode")
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "gatt_server_error",
                        "error" to "advertise_failed",
                        "status" to errorCode
                    ))
                }
            }
        }

        bleAdvertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    // ── Bug 7: Notify 反向推送 ─────────────────────────────────────────────
    /**
     * 把預快取的 outbox 事件透過 Notify 推送給指定 Central
     *
     * 當 OPPO (Central) 連上我方 GATT Server 並 subscribe Event Char 通知時呼叫。
     * OPPO 的 GATT Server 壞掉（read/write 都 timeout），但 Central 角色正常。
     * v0.3 Stage 0c wave 3A — emit `peer_ready_for_hello` exactly once per
     * connection. Both the MTU upcall and the CCCD ENABLE_NOTIFY descriptor
     * write must have happened (in either order) before we report ready.
     *
     * Spec: docs/specs/native_transport_v1_2026-05-13.md §5.2 — the 5 s
     * fallback timer in Dart starts from this event.
     */
    private fun emitPeerReadyForHelloIfReady(deviceAddress: String, role: String) {
        if (helloReadyDevices.contains(deviceAddress)) return
        val mtu = deviceMtuMap[deviceAddress] ?: return
        if (!notifySubscribers.containsKey(deviceAddress)) return
        helloReadyDevices.add(deviceAddress)
        Log.i(TAG, "peer_ready_for_hello: dev=$deviceAddress mtu=$mtu role=$role")
        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "peer_ready_for_hello",
                "device" to deviceAddress,
                "mtu" to mtu,
                "role" to role
            ))
        }
    }

    /**
     * 透過 Notify 反向推送，讓 OPPO 能「透過 Central 角色」接收資料。
     *
     * 使用 onNotificationSent callback 做流量控制（等前一個 notification 送完再送下一個），
     * 避免 BLE stack 溢出丟包。
     */
    private fun pushOutboxToDevice(device: BluetoothDevice) {
        // Bug 12 Fix: snapshot 避免 ConcurrentModificationException
        val events = sharedOutboxEvents.toList()
        val char = eventCharRef
        if (char == null || events.isEmpty()) {
            Log.d(TAG, "pushOutbox: skip (char=${char != null}, events=${events.size})")
            return
        }

        Log.i(TAG, "pushOutbox: pushing ${events.size} events to ${device.address}")
        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "notify_push_start",
                "device" to device.address,
                "count" to events.size
            ))
        }

        // Bug 8 Fix: 逐筆推送，每筆間隔 100ms 避免 BLE 壅塞
        // 加入 notifyCharacteristicChanged 回傳值診斷日誌
        var successCount = 0
        var failCount = 0
        for ((index, event) in events.withIndex()) {
            mainHandler.postDelayed({
                if (!notifySubscribers.containsKey(device.address)) {
                    Log.d(TAG, "pushOutbox: ${device.address} disconnected, abort at event $index")
                    return@postDelayed
                }
                try {
                    // v0.3 Stage 0c2: legacy hard-cap silent truncation replaced with
                    // safeSingleNotify() — sizes against the per-device MTU and REJECTS
                    // oversize payloads with explicit notify_push_error instead of
                    // silently corrupting them. Spec: native_transport_v1 §2.
                    val ok = safeSingleNotify(device, char, event, kind = "pushOutbox")
                    if (ok) successCount++ else failCount++
                } catch (e: Exception) {
                    failCount++
                    Log.e(TAG, "pushOutbox: notify failed at event $index: ${e.message}")
                    mainHandler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "notify_push_error",
                            "device" to device.address,
                            "index" to index,
                            "error" to (e.message ?: "unknown")
                        ))
                    }
                }
            }, (index * 150L)) // Bug 13 Fix: 150ms 間隔（加大，給 BLE stack 更多處理時間）
        }

        // 推送完成通知 Dart（含成功/失敗計數）
        mainHandler.postDelayed({
            Log.i(TAG, "pushOutbox DONE: ${device.address} success=$successCount fail=$failCount")
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "notify_push_done",
                "device" to device.address,
                "count" to events.size,
                "success" to successCount,
                "fail" to failCount
            ))
        }, (events.size * 150L) + 300)
    }

    /**
     * Stage 6-fix：解析 `{pin, resourceId}` JSON、SHA-256 + resourceId 比對、
     * emit `handoff_result` 事件、回傳驗證結果（供 onCharacteristicWriteRequest
     * 用 GATT response status 把結果傳回 requester central）。
     */
    private fun verifyAndEmitHandshake(device: BluetoothDevice, value: ByteArray): Boolean {
        Log.d(TAG, "HANDSHAKE_WRITE from ${device.address}: ${value.size} bytes")
        var success = false
        var resourceId = ""
        try {
            val json = org.json.JSONObject(String(value, Charsets.UTF_8))
            val pin = json.optString("pin")
            val writeResId = json.optString("resourceId")
            val storedHash = MainActivity.sharedHandoffPinHash
            val storedRes = MainActivity.sharedHandoffResourceId
            if (pin.isNotEmpty() && storedHash != null && storedRes != null) {
                val hash = java.security.MessageDigest.getInstance("SHA-256")
                    .digest(pin.toByteArray(Charsets.UTF_8))
                    .joinToString("") { "%02x".format(it) }
                resourceId = writeResId
                success = (hash == storedHash && writeResId == storedRes)
            }
        } catch (e: Exception) {
            Log.w(TAG, "HANDSHAKE payload not JSON: ${e.message}")
        }
        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "handoff_result",
                "device" to device.address,
                "resourceId" to resourceId,
                "success" to success
            ))
        }
        return success
    }

    /** 直接寫入路徑：HANDSHAKE_CHAR 把驗證結果回給 caller，其餘 char fire-and-forget。 */
    private fun processCharacteristicWriteWithResult(device: BluetoothDevice, value: ByteArray): Boolean {
        return verifyAndEmitHandshake(device, value)
    }

    // ── 統一的 Characteristic Write 處理 ─────────────────────────────────
    /** 處理完整的 characteristic write（包含直接寫入和 Prepared Write 組裝後的資料） */
    private fun processCharacteristicWrite(device: BluetoothDevice, charUuid: java.util.UUID, value: ByteArray) {
        when (charUuid) {
            IgniRelayConstants.BLOOM_CHAR_UUID -> {
                // 偵測 IBLT 控制碼（首字節 0x01）
                if (value.isNotEmpty() && value[0] == 0x01.toByte()) {
                    Log.i(TAG, "IBLT_REQUEST from ${device.address}: ${value.size} bytes")
                    mainHandler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "bloom_received",
                            "device" to device.address,
                            "size" to value.size,
                            "is_iblt" to true
                        ))
                    }
                    handleIBLTRequest(device, value)
                } else {
                    Log.i(TAG, "BLOOM_WRITE from ${device.address}: ${value.size} bytes → diff push")
                    mainHandler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "bloom_received",
                            "device" to device.address,
                            "size" to value.size
                        ))
                    }
                    pushDiffToDevice(device, value)
                }
            }
            // Stage 6 (commit #10)：HANDSHAKE_CHAR_UUID 從原本 fall-through `else`
            // 抽出成顯式 branch；驗證 `{pin, resourceId}` 後 emit 統一型別
            // `handoff_result`，與 iOS BlePlugin.swift `peripheralManager` 對齊。
            // Dart 端 physical_handoff 監聽此事件以判斷交接成功。
            //
            // Stage 6-fix：把驗證結果額外回給 caller（onCharacteristicWriteRequest
            // 用 GATT response status 把結果傳回 requester）。
            IgniRelayConstants.HANDSHAKE_CHAR_UUID -> {
                verifyAndEmitHandshake(device, value)
            }
            else -> {
                Log.d(TAG, "EVENT_WRITE from ${device.address}: ${value.size} bytes")
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "ble_data",
                        "device" to device.address,
                        "data" to value.toList()
                    ))
                }
            }
        }
    }

    /** 處理 IBLT Fast Path 請求：建構本機 IBLT 並回應 */
    private fun handleIBLTRequest(device: BluetoothDevice, value: ByteArray) {
        try {
            if (value.size < 9) {
                Log.w(TAG, "IBLT packet too short: ${value.size}")
                return
            }

            val char = eventCharRef
            if (char == null) {
                Log.w(TAG, "IBLT: eventCharRef is null, cannot respond")
                return
            }

            // Build local IBLT from outbox events
            // Bug 12 Fix: 取得 snapshot 避免 ConcurrentModificationException
            // (Dart 端可能在 iteration 中透過 updateEventOutbox 更新 sharedOutboxEvents)
            val eventsSnapshot = sharedOutboxEvents.toList()
            val localIblt = IBLT()
            val eventIds = mutableSetOf<String>()
            for (event in eventsSnapshot) {
                val eventId = tryExtractEventId(event)
                if (eventId != null) {
                    localIblt.insert(eventId)
                    eventIds.add(eventId)
                }
            }

            // Pack IBLT response: control(1) + watermark(8) + iblt(504) = 513 bytes.
            // Fits any negotiated MTU >= 517 single-notify (MTU-3 ATT header). For
            // smaller MTU peers safeSingleNotify rejects with notify_push_error
            // rather than the legacy silent truncation. Spec: native_transport_v1 §2.
            //
            // v0.3 Stage 0c wave 3E-r2 — IBLT low-MTU fallback fix:
            // At MTU=185 / MTU=247 (the §7.1 MUST-support baselines) the
            // 513-byte response does NOT fit in one notify. Previously the
            // code unconditionally added the device to `bloomReceivedDevices`
            // AFTER the failed notify, which also suppressed the 10-second
            // blind-push fallback in `onDescriptorWriteRequest` — net effect
            // was the central learning about NOTHING. The fix below:
            //   1. Only mark `bloomReceivedDevices` when the IBLT response
            //      actually went out, OR when we ran the Bloom diff fallback
            //      below (which itself answered the request fully).
            //   2. When the response is too big, treat the IBLT payload as
            //      a "device-has-something" hint and run pushOutboxToDevice
            //      so the central still receives all our events the next
            //      pass. Future wave: chunk the IBLT response via Chunker
            //      with a new control byte; receiver-side support lands at
            //      the same time. Tracked in CapabilityProfileSpec.
            //      supportsIblt (capability_profile.dart) and
            //      native_transport_v1 §6.1.2 note.
            val localIbltBytes = localIblt.toBytes()
            val responseLen = 1 + 8 + minOf(localIbltBytes.size, IBLT.TOTAL_BYTES)
            val mtuCap = maxSingleNotifyBytes(device.address)
            if (responseLen > mtuCap) {
                Log.w(TAG, "IBLT response ${responseLen}B exceeds MTU cap ${mtuCap}B for ${device.address}; falling back to blind push")
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "iblt_low_mtu_fallback",
                        "device" to device.address,
                        "response_size" to responseLen,
                        "mtu_cap" to mtuCap,
                        "event_count" to eventIds.size
                    ))
                }
                // Run the existing blind push so the central receives all
                // outbox events in this round-trip. This is bandwidth-suboptimal
                // vs. a proper chunked IBLT response, but it is CORRECT —
                // the central learns the full set, just without the IBLT
                // delta optimization. Mark bloomReceived so the 10-s timer
                // fallback in onDescriptorWriteRequest does not double-push.
                bloomReceivedDevices.add(device.address)
                pushOutboxToDevice(device)
                return
            }
            val response = ByteArray(responseLen)
            response[0] = 0x01 // kControlIBLT
            // Watermark: use 0 (Kotlin side doesn't track chat watermark separately)
            System.arraycopy(localIbltBytes, 0, response, 9,
                minOf(localIbltBytes.size, IBLT.TOTAL_BYTES))

            // Send IBLT response via safe MTU-aware notify
            val ibltSent = safeSingleNotify(device, char, response, kind = "ibltResponse")
            Log.i(TAG, "IBLT response sent to ${device.address}: ${response.size}B, events=${eventIds.size}, ok=$ibltSent")

            if (ibltSent) {
                // Only mark as bloom received when the IBLT response actually
                // went out; otherwise let the 10-s fallback path retry via
                // blind push (the wave 3E-r1 unconditional mark caused
                // silent sync stalls at low MTU).
                bloomReceivedDevices.add(device.address)
            } else {
                Log.w(TAG, "IBLT notify rejected for ${device.address}; falling back to blind push")
                bloomReceivedDevices.add(device.address)
                pushOutboxToDevice(device)
            }
        } catch (e: Exception) {
            Log.e(TAG, "IBLT handling error: ${e.message}", e)
        }
    }

    // ── Bloom Filter Bit-Vector 工具 ─────────────────────────────────────

    /** 檢測 bytes 是否帶有 bit-vector bloom magic header */
    private fun hasBloomMagic(bytes: ByteArray): Boolean {
        if (bytes.size < 4) return false
        return bytes[0] == 0xFF.toByte() && bytes[1] == 0xBF.toByte() &&
               bytes[2] == 0x02.toByte() && bytes[3] == 0x00.toByte()
    }

    /** 簡易 MurmurHash3（32-bit）— 與 Dart 端完全一致 */
    private fun murmurHash(s: String, seed: Int): Int {
        var h = seed
        for (c in s.toCharArray()) {
            var k = c.code
            k = (k.toLong() * 0xcc9e2d51L and 0xFFFFFFFFL).toInt()
            k = (k shl 15) or (k ushr 17)
            k = (k.toLong() * 0x1b873593L and 0xFFFFFFFFL).toInt()
            h = h xor k
            h = (h shl 13) or (h ushr 19)
            h = (h.toLong() * 5L + 0xe6546b64L and 0xFFFFFFFFL).toInt()
        }
        h = h xor s.length
        h = h xor (h ushr 16)
        h = (h.toLong() * 0x85ebca6bL and 0xFFFFFFFFL).toInt()
        h = h xor (h ushr 13)
        h = (h.toLong() * 0xc2b2ae35L and 0xFFFFFFFFL).toInt()
        h = h xor (h ushr 16)
        return h
    }

    /** 從事件 ID 集合建構 bit-vector Bloom Filter（含 magic header） */
    private fun buildBitVectorBloom(eventIds: Set<String>): ByteArray {
        val bits = ByteArray(BLOOM_SIZE_BYTES + 4)
        bits[0] = 0xFF.toByte(); bits[1] = 0xBF.toByte(); bits[2] = 0x02; bits[3] = 0x00
        for (id in eventIds) {
            for (i in 0 until BLOOM_HASH_COUNT) {
                val hash = (murmurHash(id, i).toLong() and 0xFFFFFFFFL) % (BLOOM_SIZE_BYTES * 8)
                val idx = hash.toInt()
                bits[4 + (idx shr 3)] = (bits[4 + (idx shr 3)].toInt() or (1 shl (idx and 7))).toByte()
            }
        }
        return bits
    }

    /** 檢查 bloom filter 是否可能包含指定 event ID */
    private fun bloomMayContain(bloom: ByteArray, eventId: String): Boolean {
        val offset = if (hasBloomMagic(bloom)) 4 else 0
        val size = bloom.size - offset
        if (size <= 0) return false
        for (i in 0 until BLOOM_HASH_COUNT) {
            val hash = (murmurHash(eventId, i).toLong() and 0xFFFFFFFFL) % (size * 8)
            val idx = hash.toInt()
            if ((bloom[offset + (idx shr 3)].toInt() and (1 shl (idx and 7))) == 0) return false
        }
        return true
    }

    // ── Bug 10: 差量推送（Bloom 比對後推送 Central 缺少的事件 + 本機 Bloom）──
    /**
     * 收到 Central 寫入的 Bloom Filter 後，比對差量，只推 Central 缺少的事件。
     * 推送結尾「若塞得下單次 notify」會附加本機 Bloom，讓 Central 知道本機已有哪些
     * 事件，反向用 GATT Write 補送 Peripheral 缺少的事件。反向 Bloom 是最佳化、非
     * 必需（細節見下方組裝 allPackets 處的註解）。
     *
     * 支援兩種格式：
     * - 新版 bit-vector：帶 magic [0xFF, 0xBF, 0x02, 0x00]，用 bloomMayContain 比對
     * - 舊版文字格式：換行分隔的 event ID 列表（向下相容）
     *
     * 協議格式：
     * - 事件封包：正常 Protobuf MeshEvent bytes
     * - 本機 Bloom（可選）：前綴 4 bytes magic [0xFF, 0xB1, 0x00, 0x4D] + Bloom bytes
     * - 結束標記：[0xFF, 0xE7, 0xD0, 0x7E]（"END" magic）
     */
    private fun pushDiffToDevice(device: BluetoothDevice, remoteBloomBytes: ByteArray) {
        bloomReceivedDevices.add(device.address)

        val char = eventCharRef
        if (char == null) {
            Log.w(TAG, "pushDiff: eventCharRef is null, skip")
            return
        }

        val isBitVector = hasBloomMagic(remoteBloomBytes)

        // 舊格式 fallback：換行分隔的 event ID 列表
        val remoteEventIds: Set<String> = if (!isBitVector) {
            try {
                String(remoteBloomBytes, Charsets.UTF_8)
                    .split("\n")
                    .filter { it.isNotBlank() }
                    .toSet()
            } catch (_: Exception) { emptySet() }
        } else emptySet()

        // Bug 12 Fix: snapshot 避免 ConcurrentModificationException
        val events = sharedOutboxEvents.toList()
        // 比對差量：只推 Central 沒有的事件
        val diffEvents = mutableListOf<ByteArray>()
        var bloomSkipped = 0
        for (event in events) {
            // 嘗試從 Protobuf 中提取 event_id 做比對
            val eventId = tryExtractEventId(event)
            if (eventId != null) {
                val alreadyHas = if (isBitVector) {
                    bloomMayContain(remoteBloomBytes, eventId)
                } else {
                    remoteEventIds.contains(eventId)
                }
                if (alreadyHas) {
                    bloomSkipped++
                    continue
                }
            }
            diffEvents.add(event)
        }

        val bloomFmt = if (isBitVector) "bitvec(${remoteBloomBytes.size}B)" else "text(${remoteEventIds.size}ids)"
        Log.i(TAG, "pushDiff: ${device.address} bloom=$bloomFmt total=${events.size} skip=$bloomSkipped diff=${diffEvents.size}")

        // 需要推送的封包：差量事件 +（可選）反向本機 Bloom + 結束標記
        val endMarker = byteArrayOf(0xFF.toByte(), 0xE7.toByte(), 0xD0.toByte(), 0x7E)

        // 反向 Bloom（把本機 bloom 反推回 Central）：讓 Central 回寫本機缺少的事件時
        // 能先做去重，省一點頻寬。但這是同步「最佳化」，不是正確性必需 —— Central 收
        // 不到反向 bloom 時 remoteEventIds 會是空集合，於是回寫全部事件，再由本機收端
        // 的 event_id 去重（seenEvents + DB-dup）兜底，系統仍會收斂。
        //
        // 問題：BLE notify 不能分片（不像 GATT Write 有 Long Write），而反向封包固定為
        // 4(magic) + 2052(sharedBloomBytes，本身已含 4-byte bloom magic) = 2056B，
        // 遠大於單次 notify 上限 minOf(MTU-3, 512)=512B —— 任何 MTU 都塞不下。過去這包
        // 一律被 safeSingleNotify 以 oversize 擋下，每次同步都噴一筆誤導性的
        // notify_push_error 並灌大 failCount，讓 logcat 看起來像真的送失敗。
        //
        // 修法：塞得下才送（保留最佳化）；塞不下就 skip 並記一行 info（不再當成錯誤）。
        // 真正「任意 MTU 都送」的完整版需要對反向 bloom 做 chunk 分片 + Dart/iOS 收端
        // 組裝，屬於新 wire 格式，這裡不做。
        val bloomPacket = byteArrayOf(0xFF.toByte(), 0xB1.toByte(), 0x00, 0x4D) + sharedBloomBytes
        val bloomCap = maxSingleNotifyBytes(device.address)
        val includeBloom = bloomPacket.size <= bloomCap
        if (!includeBloom) {
            Log.i(TAG, "pushDiff: ${device.address} local bloom reverse-push skipped " +
                "(${bloomPacket.size}B > cap ${bloomCap}B; peer dedup handled by receive-side)")
        }

        val allPackets = if (includeBloom) {
            diffEvents + listOf(bloomPacket, endMarker)
        } else {
            diffEvents + listOf(endMarker)
        }

        mainHandler.post {
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "notify_push_start",
                "device" to device.address,
                "count" to diffEvents.size,
                "bloom_skip" to bloomSkipped,
                "mode" to "diff"
            ))
        }

        var successCount = 0
        var failCount = 0
        for ((index, packet) in allPackets.withIndex()) {
            mainHandler.postDelayed({
                if (!notifySubscribers.containsKey(device.address)) {
                    Log.d(TAG, "pushDiff: ${device.address} disconnected, abort at packet $index")
                    return@postDelayed
                }
                try {
                    // v0.3 Stage 0c2: legacy hard-cap silent truncation replaced with
                    // safeSingleNotify() (per-device MTU sizing). Spec: native_transport_v1 §2.
                    val ok = safeSingleNotify(device, char, packet, kind = "pushDiff")
                    if (ok) successCount++ else failCount++
                } catch (e: Exception) {
                    failCount++
                    Log.e(TAG, "pushDiff: notify failed at packet $index: ${e.message}")
                }
            }, (index * 150L)) // Bug 13 Fix: 150ms 間隔
        }

        mainHandler.postDelayed({
            Log.i(TAG, "pushDiff DONE: ${device.address} events=${diffEvents.size} bloom_skip=$bloomSkipped success=$successCount fail=$failCount")
            MainActivity.sharedEventSink?.success(mapOf(
                "type" to "notify_push_done",
                "device" to device.address,
                "count" to diffEvents.size,
                "bloom_skip" to bloomSkipped,
                "success" to successCount,
                "fail" to failCount,
                "mode" to "diff"
            ))
        }, (allPackets.size * 150L) + 300)
    }

    /** 嘗試從 Protobuf MeshEvent bytes 中提取 event_id */
    private fun tryExtractEventId(data: ByteArray): String? {
        return try {
            // Protobuf field 1 (event_id) = tag 0x0A + length + string
            // 簡易解析：找 tag byte 0x0A，下一 byte 是長度，後面是 UTF-8 string
            if (data.size > 2 && data[0] == 0x0A.toByte()) {
                val len = data[1].toInt() and 0xFF
                if (data.size >= 2 + len) {
                    String(data, 2, len, Charsets.UTF_8)
                } else null
            } else null
        } catch (_: Exception) { null }
    }

    private fun stopBlePeripheral() {
        try {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_ADVERTISE)
                == PackageManager.PERMISSION_GRANTED) {
                advertiseCallback?.let { bleAdvertiser?.stopAdvertising(it) }
            }
        } catch (_: Exception) {}
        gattServer?.close()
        gattServer = null
        bleAdvertiser = null
        advertiseCallback = null
        isAdvertising = false
        gattServiceReady = false
        notifySubscribers.clear()
        bloomReceivedDevices.clear()
        deviceMtuMap.clear()
        eventCharRef = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // v0.3 Stage 0c2 — MTU-aware notify path
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §2 (P0 truncation removal)
    //       and §4 (chunk framing).
    //
    // Replaces the legacy hard-cap silent truncation. The maximum single-notify
    // byte count is derived from the per-device negotiated MTU (tracked in
    // `deviceMtuMap` via `onMtuChanged`). Oversized payloads are EITHER chunk-
    // framed via the v0.3 Chunker or REJECTED with an explicit
    // `notify_push_error` event — never silently truncated.
    // ─────────────────────────────────────────────────────────────────────────

    /** Single-notify ATT cap for a peer.
     *
     * Android also enforces the BLE attribute-value ceiling. Even when the
     * negotiated ATT payload budget is larger than the IBLT response, notifying
     * 513 B can still throw `IllegalArgumentException: notification should not
     * be longer than max length of an attribute value`. Clamp both limits so
     * callers fall back before entering the platform stack.
     */
    private fun maxSingleNotifyBytes(deviceAddress: String): Int {
        val mtu = deviceMtuMap[deviceAddress] ?: defaultMtuFallback
        val attPayloadCap = mtu - IgniRelayConstants.ATT_HEADER_SIZE
        return minOf(attPayloadCap, 512)
    }

    /**
     * Send a single notify payload that fits in one ATT PDU.
     *
     * Returns true when the BLE stack accepts the bytes; false when the bytes
     * exceed the per-device MTU cap (rejected — never truncated). Logs an
     * explicit `notify_push_error` to Dart on rejection so the symptom surfaces
     * instead of being silently corrupted (the legacy notify-truncation bug).
     */
    private fun safeSingleNotify(
        device: BluetoothDevice,
        char: BluetoothGattCharacteristic,
        payload: ByteArray,
        kind: String,
    ): Boolean {
        val cap = maxSingleNotifyBytes(device.address)
        if (payload.size > cap) {
            Log.w(TAG, "$kind: oversize payload (${payload.size}B > MTU-${IgniRelayConstants.ATT_HEADER_SIZE}=$cap) for ${device.address}; rejecting")
            mainHandler.post {
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "notify_push_error",
                    "device" to device.address,
                    "error" to "oversize-payload",
                    "kind" to kind,
                    "size" to payload.size,
                    "cap" to cap,
                ))
            }
            return false
        }
        val result: Any = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gattServer?.notifyCharacteristicChanged(device, char, false, payload) ?: -1
            } else {
                @Suppress("DEPRECATION")
                char.value = payload
                @Suppress("DEPRECATION")
                gattServer?.notifyCharacteristicChanged(device, char, false) ?: false
            }
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "$kind: platform rejected notify (${payload.size}B, cap=$cap) for ${device.address}: ${e.message}")
            mainHandler.post {
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "notify_push_error",
                    "device" to device.address,
                    "error" to "platform-rejected-payload",
                    "kind" to kind,
                    "size" to payload.size,
                    "cap" to cap,
                    "message" to (e.message ?: ""),
                ))
            }
            return false
        }
        Log.d(TAG, "$kind: notify → ${device.address} size=${payload.size} cap=$cap result=$result")
        return result == 0 || result == true
    }
}
