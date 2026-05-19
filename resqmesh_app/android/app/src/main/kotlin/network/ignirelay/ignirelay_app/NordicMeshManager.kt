package network.ignirelay.ignirelay_app

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import no.nordicsemi.android.ble.BleManager
import no.nordicsemi.android.ble.callback.DataReceivedCallback
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Nordic BLE Library 封裝 — Android Central 角色
 *
 * 使用 Nordic BLE Library 處理掃描、連線、讀寫，
 * 取代 flutter_blue_plus 的 Android 端 Central 實作，
 * 解決跨廠牌（MediaTek / Qualcomm / Exynos）相容性問題。
 *
 * Bug 1 修復：掃描不使用 withServices 硬體過濾器，
 * 改用軟體過濾，避免 MediaTek 晶片的 128-bit UUID 過濾 bug。
 */
class NordicMeshManager(private val context: Context) {

    companion object {
        private const val TAG = "NordicMesh"
    }

    private var scanner: BluetoothLeScanner? = null
    private var scanCallback: ScanCallback? = null
    private var isScanning = false
    private val mainHandler = Handler(Looper.getMainLooper())

    // 活躍連線池：deviceAddress -> IgniRelayBleClient
    private val connections = ConcurrentHashMap<String, IgniRelayBleClient>()

    // ── Scanning ──────────────────────────────────────────────────────────

