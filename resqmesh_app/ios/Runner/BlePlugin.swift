import Flutter
import CoreBluetooth

// ══════════════════════════════════════════════════════════════════════════
// IgniRelay BLE Plugin — iOS CoreBluetooth 實作
//
// 對應 Android 端 NordicMeshManager.kt + IgniRelayForegroundService.kt
// 統一 MethodChannel: "network.ignirelay/native"
// 統一 EventChannel:  "network.ignirelay/events"
//
// 雙角色：
//   Central  — 掃描、連線、讀寫 GATT Characteristics
//   Peripheral — GATT Server 廣播、接收寫入、Notify 推送
// ══════════════════════════════════════════════════════════════════════════

class BlePlugin: NSObject, FlutterPlugin {

    // ── Constants (對齊 Android IgniRelayConstants + Dart mesh_constants) ──
    static let SERVICE_UUID = CBUUID(string: "a4d11949-49d0-5230-96bb-43dd95d2cb2e")
    static let BLOOM_CHAR_UUID = CBUUID(string: "9b60940f-ca37-5c28-8620-42a89e7fdca7")
    static let EVENT_CHAR_UUID = CBUUID(string: "a932d89d-c24c-5d11-8320-55374c7feb74")
    static let HANDSHAKE_CHAR_UUID = CBUUID(string: "24b532d3-243f-5b61-92b0-50af4cf0bd1a")

    // ── Flutter Channels ───────────────────────────────────────────────
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    // ── CoreBluetooth Central ──────────────────────────────────────────
    private var centralManager: CBCentralManager?
    private var isScanning = false
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedPeripherals: [String: CBPeripheral] = [:]
    private var peripheralDelegates: [String: PeripheralDelegate] = [:]

    // 連線 callback
    private var connectCallbacks: [String: (Bool) -> Void] = [:]
    private var readBloomCallbacks: [String: (Data?) -> Void] = [:]
    private var writeBloomCallbacks: [String: (Bool) -> Void] = [:]
    private var writeEventCallbacks: [String: (Bool) -> Void] = [:]

    // ── CoreBluetooth Peripheral (GATT Server) ─────────────────────────
    private var peripheralManager: CBPeripheralManager?
    private var gattService: CBMutableService?
    private var bloomCharacteristic: CBMutableCharacteristic?
    private var eventCharacteristic: CBMutableCharacteristic?
    private var handshakeCharacteristic: CBMutableCharacteristic?
    private var gattReady = false

    // ── Shared State ───────────────────────────────────────────────────
    private var localBloomBytes: Data = Data()
    private var outboxEvents: [Data] = []

    // ── Plugin Registration ────────────────────────────────────────────
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BlePlugin()
        let channel = FlutterMethodChannel(
            name: "network.ignirelay/native",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "network.ignirelay/events",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        instance.methodChannel = channel
        instance.eventChannel = eventChannel
    }

    // ══════════════════════════════════════════════════════════════════
    // ── MethodChannel Handler ─────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── 藍牙硬體狀態 ──────────────────────────────────────────────
        case "isBluetoothEnabled":
            ensureCentralManager()
            result(centralManager?.state == .poweredOn)

        case "requestBluetoothEnable":
            // iOS 無法以程式方式開啟藍牙，只能提示使用者
            result(false)

        // ── Central 掃描 ──────────────────────────────────────────────
        case "startNordicScan":
            result(startScan())

        case "stopNordicScan":
            stopScan()
            result(true)

