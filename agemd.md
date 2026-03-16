# System Context: Project ResQMesh
**Target Audience**: AI Coding Assistants / Autonomous Agents

## 1. Mission Objective
Project **ResQMesh** is a highly resilient, decentralized Mobile Ad-hoc Network (MANET) and Delay-Tolerant Networking (DTN) material and rescue dispatch system designed for extreme disaster scenarios where all traditional communication infrastructures (4G/5G, Fiber, WiFi) have been completely destroyed. 

The system enables stranded civilians to form offline peer-to-peer (P2P) mesh networks using their mobile devices to broadcast SOS distress signals, share dynamic hazard maps, and match essential supplies (e.g., generators, water).

## 2. Core Technological Stack
* **Transport Layer (Cross-Platform)**: BLE Mesh (GATT dual-role, Custom Service UUID) for all cross-brand phone-to-phone and phone-to-hardware-node communication. Wi-Fi Aware (NAN) and AWDL are removed; all transport is BLE-only. Nearby Connections API is deprecated.
* **Data Serialization**: Protocol Buffers (Protobuf). **JSON is strictly prohibited** for mesh transport.
* **Local Storage & State**: SQLite/Room with Hybrid CRDT (Conflict-free Replicated Data Type) implementations.
* **Backend Gateway**: PostgreSQL + PostGIS (for geospatial heatmaps), receiving batch event logs from edge nodes (Data Mules) when they eventually reach internet-connected zones.

## 3. Core Architectural Pillars
* **Store-and-Forward Routing**: Every smartphone acts as a mobile database. Data routing relies on Priority-Driven Epidemic Routing heavily mitigated by Bloom Filters (to prevent duplicate transmissions/broadcast storms).
* **Event Sourcing**: System state is not mutating. It is an immutable append-only ledger of `Event_Logs`. The `Materials_State` is a materialized view derived from these logs.
* **Heterogeneous Nodes (Data Mules)**: Devices are not equal. **Tier 1 Android devices (running Foreground Service, battery ≥ 40%) automatically escalate into "Super Node" mode**, broadcasting at maximum BLE power and acting as high-capacity "Data Mules." They automatically downgrade back to Tier 2 when battery drops below 40%. If recharged, the device must reach **≥ 60%** before re-escalating (hysteresis design). Note: charging is NOT a requirement — disaster scenarios assume power grid failure.

## 4. Extreme Edge-Case Defenses (The "Dark Forest" Rules)
As an AI contributing to this codebase, you must ALWAYS account for the following extreme parameters in your logic:

### A. The "Time Drift" Problem (Hybrid Logical Clocks)
Smartphones running out of battery and rebooting offline will reset their internal clocks to the 1970 UNIX Epoch. **Never rely solely on absolute timestamps for CRDT merging.** Always implement **Hybrid Logical Clocks (HLC)** consisting of `[int64 hlc_timestamp, int64 hlc_counter]` to establish causal event ordering. Double-spending conflicts in the offline world are resolved via HLC vectors.

### B. QoS & Routing Preemption (Triage)
Mesh bandwidth (especially BLE) is extremely scarce. Not all packets are equal.
The system implements a Triage state machine. If an event is tagged as `SOS_RED` (life-critical, e.g., arterial bleeding), the routing layer must implement **Routing Preemption**. It must instantly terminate any ongoing low-priority background transfers (like large images or general info) and dedicate 100% of the socket bandwidth to the `SOS_RED` packet.

### C. Storage Eviction (The 500MB Limit)
Edge nodes acting as Mules will rapidly accumulate hundreds of thousands of event logs. Local storage is finite. You must enforce an aggressive **Data Eviction Strategy** (e.g., threshold at 500MB).
* **Rule**: Routinely purge expired `INFO` packets where `ttl <= 0`.
* **Locking**: `SOS_RED` events and dynamic `Hazards_State` data are **PINNED** and must never be evicted locally until successfully synced with the central Cloud Gateway.

### D. Payload Chunking (The 512 Bytes Rule)
Standard payloads must be strictly kept under 512 bytes. However, if a medical professional needs to transmit a highly compressed wound photograph, the transport layer must automatically fragment the data. Implement strict **Payload Chunking** (`chunk_index`, `total_chunks`) and a Reassembly Cache. Only emit the event to the application layer once all chunks are verified via signature.

### E. Trust, Spoofing, and Decentralized Quarantine
A disaster zone can harbor malicious actors executing Denial-of-Service (DoS) attacks by flooding fake SOS signals.
* **Ed25519 Signatures**: Every action is cryptographically signed using a keypair generated during pre-disaster e-KYC registration.
* **Endogenous Quarantine**: If a localized node detects anomalous broadcasts from a specific Public Key, it emits a `Quarantine_Vote` log. If a node collects an **accumulated weighted score of > 3.0 (exclusive)** (based on voters' identity levels) against the same Public Key, it automatically adds the key to a decentralized local Blacklist, severing its routing rights.

### F. Physical Handshake Fallback (The 4-Digit PIN)
Physical transactions (`Locked` -> `Consumed`) require Proof-of-Encounter.
* **Fallback Rule**: When devices detect a matched peer nearby via BLE, the UI prompts a 4-Digit PIN on the Provider's device and an input box on the Requester's. To prevent brute-forcing: 3 consecutive wrong attempts lock the UI for 30 seconds. Another 3 consecutive wrong attempts will **cancel the match**, freeing the resource back to the network.

## 5. Development Guidelines for the Agent
1. **Always assume the network does not exist.** Network calls (`fetch`, `axios`) are only valid in the `Gateway` module. Everything else must write to the local SQLite `Event_Logs`.
2. **Bandwidth is blood.** Optimize every byte.
3. **Handle partial connections.** A peer might walk out of range inside 2 seconds. The handshakes (Exchange Bloom Filter -> Diff -> Transfer) must be aggressive, prioritized, and resumable.
4. **Assume hostile input.** Validate signatures before parsing payloads. 

### Referenced Documentation Files
For detailed implementation specs, refer to the files in `docs/`:
* `INDEX.md` — **完整文件索引**（含地圖工具鏈、暫存腳本分類；新增或移動文件後請同步維護）
* `01_產品需求規格書_SRS.md`
* `02_系統架構設計書_SAD.md`
* `03_通訊協定與API設計_API.md`
* `04_資料庫規劃與狀態同步_DB.md`
* `05_介面流程與測試計畫_UI_QA.md`