    /**
     * 啟動 BLE 掃描（軟體過濾，不依賴硬體 UUID filter）
     *
     * Bug 1 Fix: MediaTek 晶片對 128-bit UUID 的硬體掃描過濾有 bug，
     * Pixel (Qualcomm) ↔ 小米 (MediaTek) 互相看不到。
     * 改為掃描所有 BLE 裝置，收到結果後軟體比對 Service UUID。
     */
    fun startScan(): Boolean {
        if (isScanning) return true

        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_SCAN)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "BLUETOOTH_SCAN not granted")
            return false
        }

        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter ?: return false
        if (!adapter.isEnabled) return false

        scanner = adapter.bluetoothLeScanner ?: return false

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                // v0.3 Stage 0c wave 3E — every scan callback proves the
                // BLE scanner is alive; refresh the adapter-health clock
                // before we filter for our service. Spec §8.2.
                IgniRelayForegroundService.emitAdapterTick(
                    IgniRelayForegroundService.TICK_SCAN
                )
                // 軟體過濾：檢查廣播封包是否包含我們的 Service UUID
                val serviceUuids = result.scanRecord?.serviceUuids
                val hasOurService = serviceUuids?.any {
                    it.uuid == IgniRelayConstants.SERVICE_UUID
                } == true

                if (hasOurService) {
                    mainHandler.post {
                        MainActivity.sharedEventSink?.success(
                            mapOf(
                                "type" to "nordic_found",
                                "device" to result.device.address,
                                "rssi" to result.rssi
                            )
                        )
                    }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed: errorCode=$errorCode")
                isScanning = false
            }
        }

        // null filters = 掃描所有 BLE 裝置（軟體過濾）
        scanner?.startScan(null, settings, scanCallback)
        isScanning = true
        Log.i(TAG, "Nordic scan started (software UUID filtering)")
        return true
    }

    fun stopScan() {
        if (!isScanning) return
        try {
            if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_SCAN)
                == PackageManager.PERMISSION_GRANTED
            ) {
                scanCallback?.let { scanner?.stopScan(it) }
            }
        } catch (e: Exception) {
            Log.w(TAG, "stopScan error: ${e.message}")
        }
        isScanning = false
        scanCallback = null
        Log.i(TAG, "Nordic scan stopped")
    }

    // ── Connection ────────────────────────────────────────────────────────

    /**
     * 連線到指定裝置（Nordic BLE Library 自動處理跨廠牌相容性）
     *
     * Nordic 內建：
     * - 自動 retry + backoff
     * - 自動 MTU 協商 (517)
     * - 自動服務發現
     * - 自動啟用 Event Characteristic 通知
     *
     * @param deviceAddress BLE MAC address
     * @param callback 連線結果回調 (true=成功, false=失敗)
     */
    fun connect(deviceAddress: String, callback: (Boolean) -> Unit) {
        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_CONNECT)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "BLUETOOTH_CONNECT not granted")
            callback(false)
            return
        }

        val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter
        if (adapter == null) {
            callback(false)
            return
        }

        val device = adapter.getRemoteDevice(deviceAddress)
        val client = IgniRelayBleClient(context)

        // 設定通知回調：Nordic 自動啟用 notify 後，收到的資料轉發到 Flutter
        client.onNotificationReceived = { data ->
            mainHandler.post {
                MainActivity.sharedEventSink?.success(
                    mapOf(
                        "type" to "nordic_data",
                        "device" to deviceAddress,
                        "data" to data.toList()
                    )
                )
            }
        }

        connections[deviceAddress] = client

        client.connect(device)
            .retry(3, 200)
            .useAutoConnect(false)
            .timeout(10000)
            .done {
                Log.i(TAG, "Connected to $deviceAddress via Nordic")
                // v0.3 Stage 0c wave 3A — central-side HELLO trigger.
                // Nordic's done{} fires after initialize() completes, which
                // means MTU negotiation AND service discovery + notification
                // setup are all done. This is the §5.2 trigger to start the
                // 5 s fallback timer on the Dart side.
                //
                // Wave 3E — apply the debugForceTargetMtu clamp here so
                // the central-side path reports the same effective MTU as
                // the peripheral-side path (spec §7.4).
                val rawMtu = client.negotiatedMtu
                val mtu = IgniRelayForegroundService.applyMtuOverride(deviceAddress, rawMtu)
                if (mtu != rawMtu) {
                    Log.i(TAG, "Central MTU clamped: dev=$deviceAddress actual=$rawMtu effective=$mtu")
                }
                IgniRelayForegroundService.emitAdapterTick(
                    IgniRelayForegroundService.TICK_GATT_OP
                )
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(
                        mapOf(
                            "type" to "peer_ready_for_hello",
                            "device" to deviceAddress,
                            "mtu" to mtu,
                            "role" to "central"
                        )
                    )
                    callback(true)
                }
            }
            .fail { _, status ->
                Log.e(TAG, "Connect failed to $deviceAddress: status=$status")
                connections.remove(deviceAddress)
                mainHandler.post { callback(false) }
            }
            .enqueue()
    }

    // ── Read / Write ──────────────────────────────────────────────────────

    /**
     * 讀取對端 Bloom Filter Characteristic
     */
    fun readBloom(deviceAddress: String, callback: (ByteArray?) -> Unit) {
        val client = connections[deviceAddress]
        if (client == null) {
            callback(null)
            return
        }
        client.readBloom { data ->
            mainHandler.post { callback(data) }
        }
    }

    /**
     * Bug 10 Fix: 寫入本機 Bloom Filter 到對端 Bloom Characteristic
     * 讓對端比對差量後只 Notify 推送缺少的事件。
     */
    fun writeBloom(deviceAddress: String, data: ByteArray, callback: (Boolean) -> Unit) {
        val client = connections[deviceAddress]
        if (client == null) {
            callback(false)
            return
        }
        client.writeBloom(data) { success ->
            mainHandler.post { callback(success) }
        }
    }

    /**
     * 寫入事件到對端 Event Characteristic
     */
    fun writeEvent(deviceAddress: String, data: ByteArray, callback: (Boolean) -> Unit) {
        val client = connections[deviceAddress]
        if (client == null) {
            callback(false)
            return
        }
        client.writeEvent(data) { success ->
            mainHandler.post { callback(success) }
        }
    }

    /**
     * Stage 6-fix：寫入交接 PIN/resourceId JSON 到對端 Handshake Characteristic。
     * 對應 IgniRelayForegroundService 的 onCharacteristicWriteRequest 對 HANDSHAKE_CHAR
     * 的處理：Provider 端做 SHA-256 比對後以 GATT response status 回報結果。
     * Central 端的 callback 把該 status 翻譯回 success/false。
     */
    fun writeHandshake(deviceAddress: String, data: ByteArray, callback: (Boolean) -> Unit) {
        val client = connections[deviceAddress]
        if (client == null) {
            callback(false)
            return
        }
        client.writeHandshake(data) { success ->
            mainHandler.post { callback(success) }
        }
    }

    /**
     * 斷開指定裝置
     */
    fun disconnect(deviceAddress: String) {
        connections[deviceAddress]?.let { client ->
            client.disconnect().enqueue()
            connections.remove(deviceAddress)
            Log.d(TAG, "Disconnected $deviceAddress")
        }
    }

    /**
     * 釋放所有資源
     */
    fun destroy() {
        stopScan()
        connections.values.forEach {
            try {
                it.disconnect().enqueue()
            } catch (_: Exception) {}
        }
        connections.clear()
    }
}

// ── Nordic BLE Client（單一裝置連線管理）─────────────────────────────────

/**
 * IgniRelay 專用的 Nordic BleManager 子類
 *
 * 每個實例管理一條 BLE 連線。
 * Nordic BLE Library 自動處理：
 * - 各廠牌 GATT 行為差異
 * - 連線重試 + 超時
 * - MTU 協商
 * - 服務發現
 */
class IgniRelayBleClient(context: Context) : BleManager(context) {

