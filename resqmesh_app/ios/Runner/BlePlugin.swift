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

    // v0.3 Stage 0c wave 3C — Bloom bit-vector parameters. MUST match
    // android/.../IgniRelayForegroundService.kt (BLOOM_SIZE_BYTES /
    // BLOOM_HASH_COUNT / BLOOM_MAGIC). Used by pushDiffToSubscriber to do
    // a real diff push instead of blind-pushing the whole outbox.
    private static let bloomSizeBytes = 2048
    private static let bloomHashCount = 7
    private static let bloomMagic: [UInt8] = [0xFF, 0xBF, 0x02, 0x00]
    /// Marker emitted at the end of a diff push as the local bloom payload
    /// frame: [0xFF, 0xB1, 0x00, 0x4D] || localBloom. Matches Android.
    private static let bloomPushMagic: [UInt8] = [0xFF, 0xB1, 0x00, 0x4D]
    /// End-of-push marker. Matches Android exactly.
    private static let bloomPushEndMarker: [UInt8] = [0xFF, 0xE7, 0xD0, 0x7E]

    // v0.3 Stage 0c wave 3C — Long Write / Prepared Write incoming. iOS
    // CoreBluetooth surfaces ALL fragments of one Long Write in a single
    // didReceiveWrite callback (one CBATTRequest per fragment, each with
    // its own offset). Pre-3C we treated each fragment as an independent
    // write, which silently corrupted any payload split across fragments.
    // The wave 3C code path concatenates fragments by offset and emits a
    // single nordic_data event with the assembled value.
    //
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §3.2.3.

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
    /// v0.3 Stage 0c wave 3B — subscribed centrals (keyed by uuidString) so
    /// `notifyEventChunk` can target a specific peer with updateValue(_:for:
    /// onSubscribedCentrals:).
    var subscribedCentrals: [String: CBCentral] = [:]

    // Stage 6 (commit #10)：handoff PIN 跨平台對齊。Provider 端在
    // `startHandoffAdvertising` 暫存 (resourceId, sha256(pin))，待 GATT server
    // 收到 HANDSHAKE_CHAR 寫入時驗證並發出 `handoff_result` 事件。
    private var handoffResourceId: String?
    private var handoffPinHash: String?

    // ═══════════════════════════════════════════════════════════════════
    // v0.3 Stage 0c wave 3F — iOS adapter health + 0d debug hooks
    //
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §7.4 (force MTU)
    //       + §8 (adapter recovery).
    //
    // Mirror of the Android-side state in IgniRelayForegroundService.kt
    // companion. Lives at INSTANCE scope (not static) because the
    // CoreBluetooth manager handles are instance-scoped too — there is one
    // BlePlugin per FlutterEngine, created in `register`.
    // ═══════════════════════════════════════════════════════════════════

    /// Tick-kind strings — MUST match adapter_health_monitor.dart `_onNativeEvent`
    /// AND IgniRelayForegroundService.kt companion constants.
    static let TICK_SCAN = "scan"
    static let TICK_ADVERTISE = "advertise"
    static let TICK_GATT_OP = "gatt_op"

    /// End time (epoch ms) of the current `debugForceAdapterIdle` suppression
    /// window. 0 = no suppression. Matches Kotlin
    /// `IgniRelayForegroundService.adapterIdleSuppressedUntilMs`.
    private var adapterIdleSuppressedUntilMs: Int64 = 0

    /// Per-device MTU clamp set by `debugForceTargetMtu`. Mirror of Kotlin
    /// `debugMtuOverrideByDevice`. Applied to BOTH:
    ///   - `gatt_mtu` events surfaced to Dart
    ///   - the cap used inside `notifyEventChunk` for oversize rejection
    /// so the higher layers behave as if the link negotiated the lower value.
    private var debugMtuOverrideByDevice: [String: Int] = [:]

    /// Per-kind last-tick timestamps consumed by the §8.3 recovery watchdog.
    /// 0 = never observed (lenient startup — does not trip §8.2 staleness).
    private var lastScanTickAtMs: Int64 = 0
    private var lastAdvertiseTickAtMs: Int64 = 0
    private var lastGattOpTickAtMs: Int64 = 0

    /// Recovery escalation counters (spec §8.3 step 1 → step 2 → step 4).
    /// Reset to 0 every time a fresh tick proves the adapter is healthy.
    private var consecutiveSoftRestartFailures = 0
    private var consecutiveHardRestartFailures = 0

    /// Timer that periodically emits TICK_ADVERTISE while we're advertising
    /// AND TICK_GATT_OP while we have notify subscribers. Matches Android's
    /// `adapterHealthTickRunnable` (30 s — half of spec §8.2 60 s cadence).
    private var advertiseHealthTickTimer: DispatchSourceTimer?

    /// Watchdog timer that runs `evaluateAndRecover()` at spec §8.2 cadence.
    private var adapterRecoveryTimer: DispatchSourceTimer?

    /// 30 s — half of the spec §8.2 staleness evaluation interval, so the
    /// 5-minute "both stale" threshold has ~10 chances to refresh first.
    private static let ADAPTER_HEALTH_TICK_INTERVAL_MS = 30_000

    /// 60 s — spec §8.2 staleness evaluation cadence.
    private static let ADAPTER_RECOVERY_CHECK_INTERVAL_MS = 60_000

    /// 5 minutes — spec §8.2 staleness threshold.
    private static let ADAPTER_STALE_THRESHOLD_MS: Int64 = 5 * 60_000

    private static let ADAPTER_SOFT_RESTART_DELAY_MS = 500
    private static let ADAPTER_HARD_RESTART_DELAY_MS = 1_000

    /// Wall-clock now in epoch milliseconds. Matches the Long timestamps
    /// emitted by the Android tick path so cross-platform trace rows are
    /// directly comparable.
    private func nowMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Single source of truth for adapter health ticks. Suppression skips
    /// BOTH the Dart event emission AND the per-kind timestamp update so
    /// `debugForceAdapterIdle` exercises the §8.3 recovery path end to end
    /// (the watchdog sees the timestamps go stale exactly the way a real
    /// wedged adapter would). Mirror of Kotlin
    /// `IgniRelayForegroundService.emitAdapterTick`.
    fileprivate func emitAdapterTick(_ kind: String) {
        let now = nowMs()
        if adapterIdleSuppressedUntilMs > now { return }
        switch kind {
        case BlePlugin.TICK_SCAN: lastScanTickAtMs = now
        case BlePlugin.TICK_ADVERTISE: lastAdvertiseTickAtMs = now
        case BlePlugin.TICK_GATT_OP: lastGattOpTickAtMs = now
        default: break
        }
        sendEvent([
            "type": "adapter_health_tick",
            "kind": kind,
            "ts_ms": now,
        ])
    }

    /// Apply the `debugForceTargetMtu` override (if any) to a freshly
    /// negotiated MTU. Pure function — no side effects. Mirror of Kotlin
    /// `IgniRelayForegroundService.applyMtuOverride`.
    fileprivate func applyMtuOverride(_ deviceId: String, actualMtu: Int) -> Int {
        guard let override = debugMtuOverrideByDevice[deviceId] else { return actualMtu }
        return min(actualMtu, override)
    }

    /// Idempotent. Starts both the periodic tick emitter AND the recovery
    /// watchdog. Called once from `register`; they run forever, gated by
    /// their own internal checks (gattReady, subscribedCentrals, etc.).
    private func startAdapterHealthTimers() {
        if advertiseHealthTickTimer == nil {
            let healthTimer = DispatchSource.makeTimerSource(queue: .main)
            healthTimer.schedule(
                deadline: .now() + .milliseconds(BlePlugin.ADAPTER_HEALTH_TICK_INTERVAL_MS),
                repeating: .milliseconds(BlePlugin.ADAPTER_HEALTH_TICK_INTERVAL_MS)
            )
            healthTimer.setEventHandler { [weak self] in
                guard let self = self else { return }
                // Mirror Android: only emit TICK_ADVERTISE while the
                // peripheral side is actually advertising. CoreBluetooth
                // surfaces this as `CBPeripheralManager.isAdvertising`.
                if self.peripheralManager?.isAdvertising == true {
                    self.emitAdapterTick(BlePlugin.TICK_ADVERTISE)
                }
                if !self.subscribedCentrals.isEmpty {
                    self.emitAdapterTick(BlePlugin.TICK_GATT_OP)
                }
            }
            advertiseHealthTickTimer = healthTimer
            healthTimer.resume()
        }
        if adapterRecoveryTimer == nil {
            let recoveryTimer = DispatchSource.makeTimerSource(queue: .main)
            recoveryTimer.schedule(
                deadline: .now() + .milliseconds(BlePlugin.ADAPTER_RECOVERY_CHECK_INTERVAL_MS),
                repeating: .milliseconds(BlePlugin.ADAPTER_RECOVERY_CHECK_INTERVAL_MS)
            )
            recoveryTimer.setEventHandler { [weak self] in
                self?.evaluateAndRecover()
            }
            adapterRecoveryTimer = recoveryTimer
            recoveryTimer.resume()
        }
    }

    /// Spec §8.2 + §8.3. Mirror of Kotlin `evaluateAndRecover`.
    private func evaluateAndRecover() {
        let now = nowMs()
        let scanStale = lastScanTickAtMs > 0 &&
            (now - lastScanTickAtMs) > BlePlugin.ADAPTER_STALE_THRESHOLD_MS
        let advStale = lastAdvertiseTickAtMs > 0 &&
            (now - lastAdvertiseTickAtMs) > BlePlugin.ADAPTER_STALE_THRESHOLD_MS
        if !(scanStale && advStale) {
            if consecutiveSoftRestartFailures > 0 || consecutiveHardRestartFailures > 0 {
                NSLog("[BLE-iOS] adapter healthy; reset recovery counters")
                consecutiveSoftRestartFailures = 0
                consecutiveHardRestartFailures = 0
            }
            return
        }
        // §8.2: only act when we have a peripheral up AND subscribed peers.
        guard gattReady, !subscribedCentrals.isEmpty else { return }

        if consecutiveSoftRestartFailures < 2 {
            attemptSoftRestart()
        } else if consecutiveHardRestartFailures < 2 {
            attemptHardRestart()
        } else {
            emitPermanentError()
        }
    }

    /// §8.3 step 1 — stop+restart advertising. Also restart scan if we own
    /// the central manager (parity with Android's FS-owned advertise
    /// restart; iOS happens to own both managers in one process so we can
    /// nudge scan too).
    private func attemptSoftRestart() {
        consecutiveSoftRestartFailures += 1
        NSLog("[BLE-iOS] adapter soft restart (attempt \(consecutiveSoftRestartFailures))")
        sendEvent([
            "type": "adapter_native_soft_restart",
            "attempt": consecutiveSoftRestartFailures,
        ])
        // Stop + restart scan (if currently scanning).
        if isScanning {
            centralManager?.stopScan()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                guard let self = self, self.isScanning,
                      self.centralManager?.state == .poweredOn else { return }
                self.centralManager?.scanForPeripherals(
                    withServices: [BlePlugin.SERVICE_UUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
            }
        }
        // Stop + restart advertising.
        peripheralManager?.stopAdvertising()
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(BlePlugin.ADAPTER_SOFT_RESTART_DELAY_MS)
        ) { [weak self] in
            guard let self = self,
                  let pm = self.peripheralManager,
                  pm.state == .poweredOn else { return }
            pm.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [BlePlugin.SERVICE_UUID],
                CBAdvertisementDataLocalNameKey: "IgniRelay",
            ])
        }
    }

    /// §8.3 step 2 — full GATT teardown + rebuild.
    private func attemptHardRestart() {
        consecutiveHardRestartFailures += 1
        NSLog("[BLE-iOS] adapter hard restart (attempt \(consecutiveHardRestartFailures))")
        sendEvent([
            "type": "adapter_native_hard_restart",
            "attempt": consecutiveHardRestartFailures,
        ])
        if let pm = peripheralManager {
            if let svc = gattService { pm.remove(svc) }
            pm.stopAdvertising()
        }
        peripheralManager = nil
        gattService = nil
        gattReady = false
        bloomCharacteristic = nil
        eventCharacteristic = nil
        handshakeCharacteristic = nil
        subscribedCentrals.removeAll()
        bloomReceivedDevices.removeAll()
        bloomFallbackTimers.values.forEach { $0.cancel() }
        bloomFallbackTimers.removeAll()
        // Recreate after a short pause (some CoreBluetooth state takes a
        // moment to fully release; recreating immediately occasionally
        // surfaces .poweredOff or .resetting on the new manager).
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(BlePlugin.ADAPTER_HARD_RESTART_DELAY_MS)
        ) { [weak self] in
            self?.ensurePeripheralManager()
        }
    }

    /// §8.3 step 4. Resets counters so a future recovered tick (real or
    /// from suppression window expiry) gives us another shot at the
    /// soft → hard ladder rather than wedging forever.
    private func emitPermanentError() {
        NSLog("[BLE-iOS] adapter permanent error after " +
              "\(consecutiveHardRestartFailures) hard-restart attempts")
        sendEvent([
            "type": "adapter_native_permanent_error",
            "failures": consecutiveHardRestartFailures,
        ])
        consecutiveSoftRestartFailures = 0
        consecutiveHardRestartFailures = 0
    }

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
        // v0.3 Stage 0c wave 3F — start the adapter health tick emitter +
        // recovery watchdog at plugin load. Both timers are idempotent and
        // self-gated; they cost effectively nothing while BLE is idle.
        instance.startAdapterHealthTimers()
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

        // v0.3 Stage 0c wave 3B — peripheral-side notify a single v2 chunk
        // to a subscribed central. Mirrors Android's notifyEventChunk method;
        // the chunker that produced these bytes lives in Dart.
        case "notifyEventChunk":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(false)
                return
            }
            result(notifyEventChunk(deviceId: deviceId, data: data.data))

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

        // ── v0.3 Stage 0c wave 3F — 0d acceptance-gate debug hooks ──────
        //
        // Spec: docs/specs/native_transport_v1_2026-05-13.md §7.4 (force
        // MTU) + §8.5 (force adapter idle).
        //
        // Parity with MainActivity.kt "debugForceTargetMtu" /
        // "debugForceAdapterIdle" — same arg shapes, same return semantics,
        // same out-of-range rejection. Deliberately UNGATED on a DEBUG
        // flag so the QA agent can drive the 0d gate against release-mode
        // builds too; impact is bounded (MTU clamp + tick suppression
        // only, no wire-format mutation, no signature bypass).

        case "debugForceTargetMtu":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  !deviceId.isEmpty else {
                result(false)
                return
            }
            // Note: an explicit `NSNull` for targetMtu arrives as `nil`
            // after the `as? Int` cast — same effect as "clear override".
            let targetMtu = args["targetMtu"] as? Int
            if let target = targetMtu {
                if target < 23 || target > 512 {
                    NSLog("[BLE-iOS] debugForceTargetMtu rejected mtu=\(target) out of [23,512]")
                    result(false)
                    return
                }
                debugMtuOverrideByDevice[deviceId] = target
                NSLog("[BLE-iOS] debugForceTargetMtu: dev=\(deviceId) targetMtu=\(target)")
            } else {
                debugMtuOverrideByDevice.removeValue(forKey: deviceId)
                NSLog("[BLE-iOS] debugForceTargetMtu: cleared override for \(deviceId)")
            }
            result(true)

        case "debugForceAdapterIdle":
            let args = call.arguments as? [String: Any]
            let durationMs = (args?["durationMs"] as? NSNumber)?.int64Value ?? 0
            if durationMs <= 0 {
                adapterIdleSuppressedUntilMs = 0
                NSLog("[BLE-iOS] debugForceAdapterIdle: cleared")
                result(true)
                return
            }
            adapterIdleSuppressedUntilMs = nowMs() + durationMs
            NSLog("[BLE-iOS] debugForceAdapterIdle: suppress until=" +
                  "\(adapterIdleSuppressedUntilMs) durMs=\(durationMs)")
            result(true)

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
    //
    // pushOutboxToSubscriber is the LEGACY blind-push path. It stays as the
    // fallback used by the 10s subscribe→Bloom timer (spec §3.2.5 §15.4)
    // when a peer never writes its Bloom filter. The Bloom-write-triggered
    // path now goes through pushDiffToSubscriber (added in wave 3C) for
    // parity with Android pushDiffToDevice.
    private func pushOutboxToSubscriber(_ central: CBCentral) {
        guard let eventChar = eventCharacteristic, !outboxEvents.isEmpty else { return }

        let deviceId = central.identifier.uuidString
        sendEvent(["type": "notify_push_start", "device": deviceId, "count": outboxEvents.count, "mode": "blind"])

        var sentCount = 0
        for eventData in outboxEvents {
            let ok = peripheralManager?.updateValue(
                eventData, for: eventChar, onSubscribedCentrals: [central]
            ) ?? false
            if ok { sentCount += 1 }
        }

        sendEvent(["type": "notify_push_done", "device": deviceId, "count": sentCount, "mode": "blind"])
    }

    // ── v0.3 Stage 0c wave 3C — Bloom-diff push (Android parity) ────────
    //
    // Mirrors android/.../IgniRelayForegroundService.kt pushDiffToDevice.
    // Compares each outbox event against the remote bloom bit-vector and
    // only notifies events the peer is missing, followed by our own bloom
    // (so the peer can reciprocate) and an END marker.
    private func pushDiffToSubscriber(_ central: CBCentral, remoteBloomBytes: Data) {
        guard let eventChar = eventCharacteristic else {
            NSLog("[BLE-iOS] pushDiff: eventCharacteristic nil, skip")
            return
        }
        let deviceId = central.identifier.uuidString
        bloomReceivedDevices.insert(deviceId)

        let remoteBytes = [UInt8](remoteBloomBytes)
        let isBitVector = BlePlugin.hasBloomMagic(remoteBytes)

        // Legacy fallback format: newline-separated UTF-8 event IDs.
        let remoteEventIds: Set<String>
        if isBitVector {
            remoteEventIds = []
        } else if let s = String(data: remoteBloomBytes, encoding: .utf8) {
            remoteEventIds = Set(
                s.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
            )
        } else {
            remoteEventIds = []
        }

        // Snapshot outbox to avoid concurrent mutation.
        let events = outboxEvents
        var diffEvents: [Data] = []
        var bloomSkipped = 0
        for event in events {
            if let eventId = BlePlugin.tryExtractEventId(event) {
                let alreadyHas: Bool
                if isBitVector {
                    alreadyHas = BlePlugin.bloomMayContain(remoteBytes, eventId: eventId)
                } else {
                    alreadyHas = remoteEventIds.contains(eventId)
                }
                if alreadyHas {
                    bloomSkipped += 1
                    continue
                }
            }
            diffEvents.append(event)
        }

        // Append local bloom (magic-prefixed) + end marker so the peer can
        // reciprocate. Identical packet layout to Android.
        var bloomPacket = Data(BlePlugin.bloomPushMagic)
        bloomPacket.append(localBloomBytes)
        let endMarker = Data(BlePlugin.bloomPushEndMarker)
        let allPackets = diffEvents + [bloomPacket, endMarker]

        sendEvent([
            "type": "notify_push_start",
            "device": deviceId,
            "count": diffEvents.count,
            "bloom_skip": bloomSkipped,
            "mode": "diff",
        ])

        var successCount = 0
        var failCount = 0
        // Match Android's 150ms inter-packet pacing to avoid BLE congestion.
        for (idx, packet) in allPackets.enumerated() {
            let delay = DispatchTime.now() + .milliseconds(idx * 150)
            DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
                guard let self = self else { return }
                guard self.subscribedCentrals[deviceId] != nil else {
                    NSLog("[BLE-iOS] pushDiff: \(deviceId) disconnected, abort at packet \(idx)")
                    return
                }
                let ok = self.peripheralManager?.updateValue(
                    packet, for: eventChar, onSubscribedCentrals: [central]
                ) ?? false
                if ok { successCount += 1 } else { failCount += 1 }
            }
        }
        let doneDelay = DispatchTime.now() + .milliseconds(allPackets.count * 150 + 300)
        DispatchQueue.main.asyncAfter(deadline: doneDelay) { [weak self] in
            self?.sendEvent([
                "type": "notify_push_done",
                "device": deviceId,
                "count": diffEvents.count,
                "bloom_skip": bloomSkipped,
                "success": successCount,
                "fail": failCount,
                "mode": "diff",
            ])
        }
    }

    // ── Bloom helpers (static; cross-platform parity with Android) ──────

    static func hasBloomMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4 else { return false }
        return bytes[0] == bloomMagic[0] && bytes[1] == bloomMagic[1] &&
               bytes[2] == bloomMagic[2] && bytes[3] == bloomMagic[3]
    }

    /// Per-character single-byte MurmurHash3-32 — matches Android's
    /// `murmurHash(s: String, seed: Int)` used by buildBitVectorBloom and
    /// bloomMayContain. NOTE: this is a SEPARATE function from IBLT's
    /// `murmurHash([UInt8], seed:)` even though they're nearly identical —
    /// the Bloom variant accepts a String directly and matches the Kotlin
    /// signature used by IgniRelayForegroundService.murmurHash for Bloom
    /// bit-vector construction.
    static func bloomMurmurHash(_ s: String, seed: UInt32) -> UInt32 {
        var h: UInt32 = seed
        for codeUnit in s.utf16 {
            var k = UInt32(codeUnit & 0xFF)
            k = k &* 0xcc9e2d51
            k = (k << 15) | (k >> 17)
            k = k &* 0x1b873593
            h ^= k
            h = (h << 13) | (h >> 19)
            h = h &* 5 &+ 0xe6546b64
        }
        h ^= UInt32(s.utf16.count)
        h ^= h >> 16
        h = h &* 0x85ebca6b
        h ^= h >> 13
        h = h &* 0xc2b2ae35
        h ^= h >> 16
        return h
    }

    /// Mirror of Kotlin bloomMayContain. Handles both magic-prefixed
    /// bit-vector and raw (no-magic) bit-vector — strips magic when present.
    static func bloomMayContain(_ bloom: [UInt8], eventId: String) -> Bool {
        let offset = hasBloomMagic(bloom) ? 4 : 0
        let size = bloom.count - offset
        if size <= 0 { return false }
        let totalBits = UInt32(size * 8)
        for i in 0..<UInt32(bloomHashCount) {
            let hash = bloomMurmurHash(eventId, seed: i) % totalBits
            let idx = Int(hash)
            let byte = bloom[offset + (idx >> 3)]
            let mask = UInt8(1 << (idx & 7))
            if (byte & mask) == 0 { return false }
        }
        return true
    }

    /// Best-effort proto field-1 (event_id) extractor — mirror of Android's
    /// tryExtractEventId. Assumes the legacy `pb.MeshEvent` layout where
    /// field 1 is a length-delimited string at the front of the message.
    static func tryExtractEventId(_ data: Data) -> String? {
        guard data.count > 2, data[0] == 0x0A else { return nil }
        let len = Int(data[1])
        guard data.count >= 2 + len else { return nil }
        return String(data: data.subdata(in: 2..<(2 + len)), encoding: .utf8)
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

        // v0.3 Stage 0c wave 3F — every scan callback proves the central is
        // alive. Refresh the adapter-health clock BEFORE we filter / handle,
        // so a peer-less scan stream still keeps §8.2 staleness at bay.
        emitAdapterTick(BlePlugin.TICK_SCAN)

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
        } else {
            // v0.3 Stage 0c wave 3F — confirmed advertising start. The
            // periodic timer also emits TICK_ADVERTISE every 30 s while
            // peripheralManager.isAdvertising is true, so this one is just
            // the "we've started" anchor.
            emitAdapterTick(BlePlugin.TICK_ADVERTISE)
        }
    }

    // ── GATT Server: 處理 Central 的讀請求 ─────────────────────────────
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        // v0.3 Stage 0c wave 3F — read request is a clear GATT op signal.
        emitAdapterTick(BlePlugin.TICK_GATT_OP)
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
        // v0.3 Stage 0c wave 3F — write request is a clear GATT op signal.
        emitAdapterTick(BlePlugin.TICK_GATT_OP)
        // v0.3 Stage 0c wave 3C — Long Write / Prepared Write incoming. The
        // requests array may contain MULTIPLE CBATTRequest objects for one
        // Long Write, each with its own offset. We group by (centralId,
        // characteristicUuid), sort by offset, validate contiguity + total
        // size, and emit a single concatenated value to the upper layers.
        //
        // For regular (non-prepared) writes the array still typically has
        // one request → grouping is a no-op.
        //
        // ── Why this is callback-internal, NOT a per-device persistent
        // buffer + timeout (unlike Android's Reassembler.kt) ──────────────
        //
        // CoreBluetooth's peripheral GATT server hides the ATT Prepared
        // Write / Execute Write handshake from us. The framework itself
        // accumulates each ATT_PREPARE_WRITE_REQ fragment, and only after
        // it receives ATT_EXECUTE_WRITE_REQ does it surface ONE
        // peripheralManager(_:didReceiveWrite:) call carrying the full
        // [CBATTRequest] batch. Aborted prepared sessions never reach us
        // at all — the framework drops them.
        //
        // Android's BluetoothGattServerCallback works the opposite way:
        // each prepared fragment fires onCharacteristicWriteRequest with
        // preparedWrite=true, the app must keep a per-device buffer, then
        // commit on onExecuteWrite(execute=true) — which is exactly why
        // android/.../Reassembler.kt exists with a per-device cleanup
        // timer. Porting that pattern to iOS would add dead state and a
        // redundant timer; do NOT cargo-cult it across.
        //
        // Edge case: if CoreBluetooth ever folds two distinct Long Writes
        // from the same central+characteristic into one callback (spec
        // permits but is rare in practice), our offset contiguity check
        // catches it and emits a `gatt_server_error` event with reason
        // `non-contiguous-offset` — visible, not silent corruption.
        var handshakeVerifiedFirst: Bool? = nil

        // Group by (central uuid, characteristic uuid).
        var grouped: [GroupKey: [CBATTRequest]] = [:]
        for req in requests {
            let key = GroupKey(
                centralId: req.central.identifier.uuidString,
                charUuid: req.characteristic.uuid
            )
            grouped[key, default: []].append(req)
        }

        for (key, group) in grouped {
            switch assembleLongWrite(group) {
            case .ok(let data):
                if key.charUuid == BlePlugin.EVENT_CHAR_UUID {
                    sendEvent([
                        "type": "nordic_data",
                        "device": key.centralId,
                        "data": FlutterStandardTypedData(bytes: data),
                    ])
                } else if key.charUuid == BlePlugin.BLOOM_CHAR_UUID {
                    NSLog("[BLE-iOS] Bloom received from \(key.centralId): \(data.count) bytes")
                    // v0.3 Stage 0c3 — cancel the 10s subscribe→Bloom fallback
                    // timer and mark this peer as Bloom-capable.
                    cancelSubscribeBloomFallback(forDeviceId: key.centralId)
                    // v0.3 Stage 0c wave 3C — real diff push instead of blind
                    // push (mirror Android pushDiffToDevice).
                    pushDiffToSubscriber(group[0].central, remoteBloomBytes: data)
                } else if key.charUuid == BlePlugin.HANDSHAKE_CHAR_UUID {
                    let verified = verifyAndEmitHandshake(
                        centralId: key.centralId, data: data
                    )
                    if handshakeVerifiedFirst == nil {
                        handshakeVerifiedFirst = verified
                    }
                }
            case .dropped(let reason):
                NSLog("[BLE-iOS] long-write dropped from \(key.centralId) char=\(key.charUuid) reason=\(reason)")
                sendEvent([
                    "type": "gatt_server_error",
                    "kind": "long_write_dropped",
                    "device": key.centralId,
                    "char": key.charUuid.uuidString,
                    "reason": reason,
                ])
            }
        }

        // 回應第一個請求：HANDSHAKE 用驗證結果決定 .success / .writeNotPermitted；
        // 其他 char 維持 .success（不影響 outbox 路徑）。
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

    /// v0.3 Stage 0c wave 3C — concatenate Long Write fragments by offset.
    ///
    /// Returns:
    ///   .ok(data)            — fragments are contiguous (offset 0..N-1 cover
    ///                           the whole value) and total <= cap; data is
    ///                           the assembled payload.
    ///   .dropped("reason")   — fragments are non-contiguous, overlap, or
    ///                           the total exceeds kMaxReassemblyBufferBytes.
    ///                           Caller emits a gatt_server_error event so
    ///                           the symptom is visible (never silent).
    private func assembleLongWrite(_ requests: [CBATTRequest]) -> LongWriteAssembly {
        if requests.count == 1, requests[0].offset == 0, let data = requests[0].value {
            return .ok(data)
        }
        // Sort by offset (CoreBluetooth typically delivers in order but the
        // spec does not guarantee it).
        let sorted = requests.sorted { $0.offset < $1.offset }
        var assembled = Data()
        var expectedOffset = 0
        for req in sorted {
            guard let value = req.value else {
                return .dropped("missing-value")
            }
            if req.offset != expectedOffset {
                return .dropped("non-contiguous-offset")
            }
            assembled.append(value)
            expectedOffset += value.count
            if assembled.count > IgniRelayConstants.MAX_REASSEMBLY_BUFFER_BYTES {
                return .dropped("oversize-long-write")
            }
        }
        return .ok(assembled)
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
        // v0.3 Stage 0c wave 3F — subscribe is a clear GATT op signal.
        emitAdapterTick(BlePlugin.TICK_GATT_OP)

        if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            // v0.3 Stage 0c wave 3A — peripheral-role HELLO trigger. By the
            // time a central subscribes to EVENT_CHAR notify it has discovered
            // our service; the per-central MTU is exposed via
            // `central.maximumUpdateValueLength` plus the ATT header. This
            // satisfies §5.2 from the peripheral perspective.
            //
            // Wave 3F — apply the debugForceTargetMtu clamp BEFORE storing
            // / surfacing the value so all downstream sizing (notifyEventChunk
            // oversize cap, peer_ready_for_hello, gatt_mtu) sees the clamped
            // MTU. Spec §7.4 + parity with Android `applyMtuOverride`.
            let rawAttMtu = central.maximumUpdateValueLength +
                IgniRelayConstants.ATT_HEADER_SIZE
            let attMtu = applyMtuOverride(deviceId, actualMtu: rawAttMtu)
            if attMtu != rawAttMtu {
                NSLog("[BLE-iOS] MTU clamped by debug override: dev=\(deviceId) actual=\(rawAttMtu) effective=\(attMtu)")
            }
            deviceMtuMap[deviceId] = attMtu
            // v0.3 Stage 0c wave 3B — track the CBCentral so notifyEventChunk
            // can target it directly via updateValue(_:for:onSubscribedCentrals:).
            subscribedCentrals[deviceId] = central
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
        // v0.3 Stage 0c wave 3F — unsubscribe is a clear GATT op signal.
        emitAdapterTick(BlePlugin.TICK_GATT_OP)
        if characteristic.uuid == BlePlugin.EVENT_CHAR_UUID {
            // v0.3 Stage 0c wave 3A — drop the ready-set entry so a reconnect
            // re-emits peer_ready_for_hello and re-arms the Dart-side timer.
            helloReadyDevices.remove(deviceId)
            deviceMtuMap.removeValue(forKey: deviceId)
            bloomFallbackTimers.removeValue(forKey: deviceId)?.cancel()
            bloomReceivedDevices.remove(deviceId)
            // v0.3 Stage 0c wave 3B — drop the CBCentral handle too.
            subscribedCentrals.removeValue(forKey: deviceId)
        }
    }

    // MARK: - v0.3 Stage 0c wave 3B — capability-aware single-chunk notify

    /// Notify a single v2 chunk to a subscribed central. The chunker is in
    /// Dart; here we just hand one PDU to CoreBluetooth.
    ///
    /// Returns true when the BLE stack accepted the bytes for the given
    /// central; false when:
    ///   • the deviceId is not currently subscribed,
    ///   • the bytes exceed the per-central MTU cap,
    ///   • CoreBluetooth back-pressures (updateValue returned false).
    fileprivate func notifyEventChunk(deviceId: String, data: Data) -> Bool {
        guard let central = subscribedCentrals[deviceId] else {
            NSLog("[BLE-iOS] notifyEventChunk: no subscriber \(deviceId)")
            return false
        }
        guard let eventChar = eventCharacteristic else {
            NSLog("[BLE-iOS] notifyEventChunk: eventCharacteristic is nil")
            return false
        }
        // v0.3 Stage 0c wave 3F — use the CLAMPED cap so debugForceTargetMtu
        // (§7.4) rejections fire at the value we told Dart about. Without
        // this clamp the 0d gate forced-MTU=185 scenarios would still let
        // 247-byte payloads through because CoreBluetooth uses the real
        // negotiated MTU, contradicting the MTU figure surfaced via
        // `gatt_mtu` / `peer_ready_for_hello`.
        //
        // Falls back to `central.maximumUpdateValueLength` when no override
        // is active so production code path stays exactly as before 3F.
        let storedMtu = deviceMtuMap[deviceId]
        let cap: Int = storedMtu.map { $0 - IgniRelayConstants.ATT_HEADER_SIZE }
            ?? central.maximumUpdateValueLength
        if data.count > cap {
            NSLog("[BLE-iOS] notifyEventChunk: oversize \(data.count)B > cap \(cap) for \(deviceId)")
            sendEvent([
                "type": "notify_push_error",
                "device": deviceId,
                "error": "oversize-payload",
                "kind": "v2_chunk",
                "size": data.count,
                "cap": cap,
            ])
            return false
        }
        let ok = peripheralManager?.updateValue(
            data,
            for: eventChar,
            onSubscribedCentrals: [central]
        ) ?? false
        if ok {
            // v0.3 Stage 0c wave 3F — successful notify is a clear GATT op
            // signal. Android's `onNotificationSent` callback emits this
            // tick too; iOS lacks an equivalent callback, so we emit it at
            // send time. The trade-off (no transport-layer confirmation) is
            // unchanged from existing iOS behavior.
            emitAdapterTick(BlePlugin.TICK_GATT_OP)
        } else {
            NSLog("[BLE-iOS] notifyEventChunk: updateValue back-pressured for \(deviceId)")
        }
        return ok
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
        //
        // Wave 3F — apply the debugForceTargetMtu clamp here so the central-
        // side path reports the same effective MTU as the peripheral-side
        // path (spec §7.4 + parity with NordicMeshManager.connect done{}).
        let writeWithoutResponseLen = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let rawAttMtu = writeWithoutResponseLen + IgniRelayConstants.ATT_HEADER_SIZE
        let attMtu = plugin?.applyMtuOverride(deviceId, actualMtu: rawAttMtu) ?? rawAttMtu
        if attMtu != rawAttMtu {
            NSLog("[BLE-iOS] Central MTU clamped: dev=\(deviceId) actual=\(rawAttMtu) effective=\(attMtu)")
        }
        plugin?.deviceMtuMap[deviceId] = attMtu
        plugin?.sendEvent([
            "type": "gatt_mtu",
            "device": deviceId,
            "mtu": attMtu,
        ])
        // v0.3 Stage 0c wave 3F — central-side connection settle is a clear
        // GATT op signal; refresh the adapter-health clock.
        plugin?.emitAdapterTick(BlePlugin.TICK_GATT_OP)

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
        // v0.3 Stage 0c wave 3F — incoming notify / read response proves the
        // GATT layer is healthy from the central perspective.
        plugin?.emitAdapterTick(BlePlugin.TICK_GATT_OP)

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
        // v0.3 Stage 0c wave 3F — write-ack is a clear GATT op signal.
        plugin?.emitAdapterTick(BlePlugin.TICK_GATT_OP)
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

// ══════════════════════════════════════════════════════════════════════════
// ── v0.3 Stage 0c wave 3C — Long Write assembly support types ─────────────
// ══════════════════════════════════════════════════════════════════════════

/// Composite key used by didReceiveWrite to group CBATTRequest fragments
/// that belong to the same Long Write transaction.
struct GroupKey: Hashable {
    let centralId: String
    let charUuid: CBUUID
}

/// Result of concatenating Long Write fragments.
enum LongWriteAssembly {
    case ok(Data)
    case dropped(String)
}

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
