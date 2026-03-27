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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
    }

    private var nordicManager: NordicMeshManager? = null
    private var dataMuleServiceRunning = false

    // Bloom Filter 快取（由 Dart 端推送更新）
    @Volatile
    private var localBloomBytes: ByteArray = ByteArray(0)

    // 交接 PIN 狀態
    private var handoffResourceId: String? = null
    private var handoffPinHash: String? = null

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
                        handoffResourceId = call.argument<String>("resourceId")
                        handoffPinHash = call.argument<String>("pinHash")
                        startDataMuleService()
                        Log.d(TAG, "Handoff advertising started for resource: $handoffResourceId")
                        result.success(true)
                    }
                    "sendHandoffPin" -> {
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
        return hash == handoffPinHash && resourceId == handoffResourceId
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