    companion object {
        private const val TAG = "NordicClient"
    }

    private var eventChar: BluetoothGattCharacteristic? = null
    private var bloomChar: BluetoothGattCharacteristic? = null
    private var handshakeChar: BluetoothGattCharacteristic? = null

    /** 通知資料回調（由 NordicMeshManager 設定） */
    var onNotificationReceived: ((ByteArray) -> Unit)? = null

    /**
     * v0.3 Stage 0c wave 3A — captured MTU from requestMtu().with{}.
     * Defaults to the BLE 4.0 baseline (23) so callers always get a sane
     * value even if the request callback hasn't fired yet.
     */
    var negotiatedMtu: Int = 23
        private set

    override fun getGattCallback(): BleManagerGattCallback = IgniRelayGattCallback()

    private inner class IgniRelayGattCallback : BleManagerGattCallback() {

        override fun isRequiredServiceSupported(gatt: BluetoothGatt): Boolean {
            val service = gatt.getService(IgniRelayConstants.SERVICE_UUID) ?: return false
            eventChar = service.getCharacteristic(IgniRelayConstants.EVENT_CHAR_UUID)
            bloomChar = service.getCharacteristic(IgniRelayConstants.BLOOM_CHAR_UUID)
            handshakeChar = service.getCharacteristic(IgniRelayConstants.HANDSHAKE_CHAR_UUID)
            // Bloom + Event 是必要的，Handshake 是可選的
            return eventChar != null && bloomChar != null
        }

        override fun onServicesInvalidated() {
            eventChar = null
            bloomChar = null
            handshakeChar = null
        }

        override fun initialize() {
            // MTU 協商（517，BLE 5.0+）
            // v0.3 Stage 0c wave 3A — capture the actually negotiated MTU so
            // NordicMeshManager can include it in the peer_ready_for_hello
            // event (§5.2).
            requestMtu(IgniRelayConstants.REQUEST_MTU)
                .with { _, mtu -> negotiatedMtu = mtu }
                .enqueue()

            // 自動啟用 Event Characteristic 通知
            eventChar?.let { char ->
                setNotificationCallback(char)
                    .with(DataReceivedCallback { _, data ->
                        data.value?.let { bytes ->
                            onNotificationReceived?.invoke(bytes)
                        }
                    })
                enableNotifications(char)
                    .enqueue()
            }
        }
    }

    // ── Public API（供 NordicMeshManager 呼叫）─────────────────────────────

