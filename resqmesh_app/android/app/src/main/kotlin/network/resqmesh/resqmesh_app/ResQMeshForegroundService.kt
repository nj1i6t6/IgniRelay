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
import java.util.UUID

/**
 * ResQMesh 後台 Foreground Service
 * 保持 BLE 廣播（Peripheral 角色）在螢幕關閉後持續運作（Data Mule 模式）。
 */
class ResQMeshForegroundService : Service() {

    companion object {
        private const val TAG = "ResQMeshService"
        private const val CHANNEL_ID = "resqmesh_data_mule"
        private const val NOTIFICATION_ID = 1001

        private val RESQMESH_SERVICE_UUID = UUID.fromString("f47a7b20-2d0a-11ee-be56-0242ac120002")
        private val EVENT_CHAR_UUID = UUID.fromString("f47a7b21-2d0a-11ee-be56-0242ac120002")
        private val BLOOM_CHAR_UUID = UUID.fromString("f47a7b22-2d0a-11ee-be56-0242ac120002")
        private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private var bleAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null

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

    // ── Notification ──────────────────────────────────────────────────────────

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

    // ── BLE Peripheral ────────────────────────────────────────────────────────

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

        // Open GATT server
        gattServer = btManager.openGattServer(this, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                Log.d(TAG, "GATT: ${device.address} -> state $newState")
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
                Log.d(TAG, "Received ${value.size} bytes from ${device.address}")
                // TODO: Forward to Flutter via EventChannel when needed
            }
            override fun onCharacteristicReadRequest(
                device: BluetoothDevice, requestId: Int,
                offset: Int, characteristic: BluetoothGattCharacteristic
            ) {
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

        // Build and add service
        val service = BluetoothGattService(RESQMESH_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
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
        service.addCharacteristic(BluetoothGattCharacteristic(
            BLOOM_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        ))
        gattServer?.addService(service)

        // Start advertising
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_ADVERTISE)
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "BLUETOOTH_ADVERTISE not granted")
            return
        }
        bleAdvertiser = adapter.bluetoothLeAdvertiser ?: return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(android.os.ParcelUuid(RESQMESH_SERVICE_UUID))
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.i(TAG, "BLE advertising started in foreground service")
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "BLE advertising failed: $errorCode")
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
    }

}
