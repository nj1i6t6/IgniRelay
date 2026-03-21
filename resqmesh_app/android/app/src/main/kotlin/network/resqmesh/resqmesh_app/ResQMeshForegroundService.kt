package network.resqmesh.resqmesh_app

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

/**
 * ResQMesh 後台 Foreground Service
 *
 * Bug 2 Fix: 這是唯一的 GATT Server 來源。
 * MainActivity 不再開 GATT Server，避免 Android 只允許一個 GATT Server 的衝突。
 *
 * Bug 3 Fix: onCharacteristicWriteRequest 收到資料後，
 * 透過 MainActivity.sharedEventSink 轉發到 Flutter EventChannel。
 */
class ResQMeshForegroundService : Service() {

    companion object {
        private const val TAG = "ResQMeshService"
        private const val CHANNEL_ID = "resqmesh_data_mule"
        private const val NOTIFICATION_ID = 1001

        // 共享 Bloom Filter 快取（由 MainActivity 透過 MethodChannel 更新）
        @Volatile
        @JvmStatic
        var sharedBloomBytes: ByteArray = ByteArray(0)

        // 持久 GATT Server 狀態（供 Dart 查詢，不依賴 log buffer）
        @Volatile
        @JvmStatic
        var gattServiceReady: Boolean = false

        @Volatile
        @JvmStatic
        var gattServiceStatus: Int = -999  // 尚未回報
    }

    private var bleAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var serviceAddRetryCount = 0
    private var isAdvertising = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startBlePeripheral()
        Log.i(TAG, "ResQMesh Data Mule service started")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopBlePeripheral()
        Log.i(TAG, "ResQMesh Data Mule service stopped")
        super.onDestroy()
    }

    // ── Notification ──────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ResQMesh 資料騾模式",
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
            .setContentTitle("ResQMesh 資料騾運作中")
            .setContentText("正在廣播 Mesh 節點，協助轉送救援資訊")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    // ── BLE Peripheral (GATT Server + Advertising) ───────────────────────

    /** 建構 ResQMesh GATT Service（提取為獨立函式供重試使用） */
    private fun buildResQMeshService(): BluetoothGattService {
        val service = BluetoothGattService(
            ResQMeshConstants.SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        // Event characteristic (read/write/notify)
        val eventChar = BluetoothGattCharacteristic(
            ResQMeshConstants.EVENT_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
                BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        eventChar.addDescriptor(BluetoothGattDescriptor(
            ResQMeshConstants.CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or
                BluetoothGattDescriptor.PERMISSION_WRITE
        ))
        service.addCharacteristic(eventChar)

        // Bloom filter characteristic (read-only)
        service.addCharacteristic(BluetoothGattCharacteristic(
            ResQMeshConstants.BLOOM_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        ))

        // Handshake characteristic (read/write)
        service.addCharacteristic(BluetoothGattCharacteristic(
            ResQMeshConstants.HANDSHAKE_CHAR_UUID,
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
                Log.d(TAG, "onWriteReq: dev=${device.address} prep=$preparedWrite resp=$responseNeeded off=$offset len=${value.size}")

                // Fix: 回應要回傳 offset 和 value，確保 Prepared Write 驗證通過
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }

                // 只處理非 Prepared Write 的完整寫入（Prepared Write 的資料在 onExecuteWrite 後才完整）
                if (!preparedWrite) {
                    Log.d(TAG, "Received ${value.size} bytes from ${device.address}")
                    mainHandler.post {
                        MainActivity.sharedEventSink?.success(mapOf(
                            "type" to "ble_data",
                            "device" to device.address,
                            "data" to value.toList()
                        ))
                    }
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice, requestId: Int,
                offset: Int, characteristic: BluetoothGattCharacteristic
            ) {
                Log.d(TAG, "onReadReq: dev=${device.address} char=${characteristic.uuid} off=$offset")
                val responseBytes = when (characteristic.uuid) {
                    ResQMeshConstants.BLOOM_CHAR_UUID -> {
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
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }

            // Fix: 處理 Long Write (Prepared Write) 的 Execute 階段
            override fun onExecuteWrite(device: BluetoothDevice, requestId: Int, execute: Boolean) {
                Log.d(TAG, "onExecuteWrite: dev=${device.address} execute=$execute")
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }

            // Bug 4 Fix: addService 是非同步的，必須等 onServiceAdded 成功後才能開始廣播
            // 否則 Central 連進來時 service 尚未註冊，characteristics 全是 null
            override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
                val ok = status == BluetoothGatt.GATT_SUCCESS
                gattServiceReady = ok
                gattServiceStatus = status
                Log.i(TAG, "onServiceAdded: status=$status ok=$ok uuid=${service?.uuid}")
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
                            gattServer?.addService(buildResQMeshService())
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

            // 診斷: MTU 協商結果
            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
                Log.d(TAG, "MTU changed: dev=${device?.address} mtu=$mtu")
                mainHandler.post {
                    MainActivity.sharedEventSink?.success(mapOf(
                        "type" to "gatt_mtu",
                        "device" to (device?.address ?: ""),
                        "mtu" to mtu
                    ))
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

        // ── Build & Register ResQMesh GATT Service ──
        // Bug 4 Fix: addService 是非同步的！不能在這裡立即開始廣播。
        // 必須等 onServiceAdded callback 確認成功後才能廣播。
        // 否則 Central 連進來時 service/characteristics 尚未註冊完成。
        serviceAddRetryCount = 0
        gattServiceReady = false
        gattServiceStatus = -999

        // 先快取 adapter，供 startAdvertisingInternal 使用
        bleAdvertiser = adapter.bluetoothLeAdvertiser

        val service = buildResQMeshService()
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
            .addServiceUuid(android.os.ParcelUuid(ResQMeshConstants.SERVICE_UUID))
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
    }
}