        // ── Central 連線 ──────────────────────────────────────────────
        case "nordicConnect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  !deviceId.isEmpty else {
                result(false)
                return
            }
            connectToDevice(deviceId) { success in
                result(success)
            }

        case "nordicDisconnect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(true)
                return
            }
            disconnectDevice(deviceId)
            result(true)

        // ── Central 讀寫 ──────────────────────────────────────────────
        case "nordicReadBloom":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  !deviceId.isEmpty else {
                result(nil)
                return
            }
            readBloom(deviceId) { data in
                if let data = data {
                    result(FlutterStandardTypedData(bytes: data))
                } else {
                    result(nil)
                }
            }

        case "nordicWriteBloom":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(false)
                return
            }
            writeBloom(deviceId, data: data.data) { success in
                result(success)
            }

        case "nordicWriteEvent":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(false)
                return
            }
            writeEvent(deviceId, data: data.data) { success in
                result(success)
            }

        // ── Peripheral (GATT Server) ─────────────────────────────────
        case "startBleAdvertising", "startBleRelayMode", "startDataMuleMode",
             "startMeshForegroundService":
            startAdvertising()
            result(true)

        case "stopBleAdvertising", "stopMeshForegroundService":
            stopAdvertising()
            result(true)

        case "stopAllServices":
            stopScan()
            stopAdvertising()
            result(true)

        // ── Bloom / Outbox 更新 ──────────────────────────────────────
        case "updateBloomFilter":
            if let args = call.arguments as? [String: Any],
               let bloom = args["bloom"] as? FlutterStandardTypedData {
                localBloomBytes = bloom.data
                updateGattBloomValue()
            }
            result(true)

        case "updateEventOutbox":
            if let args = call.arguments as? [String: Any],
               let data = args["data"] as? FlutterStandardTypedData {
                outboxEvents = parseLengthPrefixedFrames(data.data)
            } else {
                outboxEvents = []
            }
            result(true)

        // ── 查詢 ─────────────────────────────────────────────────────
        case "getBatteryLevel":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = Int(UIDevice.current.batteryLevel * 100)
            result(level >= 0 ? level : -1)

        case "getGattServerStatus":
            result([
                "ready": gattReady,
                "status": gattReady ? 0 : -1,
            ])

        case "getManufacturer":
            result("apple")

        // ── iOS 不需要的 Android 專用方法（回傳預設值）────────────────
        case "requestBatteryOptimizationExemption",
             "isBatteryOptimizationExempt":
            result(true) // iOS 無此概念

        case "openBatterySettings",
             "openManufacturerPowerSettings":
            // 開啟系統設定
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
                result(true)
            } else {
                result(false)
            }

        case "requestHighBandwidthTransfer":
            result(false)

        case "requestBluetoothEnable":
            result(false) // iOS 無法程式化開啟藍牙

        // ── 交接 PIN ─────────────────────────────────────────────────
        case "startHandoffAdvertising":
            startAdvertising()
            result(true)

        case "stopHandoffAdvertising":
            result(true)

        case "sendHandoffPin":
            // TODO: 實作 PIN 驗證邏輯
            result(false)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Central: 掃描 ─────────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════

    private func ensureCentralManager() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    private func startScan() -> Bool {
        ensureCentralManager()
        guard centralManager?.state == .poweredOn else { return false }
        guard !isScanning else { return true }

        isScanning = true
        // 使用軟體過濾（與 Android 一致），掃描所有裝置後在 delegate 中過濾 UUID
        centralManager?.scanForPeripherals(
            withServices: [BlePlugin.SERVICE_UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        NSLog("[BLE-iOS] Scan started")
        return true
    }

    private func stopScan() {
        isScanning = false
        centralManager?.stopScan()
        NSLog("[BLE-iOS] Scan stopped")
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Central: 連線 / 斷線 ──────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════

    private func connectToDevice(_ deviceId: String, completion: @escaping (Bool) -> Void) {
        guard let peripheral = discoveredPeripherals[deviceId] else {
            NSLog("[BLE-iOS] Device not found: \(deviceId)")
            completion(false)
            return
        }

        connectCallbacks[deviceId] = completion

        let delegate = PeripheralDelegate(plugin: self, deviceId: deviceId)
        peripheralDelegates[deviceId] = delegate
        peripheral.delegate = delegate

        centralManager?.connect(peripheral, options: nil)

        // 15 秒 timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.connectedPeripherals[deviceId] == nil {
                self?.centralManager?.cancelPeripheralConnection(peripheral)
                self?.connectCallbacks.removeValue(forKey: deviceId)?(false)
            }
        }
    }

    private func disconnectDevice(_ deviceId: String) {
        if let peripheral = connectedPeripherals[deviceId] ?? discoveredPeripherals[deviceId] {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripherals.removeValue(forKey: deviceId)
        peripheralDelegates.removeValue(forKey: deviceId)
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Central: 讀寫 Characteristics ─────────────────────────────────
    // ══════════════════════════════════════════════════════════════════

    private func readBloom(_ deviceId: String, completion: @escaping (Data?) -> Void) {
        guard let delegate = peripheralDelegates[deviceId],
              let bloomChar = delegate.bloomCharacteristic,
              let peripheral = connectedPeripherals[deviceId] else {
            completion(nil)
            return
        }
        readBloomCallbacks[deviceId] = completion
        peripheral.readValue(for: bloomChar)
    }

    private func writeBloom(_ deviceId: String, data: Data, completion: @escaping (Bool) -> Void) {
        guard let delegate = peripheralDelegates[deviceId],
              let bloomChar = delegate.bloomCharacteristic,
              let peripheral = connectedPeripherals[deviceId] else {
            completion(false)
            return
        }
        writeBloomCallbacks[deviceId] = completion
        peripheral.writeValue(data, for: bloomChar, type: .withResponse)
    }

    private func writeEvent(_ deviceId: String, data: Data, completion: @escaping (Bool) -> Void) {
        guard let delegate = peripheralDelegates[deviceId],
              let eventChar = delegate.eventCharacteristic,
              let peripheral = connectedPeripherals[deviceId] else {
            completion(false)
            return
        }
        writeEventCallbacks[deviceId] = completion
        peripheral.writeValue(data, for: eventChar, type: .withResponse)
    }

    // ══════════════════════════════════════════════════════════════════
    // ── Peripheral: GATT Server + Advertising ─────────────────────────
    // ══════════════════════════════════════════════════════════════════

    private func ensurePeripheralManager() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }

    private func startAdvertising() {
        ensurePeripheralManager()
        guard peripheralManager?.state == .poweredOn else {
            // 等 peripheralManagerDidUpdateState 再 setup
            return
        }
        setupGattService()
    }

    private func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        if let service = gattService {
            peripheralManager?.remove(service)
        }
        gattReady = false
    }

    private func setupGattService() {
        guard let pm = peripheralManager else { return }

        // 移除舊 service
        if let old = gattService { pm.remove(old) }

        bloomCharacteristic = CBMutableCharacteristic(
            type: BlePlugin.BLOOM_CHAR_UUID,
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        eventCharacteristic = CBMutableCharacteristic(
            type: BlePlugin.EVENT_CHAR_UUID,
            properties: [.write, .notify],
            value: nil,
            permissions: [.writeable]
        )

        handshakeCharacteristic = CBMutableCharacteristic(
            type: BlePlugin.HANDSHAKE_CHAR_UUID,
            properties: [.write, .notify],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(type: BlePlugin.SERVICE_UUID, primary: true)
        service.characteristics = [bloomCharacteristic!, eventCharacteristic!, handshakeCharacteristic!]
        gattService = service

        pm.add(service)
    }

    private func updateGattBloomValue() {
        // Bloom char 在 read request 中動態回傳，不需預設值
    }

    // ── Outbox 推送（Central subscribe 時觸發）────────────────────────
    private func pushOutboxToSubscriber(_ central: CBCentral) {
        guard let eventChar = eventCharacteristic, !outboxEvents.isEmpty else { return }

        let deviceId = central.identifier.uuidString
        sendEvent(["type": "notify_push_start", "device": deviceId, "count": outboxEvents.count])

        var sentCount = 0
        for eventData in outboxEvents {
            let ok = peripheralManager?.updateValue(
                eventData, for: eventChar, onSubscribedCentrals: [central]
            ) ?? false
            if ok { sentCount += 1 }
        }

        sendEvent(["type": "notify_push_done", "device": deviceId, "count": sentCount])
    }

    // ── Length-prefix frame 解析 ──────────────────────────────────────
    private func parseLengthPrefixedFrames(_ data: Data) -> [Data] {
        var events: [Data] = []
        var pos = 0
        while pos + 4 <= data.count {
            let len = Int(data[pos]) << 24 | Int(data[pos+1]) << 16 |
                      Int(data[pos+2]) << 8 | Int(data[pos+3])
            pos += 4
            if pos + len <= data.count {
                events.append(data.subdata(in: pos..<(pos + len)))
                pos += len
            } else { break }
        }
        return events
    }

    // ── Event Sink Helper ────────────────────────────────────────────
    fileprivate func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// ── CBCentralManagerDelegate ──────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════

extension BlePlugin: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("[BLE-iOS] Central state: \(central.state.rawValue)")
        if central.state == .poweredOn && isScanning {
            _ = startScan()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        discoveredPeripherals[deviceId] = peripheral

        sendEvent([
            "type": "nordic_found",
            "device": deviceId,
            "rssi": RSSI.intValue,
        ])
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        connectedPeripherals[deviceId] = peripheral
        NSLog("[BLE-iOS] Connected: \(deviceId)")

        // 發現服務
        peripheral.discoverServices([BlePlugin.SERVICE_UUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        NSLog("[BLE-iOS] Connect failed: \(deviceId) — \(error?.localizedDescription ?? "unknown")")
        connectCallbacks.removeValue(forKey: deviceId)?(false)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        connectedPeripherals.removeValue(forKey: deviceId)
        peripheralDelegates.removeValue(forKey: deviceId)
        NSLog("[BLE-iOS] Disconnected: \(deviceId)")
    }
}

// ══════════════════════════════════════════════════════════════════════════
// ── CBPeripheralManagerDelegate (GATT Server) ─────────────────────────────
// ══════════════════════════════════════════════════════════════════════════

extension BlePlugin: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        NSLog("[BLE-iOS] Peripheral state: \(peripheral.state.rawValue)")
        if peripheral.state == .poweredOn {
            setupGattService()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didAdd service: CBService, error: Error?) {
        if let error = error {
            NSLog("[BLE-iOS] GATT service add failed: \(error.localizedDescription)")
            sendEvent(["type": "gatt_service_added", "success": false, "status": -1])
            return
        }

        gattReady = true
        sendEvent(["type": "gatt_service_added", "success": true, "status": 0])

        // 開始廣播
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BlePlugin.SERVICE_UUID],
            CBAdvertisementDataLocalNameKey: "IgniRelay",
        ])
        NSLog("[BLE-iOS] GATT service added, advertising started")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            NSLog("[BLE-iOS] Advertising failed: \(error.localizedDescription)")
        }
    }

    // ── GATT Server: 處理 Central 的讀請求 ─────────────────────────────
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == BlePlugin.BLOOM_CHAR_UUID {
            // 回傳本機 Bloom Filter
            if request.offset > localBloomBytes.count {
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            request.value = localBloomBytes.subdata(in: request.offset..<localBloomBytes.count)
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    // ── GATT Server: 處理 Central 的寫請求 ─────────────────────────────
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == BlePlugin.EVENT_CHAR_UUID,
               let data = request.value {
                // Central 寫入事件資料 → 通知 Dart 層
                let deviceId = request.central.identifier.uuidString
                sendEvent([
                    "type": "nordic_data",
                    "device": deviceId,
                    "data": FlutterStandardTypedData(bytes: data),
                ])
            } else if request.characteristic.uuid == BlePlugin.BLOOM_CHAR_UUID,
                      let data = request.value {
                // Central 寫入其 Bloom → 做差量比對後 Notify 推送
                let deviceId = request.central.identifier.uuidString
                NSLog("[BLE-iOS] Bloom received from \(deviceId): \(data.count) bytes")
                // 差量推送 outbox 事件
                pushOutboxToSubscriber(request.central)
            } else if request.characteristic.uuid == BlePlugin.HANDSHAKE_CHAR_UUID,
                      let data = request.value {
                // Central 寫入交接握手資料 → 通知 Dart 層
                let deviceId = request.central.identifier.uuidString
                sendEvent([
                    "type": "handshake_data",
                    "device": deviceId,
                    "data": FlutterStandardTypedData(bytes: data),
                ])
            }
        }
        // 回應第一個請求
        if let first = requests.first {
            peripheral.respond(to: first, withResult: .success)
        }
    }

    // ── GATT Server: Central 訂閱 Notify ──────────────────────────────
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        let deviceId = central.identifier.uuidString
        NSLog("[BLE-iOS] \(deviceId) subscribed to \(characteristic.uuid)")

        if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            // 立即推送 outbox
            pushOutboxToSubscriber(central)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// ── PeripheralDelegate — 個別 Peripheral 的服務發現 + 讀寫回呼 ──────────
