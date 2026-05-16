import Flutter
import CoreBluetooth
import CommonCrypto // Stage 6：SHA-256 PIN hash 用

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
    // Stage 6-fix：requester 端 BLE PIN write callback。
    var writeHandshakeCallbacks: [String: (Bool) -> Void] = [:]

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

    // ── v0.3 Stage 0c3 — per-peer transport state ─────────────────────
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §3 (iOS parity).
    /// Per-peer negotiated MTU (set when MTU upcall fires after service discovery).
    var deviceMtuMap: [String: Int] = [:]
    /// Tracks centrals that wrote a Bloom filter so the 10s fallback timer can be
    /// suppressed (spec §3.2.5 §15.4).
    var bloomReceivedDevices: Set<String> = []
    /// Pending 10s subscribe→Bloom fallback timers, keyed by central uuidString.
    var bloomFallbackTimers: [String: DispatchSourceTimer] = [:]
    /// v0.3 Stage 0c wave 3A — peers we've already emitted peer_ready_for_hello for.
    /// Spec: docs/specs/native_transport_v1_2026-05-13.md §5.2.
    var helloReadyDevices: Set<String> = []

    // Stage 6 (commit #10)：handoff PIN 跨平台對齊。Provider 端在
    // `startHandoffAdvertising` 暫存 (resourceId, sha256(pin))，待 GATT server
    // 收到 HANDSHAKE_CHAR 寫入時驗證並發出 `handoff_result` 事件。
    private var handoffResourceId: String?
    private var handoffPinHash: String?

    // ── SHA-256 helper（純 C API，避免引入 CryptoKit 提高 deployment target）──
    static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

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

        // Stage 6-fix：requester 透過此 method 把 PIN+resourceId 寫到 provider
        // 的 HANDSHAKE_CHAR；provider 的 peripheralManager(_:didReceiveWrite:)
        // 做驗證後以 respond(to:withResult:) 回報結果。
        case "nordicWriteHandshake":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(false)
                return
            }
            writeHandshake(deviceId, data: data.data) { success in
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

        // Stage 6 (commit #10): 移除原本第二個 "requestBluetoothEnable"
        // duplicate case（已於 L83 處理）。

        // ── 交接 PIN ─────────────────────────────────────────────────
        case "startHandoffAdvertising":
            // Stage 6：與 Android `MainActivity.handoffResourceId/handoffPinHash`
            // 對齊——把 resourceId / pinHash 暫存於 BlePlugin 實例，
            // 待 GATT server 收到 HANDSHAKE_CHAR 寫入時做 SHA-256 + resourceId 比對。
            if let args = call.arguments as? [String: Any] {
                handoffResourceId = args["resourceId"] as? String
                handoffPinHash = args["pinHash"] as? String
            }
            startAdvertising()
            result(true)

        case "stopHandoffAdvertising":
            handoffResourceId = nil
            handoffPinHash = nil
            result(true)

        case "sendHandoffPin":
            // Stage 6：完成原本的 TODO，對齊 Android `verifyHandoffPin` 同裝置
            // 本地驗證邏輯（physical_handoff fallback 路徑使用）。
            // 跨裝置 BLE handoff 走 GATT write，於 didReceiveWrite 處理。
            guard let args = call.arguments as? [String: Any],
                  let pin = args["pin"] as? String,
                  let resourceId = args["resourceId"] as? String,
                  let storedHash = handoffPinHash,
                  let storedResId = handoffResourceId else {
                result(false)
                return
            }
            let hash = BlePlugin.sha256Hex(pin)
            result(hash == storedHash && resourceId == storedResId)

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

    // Stage 6-fix：Central 端寫 PIN+resourceId 到 Provider 的 HANDSHAKE_CHAR。
    // Provider GATT server 在 peripheralManager(_:didReceiveWrite:) 做驗證並
    // 以 respond(to:withResult:) 回 .success 或失敗碼；Central 的
    // didWriteValueFor callback 收到的 error 非 nil 即代表驗證失敗。
    private func writeHandshake(_ deviceId: String, data: Data, completion: @escaping (Bool) -> Void) {
        guard let delegate = peripheralDelegates[deviceId],
              let handshakeChar = delegate.handshakeCharacteristic,
              let peripheral = connectedPeripherals[deviceId] else {
            completion(false)
            return
        }
        writeHandshakeCallbacks[deviceId] = completion
        peripheral.writeValue(data, for: handshakeChar, type: .withResponse)
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
        // v0.3 Stage 0c3 — drop per-peer transport state on disconnect.
        deviceMtuMap.removeValue(forKey: deviceId)
        bloomReceivedDevices.remove(deviceId)
        bloomFallbackTimers.removeValue(forKey: deviceId)?.cancel()
        // v0.3 Stage 0c wave 3A — clear HELLO ready set so a reconnect
        // re-emits peer_ready_for_hello and the Dart-side 5 s fallback
        // timer restarts cleanly.
        helloReadyDevices.remove(deviceId)
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
            // v0.3 Stage 0c3 — emit gatt_server_error to Dart so error handling
            // is symmetric with Android (spec native_transport_v1 §3.2.6).
            sendEvent([
                "type": "gatt_server_error",
                "kind": "advertising_failed",
                "message": error.localizedDescription,
            ])
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
        // Stage 6-fix：HANDSHAKE 寫入要把驗證結果以 respond(withResult:) 傳回。
        // 其他 char 維持先 success-respond 再處理（不影響 outbox 路徑）。
        var handshakeVerifiedFirst: Bool? = nil

        for request in requests {
            if request.characteristic.uuid == BlePlugin.EVENT_CHAR_UUID,
               let data = request.value {
                let deviceId = request.central.identifier.uuidString
                sendEvent([
                    "type": "nordic_data",
                    "device": deviceId,
                    "data": FlutterStandardTypedData(bytes: data),
                ])
            } else if request.characteristic.uuid == BlePlugin.BLOOM_CHAR_UUID,
                      let data = request.value {
                let deviceId = request.central.identifier.uuidString
                NSLog("[BLE-iOS] Bloom received from \(deviceId): \(data.count) bytes")
                // v0.3 Stage 0c3 — cancel the 10s subscribe→Bloom fallback timer
                // and mark this peer as Bloom-capable for this session.
                cancelSubscribeBloomFallback(forDeviceId: deviceId)
                pushOutboxToSubscriber(request.central)
            } else if request.characteristic.uuid == BlePlugin.HANDSHAKE_CHAR_UUID,
                      let data = request.value {
                let verified = verifyAndEmitHandshake(centralId: request.central.identifier.uuidString,
                                                      data: data)
                if handshakeVerifiedFirst == nil {
                    handshakeVerifiedFirst = verified
                }
            }
        }
        // 回應第一個請求：HANDSHAKE 用驗證結果決定 .success / .writeNotPermitted
        if let first = requests.first {
            if first.characteristic.uuid == BlePlugin.HANDSHAKE_CHAR_UUID,
               let verified = handshakeVerifiedFirst {
                peripheral.respond(to: first,
                                   withResult: verified ? .success : .writeNotPermitted)
            } else {
                peripheral.respond(to: first, withResult: .success)
            }
        }
    }

    /// Stage 6-fix：解析 PIN+resourceId、SHA-256 + resourceId 比對、emit
    /// `handoff_result` 事件，回傳驗證結果。
    private func verifyAndEmitHandshake(centralId: String, data: Data) -> Bool {
        var success = false
        var resId = ""
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pin = json["pin"] as? String,
           let writeResId = json["resourceId"] as? String,
           let storedHash = handoffPinHash,
           let storedRes = handoffResourceId {
            resId = writeResId
            success = (BlePlugin.sha256Hex(pin) == storedHash &&
                       writeResId == storedRes)
        }
        sendEvent([
            "type": "handoff_result",
            "device": centralId,
            "resourceId": resId,
            "success": success,
        ])
        return success
    }

    // ── GATT Server: Central 訂閱 Notify ──────────────────────────────
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        let deviceId = central.identifier.uuidString
        NSLog("[BLE-iOS] \(deviceId) subscribed to \(characteristic.uuid)")

        if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            // v0.3 Stage 0c wave 3A — peripheral-role HELLO trigger. By the
            // time a central subscribes to EVENT_CHAR notify it has discovered
            // our service; the per-central MTU is exposed via
            // `central.maximumUpdateValueLength` plus the ATT header. This
            // satisfies §5.2 from the peripheral perspective.
            let attMtu = central.maximumUpdateValueLength + IgniRelayConstants.ATT_HEADER_SIZE
            deviceMtuMap[deviceId] = attMtu
            if helloReadyDevices.insert(deviceId).inserted {
                sendEvent([
                    "type": "peer_ready_for_hello",
                    "device": deviceId,
                    "mtu": attMtu,
                    "role": "peripheral",
                ])
            }

            // v0.3 Stage 0c3 — schedule the 10-second subscribe→Bloom fallback
            // timer (spec native_transport_v1 §3.2.5 / §15.4). If a Bloom write
            // arrives within 10s the timer is cancelled in didReceiveWrite;
            // otherwise we fall back to the legacy blind-push outbox path so
            // legacy peers (no Bloom support) still receive events.
            scheduleSubscribeBloomFallback(for: central)
        }
    }

    // ── GATT Server: Central 取消訂閱 / 斷線清理 ───────────────────────
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        let deviceId = central.identifier.uuidString
        NSLog("[BLE-iOS] \(deviceId) unsubscribed from \(characteristic.uuid)")
        if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            // v0.3 Stage 0c wave 3A — drop the ready-set entry so a reconnect
            // re-emits peer_ready_for_hello and re-arms the Dart-side timer.
            helloReadyDevices.remove(deviceId)
            deviceMtuMap.removeValue(forKey: deviceId)
            bloomFallbackTimers.removeValue(forKey: deviceId)?.cancel()
            bloomReceivedDevices.remove(deviceId)
        }
    }

    /// Start (or restart) the 10s subscribe→Bloom fallback timer for a central.
    /// If the central already wrote a Bloom filter, push immediately and exit.
    private func scheduleSubscribeBloomFallback(for central: CBCentral) {
        let deviceId = central.identifier.uuidString
        if bloomReceivedDevices.contains(deviceId) {
            // Peer already wrote Bloom in this session — push outbox now.
            pushOutboxToSubscriber(central)
            return
        }
        // Cancel any previous pending timer for this central.
        bloomFallbackTimers[deviceId]?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        let deadline: DispatchTimeInterval = .milliseconds(IgniRelayConstants.SUBSCRIBE_BLOOM_FALLBACK_MS)
        timer.schedule(deadline: .now() + deadline)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.bloomFallbackTimers.removeValue(forKey: deviceId)
            if !self.bloomReceivedDevices.contains(deviceId) {
                NSLog("[BLE-iOS] Bloom fallback fired for \(deviceId); blind-pushing outbox")
                self.sendEvent([
                    "type": "bloom_fallback_fired",
                    "device": deviceId,
                ])
                self.pushOutboxToSubscriber(central)
            }
        }
        bloomFallbackTimers[deviceId] = timer
        timer.resume()
    }

    /// Cancel a pending subscribe-fallback timer (call from didReceiveWrite for
    /// BLOOM_CHAR_UUID).
    fileprivate func cancelSubscribeBloomFallback(forDeviceId deviceId: String) {
        bloomFallbackTimers.removeValue(forKey: deviceId)?.cancel()
        bloomReceivedDevices.insert(deviceId)
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

        // v0.3 Stage 0c3 — MTU upcall to Dart (spec native_transport_v1 §3.2.4).
        // iOS does not expose a `didNegotiateMtu` callback; the equivalent is
        // `peripheral.maximumWriteValueLength(for:)` once service discovery
        // completes. We add the chunk-header size + ATT header to derive the
        // ATT MTU value reported to Dart so the cross-platform `gatt_mtu` event
        // shape stays symmetric with Android.
        let writeWithoutResponseLen = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let attMtu = writeWithoutResponseLen + IgniRelayConstants.ATT_HEADER_SIZE
        plugin?.deviceMtuMap[deviceId] = attMtu
        plugin?.sendEvent([
            "type": "gatt_mtu",
            "device": deviceId,
            "mtu": attMtu,
        ])

        // v0.3 Stage 0c wave 3A — central-role HELLO trigger. Service discovery
        // and MTU computation have both completed here, satisfying §5.2.
        if let plugin = plugin, plugin.helloReadyDevices.insert(deviceId).inserted {
            plugin.sendEvent([
                "type": "peer_ready_for_hello",
                "device": deviceId,
                "mtu": attMtu,
                "role": "central",
            ])
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
        } else if characteristic.uuid == BlePlugin.HANDSHAKE_CHAR_UUID {
            // Stage 6-fix：Provider 端用 respond(withResult:) 把驗證結果回傳；
            // 失敗時 error 非 nil（CBATTError.writeNotPermitted 等），代表 PIN
            // 不對。Central 端把 success 直接當作 PIN 驗證結果回給 Dart。
            plugin?.writeHandshakeCallbacks.removeValue(forKey: deviceId)?(success)
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
