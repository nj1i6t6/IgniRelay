# Release Checklist (v0.1.27+)

## Release 前必須完成項目

### 1. Android Release Signing
- **位置**: `android/app/build.gradle.kts` L34-40
- **現狀**: release buildType 使用 debug signing (`signingConfigs.getByName("debug")`)
- **處理**: 建立正式 keystore，配置 `signingConfigs.release`，設定 `storeFile / storePassword / keyAlias / keyPassword`
- **影響**: 上架 Google Play 或分發正式 APK 的前置條件

### 2. `_publishAndStore` 缺少座標欄位
- **位置**: `lib/mesh/event_manager.dart` `_publishAndStore()` helper
- **現狀**: 未填入 `received_lat / received_lng / origin_lat / origin_lng`
- **處理**: 加入 `LocationService().currentLocation` 取得座標填入 Event_Logs
- **影響**: 經由此 helper 發出的事件（matchOffer、matchAccept、matchDecline 等）無法參與 Zone-Based Geo-Fencing 路由

### 3. EventSerializer 死碼清理
- **位置**: `lib/mesh/event_serializer.dart` (279 行)
- **現狀**: 完整 Protobuf 序列化封裝，但全專案無任何 import
- **處理**: 確認無用後刪除檔案
- **影響**: 減少維護困惑

### 4. BUILD_TIMESTAMP fallback 過期
- **位置**: `lib/main.dart` L25-28
- **現狀**: `defaultValue: 1712102400000` 是 2024-04-03 的時間戳
- **處理**: 更新為接近 release 日期的時間戳，或確保 CI/CD 一定注入 `--dart-define=BUILD_TIMESTAMP=$(date +%s000)`
- **影響**: 若 build system 未注入，HLC 時鐘偏差保護基準會偏離 2 年