// ══════════════════════════════════════════════════════════════════════════

class PeripheralDelegate: NSObject, CBPeripheralDelegate {

    private weak var plugin: BlePlugin?
    private let deviceId: String

    var bloomCharacteristic: CBCharacteristic?
    var eventCharacteristic: CBCharacteristic?
    var handshakeCharacteristic: CBCharacteristic?

    init(plugin: BlePlugin, deviceId: String) {
        self.plugin = plugin
        self.deviceId = deviceId
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            NSLog("[BLE-iOS] Service discovery failed: \(error!.localizedDescription)")
            plugin?.connectCallbacks.removeValue(forKey: deviceId)?(false)
            return
        }

        if let service = peripheral.services?.first(where: { $0.uuid == BlePlugin.SERVICE_UUID }) {
            peripheral.discoverCharacteristics(
                [BlePlugin.BLOOM_CHAR_UUID, BlePlugin.EVENT_CHAR_UUID, BlePlugin.HANDSHAKE_CHAR_UUID],
                for: service
            )
        } else {
            NSLog("[BLE-iOS] No IgniRelay service on \(deviceId)")
            plugin?.connectCallbacks.removeValue(forKey: deviceId)?(false)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            plugin?.connectCallbacks.removeValue(forKey: deviceId)?(false)
            return
        }