    fun readBloom(callback: (ByteArray?) -> Unit) {
        val char = bloomChar
        if (char == null) {
            Log.e(TAG, "readBloom: bloomChar is NULL (service discovery failed?)")
            Handler(Looper.getMainLooper()).post {
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "gatt_op_fail",
                    "op" to "read_bloom",
                    "status" to -1,
                    "reason" to "bloomChar_null"
                ))
            }
            callback(null)
            return
        }

        // Bug 6 Fix: Handler-based 5s timeout — Nordic BLE Library 沒有 .timeout() API，
        // 改用 Handler.postDelayed 實作。OPPO/ColorOS GATT Server 不回應 read requests，
        // 5s 後觸發 timeout 讓 Dart 端進入 blind relay 模式（發送全部事件）。
        val handler = Handler(Looper.getMainLooper())
        var callbackFired = false

        val timeoutRunnable = Runnable {
            if (!callbackFired) {
                callbackFired = true
                Log.w(TAG, "readBloom TIMEOUT (5s) — remote GATT Server not responding to read")
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "gatt_op_fail",
                    "op" to "read_bloom",
                    "status" to -2,
                    "reason" to "timeout_5s"
                ))
                callback(null)
            }
        }
        handler.postDelayed(timeoutRunnable, 5000)

        readCharacteristic(char)
            .with(DataReceivedCallback { _, data ->
                if (!callbackFired) {
                    callbackFired = true
                    handler.removeCallbacks(timeoutRunnable)
                    callback(data.value)
                }
            })
            .fail { _: BluetoothDevice, status: Int ->
                if (!callbackFired) {
                    callbackFired = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.e(TAG, "readBloom failed: status=$status")
                    handler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "gatt_op_fail",
                            "op" to "read_bloom",
                            "status" to status
                        ))
                    }
                    callback(null)
                }
            }
            .enqueue()
    }

    /** Bug 10 Fix: 寫入本機 Bloom Filter 到對端 Bloom Characteristic */
    /** Bug 13 Fix: 加上 .split() 啟用 Long Write (Prepared Write)，
     *  否則 data > MTU-3 的寫入會直接 fail 或造成 BLE stack 崩潰 */
    fun writeBloom(data: ByteArray, callback: (Boolean) -> Unit) {
        val char = bloomChar
        if (char == null) {
            Log.e(TAG, "writeBloom: bloomChar is NULL")
            callback(false)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var callbackFired = false

        val timeoutRunnable = Runnable {
            if (!callbackFired) {
                callbackFired = true
                Log.w(TAG, "writeBloom TIMEOUT (8s) data=${data.size}B")
                handler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "gatt_op_fail",
                        "op" to "write_bloom",
                        "status" to -2,
                        "reason" to "timeout_8s",
                        "size" to data.size
                    ))
                }
                callback(false)
            }
        }
        handler.postDelayed(timeoutRunnable, 8000) // 加長到 8s，Long Write 需要更多時間

        Log.d(TAG, "writeBloom: ${data.size}B → Long Write (split enabled)")
        writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
            .split() // Bug 13 Fix: 啟用自動分包（Long Write / Prepared Write）
            .done {
                if (!callbackFired) {
                    callbackFired = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.d(TAG, "writeBloom OK: ${data.size}B")
                    callback(true)
                }
            }
            .fail { _: BluetoothDevice, status: Int ->
                if (!callbackFired) {
                    callbackFired = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.e(TAG, "writeBloom failed: status=$status size=${data.size}B")
                    handler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "gatt_op_fail",
                            "op" to "write_bloom",
                            "status" to status,
                            "size" to data.size
                        ))
                    }
                    callback(false)
                }
            }
            .enqueue()
    }

    /**
     * Stage 6-fix：對端 HANDSHAKE_CHAR 寫入。Provider 端 GATT server 收到後做
     * SHA-256 + resourceId 比對；驗證結果以 BluetoothGattServer.sendResponse 的
     * status 回報——GATT_SUCCESS = 通過、其他 = 失敗。Central 端在這個 callback
     * 收到 .done / .fail 來判定 PIN 驗證結果。
     */
    fun writeHandshake(data: ByteArray, callback: (Boolean) -> Unit) {
        val char = handshakeChar
        if (char == null) {
            Log.e(TAG, "writeHandshake: handshakeChar is NULL")
            callback(false)
            return
        }
        val handler = Handler(Looper.getMainLooper())
        var fired = false
        val timeoutRunnable = Runnable {
            if (!fired) {
                fired = true
                Log.w(TAG, "writeHandshake TIMEOUT (5s) data=${data.size}B")
                callback(false)
            }
        }
        handler.postDelayed(timeoutRunnable, 5000)

        Log.d(TAG, "writeHandshake: ${data.size}B → ${char.uuid}")
        writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
            .done {
                if (!fired) {
                    fired = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.d(TAG, "writeHandshake OK (PIN verified by provider)")
                    callback(true)
                }
            }
            .fail { _: BluetoothDevice, status: Int ->
                if (!fired) {
                    fired = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.w(TAG, "writeHandshake REJECTED status=$status (PIN mismatch likely)")
                    callback(false)
                }
            }
            .enqueue()
    }

    fun writeEvent(data: ByteArray, callback: (Boolean) -> Unit) {
        val char = eventChar
        if (char == null) {
            Log.e(TAG, "writeEvent: eventChar is NULL (service discovery failed?)")
            Handler(Looper.getMainLooper()).post {
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "gatt_op_fail",
                    "op" to "write",
                    "status" to -1,
                    "reason" to "eventChar_null"
                ))
            }
            callback(false)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var callbackFired = false

        val timeoutRunnable = Runnable {
            if (!callbackFired) {
                callbackFired = true
                Log.w(TAG, "writeEvent TIMEOUT (8s) data=${data.size}B")
                MainActivity.sharedEventSink?.success(mapOf(
                    "type" to "gatt_op_fail",
                    "op" to "write",
                    "status" to -2,
                    "reason" to "timeout_8s",
                    "size" to data.size
                ))
                callback(false)
            }
        }
        handler.postDelayed(timeoutRunnable, 8000) // Bug 13 Fix: 加長 timeout

        // Bug 13 Fix: 加 .split() 啟用 Long Write，避免大事件寫入失敗
        writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
            .split()
            .done {
                if (!callbackFired) {
                    callbackFired = true
                    handler.removeCallbacks(timeoutRunnable)
                    callback(true)
                }
            }
            .fail { _: BluetoothDevice, status: Int ->
                if (!callbackFired) {
                    callbackFired = true
                    handler.removeCallbacks(timeoutRunnable)
                    Log.e(TAG, "writeEvent failed: status=$status size=${data.size}B")
                    handler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "gatt_op_fail",
                            "op" to "write",
                            "status" to status,
                            "size" to data.size
                        ))
                    }
                    callback(false)
                }
            }
            .enqueue()
    }
}
