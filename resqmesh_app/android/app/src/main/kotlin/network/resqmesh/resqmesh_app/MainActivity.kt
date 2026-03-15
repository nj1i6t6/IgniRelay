package network.resqmesh.resqmesh_app

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.wifi.aware.*
import android.os.*
import android.provider.Settings
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "network.resqmesh/native"
        private const val EVENT_CHANNEL = "network.resqmesh/events"
        private const val TAG = "ResQMesh"

        private val RESQMESH_SERVICE_UUID = UUID.fromString("f47a7b20-2d0a-11ee-be56-0242ac120002")
        private val EVENT_CHAR_UUID = UUID.fromString("f47a7b21-2d0a-11ee-be56-0242ac120002")
        private val BLOOM_CHAR_UUID = UUID.fromString("f47a7b22-2d0a-11ee-be56-0242ac120002")
        private val HANDSHAKE_CHAR_UUID = UUID.fromString("f47a7b23-2d0a-11ee-be56-0242ac120002")
        private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private var bleAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var wifiAwareManager: WifiAwareManager? = null
    private var wifiAwareSession: WifiAwareSession? = null
    private var nativeEventSink: EventChannel.EventSink? = null
    private var dataMuleServiceRunning = false
    // 交接 PIN 狀態
    private var handoffResourceId: String? = null
    private var handoffPinHash: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryLevel" -> {
                        val bm = getSystemService(BATTERY_SERVICE) as BatteryManager
                        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        result.success(level)
                    }
                    "isWifiAwareSupported" -> {
                        val supported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_AWARE)
                        } else false
                        result.success(supported)
                    }
                    "startBleAdvertising" -> {
                        startBleGattServer()
                        startBleAdvertising()
                        result.success(true)
                    }
                    "stopBleAdvertising" -> {
                        stopBleAdvertising()
                        result.success(true)
                    }
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
                    "startBleRelayMode" -> {
                        // BLE Relay = GATT Server + Advertising (低耗電背景模式)
                        startBleGattServer()
                        startBleAdvertising()
                        result.success(true)
                    }
                    "stopAllServices" -> {
                        stopBleAdvertising()
                        stopDataMuleService()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            wifiAwareSession?.close()
                            wifiAwareSession = null
                        }
                        result.success(true)
                    }
                    "requestHighBandwidthTransfer" -> {
                        // 目前透過 WiFi Aware message 傳送
                        // 完整版可使用 WiFi Aware Network Specifier
                        result.success(false) // TODO: implement
                    }
                    // ── 跨裝置 PIN 交接方法 ──
                    "startHandoffAdvertising" -> {
                        handoffResourceId = call.argument<String>("resourceId")
                        handoffPinHash = call.argument<String>("pinHash")
                        startBleGattServer()
                        startBleAdvertising()
                        Log.d(TAG, "Handoff advertising started for resource: $handoffResourceId")
                        result.success(true)
                    }
                    "sendHandoffPin" -> {
                        // Requester 端：發送 PIN 到 Provider
                        // 實際上透過 BLE Central 連線到 Provider 的 GATT 寫入
                        val pin = call.argument<String>("pin") ?: ""
                        val resId = call.argument<String>("resourceId") ?: ""
                        val verified = verifyHandoffPin(pin, resId)
                        result.success(verified)
                    }
                    "stopHandoffAdvertising" -> {
                        handoffResourceId = null
                        handoffPinHash = null
                        result.success(true)
                    }
                    "startWifiAwarePublish" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startWifiAwarePublish(result)
                        } else {
                            result.error("UNSUPPORTED", "WiFi Aware requires Android 8+", null)
                        }
                    }
                    "stopWifiAware" -> {
                        wifiAwareSession?.close()
                        wifiAwareSession = null
                        result.success(true)
                    }
                    // ── 前景服務 & 電池優化 ──
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
                            // 嘗試開啟電池優化設定頁面
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // fallback: 開啟一般設定
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
                        // 各大廠私有電源管理頁面
                        val opened = openManufacturerPowerSettings()
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nativeEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    nativeEventSink = null
                }
            })
    }

    // ── BLE GATT Server (Peripheral / Advertiser) ─────────────────────────────

    private fun startBleGattServer() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "BLUETOOTH_CONNECT not granted, skipping GATT server")
            return
        }

        val btManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter ?: return
        if (!adapter.isEnabled) return

        gattServer = btManager.openGattServer(this, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                val stateStr = if (newState == BluetoothProfile.STATE_CONNECTED) "connected" else "disconnected"
                runOnUiThread {
                    nativeEventSink?.success(mapOf(
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
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }

                // 判斷是否為交接 PIN 驗證請求
                if (characteristic.uuid == HANDSHAKE_CHAR_UUID && handoffPinHash != null) {
                    val receivedStr = String(value, Charsets.UTF_8)
                    if (receivedStr.startsWith("VERIFY|")) {
                        val parts = receivedStr.split("|")
                        if (parts.size >= 3) {
                            val resId = parts[1]
                            val pinHashFromRequester = parts[2]
                            val match = (resId == handoffResourceId && pinHashFromRequester == handoffPinHash)
                            Log.d(TAG, "Handoff PIN verification: match=$match for resource=$resId")
                            runOnUiThread {
                                nativeEventSink?.success(mapOf(
                                    "type" to "handoff_result",
                                    "resourceId" to resId,
                                    "success" to match,
                                    "device" to device.address
                                ))
                            }
                        }
                    }
                }

                // 通知 Flutter 端收到 BLE 資料
                runOnUiThread {
                    nativeEventSink?.success(mapOf(
                        "type" to "ble_data",
                        "device" to device.address,
                        "data" to value.toList()
                    ))
                }
                Log.d(TAG, "Received ${value.size} bytes from ${device.address}")
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice, requestId: Int,
                offset: Int, characteristic: BluetoothGattCharacteristic
            ) {
                // Return empty bloom filter bytes
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, ByteArray(0))
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice, requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean, responseNeeded: Boolean,
                offset: Int, value: ByteArray
            ) {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }
        })

        // Build ResQMesh primary service
        val service = BluetoothGattService(RESQMESH_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // Event characteristic (read/write/notify)
        val eventChar = BluetoothGattCharacteristic(
            EVENT_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        eventChar.addDescriptor(BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        ))
        service.addCharacteristic(eventChar)

        // Bloom filter characteristic (read-only)
        service.addCharacteristic(BluetoothGattCharacteristic(
            BLOOM_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        ))

        // Handshake characteristic (read/write)
        service.addCharacteristic(BluetoothGattCharacteristic(
            HANDSHAKE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        ))

        gattServer?.addService(service)
        Log.d(TAG, "GATT server started with ResQMesh service")
    }

    private fun startBleAdvertising() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADVERTISE)
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "BLUETOOTH_ADVERTISE not granted, skipping advertising")
            return
        }

        val btManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        bleAdvertiser = btManager.adapter?.bluetoothLeAdvertiser
        if (bleAdvertiser == null) {
            Log.w(TAG, "BLE advertising not supported on this device")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0) // Advertise indefinitely
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(android.os.ParcelUuid(RESQMESH_SERVICE_UUID))
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.i(TAG, "BLE advertising started successfully")
                runOnUiThread {
                    nativeEventSink?.success(mapOf("type" to "ble_advertising", "state" to "started"))
                }
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "BLE advertising failed with error code: $errorCode")
            }
        }

        bleAdvertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    private fun stopBleAdvertising() {
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADVERTISE)
                == PackageManager.PERMISSION_GRANTED) {
                advertiseCallback?.let { bleAdvertiser?.stopAdvertising(it) }
            }
        } catch (_: Exception) {}
        gattServer?.close()
        gattServer = null
        bleAdvertiser = null
        advertiseCallback = null
        Log.d(TAG, "BLE advertising stopped")
    }

    // ── WiFi Aware (Android 8+, API 26+) ──────────────────────────────────────

    @RequiresApi(Build.VERSION_CODES.O)
    private fun startWifiAwarePublish(result: MethodChannel.Result) {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_AWARE)) {
            result.error("UNSUPPORTED", "WiFi Aware not supported on this device", null)
            return
        }
        wifiAwareManager = getSystemService(Context.WIFI_AWARE_SERVICE) as? WifiAwareManager
        if (wifiAwareManager == null) {
            result.error("UNAVAILABLE", "WiFi Aware service unavailable", null)
            return
        }

        wifiAwareManager?.attach(object : AttachCallback() {
            override fun onAttached(session: WifiAwareSession) {
                wifiAwareSession = session
                Log.d(TAG, "WiFi Aware session attached")

                val config = PublishConfig.Builder()
                    .setServiceName("ResQMesh")
                    .build()

                session.publish(config, object : DiscoverySessionCallback() {
                    override fun onPublishStarted(session: PublishDiscoverySession) {
                        Log.i(TAG, "WiFi Aware publish started")
                        runOnUiThread {
                            nativeEventSink?.success(mapOf("type" to "wifi_aware", "state" to "publishing"))
                            result.success(true)
                        }
                    }
                    override fun onMessageReceived(peerHandle: PeerHandle, message: ByteArray) {
                        Log.d(TAG, "WiFi Aware: received ${message.size} bytes")
                        runOnUiThread {
                            nativeEventSink?.success(mapOf(
                                "type" to "wifi_aware_data",
                                "data" to message.toList()
                            ))
                        }
                    }
                    override fun onSessionConfigFailed() {
                        Log.e(TAG, "WiFi Aware publish config failed")
                        runOnUiThread { result.error("PUBLISH_FAILED", "WiFi Aware publish failed", null) }
                    }
                }, null)
            }

            override fun onAttachFailed() {
                Log.e(TAG, "WiFi Aware attach failed")
                result.error("ATTACH_FAILED", "WiFi Aware attach failed", null)
            }
        }, null)
    }

    // ── Foreground Service (Data Mule) ────────────────────────────────────────

    private fun startDataMuleService(): Boolean {
        return try {
            val intent = Intent(this, ResQMeshForegroundService::class.java)
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
        stopService(Intent(this, ResQMeshForegroundService::class.java))
        dataMuleServiceRunning = false
        Log.i(TAG, "Data Mule service stopped")
    }

    // ── PIN 驗證 (Requester 端在本地比對 Provider 的 pinHash) ──────────────

    private fun verifyHandoffPin(pin: String, resourceId: String): Boolean {
        // 在真正的跨裝置情境中，Requester 連線到 Provider 的 GATT
        // 讀取 handshake characteristic 取得 pinHash，然後本地比對
        // 簡化版：直接比對（同裝置測試用）
        val hash = java.security.MessageDigest.getInstance("SHA-256")
            .digest(pin.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return hash == handoffPinHash && resourceId == handoffResourceId
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    // ── 各大廠私有電源管理設定頁 ──────────────────────────────────────────────

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

        // 嘗試開啟各廠商頁面，失敗則 fallback 到一般電池設定
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }

        // Fallback: 開啟 Android 電池優化設定
        return try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        stopBleAdvertising()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            wifiAwareSession?.close()
        }
        super.onDestroy()
    }
}