        for char in service.characteristics ?? [] {
            if char.uuid == BlePlugin.BLOOM_CHAR_UUID { bloomCharacteristic = char }
            if char.uuid == BlePlugin.EVENT_CHAR_UUID { eventCharacteristic = char }
            if char.uuid == BlePlugin.HANDSHAKE_CHAR_UUID { handshakeCharacteristic = char }
        }

        let hasAll = bloomCharacteristic != nil && eventCharacteristic != nil
        NSLog("[BLE-iOS] Chars discovered: bloom=\(bloomCharacteristic != nil), event=\(eventCharacteristic != nil), handshake=\(handshakeCharacteristic != nil)")

        // 訂閱 Event Characteristic 的 Notify
        if let eventChar = eventCharacteristic, eventChar.properties.contains(.notify) {
            peripheral.setNotifyValue(true, for: eventChar)
        }

        plugin?.connectCallbacks.removeValue(forKey: deviceId)?(hasAll)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else { return }

        if characteristic.uuid == BlePlugin.BLOOM_CHAR_UUID {
            // Read Bloom 回呼
            plugin?.readBloomCallbacks.removeValue(forKey: deviceId)?(characteristic.value)
        } else if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            // Notify 接收事件資料
            if let data = characteristic.value, !data.isEmpty {
                plugin?.sendEvent([
                    "type": "nordic_data",
                    "device": deviceId,
                    "data": [UInt8](data),
                ])
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        let success = error == nil
        if characteristic.uuid == BlePlugin.BLOOM_CHAR_UUID {
            plugin?.writeBloomCallbacks.removeValue(forKey: deviceId)?(success)
        } else if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            plugin?.writeEventCallbacks.removeValue(forKey: deviceId)?(success)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
// ── FlutterStreamHandler (EventChannel) ───────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════

extension BlePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
