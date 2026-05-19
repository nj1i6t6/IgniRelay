package network.ignirelay.ignirelay_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 為什麼是 [FlutterFragmentActivity] 而不是 [io.flutter.embedding.android.FlutterActivity]？
 *
 * `health` plugin（13.x，cachet.plugins.health.HealthPlugin#onAttachedToActivity）會直接做：
 *
 *     (activity as ComponentActivity).registerForActivityResult(...)
 *
 * `FlutterActivity` 不是 `ComponentActivity`，這個強制 cast 會在 release 啟動的
 * `GeneratedPluginRegistrant.registerWith(...)` 路徑上拋 `ClassCastException`，
 * 雖然 Flutter 會 catch 住、不直接 crash，但 plugin 從此沒有 attach Activity，
 * 之後任何 Health Connect 權限 / 匯入流程都會因 launcher 不存在而失敗。
 *
 * `FlutterFragmentActivity` 繼承自 `androidx.fragment.app.FragmentActivity`，後者繼承
 * `ComponentActivity`，cast 成立、`registerForActivityResult` 可正常呼叫。
 *
 * 這也是 health plugin README 對 host activity 的明文要求。
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val METHOD_CHANNEL = "network.ignirelay/native"
        private const val EVENT_CHANNEL = "network.ignirelay/events"
        private const val TAG = "IgniRelay"

        /**
         * 共享 EventSink — 供 ForegroundService 轉發 GATT Server 收到的資料到 Flutter
         * Bug 3 Fix: ForegroundService 的 onCharacteristicWriteRequest 透過此 sink 發送事件
         */
        @Volatile
        @JvmStatic
        var sharedEventSink: EventChannel.EventSink? = null

        /**
         * Stage 6 (commit #10)：交接 PIN 狀態跨平台對齊。
         * - 由 `startHandoffAdvertising` (provider) 寫入。
         * - GATT Server 在 ForegroundService 收到 HANDSHAKE_CHAR 寫入時讀取
         *   並做 SHA-256 + resourceId 比對，發出 `handoff_result` 事件。
         * - 之前是 MainActivity instance fields，因 ForegroundService 跨進程無法
         *   直接存取；改為 companion 上的 @Volatile @JvmStatic 共享變數。
         */
        @Volatile
        @JvmStatic
        var sharedHandoffResourceId: String? = null

        @Volatile
        @JvmStatic
        var sharedHandoffPinHash: String? = null
    }

    private var nordicManager: NordicMeshManager? = null
    private var dataMuleServiceRunning = false

    // Bloom Filter 快取（由 Dart 端推送更新）
    @Volatile
    private var localBloomBytes: ByteArray = ByteArray(0)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化 Nordic BLE Manager
        nordicManager = NordicMeshManager(this)

        // ── EventChannel ──────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sharedEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    sharedEventSink = null
                }
            })

        // ── MethodChannel ─────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── 藍牙硬體狀態檢查 ──────────────────────────────────
                    "isBluetoothEnabled" -> {
                        val adapter = android.bluetooth.BluetoothManager::class.java
                            .let { getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager }
                            ?.adapter
                        result.success(adapter?.isEnabled ?: false)
                    }
                    "requestBluetoothEnable" -> {
                        try {
                            val enableBtIntent = Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE)
                            startActivity(enableBtIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.w(TAG, "requestBluetoothEnable failed: ${e.message}")
                            result.success(false)
                        }
                    }

                    // ── Nordic BLE Central 操作 ──────────────────────────
                    "startNordicScan" -> {
                        val success = nordicManager?.startScan() ?: false
                        result.success(success)
                    }
                    "stopNordicScan" -> {
                        nordicManager?.stopScan()
                        result.success(true)
                    }
                    "nordicConnect" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        if (deviceId.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        nordicManager?.connect(deviceId) { success ->
                            result.success(success)
                        }
                    }
                    "nordicDisconnect" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        nordicManager?.disconnect(deviceId)
                        result.success(true)
                    }
                    "nordicReadBloom" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        if (deviceId.isEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        nordicManager?.readBloom(deviceId) { data ->
                            result.success(data)
                        }
                    }
                    // Bug 10 Fix: 寫入本機 Bloom 到對端（觸發差量推送）
                    "nordicWriteBloom" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        val data = call.argument<ByteArray>("data")
                        if (deviceId.isEmpty() || data == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        nordicManager?.writeBloom(deviceId, data) { success ->
                            result.success(success)
                        }
                    }
                    "nordicWriteEvent" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        val data = call.argument<ByteArray>("data")
                        if (deviceId.isEmpty() || data == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        nordicManager?.writeEvent(deviceId, data) { success ->
                            result.success(success)
                        }
                    }
                    // v0.3 Stage 0c wave 3B — peripheral-side notify a single
                    // v2 chunk to a subscribed central. The chunker is in Dart;
                    // this method just forwards one PDU. See
                    // IgniRelayForegroundService.notifyEventChunkToCentral.
                    "notifyEventChunk" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        val data = call.argument<ByteArray>("data")
                        if (deviceId.isEmpty() || data == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val svc = IgniRelayForegroundService.instance
                        if (svc == null) {
                            Log.w(TAG, "notifyEventChunk: foreground service not running")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(svc.notifyEventChunkToCentral(deviceId, data))
                    }
                    // Stage 6-fix：requester 透過此 method 把 PIN+resourceId
                    // 寫到 provider 的 HANDSHAKE_CHAR；provider 的 GATT server 在
                    // IgniRelayForegroundService 做驗證後以 response status 回報結果。
                    "nordicWriteHandshake" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        val data = call.argument<ByteArray>("data")
                        if (deviceId.isEmpty() || data == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        nordicManager?.writeHandshake(deviceId, data) { success ->
                            result.success(success)
                        }
                    }

                    // ── Peripheral 角色（統一由 ForegroundService 管理）──
                    "startBleAdvertising" -> {
                        // Bug 2 Fix: GATT Server + Advertising 統一由 ForegroundService 管理
                        // 不再在 MainActivity 開第二個 GATT Server
                        result.success(startDataMuleService())
                    }
                    "stopBleAdvertising" -> {
                        stopDataMuleService()
                        result.success(true)
                    }
                    "startBleRelayMode" -> {
                        result.success(startDataMuleService())
                    }

                    // ── 基本查詢 ──────────────────────────────────────────
                    "getBatteryLevel" -> {
                        val bm = getSystemService(BATTERY_SERVICE) as BatteryManager
                        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        result.success(level)
                    }

                    // ── Foreground Service (Data Mule) ────────────────────
                    "startAndroidDataMuleMode", "startDataMuleMode" -> {
                        result.success(startDataMuleService())
                    }
                    "stopAndroidDataMuleMode" -> {
                        stopDataMuleService()
                        result.success(true)
                    }
                    "isDataMuleRunning" -> {
                        result.success(dataMuleServiceRunning)
                    }
                    "stopAllServices" -> {
                        nordicManager?.stopScan()
                        stopDataMuleService()
                        result.success(true)
                    }
                    "requestHighBandwidthTransfer" -> {
                        result.success(false)
                    }

                    // ── 跨裝置 PIN 交接方法 ────────────────────────────────
                    "startHandoffAdvertising" -> {
                        // Stage 6：寫到 companion 的 @JvmStatic 變數，讓
                        // IgniRelayForegroundService 能在 GATT 寫入回調直接讀取。
                        sharedHandoffResourceId = call.argument<String>("resourceId")
                        sharedHandoffPinHash = call.argument<String>("pinHash")
                        startDataMuleService()
                        Log.d(TAG, "Handoff advertising started for resource: $sharedHandoffResourceId")
                        result.success(true)
                    }
                    "sendHandoffPin" -> {
                        val pin = call.argument<String>("pin") ?: ""
                        val resId = call.argument<String>("resourceId") ?: ""
                        val verified = verifyHandoffPin(pin, resId)
                        result.success(verified)
                    }
                    "stopHandoffAdvertising" -> {
                        sharedHandoffResourceId = null
                        sharedHandoffPinHash = null
                        result.success(true)
                    }

                    // ── 前景服務 & 電池優化 ────────────────────────────────
                    "startMeshForegroundService" -> {
                        result.success(startDataMuleService())
                    }
                    "stopMeshForegroundService" -> {
                        stopDataMuleService()
                        result.success(true)
                    }
                    "isBatteryOptimizationExempt" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestBatteryOptimizationExemption" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Cannot request battery optimization exemption: ${e.message}")
                            result.success(false)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_SETTINGS)
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER.lowercase())
                    }
                    "openManufacturerPowerSettings" -> {
                        val opened = openManufacturerPowerSettings()
                        result.success(opened)
                    }
                    "updateBloomFilter" -> {
                        val bytes = call.argument<ByteArray>("bloom")
                        if (bytes != null) {
                            localBloomBytes = bytes
                            IgniRelayForegroundService.sharedBloomBytes = bytes
                            Log.d(TAG, "Bloom filter updated: ${bytes.size} bytes")
                        }
                        result.success(true)
                    }
                    // Bug 7 Fix: 更新事件 outbox（供 GATT Server Notify 反向推送使用）
                    // Dart 端把最近的事件序列化後推送到 native，GATT Server 在 Central
                    // subscribe 通知時主動推送，讓 OPPO (Central 角色) 能接收資料。
                    "updateEventOutbox" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data != null && data.isNotEmpty()) {
                            // 解析 length-prefix framed 格式: [4-byte len][event bytes] ...
                            val events = mutableListOf<ByteArray>()
                            var pos = 0
                            while (pos + 4 <= data.size) {
                                val len = ((data[pos].toInt() and 0xFF) shl 24) or
                                          ((data[pos + 1].toInt() and 0xFF) shl 16) or
                                          ((data[pos + 2].toInt() and 0xFF) shl 8) or
                                          (data[pos + 3].toInt() and 0xFF)
                                pos += 4
                                if (pos + len <= data.size) {
                                    events.add(data.copyOfRange(pos, pos + len))
                                    pos += len
                                } else break
                            }
                            IgniRelayForegroundService.sharedOutboxEvents = events
                            Log.d(TAG, "Event outbox updated: ${events.size} events")
                        } else {
                            IgniRelayForegroundService.sharedOutboxEvents = emptyList()
                        }
                        result.success(true)
                    }
                    "getGattServerStatus" -> {
                        result.success(mapOf(
                            "ready" to IgniRelayForegroundService.gattServiceReady,
                            "status" to IgniRelayForegroundService.gattServiceStatus
                        ))
                    }

                    // ── v0.3 Stage 0c wave 3E — 0d acceptance-gate debug hooks ──
                    //
                    // Spec: docs/specs/native_transport_v1_2026-05-13.md §7.4
                    // (force MTU) + §8.5 (force adapter idle).
                    //
                    // These two handlers are deliberately UNGATED on
                    // BuildConfig.DEBUG so the QA agent can drive the 0d
                    // gate against release-mode builds too (the gate exercises
                    // the production binary, not the debug binary). The
                    // impact of either hook is bounded: forceTargetMtu only
                    // CLAMPS the negotiated value the upper layers see, and
                    // forceAdapterIdle only SUPPRESSES the diagnostic ticks
                    // (no production code path reads them). Neither alters
                    // wire format or bypasses signature verification.

                    "debugForceTargetMtu" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        val targetMtu = call.argument<Int>("targetMtu")
                        if (deviceId.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        if (targetMtu == null) {
                            // Clear override
                            IgniRelayForegroundService.debugMtuOverrideByDevice.remove(deviceId)
                            Log.i(TAG, "debugForceTargetMtu: cleared override for $deviceId")
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        if (targetMtu < 23 || targetMtu > 512) {
                            Log.w(TAG, "debugForceTargetMtu: rejected mtu=$targetMtu out of [23,512]")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        IgniRelayForegroundService.debugMtuOverrideByDevice[deviceId] = targetMtu
                        Log.i(TAG, "debugForceTargetMtu: dev=$deviceId targetMtu=$targetMtu")
                        result.success(true)
                    }

                    "debugForceAdapterIdle" -> {
                        val durationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                        if (durationMs <= 0L) {
                            // Clear any active suppression.
                            IgniRelayForegroundService.adapterIdleSuppressedUntilMs = 0L
                            Log.i(TAG, "debugForceAdapterIdle: cleared")
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        val until = System.currentTimeMillis() + durationMs
                        IgniRelayForegroundService.adapterIdleSuppressedUntilMs = until
                        Log.i(TAG, "debugForceAdapterIdle: suppress until=$until (durMs=$durationMs)")
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Foreground Service (Data Mule) ────────────────────────────────────

    private fun startDataMuleService(): Boolean {
        return try {
            val intent = Intent(this, IgniRelayForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            dataMuleServiceRunning = true
            Log.i(TAG, "Data Mule foreground service started")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Data Mule service: ${e.message}")
            false
        }
    }

    private fun stopDataMuleService() {
        stopService(Intent(this, IgniRelayForegroundService::class.java))
        dataMuleServiceRunning = false
        Log.i(TAG, "Data Mule service stopped")
    }

    // ── PIN 驗證 ──────────────────────────────────────────────────────────

    private fun verifyHandoffPin(pin: String, resourceId: String): Boolean {
        val hash = java.security.MessageDigest.getInstance("SHA-256")
            .digest(pin.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return hash == sharedHandoffPinHash && resourceId == sharedHandoffResourceId
    }

    // ── 各大廠私有電源管理設定頁 ──────────────────────────────────────────

    private fun openManufacturerPowerSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intents = mutableListOf<Intent>()

        when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> {
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                })
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.miui.powerkeeper",
                        "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
                    )
                })
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                })
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity"
                    )
                })
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                })
            }
            manufacturer.contains("vivo") -> {
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                })
            }
            manufacturer.contains("samsung") -> {
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.battery.ui.BatteryActivity"
                    )
                })
            }
            manufacturer.contains("asus") -> {
                intents.add(Intent().apply {
                    component = android.content.ComponentName(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.autostart.AutoStartActivity"
                    )
                })
            }
        }

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        return try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (_: Exception) {
            false
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onDestroy() {
        nordicManager?.destroy()
        nordicManager = null
        super.onDestroy()
    }
}
