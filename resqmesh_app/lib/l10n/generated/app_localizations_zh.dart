// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '烽傳 IgniRelay';

  @override
  String get mainStartupLoading => '烽傳 啟動中...';

  @override
  String get mainBluetoothDialogTitle => '需要開啟藍牙';

  @override
  String get mainBluetoothDialogContent =>
      '烽傳使用藍牙建立 Mesh 離線網路，\n用於傳遞求救訊號與物資媒合。\n\n請開啟藍牙以啟用完整功能。';

  @override
  String get mainBluetoothDialogCancel => '稍後';

  @override
  String get mainBluetoothDialogConfirm => '開啟藍牙';

  @override
  String mainBleFailSnack(String error) {
    return 'BLE Mesh 啟動失敗：$error';
  }

  @override
  String get mainPermissionSnack => '需要藍牙與位置權限才能啟用 Mesh 網路';

  @override
  String get tabMap => '離線地圖';

  @override
  String get tabMeshGuard => 'Mesh 守護';

  @override
  String get tabChat => '聊天';

  @override
  String get tabMatch => '物資媒合';

  @override
  String get tabProfile => '身分信任';

  @override
  String mainTabSosYellowSnack(String desc) {
    return '收到求助訊號：$desc';
  }

  @override
  String get mainTabSosYellowAction => '查看地圖';

  @override
  String get mainTabSosRedDialogTitle => '緊急求救訊號！';

  @override
  String get mainTabSosRedDialogFallback => '附近有人發出緊急求救';

  @override
  String get mainTabSosRedDialogContent =>
      '此訊號透過 Mesh 網路傳遞，發送者可能在附近。\n請前往地圖查看位置資訊。';

  @override
  String get mainTabSosRedDialogDismiss => '知道了';

  @override
  String get mainTabSosRedDialogViewMap => '查看地圖';

  @override
  String get mainTabMatchNotifProvider => '有人願意提供你需要的物資！點擊查看。';

  @override
  String get mainTabMatchNotifRequester => '有人需要你的物資！點擊查看。';

  @override
  String get mainTabMatchNotifAction => '查看媒合';

  @override
  String get onboardingBadgeL0 => '匿名 (L0)';

  @override
  String get onboardingBadgeL1 => '手機驗證 (L1)';

  @override
  String get onboardingBadgeL2 => '社群背書 (L2)';

  @override
  String get onboardingBadgeL3 => '政府身分 (L3)';

  @override
  String onboardingDeviceId(String pubKeyHex) {
    return '裝置 ID: $pubKeyHex...';
  }

  @override
  String get onboardingTitle => '烽傳 IgniRelay\n離線 Mesh 災難應急系統';

  @override
  String get onboardingDesc => '無網路時仍可透過 BLE Mesh 組成自組織網路，\n即時傳遞求救與物資配對訊息。';

  @override
  String get onboardingNicknameHint => '設定你的暱稱（可選）';

  @override
  String get onboardingUpgradeDialogTitle => '手機驗證 (L1)';

  @override
  String get onboardingUpgradeDialogContent =>
      '透過 SMS OTP 驗證手機號碼，\n提升信任等級至 L1（銅牌）。\n\n驗證後可解鎖更多功能。';

  @override
  String get onboardingUpgradeDialogConfirm => '確認升級';

  @override
  String get onboardingUpgradeSnack => '已升級至 L1 (銅牌) - 手機驗證';

  @override
  String get onboardingUpgradeButton => '升級至 L1（手機驗證）';

  @override
  String get onboardingStartButton => '開始使用烽傳';

  @override
  String get profileTitle => '身分與信任';

  @override
  String get profileBadgeDescL0 => '自動生成 Ed25519 金鑰，無需網路';

  @override
  String get profileBadgeDescL1 => '已綁定手機號碼，信任度提升';

  @override
  String get profileBadgeDescL2 => '已獲 3 位以上用戶背書';

  @override
  String get profileBadgeDescL3 => '已通過 TW FidO 政府身分驗證';

  @override
  String get profileAnonymous => '匿名用戶';

  @override
  String get profileNicknameDialogTitle => '修改暱稱';

  @override
  String get profileNicknameDialogHint => '輸入新暱稱';

  @override
  String get profileNicknameDialogCancel => '取消';

  @override
  String get profileNicknameDialogSave => '儲存';

  @override
  String profileNicknameUpdated(String nickname) {
    return '暱稱已更新為「$nickname」';
  }

  @override
  String get profileNicknameCleared => '已清除暱稱';

  @override
  String get profilePubKeyLabel => '公鑰 (Ed25519)';

  @override
  String get profilePubKeyLoading => '載入中...';

  @override
  String get profileBatteryButton => '背景執行 / 電池優化設定';

  @override
  String get profileMedicalCardEdit => '編輯醫療卡';

  @override
  String get profileMedicalCardCreate => '建立醫療卡';

  @override
  String get profileTrustPhoneVerify => '手機驗證';

  @override
  String get profileTrustNotOpen => '尚未開放';

  @override
  String get profileUpgradeSnack => '已升級至 手機驗證 (L1)（待後端 SMS OTP 串接）';

  @override
  String get profileLanguageLabel => '語言';

  @override
  String get mapTitle => '離線地圖';

  @override
  String get mapLayerControlTooltip => '圖層控制';

  @override
  String get mapLegendTooltip => '圖例';

  @override
  String get mapRefreshTooltip => '重新整理';

  @override
  String get mapLoading => '正在載入離線地圖...';

  @override
  String get mapLoadingNote => '(首次啟動解壓 201MB 地圖需要一點時間)';

  @override
  String get mapErrorTitle => '離線地圖不可用';

  @override
  String get mapErrorUnknown => '未知錯誤';

  @override
  String get mapErrorAssetNote =>
      '請確認 assets/maps/taiwan_ignirelay.mbtiles 已正確打包';

  @override
  String get mapRetryButton => '重試';

  @override
  String get mapMbtilesNotFound => '找不到離線地圖檔案 (taiwan_ignirelay.mbtiles)';

  @override
  String mapMbtilesLoadFail(String error) {
    return '地圖載入失敗: $error';
  }

  @override
  String get mapHazardRoadblock => '道路封閉';

  @override
  String get mapHazardFire => '火災';

  @override
  String get mapHazardChemical => '化學/毒氣';

  @override
  String get mapHazardFlood => '水災/淹水';

  @override
  String get mapHazardCollapse => '建物倒塌';

  @override
  String get mapHazardLandslide => '土石流';

  @override
  String get mapEventSosRed => 'SOS 緊急求救';

  @override
  String get mapEventSosYellow => '求助';

  @override
  String get mapEventSupply => '物資';

  @override
  String get mapEventInfo => '資訊';

  @override
  String get mapEventTypeSupply => '物資供給';

  @override
  String get mapEventTypeRequest => '物資需求';

  @override
  String mapEventTypeUnknown(int eventType) {
    return '事件 (type=$eventType)';
  }

  @override
  String get mapPoiHospital => '醫院';

  @override
  String get mapPoiClinic => '診所';

  @override
  String get mapPoiNursingHome => '護理之家';

  @override
  String get mapPoiPharmacy => '藥局';

  @override
  String get mapPoiPolice => '警察局';

  @override
  String get mapPoiFireStation => '消防隊';

  @override
  String get mapPoiSchool => '學校';

  @override
  String get mapPoiUniversity => '大學';

  @override
  String get mapPoiSupermarket => '超市';

  @override
  String get mapPoiConvenience => '便利商店';

  @override
  String get mapPoiMall => '商場';

  @override
  String get mapPoiGasStation => '加油站';

  @override
  String get mapPoiRestaurant => '餐廳';

  @override
  String get mapPoiCafe => '咖啡廳';

  @override
  String get mapPoiBank => '銀行';

  @override
  String get mapPoiPostOffice => '郵局';

  @override
  String get mapPoiReligious => '宗教場所';

  @override
  String get mapPoiParking => '停車場';

  @override
  String get mapPoiShop => '商店';

  @override
  String get mapPoiInfoAddress => '地址';

  @override
  String get mapPoiInfoPhone => '電話';

  @override
  String get mapPoiInfoOpen => '營業';

  @override
  String get mapPoiInfoNoDetail => '（此地點未提供詳細資訊）';

  @override
  String get mapDayMonday => '週一';

  @override
  String get mapDayTuesday => '週二';

  @override
  String get mapDayWednesday => '週三';

  @override
  String get mapDayThursday => '週四';

  @override
  String get mapDayFriday => '週五';

  @override
  String get mapDaySaturday => '週六';

  @override
  String get mapDaySunday => '週日';

  @override
  String get mapDayHoliday => '國定假日';

  @override
  String get mapDayClosed => '公休';

  @override
  String get mapCredibilityConfirmed => '確信';

  @override
  String get mapCredibilityCredible => '可信';

  @override
  String get mapCredibilityEndorsed => '有附議';

  @override
  String get mapCredibilityUnverified => '未驗證';

  @override
  String mapTimeAgoMinutes(int mins) {
    return '$mins 分鐘前';
  }

  @override
  String mapTimeAgoHours(int hours) {
    return '$hours 小時前';
  }

  @override
  String mapTimeAgoDays(int days) {
    return '$days 天前';
  }

  @override
  String get mapMarkingNearbyExists => '附近已有回報';

  @override
  String mapMarkingNearbyContent(
      int distanceMeters, String typeLabel, int confirmCount) {
    return '距離 ${distanceMeters}m 處已有「$typeLabel」回報，目前已有 $confirmCount 人確認。\n\n你可以「確認」來增加可信度，或建立全新標記。';
  }

  @override
  String get mapMarkingCreateNew => '建立新標記';

  @override
  String get mapMarkingConfirmReport => '確認回報';

  @override
  String get mapMarkingEditTitle => '編輯危險標記';

  @override
  String get mapMarkingNewTitle => '標記危險區域';

  @override
  String get mapMarkingTapHint => '  點擊地圖可移動標記位置';

  @override
  String get mapMarkingSeverityLabel => ' 嚴重度';

  @override
  String get mapMarkingRadiusLabel => ' 半徑';

  @override
  String get mapMarkingDescHint => '簡述狀況 (選填)';

  @override
  String get mapMarkingUpdateButton => '更新標記';

  @override
  String get mapMarkingPublishButton => '發布至 Mesh';

  @override
  String get mapHazardUpdatedSnack => '危險標記已更新';

  @override
  String get mapHazardPublishedSnack => '危險標記已發布至 Mesh';

  @override
  String get mapHazardDeleteTitle => '解除危險標記？';

  @override
  String get mapHazardDeleteContent => '解除後此標記將從地圖上移除。';

  @override
  String get mapHazardDeleteCancel => '取消';

  @override
  String get mapHazardDeleteConfirm => '解除';

  @override
  String get mapHazardDeletedSnack => '危險標記已解除';

  @override
  String get mapHazardInfoSeverity => '嚴重度';

  @override
  String mapHazardInfoRadius(int radius) {
    return '影響範圍: ${radius}m';
  }

  @override
  String mapHazardInfoDesc(String desc) {
    return '描述: $desc';
  }

  @override
  String mapHazardInfoTime(String timeAgo) {
    return '回報時間: $timeAgo';
  }

  @override
  String get mapHazardInfoMine => '你的回報';

  @override
  String get mapHazardInfoEditButton => '編輯';

  @override
  String get mapHazardInfoConfirmButton => '確認此回報';

  @override
  String mapHazardConfirmSnack(String typeLabel, int count) {
    return '已確認「$typeLabel」回報 ($count人)';
  }

  @override
  String mapEventInfoDistance(String distance) {
    return '距離: $distance';
  }

  @override
  String mapEventInfoTime(String timeAgo) {
    return '時間: $timeAgo';
  }

  @override
  String get mapLongPressHint => '長按地圖 → 標記危險區域';

  @override
  String get mapSosSentLabel => 'SOS 已發送  ✕ 取消';

  @override
  String get mapSosButton => '求救 SOS';

  @override
  String get mapSosHoldHint => '長按 1.5 秒以發出 SOS';

  @override
  String get mapCancelSosTitle => '取消求救';

  @override
  String get mapCancelSosContent => '確定要取消 SOS 求救訊號嗎？\n取消後其他裝置會收到通知。';

  @override
  String get mapCancelSosBack => '返回';

  @override
  String get mapCancelSosConfirm => '確定取消';

  @override
  String get mapSosCancelledPrefix => '【SOS 已取消】';

  @override
  String get mapSosCancelledSnack => 'SOS 已取消';

  @override
  String mapSosCancelFailSnack(String error) {
    return '取消失敗: $error';
  }

  @override
  String get mapGpsNotReady => 'GPS 尚未定位，請確認已開啟位置服務';

  @override
  String get mapTriageBroadcastLabel0 => '資訊';

  @override
  String get mapTriageBroadcastLabel1 => '物資需求';

  @override
  String get mapTriageBroadcastLabel2 => '求助 (黃)';

  @override
  String get mapTriageBroadcastLabel3 => '緊急求救 (紅)';

  @override
  String mapTriageBroadcastSnack(String label, String desc) {
    return '已廣播 $label：$desc';
  }

  @override
  String get mapLegendTitle => '救災地標 (離線圖磚)';

  @override
  String get mapLegendZoomHint => '放大至街道層級可載入點位';

  @override
  String get mapLegendHospital => '醫院/診所';

  @override
  String get mapLegendPolice => '警消單位';

  @override
  String get mapLegendSchool => '學校 (避難所)';

  @override
  String get mapLegendPharmacy => '藥局 (醫療物資)';

  @override
  String get mapLegendSupermarket => '超市/便利商店';

  @override
  String get mapLegendMeshEvents => 'Mesh 事件';

  @override
  String mapPayloadQtyUnit(String name, int qty, String unit) {
    return '$name $qty $unit';
  }

  @override
  String mapPayloadQtyPcs(String name, int qty) {
    return '$name $qty 份';
  }

  @override
  String get mapLayerTitle => '圖層控制';

  @override
  String get mapLayerPoiSection => '地點圖標';

  @override
  String get mapLayerHazardSection => '危險區域';

  @override
  String get mapLayerPoiHospital => '醫院/診所';

  @override
  String get mapLayerPoiPharmacy => '藥局';

  @override
  String get mapLayerPoiPolice => '警消單位';

  @override
  String get mapLayerPoiSchool => '學校（避難所）';

  @override
  String get mapLayerPoiSupermarket => '超市/商店';

  @override
  String get mapLayerHazardShowOthers => '顯示他人回報';

  @override
  String get mapLayerHazardMinCredibility => '最低可信度';

  @override
  String get mapLayerCredAll => '全部顯示';

  @override
  String get mapLayerCredAllDesc => '包含未驗證';

  @override
  String get mapLayerCred2 => '2 人以上';

  @override
  String get mapLayerCred2Desc => '有人附議';

  @override
  String get mapLayerCred3 => '3 人以上';

  @override
  String get mapLayerCred3Desc => '多人回報';

  @override
  String get mapLayerCred5 => '確信 (5+)';

  @override
  String get mapLayerCred5Desc => '高度可信';

  @override
  String get triageTitle => '緊急求救廣播';

  @override
  String get triageDescHint => '描述需求或物資 (如: 需要飲水、有急救箱)';

  @override
  String get triageMedicalCardToggle => '附帶醫療卡資訊';

  @override
  String get triageMedicalCardOn => '已開啟';

  @override
  String get triageMedicalCardOff => '已關閉';

  @override
  String get triageSosYellowButton => '求助 (SOS_YELLOW)';

  @override
  String get triageSosRedButton => '立即發送 SOS_RED 緊急求救';

  @override
  String triageSosRedCountdown(int seconds) {
    return '長按中... 剩 $seconds 秒';
  }

  @override
  String get triageSosRedHoldHint => '長按 3 秒解鎖致命求救 (SOS_RED)';

  @override
  String get hazardDialogTitle => '標記危險區域';

  @override
  String hazardDialogCoordinate(String lat, String lng) {
    return '座標: $lat, $lng';
  }

  @override
  String get hazardDialogTypeLabel => '危險類型';

  @override
  String get hazardDialogSeverityLabel => '嚴重程度';

  @override
  String get hazardDialogSeverityMin => '輕微';

  @override
  String get hazardDialogSeverityMax => '致命';

  @override
  String get hazardDialogRadiusLabel => '影響半徑';

  @override
  String get hazardDialogDescHint => '簡述狀況 (選填)';

  @override
  String get hazardDialogCancel => '取消';

  @override
  String get hazardDialogPublish => '發布至 Mesh';

  @override
  String get matchTitle => '物資媒合';

  @override
  String get matchTabSupplies => '我的物資';

  @override
  String get matchTabRequests => '我的需求';

  @override
  String get matchTabNegotiations => '進行中';

  @override
  String get matchTabCommunity => '社區';

  @override
  String get matchFabRegisterSupply => '登記物資供給';

  @override
  String get matchFabPublishRequest => '發布物資需求';

  @override
  String get matchNegAcceptedSnack => '協商已接受';

  @override
  String get matchNegDeclinedSnack => '協商已拒絕';

  @override
  String get matchNegCancelledSnack => '協商已取消';

  @override
  String get matchHandoffCompleteSnack => '交接完成';

  @override
  String get matchNegExpiredSnack => '協商已逾期';

  @override
  String get matchOverQuantityWarning => '物資超量警告';

  @override
  String matchLoadError(String error) {
    return '載入錯誤: $error';
  }

  @override
  String get matchGpsOpenSettings => '開啟設定';

  @override
  String get matchGpsEnableLocation => '開啟定位';

  @override
  String get matchRetry => '重試';

  @override
  String get matchUrgencyEmergency => '緊急求救';

  @override
  String get matchUrgencyHelp => '求助';

  @override
  String get matchUrgencySupply => '物資';

  @override
  String get matchUrgencyInfo => '資訊';

  @override
  String get matchCountdownExpired => '已逾期';

  @override
  String matchCancelSupplySnack(String name) {
    return '已取消供給：$name';
  }

  @override
  String matchCancelRequestSnack(String name) {
    return '已取消需求：$name';
  }

  @override
  String matchCancelFailSnack(String error) {
    return '取消失敗: $error';
  }

  @override
  String get matchAcceptSnack => '已接受協商';

  @override
  String matchAcceptFailSnack(String error) {
    return '接受失敗: $error';
  }

  @override
  String get matchDeclineSnack => '已拒絕協商';

  @override
  String matchDeclineFailSnack(String error) {
    return '拒絕失敗: $error';
  }

  @override
  String matchCommunityRequestSnack(int qty, String name) {
    return '已發布需求 $qty 份「$name」';
  }

  @override
  String matchCommunitySupplySnack(int qty, String name) {
    return '已登記供給 $qty 份「$name」';
  }

  @override
  String matchCommunityFailSnack(String error) {
    return '發布失敗: $error';
  }

  @override
  String get matchCommunityNote => '回應社區供給';

  @override
  String get suppliesEmptyTitle => '尚未登記物資供給';

  @override
  String get suppliesEmptySubtitle => '點擊下方按鈕登記您可提供的物資';

  @override
  String get suppliesStatusExhausted => '已耗盡';

  @override
  String get suppliesStatusPartial => '部分承諾';

  @override
  String get suppliesStatusAvailable => '可用';

  @override
  String get suppliesDeliveryDeliver => '可協助送達';

  @override
  String get suppliesDeliveryPickup => '需求者自取';

  @override
  String get suppliesQtyTotal => '總量';

  @override
  String get suppliesQtyAvailable => '可用';

  @override
  String get suppliesQtyCommitted => '承諾中';

  @override
  String get suppliesCancelButton => '取消';

  @override
  String get suppliesCancelDialogTitle => '取消物資供給';

  @override
  String suppliesCancelDialogContent(String name) {
    return '確定要取消「$name」嗎？\n取消後將從 Mesh 網路移除。';
  }

  @override
  String get suppliesCancelDialogBack => '返回';

  @override
  String get suppliesCancelDialogConfirm => '確定取消';

  @override
  String get suppliesNotFoundSnack => '找不到對應的發布記錄';

  @override
  String get requestsEmptyTitle => '尚未發布物資需求';

  @override
  String get requestsEmptySubtitle => '點擊下方按鈕發布您需要的物資';

  @override
  String get requestsStatusMatching => '媒合中';

  @override
  String get requestsStatusFulfilled => '已滿足';

  @override
  String get requestsStatusWaiting => '等待中';

  @override
  String get requestsQtyNeeded => '需求';

  @override
  String get requestsQtyRemaining => '剩餘';

  @override
  String get requestsQtyFulfilled => '已滿足';

  @override
  String get requestsQtyUnit => '份';

  @override
  String get requestsProposalsTitle => '收到的提議：';

  @override
  String requestsProposalOffer(int qty) {
    return '提供 $qty 份';
  }

  @override
  String requestsProposalRemaining(String remaining) {
    return '剩餘 $remaining';
  }

  @override
  String get requestsAcceptButton => '接受';

  @override
  String get requestsDeclineButton => '拒絕';

  @override
  String get requestsCancelButton => '取消';

  @override
  String get requestsCancelDialogTitle => '取消物資需求';

  @override
  String requestsCancelDialogContent(String name) {
    return '確定要取消「$name」嗎？\n取消後將從 Mesh 網路移除。';
  }

  @override
  String get requestsCancelDialogBack => '返回';

  @override
  String get requestsCancelDialogConfirm => '確定取消';

  @override
  String get negEmptyTitle => '目前沒有進行中的協商';

  @override
  String get negEmptySubtitle => '當有人回應您的物資或需求時，協商會顯示在這裡';

  @override
  String get negStatusPending => '等待確認';

  @override
  String get negStatusAccepted => '已接受';

  @override
  String get negStatusNavigating => '導航中';

  @override
  String get negRoleRequester => '需求方';

  @override
  String get negRoleProvider => '供給方';

  @override
  String get negRoleMeProvider => '我提供';

  @override
  String get negRoleMeRequester => '我需要';

  @override
  String get negScoreUnit => '分';

  @override
  String get negStaleLabel => '超時';

  @override
  String get negViewMapButton => '查看地圖';

  @override
  String get negCancelButton => '取消';

  @override
  String get negCancelDialogTitle => '取消協商';

  @override
  String get negCancelDialogContent => '確定要取消此協商嗎？';

  @override
  String get negCancelDialogBack => '返回';

  @override
  String get negCancelDialogConfirm => '確定取消';

  @override
  String negQtyUnit(int qty) {
    return '$qty 份';
  }

  @override
  String get communityEmptyTitle => '尚無社區動態';

  @override
  String get communityEmptySubtitle => '同區域其他用戶的物資供給與需求會顯示在這裡';

  @override
  String get communityTypeSupply => '有人可提供';

  @override
  String get communityTypeRequest => '有人需要';

  @override
  String get communityActionNeed => '我需要';

  @override
  String get communityActionHelp => '我想幫忙';

  @override
  String get communityDialogConfirmNeed => '確認需求數量';

  @override
  String get communityDialogConfirmSupply => '確認提供數量';

  @override
  String communityDialogSupplyInfo(String name, int qty) {
    return '有人可以提供「$name」$qty 份';
  }

  @override
  String communityDialogRequestInfo(String name, int qty) {
    return '有人需要「$name」$qty 份';
  }

  @override
  String get communityDialogHowManyNeed => '您需要幾份？';

  @override
  String get communityDialogHowManySupply => '您可以提供幾份？';

  @override
  String get communityDialogQtyHint => '數量';

  @override
  String get communityDialogQtySuffix => '份';

  @override
  String get communityDialogCancel => '取消';

  @override
  String get communityDialogConfirmNeedButton => '確認需求';

  @override
  String get communityDialogConfirmSupplyButton => '確認提供';

  @override
  String get communityDialogQtyError => '數量必須大於 0';

  @override
  String get supplyRegTitle => '登記物資供給';

  @override
  String get supplyRegCategoryLabel => '物資大類';

  @override
  String supplyRegSubCategoryLabel(String categoryLabel) {
    return '→ $categoryLabel 子類別';
  }

  @override
  String get supplyRegItemLabel => '具體品項 (可選)';

  @override
  String get supplyRegExpiryLabel => '有效期限';

  @override
  String get supplyRegExpiryHint => '點擊選擇有效期限 (選填)';

  @override
  String get supplyRegConditionLabel => '物品狀態';

  @override
  String get supplyRegQtyLabel => '數量';

  @override
  String get supplyRegQtyValidator => '請輸入數量';

  @override
  String get supplyRegDeliverySection => '交接方式（可複選）';

  @override
  String get supplyRegDeliveryDeliver => '我送過去';

  @override
  String get supplyRegDeliveryDeliverDesc => '主動將物資送到對方位置';

  @override
  String get supplyRegDeliveryPickup => '對方來取';

  @override
  String get supplyRegDeliveryPickupDesc => '對方來我這裡取物資';

  @override
  String get supplyRegDeliveryDropoff => '放置物資';

  @override
  String get supplyRegDeliveryDropoffDesc => '無接觸交接 — 放置後通知對方自取';

  @override
  String get supplyRegNoteHint => '備註描述 (選填)';

  @override
  String supplyRegRange(String km) {
    return '覆蓋半徑: $km km';
  }

  @override
  String get supplyRegRangeNote => '* 由地理環境自動建議，可手動調整';

  @override
  String get supplyRegPublishing => '發布中...';

  @override
  String get supplyRegPublishButton => '發布至 Mesh 網路';

  @override
  String get supplyRegSuccessSnack => '物資已成功發布！';

  @override
  String supplyRegFailSnack(String error) {
    return '發布失敗: $error';
  }

  @override
  String get reqSheetTitle => '發佈物資需求';

  @override
  String get reqSheetCategoryLabel => '需要什麼物資？';

  @override
  String get reqSheetSubCategoryLabel => '→ 子類別';

  @override
  String get reqSheetItemLabel => '具體品項 (可選)';

  @override
  String get reqSheetQtyLabel => '需求數量';

  @override
  String get reqSheetMobilitySection => '交接方式';

  @override
  String get reqSheetMobilityPickup => '我可以過去拿';

  @override
  String get reqSheetMobilityPickupDesc => '我可以移動去取物資';

  @override
  String get reqSheetMobilityDelivery => '需要送過來';

  @override
  String get reqSheetMobilityDeliveryDesc => '無法移動，需要人送來';

  @override
  String get reqSheetMobilityDropoff => '無接觸交接';

  @override
  String get reqSheetMobilityDropoffDesc => '供給方放置物資，我自行取回';

  @override
  String reqSheetRange(String km) {
    return '搜尋半徑: $km km';
  }

  @override
  String get reqSheetNoteHint => '備註描述 (選填)';

  @override
  String get reqSheetPublishing => '廣播中...';

  @override
  String get reqSheetPublishButton => '發布需求至 Mesh 網路';

  @override
  String get reqSheetSuccessSnack => '需求已廣播至 Mesh 網路！';

  @override
  String reqSheetFailSnack(String error) {
    return '發布失敗: $error';
  }

  @override
  String get navTitle => '導航指引';

  @override
  String get navDirectionProviderToReq => '供給者前往需求者';

  @override
  String get navDirectionReqToProvider => '需求者前往供給者';

  @override
  String navSupplyInfo(int supplyQty, int requestQty, int ratio) {
    return '供給: $supplyQty 份 ←→ 需求: $requestQty 份 (滿足率 $ratio%)';
  }

  @override
  String get navGpsLocating => 'GPS 定位中...';

  @override
  String get navBleDetected => '偵測到 Mesh 節點';

  @override
  String navBleSignal(String strength) {
    return '信號 $strength';
  }

  @override
  String get navBleSignalStrong => '強 (很近)';

  @override
  String get navBleSignalMedium => '中 (附近)';

  @override
  String get navBleSignalWeak => '弱 (較遠)';

  @override
  String get navBleScanning => '掃描藍牙中... 接近對方時會自動偵測';

  @override
  String get navHandoffButton => '開始交接';

  @override
  String get navHandoffWaiting => '等待偵測到對方藍牙...';

  @override
  String get navCancelDialogTitle => '媒合已取消';

  @override
  String get navCancelDialogContent => '對方已取消此次媒合。';

  @override
  String get navCancelDialogBack => '返回首頁';

  @override
  String get navCompleteSnack => '交接完成！';

  @override
  String get handoffTitle => '實體交接確認';

  @override
  String handoffProviderResource(String resourceType) {
    return '物資：$resourceType';
  }

  @override
  String get handoffProviderPinLabel => '告訴對方以下 PIN 碼';

  @override
  String handoffProviderTimeout(String timeout) {
    return '若 $timeout 內未完成，物資將自動歸還';
  }

  @override
  String get handoffProviderWaiting => '等待對方透過 BLE 輸入 PIN 確認收到物資...';

  @override
  String get handoffProviderGattNote => '(本裝置已開啟 GATT 交接廣播)';

  @override
  String get handoffRequesterPinPrompt => '請輸入供給方顯示的 4 位 PIN';

  @override
  String handoffRequesterLockout(int seconds) {
    return '輸入錯誤次數過多，請等待 $seconds 秒...';
  }

  @override
  String handoffRequesterWrong(int remaining) {
    return '錯誤！剩餘嘗試次數: $remaining / 6';
  }

  @override
  String get handoffRequesterConfirmButton => '確認收到物資';

  @override
  String get handoffDropoffProviderTitle => '無接觸交接 — 放置物資';

  @override
  String get handoffDropoffLocationLabel => '放置位置';

  @override
  String get handoffDropoffUseCurrentLocation => '點擊使用目前位置';

  @override
  String get handoffDropoffLocateButton => '定位';

  @override
  String get handoffDropoffDescLabel => '放置描述 / 照片備註（選填）';

  @override
  String get handoffDropoffDescHint => '例如：放在大門左側紙箱旁';

  @override
  String get handoffDropoffWaitingButton => '已放置，等待對方取回';

  @override
  String get handoffDropoffConfirmButton => '確認放置物資';

  @override
  String get handoffDropoffRequesterTitle => '無接觸交接';

  @override
  String get handoffDropoffRequesterContent => '供給方已將物資放置於指定位置，\n請前往取回後確認。';

  @override
  String get handoffDropoffRequesterConfirm => '已取得物資';

  @override
  String get handoffSuccessTitle => '交接完成！';

  @override
  String handoffSuccessContent(String resourceType) {
    return '$resourceType 已成功轉交';
  }

  @override
  String get handoffSuccessBack => '返回';

  @override
  String get handoffCancelledTitle => '交接已取消';

  @override
  String get handoffCancelledContent => '物資已歸還至可用狀態';

  @override
  String get handoffCancelledBack => '返回';

  @override
  String get handoffTimeout30min => '30 分鐘';

  @override
  String get handoffTimeout4hr => '4 小時';

  @override
  String get medicalTitle => '醫療卡';

  @override
  String get medicalSosInfo => '帶有廣播圖標的欄位會在 SOS 求救時\n隨訊號一起透過 Mesh 網路傳送給附近救援者';

  @override
  String get medicalPresetLabel => '快速預設';

  @override
  String get medicalPresetMinimal => '最小揭露';

  @override
  String get medicalPresetRecommended => '建議設定';

  @override
  String get medicalPresetFull => '全部分享';

  @override
  String medicalPresetApplied(String presetName) {
    return '已套用「$presetName」預設';
  }

  @override
  String get medicalSectionBasic => '基本生理';

  @override
  String get medicalSectionBackground => '醫療背景';

  @override
  String get medicalSectionEmergency => '急救資訊';

  @override
  String get medicalFieldName => '姓名';

  @override
  String get medicalFieldAge => '年齡';

  @override
  String get medicalFieldHeight => '身高 (cm)';

  @override
  String get medicalFieldWeight => '體重 (kg)';

  @override
  String get medicalFieldBloodType => '血型';

  @override
  String get medicalFieldConditions => '醫療狀況';

  @override
  String get medicalFieldAllergies => '過敏原';

  @override
  String get medicalFieldMedications => '目前藥物';

  @override
  String get medicalFieldEmergencyContact => '緊急聯絡人';

  @override
  String get medicalFieldOrganDonor => '器官捐贈意願';

  @override
  String get medicalFieldPrimaryLanguage => '主要語言';

  @override
  String get medicalHintName => '你的姓名';

  @override
  String get medicalHintAge => '年齡';

  @override
  String get medicalSuffixAge => '歲';

  @override
  String get medicalHintHeight => '身高';

  @override
  String get medicalSuffixHeight => 'cm';

  @override
  String get medicalHintWeight => '體重';

  @override
  String get medicalSuffixWeight => 'kg';

  @override
  String get medicalHintConditions => '如：糖尿病、癲癇、氣喘（用頓號分隔）';

  @override
  String get medicalHintMedications => '如：胰島素、降血壓藥（用頓號分隔）';

  @override
  String get medicalHintLanguage => '如：繁體中文、English';

  @override
  String get medicalBloodTypeNone => '未選擇';

  @override
  String get medicalAllergenLabel => '過敏原';

  @override
  String get medicalAllergenHint => '過敏原';

  @override
  String get medicalReactionHint => '反應症狀';

  @override
  String get medicalReactionUnknown => '未知反應';

  @override
  String get medicalEcPhoneLabel => '緊急聯絡人電話';

  @override
  String get medicalEcPhoneHint => '0912-345-678';

  @override
  String get medicalEcRelationLabel => '與你的關係';

  @override
  String get medicalEcRelationHint => '如：母親、配偶';

  @override
  String get medicalOrganDonorLabel => '器官捐贈意願';

  @override
  String get medicalOrganDonorNone => '未設定';

  @override
  String get medicalOrganDonorYes => '願意';

  @override
  String get medicalOrganDonorNo => '不願意';

  @override
  String get medicalHealthImportButton => '從 Health Connect 匯入';

  @override
  String get medicalHealthConnectRequired => '需要 Health Connect';

  @override
  String get medicalHealthConnectInstallGuide =>
      '此功能需要 Google Health Connect 應用。\n\n請前往 Google Play 商店安裝「Health Connect」後再試。\n\n安裝後，請先在 Health Connect 中新增您的健康資料（身高、體重、血型），然後回到此頁面匯入。';

  @override
  String get medicalHealthConnectDismiss => '了解';

  @override
  String get medicalHealthConnectInstall => '前往安裝';

  @override
  String get medicalHealthConnectAuthFail => '授權失敗';

  @override
  String get medicalHealthConnectAuthGuide =>
      '未獲得 Health Connect 讀取權限。\n\n請手動授權：\n1. 開啟「Health Connect」應用\n2. 點選「應用程式權限」\n3. 找到「烽傳」並允許讀取身高、體重、血型';

  @override
  String get medicalHealthConnectNoData => 'Health Connect 中沒有找到健康資料';

  @override
  String medicalHealthConnectImported(int count) {
    return '已從 Health Connect 匯入 $count 項資料';
  }

  @override
  String get medicalHealthConnectNoNewData => '未匯入新資料（欄位已有值或無可用資料）';

  @override
  String medicalHealthConnectFailSnack(String error) {
    return 'Health Connect 匯入失敗：$error\n請確認已安裝 Health Connect 應用';
  }

  @override
  String get medicalSaving => '儲存中...';

  @override
  String get medicalSaveButton => '儲存醫療卡';

  @override
  String get medicalSavedSnack => '醫療卡已儲存';

  @override
  String medicalSaveFailSnack(String error) {
    return '儲存失敗: $error';
  }

  @override
  String get medicalSosToggleOn => 'ON';

  @override
  String get medicalSosToggleOff => 'OFF';

  @override
  String get chatListTitle => '聊天室';

  @override
  String get chatListRefreshTooltip => '重新整理';

  @override
  String get chatListRoomNational => '全國公告';

  @override
  String get chatListRoomCounty => '縣市公告';

  @override
  String get chatListRoomTownship => '鄉鎮區公告';

  @override
  String get chatListRoomVillage => '里聊天室';

  @override
  String get chatListRoomCustom => '自訂頻道';

  @override
  String get chatListEmptyTitle => '尚未加入任何聊天室';

  @override
  String get chatListEmptySubtitle => '點擊右下角 + 加入或掃碼';

  @override
  String get chatListAutoJoin => '自動加入所在里聊天室';

  @override
  String get chatListAutoJoinSuccess => '已自動加入所在里的聊天室';

  @override
  String get chatListAutoJoinFail => '無法取得位置資訊，請手動加入';

  @override
  String get chatListFabTooltip => '加入聊天室';

  @override
  String get chatListAdminBadge => '公告頻道';

  @override
  String get chatListLeaveTitle => '離開聊天室';

  @override
  String chatListLeaveContent(String roomName) {
    return '確定要離開「$roomName」嗎？歷史訊息將被清除。';
  }

  @override
  String get chatListLeaveCancel => '取消';

  @override
  String get chatListLeaveConfirm => '離開';

  @override
  String chatRoomMessageCount(int count) {
    return '$count 則訊息';
  }

  @override
  String get chatRoomEmpty => '還沒有訊息';

  @override
  String get chatRoomReply => '回覆訊息';

  @override
  String get chatRoomAdminLock => '公告頻道 — 僅管理員（L3）可發言';

  @override
  String get chatRoomInputHint => '輸入訊息...';

  @override
  String chatRoomSendCooldown(int seconds) {
    return '發送失敗，請等待 $seconds 秒後再試';
  }

  @override
  String get chatRoomAnonymous => '匿名';

  @override
  String get chatJoinTitle => '加入聊天室';

  @override
  String get chatJoinAutoSection => '自動加入';

  @override
  String get chatJoinAutoDesc => '根據 GPS 位置自動加入所在里聊天室及行政區公告頻道';

  @override
  String get chatJoinGpsLocating => '正在取得 GPS 位置...';

  @override
  String chatJoinGpsWaiting(int seconds) {
    return '等待 GPS 定位中... (${seconds}s)';
  }

  @override
  String get chatJoinGpsQuerying => '正在查詢所在行政區...';

  @override
  String get chatJoinGpsFail => 'GPS 定位失敗，請確認 GPS 已開啟，或使用下方手動設定';

  @override
  String get chatJoinAutoSuccess => '已加入所在里聊天室及公告頻道';

  @override
  String get chatJoinAutoFailRegion => '無法識別所在行政區，請使用手動設定';

  @override
  String get chatJoinAutoButton => '偵測並加入里聊天室';

  @override
  String get chatJoinManualSection => '手動設定所在區域';

  @override
  String get chatJoinManualDesc => '輸入縣市、鄉鎮區或里名稱搜尋，選擇後加入對應聊天室';

  @override
  String get chatJoinSearchHint => '例：新興區、安康里、高雄市';

  @override
  String get chatJoinSearchButton => '搜尋';

  @override
  String chatJoinSearchResults(int count) {
    return '搜尋結果（$count 筆）';
  }

  @override
  String chatJoinSearchVillcode(String villcode) {
    return '代碼: $villcode';
  }

  @override
  String get chatJoinSearchNoResults => '找不到符合的村里，請嘗試其他關鍵字';

  @override
  String chatJoinSuccess(String fullName) {
    return '已加入 $fullName 聊天室及公告頻道';
  }

  @override
  String chatJoinFail(String error) {
    return '加入失敗: $error';
  }

  @override
  String get chatJoinInviteSection => '輸入邀請碼';

  @override
  String get chatJoinInviteDesc => '輸入聊天室 ID 或邀請碼加入自訂頻道';

  @override
  String get chatJoinInviteHint => '聊天室 ID 或 ID:密碼';

  @override
  String get chatJoinInviteButton => '加入';

  @override
  String get chatJoinInviteSuccess => '已加入聊天室';

  @override
  String get chatJoinInfoSection => '聊天室說明';

  @override
  String get chatJoinInfoVillage => '- 里聊天室：所有人皆可發言，每 3 分鐘可發一則';

  @override
  String get chatJoinInfoAdmin => '- 鄉鎮區/縣市/全國：僅管理員（L3）可發布公告';

  @override
  String get chatJoinInfoCustom => '- 自訂頻道：需掃碼或輸入邀請碼加入';

  @override
  String get chatJoinInfoMesh => '- 所有訊息透過 BLE Mesh 傳播，48 小時後自動清除';

  @override
  String get chatJoinInfoSwitch => '- 切換區域後，舊區域的聊天室會被移除';

  @override
  String get survivalListening => '正在監聽周遭求救與物資訊號...';

  @override
  String survivalBattery(int level) {
    return '電量: $level%';
  }

  @override
  String get survivalDataMuleDisable => '停用 Data Mule';

  @override
  String get survivalDataMuleEnable => '啟用 Data Mule';

  @override
  String get survivalBlePause => '暫停 BLE';

  @override
  String get survivalBleResume => '恢復 BLE';

  @override
  String get survivalStatsLocalEvents => '本機事件';

  @override
  String get survivalStatsBleConnections => 'BLE 連線';

  @override
  String get survivalRecentEvents => '最近 Mesh 事件';

  @override
  String get survivalDataMuleFailSnack => 'Data Mule 服務啟動失敗\nBLE Mesh 層仍持續運作中';

  @override
  String survivalBleFailSnack(String error) {
    return 'BLE 啟動失敗：$error\n請確認藍牙已開啟且已授予權限';
  }

  @override
  String get survivalDataMuleDialogTitle => '什麼是 Data Mule？';

  @override
  String get survivalDataMuleDialogDismiss => '了解';

  @override
  String get survivalExportButton => '匯出完整日誌';

  @override
  String survivalExportSuccess(String filename) {
    return '日誌已存到「下載」：$filename';
  }

  @override
  String survivalExportFail(String error) {
    return '匯出失敗：$error';
  }

  @override
  String survivalMeshReceived(int bytes) {
    return '[Mesh] 收到 $bytes bytes';
  }

  @override
  String get survivalDataMuleDialogContent =>
      'Data Mule（資料騾）是一種離線中繼模式：\n\n• 你的手機會持續接收周圍裝置的求救與物資訊號\n• 即使你移動到不同區域，攜帶的資料會自動轉發給新遇到的裝置\n• 適合在災區移動的志工或救難人員，幫助訊息跨越斷網區域\n\n啟用後會以 Android 前景服務保持運作，即使螢幕關閉也不會被系統終止。\n\n耗電量：中等（持續 BLE 掃描+廣播）';

  @override
  String get stationTitle => '據點物資管理';

  @override
  String get stationAuthRequired => '需要 L2 以上身分等級';

  @override
  String stationAuthCurrentLevel(int level) {
    return '目前等級: L$level';
  }

  @override
  String get stationAuthDesc => '據點物資管理功能僅限經過驗證的用戶使用。\n請透過實體交叉驗證提升身分等級。';

  @override
  String get stationTabAdd => '新增據點物資';

  @override
  String get stationTabManage => '管理已註冊';

  @override
  String get stationCategoryLabel => '物資大類';

  @override
  String get stationSubCategoryLabel => '→ 子類別';

  @override
  String get stationItemLabel => '具體品項 (可選)';

  @override
  String get stationQtyLabel => '庫存數量';

  @override
  String get stationTotalQtyLabel => '總庫存數量';

  @override
  String get stationQuotaSection => '個人配額設定';

  @override
  String get stationQuotaCategoryLimit => '每人每類上限';

  @override
  String get stationQuotaTotalLimit => '每人總量上限';

  @override
  String get stationResetCycleLabel => '配額重設週期';

  @override
  String get stationResetChip6h => '6 小時';

  @override
  String get stationResetChip12h => '12 小時';

  @override
  String get stationResetChip24h => '24 小時';

  @override
  String get stationResetChip48h => '48 小時';

  @override
  String get stationResetChip72h => '72 小時';

  @override
  String get stationResetChipNone => '不重設';

  @override
  String stationResetNoteInterval(int hours) {
    return '每 $hours 小時自動重設個人已領取額度';
  }

  @override
  String get stationResetNoteNone => '配額用完即止，不會自動重設';

  @override
  String get stationVisibilityLabel => '物資可見範圍';

  @override
  String get stationVisibilityVillage => '指定村里';

  @override
  String get stationVisibilityVillageDesc => '可多選鄰近村里';

  @override
  String get stationVisibilityTownship => '整個鄉鎮區';

  @override
  String get stationVisibilityTownshipDesc => '該行政區全部可見';

  @override
  String get stationVisibilityNoVillages => '無法取得附近村里資訊';

  @override
  String get stationVisibilityVillageNote => '* 已根據目前位置列出鄰近村里，可勾選多個';

  @override
  String get stationVisibilityTownNotLocated => '尚未定位';

  @override
  String get stationVisibilityTownNote => '* 將以目前定位的鄉鎮市區為可見範圍';

  @override
  String get stationQtyValidator => '請輸入有效數量';

  @override
  String get stationFieldRequired => '必填';

  @override
  String get stationPublishing => '發布中...';

  @override
  String get stationPublishButton => '發布據點物資';

  @override
  String get stationPublishSuccess => '據點物資已成功發布！';

  @override
  String get stationManageEmptyTitle => '尚無據點物資';

  @override
  String get stationManageEmptySubtitle => '切換到「新增據點物資」頁面開始註冊';

  @override
  String get stationStatusSufficient => '充足';

  @override
  String get stationStatusLow => '低庫存';

  @override
  String get stationStatusCritical => '即將用盡';

  @override
  String get stationStatusDepleted => '已用盡';

  @override
  String get stationInfoTotalQty => '總庫存';

  @override
  String get stationInfoUsed => '已領取';

  @override
  String get stationInfoRemaining => '剩餘';

  @override
  String get stationInfoUsers => '領取人數';

  @override
  String stationInfoQtyUnit(int qty) {
    return '$qty 份';
  }

  @override
  String stationInfoUsersUnit(int count) {
    return '$count 人';
  }

  @override
  String get stationQuotaRulesLabel => '配額規則';

  @override
  String get stationQuotaCategoryLimitInfo => '每人每類上限';

  @override
  String get stationQuotaTotalLimitInfo => '每人總量上限';

  @override
  String get stationQuotaResetCycleInfo => '重設週期';

  @override
  String stationQuotaResetHours(int hours) {
    return '$hours 小時';
  }

  @override
  String get stationQuotaResetNone => '不重設';

  @override
  String get stationVisibleZones => '可見範圍';

  @override
  String stationVisibleZonesCount(int count) {
    return '$count 個村里';
  }

  @override
  String stationVisibleTownship(String township) {
    return '鄉鎮區 $township';
  }

  @override
  String get stationQuotaDetailButton => '額度明細';

  @override
  String get stationQuotaResetButton => '重設額度';

  @override
  String get stationRemoveButton => '下架';

  @override
  String get stationQuotaDetailEmpty => '尚無領取紀錄';

  @override
  String stationQuotaDetailTitle(String name) {
    return '額度明細 — $name';
  }

  @override
  String stationQuotaUserLabel(String keyHex) {
    return '用戶 $keyHex...';
  }

  @override
  String stationQuotaUsedTotal(int used, int total) {
    return '本期已領: $used / 總計: $total';
  }

  @override
  String stationQuotaLastReset(String date) {
    return '上次重設: $date';
  }

  @override
  String get stationResetAllDialogTitle => '重設所有額度';

  @override
  String get stationResetAllDialogContent =>
      '確定要重設此物資的所有用戶額度嗎？\n重設後所有人的已領取數量將歸零。';

  @override
  String get stationResetAllDialogCancel => '取消';

  @override
  String get stationResetAllDialogConfirm => '確認重設';

  @override
  String get stationResetSuccessSnack => '額度已重設';

  @override
  String stationResetFailSnack(String error) {
    return '重設失敗: $error';
  }

  @override
  String get stationRemoveDialogTitle => '下架據點物資';

  @override
  String stationRemoveDialogContent(String name) {
    return '確定要下架「$name」嗎？\n此操作會將該物資標記為已消耗。';
  }

  @override
  String get stationRemoveDialogCancel => '取消';

  @override
  String get stationRemoveDialogConfirm => '確認下架';

  @override
  String get stationRemoveSuccessSnack => '物資已下架';

  @override
  String stationRemoveFailSnack(String error) {
    return '下架失敗: $error';
  }

  @override
  String get batteryAndroidOnly => '此功能僅適用 Android 裝置';

  @override
  String get batteryIntroTitle => '重要！Mesh 網路需要在後台持續運行';

  @override
  String get batteryIntroAppName => '烽傳';

  @override
  String get batteryIntroConsequence1 => '無法接收附近求救訊號';

  @override
  String get batteryIntroConsequence2 => '無法擔任 Data Mule 中繼節點';

  @override
  String get batteryIntroConsequence3 => '無法自動同步物資媒合資訊';

  @override
  String get batteryIntroGuide => '接下來會引導您完成 1-2 步設定，確保 Mesh 網路持續運作。';

  @override
  String get batteryStep1Label => '步驟 1/2';

  @override
  String get batteryStep1Title => '系統電池優化豁免';

  @override
  String get batteryStep1Button => '開啟電池優化豁免';

  @override
  String get batteryStep1Done => '已完成';

  @override
  String get batteryStep1Success => '已成功豁免電池優化';

  @override
  String get batteryLaterButton => '稍後再說';

  @override
  String get batteryStartButton => '開始設定';

  @override
  String get batterySkipButton => '跳過此步';

  @override
  String get batteryNextButton => '下一步';

  @override
  String get batteryFinishButton => '完成';

  @override
  String get batteryDoneTitle => '設定完成！';

  @override
  String get batteryDoneContent => '背景執行設定完成！';

  @override
  String get batteryDoneNote => '前景服務通知會在 Mesh 守護啟動後出現';

  @override
  String get batteryGuideTitle => '背景執行設定';

  @override
  String get batteryIntroBody =>
      '烽傳 依賴藍牙 Mesh 在背景持續廣播與中繼救援資訊。\n\n若 Android 系統將 App 殺掉，您的裝置將：';

  @override
  String get batteryStep1Desc =>
      '點擊下方按鈕，系統會彈出確認視窗。\n請選擇「允許」，讓 烽傳 不受 Doze 省電限制。';

  @override
  String get batteryStep2Label => '步驟 2/2';

  @override
  String batteryStep2Title(String manufacturer) {
    return '$manufacturer 背景執行設定';
  }

  @override
  String get batteryGoSettings => '前往設定';

  @override
  String get batteryOpenedSettings => '已開啟設定';

  @override
  String get batteryReturnNote => '請在設定頁面完成操作後返回此畫面';

  @override
  String get batteryManufacturerXiaomi => '小米 / Redmi';

  @override
  String get batteryManufacturerHuawei => '華為';

  @override
  String get batteryManufacturerHonor => '榮耀';

  @override
  String get batteryManufacturerOppo => 'OPPO';

  @override
  String get batteryManufacturerRealme => 'realme';

  @override
  String get batteryManufacturerVivo => 'vivo';

  @override
  String get batteryManufacturerSamsung => '三星 Samsung';

  @override
  String get batteryManufacturerAsus => '華碩 ASUS';

  @override
  String get batteryInstructionXiaomi =>
      '請在「自啟動管理」中找到 烽傳 → 開啟自啟動\n另外在「省電策略」→ 選擇「無限制」';

  @override
  String get batteryInstructionHuawei =>
      '請在「啟動管理」中找到 烽傳\n→ 關閉「自動管理」→ 手動開啟所有開關\n另在「鎖屏清理」中不要清理本 App';

  @override
  String get batteryInstructionHonor => '請在「啟動管理」中找到 烽傳\n→ 關閉「自動管理」→ 手動開啟所有開關';

  @override
  String get batteryInstructionOppo =>
      '請在「自啟動管理」中允許 烽傳 自啟動\n另在「省電」→「App 電池管理」→ 選擇「不優化」';

  @override
  String get batteryInstructionRealme =>
      '請在「自啟動管理」中允許 烽傳 自啟動\n另在「省電」→「App 電池管理」→ 選擇「不優化」';

  @override
  String get batteryInstructionVivo => '請在「後臺管理」中允許 烽傳 高耗電運行\n另在「自啟動」中開啟本 App';

  @override
  String get batteryInstructionSamsung =>
      '請在「電池」→「背景使用限制」\n→ 將 烽傳 從「受限 App」清單移除\n或加入「永不進入休眠」清單';

  @override
  String get batteryInstructionAsus => '請在「自動啟動管理員」中允許 烽傳\n另在「電池」中選擇「不受限」';

  @override
  String get batteryInstructionDefault =>
      '請到手機的「設定」→「電池」→「背景執行管理」中\n允許 烽傳 在背景運行。';

  @override
  String get batteryDoneBody => '烽傳 現在可以在背景持續運行 Mesh 網路，\n即使螢幕關閉也能接收並中繼救援資訊。';

  @override
  String get locationGpsDisabled => 'GPS 服務未開啟，請前往系統設定啟用定位功能';

  @override
  String get locationGpsDeniedForever => 'GPS 權限已被永久拒絕，請前往系統設定 → 應用程式 → 授予定位權限';

  @override
  String get locationGpsDenied => '請授予 GPS 定位權限以取得更準確的媒合結果';

  @override
  String get locationGpsTimeout => 'GPS 定位逾時，請確認已開啟定位功能或移到開闊處';

  @override
  String locationGpsFail(String error) {
    return 'GPS 定位失敗: $error';
  }

  @override
  String locationInitFail(String error) {
    return '定位服務初始化失敗: $error';
  }

  @override
  String get locationDirectionN => '北方';

  @override
  String get locationDirectionNE => '東北方';

  @override
  String get locationDirectionE => '東方';

  @override
  String get locationDirectionSE => '東南方';

  @override
  String get locationDirectionS => '南方';

  @override
  String get locationDirectionSW => '西南方';

  @override
  String get locationDirectionW => '西方';

  @override
  String get locationDirectionNW => '西北方';

  @override
  String get supplyCategory_WATER => '飲用水';

  @override
  String get supplyCategory_FOOD => '食物';

  @override
  String get supplyCategory_MEDICAL => '藥品/急救';

  @override
  String get supplyCategory_HYGIENE => '衛生/生理';

  @override
  String get supplyCategory_PROTECTION => '防護裝備';

  @override
  String get supplyCategory_SHELTER => '住所/避難';

  @override
  String get supplyCategory_TOOL => '工具/設備';

  @override
  String get supplyCategory_PETS => '寵物用品';

  @override
  String get supplyCategory_SKILL => '技能服務';

  @override
  String get supplySubCategory_WATER_BOTTLE => '瓶裝水';

  @override
  String get supplySubCategory_WATER_PURIFY => '淨水設備';

  @override
  String get supplySubCategory_WATER_CONTAINER => '儲水容器';

  @override
  String get supplySubCategory_FOOD_READY => '即食食品';

  @override
  String get supplySubCategory_FOOD_STAPLE => '主食/乾糧';

  @override
  String get supplySubCategory_FOOD_BABY => '嬰幼兒食品';

  @override
  String get supplySubCategory_FOOD_SUPPLEMENT => '營養補充';

  @override
  String get supplySubCategory_FOOD_COOKING => '炊事用具';

  @override
  String get supplySubCategory_MED_PAIN => '止痛退燒';

  @override
  String get supplySubCategory_MED_WOUND => '傷口處理';

  @override
  String get supplySubCategory_MED_CHRONIC => '慢性病藥';

  @override
  String get supplySubCategory_MED_RESPIRATORY => '呼吸道';

  @override
  String get supplySubCategory_MED_GI => '腸胃道';

  @override
  String get supplySubCategory_MED_FIRSTAID_KIT => '急救包/器材';

  @override
  String get supplySubCategory_HYG_FEMININE => '女性生理';

  @override
  String get supplySubCategory_HYG_BABY => '嬰幼兒衛生';

  @override
  String get supplySubCategory_HYG_PERSONAL => '個人清潔';

  @override
  String get supplySubCategory_HYG_SANITATION => '環境衛生';

  @override
  String get supplySubCategory_PROT_RESPIRATORY => '呼吸防護';

  @override
  String get supplySubCategory_PROT_BODY => '身體防護';

  @override
  String get supplySubCategory_PROT_LIGHT => '照明/能源';

  @override
  String get supplySubCategory_SHELTER_TEMP => '臨時避所';

  @override
  String get supplySubCategory_SHELTER_BEDDING => '寢具保暖';

  @override
  String get supplySubCategory_SHELTER_CLOTHING => '衣物';

  @override
  String get supplySubCategory_TOOL_COMM => '通訊工具';

  @override
  String get supplySubCategory_TOOL_RESCUE => '救難工具';

  @override
  String get supplySubCategory_TOOL_POWER => '電力設備';

  @override
  String get supplySubCategory_TOOL_TRANSPORT => '搬運工具';

  @override
  String get supplySubCategory_PET_FOOD => '寵物食品';

  @override
  String get supplySubCategory_PET_CARE => '安置與照護';

  @override
  String get supplySubCategory_SKILL_MEDICAL => '醫療';

  @override
  String get supplySubCategory_SKILL_RESCUE => '搜救';

  @override
  String get supplySubCategory_SKILL_LANG => '翻譯/語言';

  @override
  String get supplySubCategory_SKILL_PSYCH => '心理輔導';

  @override
  String get supplySubCategory_SKILL_CARE => '照護服務';

  @override
  String get supplySubCategory_SKILL_TECH => '技術';

  @override
  String get supplySubCategory_SKILL_LOGISTICS => '後勤/駕駛';

  @override
  String get profileSubtitle => '身分 · 設定 · 醫療資訊';

  @override
  String get profileQuickActionMedicalCardCreate => '建立醫療卡';

  @override
  String get profileQuickActionMedicalCard => '醫療卡';

  @override
  String get profileSectionMesh => 'Mesh 狀態';

  @override
  String get profileSectionTrust => '信任等級';

  @override
  String get profileSectionSettings => '設定';

  @override
  String get profilePubKeyCopied => '公鑰已複製';

  @override
  String get profileSettingsAppearance => '外觀';

  @override
  String get profileSettingsTextScale => '字體大小';

  @override
  String get profileSettingsLanguage => '語言';

  @override
  String get profileSettingsBattery => '背景執行 / 電池優化';

  @override
  String get profileSettingsPrivacy => '隱私與資料';

  @override
  String get profileThemeDark => '深色';

  @override
  String get profileThemeLight => '淺色';

  @override
  String get profileTextScaleStandard => '標準';

  @override
  String get profileTextScaleLarge => '大字';

  @override
  String get profileTextScaleXLarge => '特大字';

  @override
  String get profileTextScaleHuge => '超大字';

  @override
  String get profileMeshBatteryLabel => '裝置電量';

  @override
  String get profileMeshAdvancedLabel => '進階控制';

  @override
  String profileFooterVersion(String version, String build) {
    return '烽傳 v$version · BUILD $build';
  }

  @override
  String get profileFooterTagline => 'OFFLINE · MESH · PRIVATE';

  @override
  String matchHeaderItemsSubtitle(int count) {
    return '$count 項社區資源';
  }

  @override
  String get mapAttributionLabel => '© OpenStreetMap contributors';

  @override
  String get supplyItem_WATER_BOTTLE_500 => '瓶裝水 500ml';

  @override
  String get supplyItem_WATER_BOTTLE_1500 => '瓶裝水 1.5L';

  @override
  String get supplyItem_WATER_BOTTLE_5000 => '桶裝水 5L+';

  @override
  String get supplyItem_WATER_PURIFY_TABLET => '淨水錠';

  @override
  String get supplyItem_WATER_PURIFY_STRAW => '攜帶式濾水器';

  @override
  String get supplyItem_WATER_PURIFY_PUMP => '手壓式淨水器';

  @override
  String get supplyItem_WATER_CONTAINER_FOLD => '折疊水袋 (5-20L)';

  @override
  String get supplyItem_WATER_CONTAINER_JERRY => '硬殼儲水桶 (20L)';

  @override
  String get supplyItem_FOOD_READY_CRACKER => '蘇打餅乾/能量棒';

  @override
  String get supplyItem_FOOD_READY_CAN => '罐頭食品 (含肉/豆)';

  @override
  String get supplyItem_FOOD_READY_RETORT => '調理包 (加熱即食)';

  @override
  String get supplyItem_FOOD_READY_MRE => '軍用/災備即食餐 (MRE)';

  @override
  String get supplyItem_FOOD_STAPLE_RICE => '白米/免洗米';

  @override
  String get supplyItem_FOOD_STAPLE_NOODLE => '乾拌麵/泡麵';

  @override
  String get supplyItem_FOOD_STAPLE_OATS => '麥片/穀粉';

  @override
  String get supplyItem_FOOD_BABY_FORMULA => '嬰兒奶粉';

  @override
  String get supplyItem_FOOD_BABY_PUREE => '寶寶副食品泥';

  @override
  String get supplyItem_FOOD_BABY_BOTTLE => '奶瓶/水杯 (清潔消毒用品)';

  @override
  String get supplyItem_FOOD_SUPP_ELECTROLYTE => '電解質沖泡粉/口服補液鹽';

  @override
  String get supplyItem_FOOD_SUPP_VITAMIN => '綜合維他命';

  @override
  String get supplyItem_FOOD_SUPP_PROTEIN => '高蛋白飲品';

  @override
  String get supplyItem_FOOD_COOK_STOVE => '攜帶型瓦斯爐/酒精爐';

  @override
  String get supplyItem_FOOD_COOK_FUEL => '卡式瓦斯罐/燃料';

  @override
  String get supplyItem_FOOD_COOK_UTENSIL => '免洗餐具 / 折疊鍋組';

  @override
  String get supplyItem_MED_PAIN_ACETAMINOPHEN => '普拿疼 (乙醯胺酚)';

  @override
  String get supplyItem_MED_PAIN_IBUPROFEN => '布洛芬 (Ibuprofen)';

  @override
  String get supplyItem_MED_PAIN_PATCH => '痠痛貼布/藥膏';

  @override
  String get supplyItem_MED_WOUND_BANDAGE => '紗布/彈性繃帶';

  @override
  String get supplyItem_MED_WOUND_GAUZE => '無菌紗布墊 (4×4)';

  @override
  String get supplyItem_MED_WOUND_ANTISEPTIC => '碘酒/生理食鹽水';

  @override
  String get supplyItem_MED_WOUND_TAPE => '醫用膠帶/透氣膠帶';

  @override
  String get supplyItem_MED_WOUND_TOURNIQUET => '止血帶 (CAT)';

  @override
  String get supplyItem_MED_CHRONIC_BP => '降血壓藥 (依醫囑)';

  @override
  String get supplyItem_MED_CHRONIC_DIABETES => '胰島素/降血糖藥';

  @override
  String get supplyItem_MED_CHRONIC_HEART => '心臟用藥 (硝化甘油等)';

  @override
  String get supplyItem_MED_CHRONIC_EPILEPSY => '抗癲癇藥';

  @override
  String get supplyItem_MED_RESP_INHALER => '氣喘吸入劑';

  @override
  String get supplyItem_MED_RESP_MASK_O2 => '氧氣面罩/攜帶氧氣瓶';

  @override
  String get supplyItem_MED_GI_ORS => '口服補液鹽 (ORS)';

  @override
  String get supplyItem_MED_GI_ANTACID => '胃藥/制酸劑';

  @override
  String get supplyItem_MED_GI_CHARCOAL => '活性碳 (中毒急救)';

  @override
  String get supplyItem_MED_KIT_BASIC => '基礎急救包';

  @override
  String get supplyItem_MED_KIT_SPLINT => '固定夾板/三角巾';

  @override
  String get supplyItem_MED_KIT_AED => 'AED (自動體外心臟去顫器)';

  @override
  String get supplyItem_HYG_FEM_PAD => '衛生棉';

  @override
  String get supplyItem_HYG_FEM_TAMPON => '棉條';

  @override
  String get supplyItem_HYG_FEM_CUP => '月亮杯 (可重複使用)';

  @override
  String get supplyItem_HYG_BABY_DIAPER => '尿布 (S/M/L/XL)';

  @override
  String get supplyItem_HYG_BABY_WIPE => '濕紙巾 (厚型)';

  @override
  String get supplyItem_HYG_BABY_CREAM => '屁屁膏/護膚膏';

  @override
  String get supplyItem_HYG_PERS_SOAP => '肥皂/洗手乳';

  @override
  String get supplyItem_HYG_PERS_TOOTH => '牙刷牙膏組';

  @override
  String get supplyItem_HYG_PERS_TISSUE => '衛生紙/面紙';

  @override
  String get supplyItem_HYG_PERS_TOWEL => '快乾毛巾';

  @override
  String get supplyItem_HYG_SAN_BLEACH => '漂白水 (環境消毒)';

  @override
  String get supplyItem_HYG_SAN_TRASH => '垃圾袋 (大/厚)';

  @override
  String get supplyItem_HYG_SAN_GLOVE => '拋棄式手套';

  @override
  String get supplyItem_HYG_SAN_BUCKET => '摺疊水桶 (清潔用)';

  @override
  String get supplyItem_PROT_RESP_N95 => 'N95 口罩';

  @override
  String get supplyItem_PROT_RESP_SURGICAL => '醫用口罩';

  @override
  String get supplyItem_PROT_RESP_GAS => '防毒面具/濾罐';

  @override
  String get supplyItem_PROT_BODY_GLOVES => '工作手套 (防割/防滑)';

  @override
  String get supplyItem_PROT_BODY_HELMET => '安全帽/工程帽';

  @override
  String get supplyItem_PROT_BODY_BOOTS => '安全雨鞋/工作鞋';

  @override
  String get supplyItem_PROT_BODY_GOGGLES => '護目鏡/防塵眼鏡';

  @override
  String get supplyItem_PROT_BODY_VEST => '反光背心';

  @override
  String get supplyItem_PROT_LIGHT_FLASHLIGHT => '手電筒/頭燈';

  @override
  String get supplyItem_PROT_LIGHT_LANTERN => '營燈/LED 掛燈';

  @override
  String get supplyItem_PROT_LIGHT_BATTERY => '乾電池 (AA/AAA/D)';

  @override
  String get supplyItem_PROT_LIGHT_CANDLE => '蠟燭/防風打火機';

  @override
  String get supplyItem_SHELTER_TEMP_TENT => '帳篷/天幕';

  @override
  String get supplyItem_SHELTER_TEMP_TARP => '防水帆布/地布';

  @override
  String get supplyItem_SHELTER_TEMP_ROPE => '營繩/繫固帶';

  @override
  String get supplyItem_SHELTER_BED_BAG => '睡袋';

  @override
  String get supplyItem_SHELTER_BED_MAT => '充氣睡墊/瑜珈墊';

  @override
  String get supplyItem_SHELTER_BED_BLANKET => '毛毯/太空毯';

  @override
  String get supplyItem_SHELTER_CLOTH_RAIN => '雨衣/防水外套';

  @override
  String get supplyItem_SHELTER_CLOTH_WARM => '保暖內衣/刷毛外套';

  @override
  String get supplyItem_SHELTER_CLOTH_CHANGE => '換洗衣物套組';

  @override
  String get supplyItem_TOOL_COMM_RADIO => '對講機 (UHF/VHF)';

  @override
  String get supplyItem_TOOL_COMM_CHARGER => '手搖/太陽能充電器';

  @override
  String get supplyItem_TOOL_COMM_POWERBANK => '行動電源 (10000mAh+)';

  @override
  String get supplyItem_TOOL_COMM_WHISTLE => '緊急哨子';

  @override
  String get supplyItem_TOOL_RESCUE_CROWBAR => '撬棒/破壞鉗';

  @override
  String get supplyItem_TOOL_RESCUE_SHOVEL => '折疊鏟';

  @override
  String get supplyItem_TOOL_RESCUE_SAW => '折疊手鋸';

  @override
  String get supplyItem_TOOL_RESCUE_MULTI => '多功能工具鉗';

  @override
  String get supplyItem_TOOL_POWER_GENERATOR => '發電機';

  @override
  String get supplyItem_TOOL_POWER_SOLAR => '太陽能充電板';

  @override
  String get supplyItem_TOOL_POWER_INVERTER => '逆變器 (12V→110V)';

  @override
  String get supplyItem_TOOL_POWER_EXT => '延長線/電線捲';

  @override
  String get supplyItem_TOOL_TRANS_CART => '折疊推車/手拉車';

  @override
  String get supplyItem_TOOL_TRANS_STRETCHER => '簡易擔架';

  @override
  String get supplyItem_PET_FOOD_DOG_DRY => '狗乾糧';

  @override
  String get supplyItem_PET_FOOD_DOG_CAN => '狗罐頭';

  @override
  String get supplyItem_PET_FOOD_CAT_DRY => '貓乾糧';

  @override
  String get supplyItem_PET_FOOD_CAT_CAN => '貓罐頭';

  @override
  String get supplyItem_PET_FOOD_BOWL => '寵物飲水/食碗 (可折疊)';

  @override
  String get supplyItem_PET_CARE_CRATE => '外出籠/寵物提包';

  @override
  String get supplyItem_PET_CARE_LEASH => '牽繩/胸背帶';

  @override
  String get supplyItem_PET_CARE_PAD => '寵物尿布墊';

  @override
  String get supplyItem_PET_CARE_MED => '寵物基礎藥品 (驅蟲/皮膚)';

  @override
  String get supplyItem_PET_CARE_TAG => '防走失吊牌/晶片貼紙';

  @override
  String get supplyItem_SKILL_MEDICAL_DOCTOR => '醫師';

  @override
  String get supplyItem_SKILL_MEDICAL_NURSE => '護理師';

  @override
  String get supplyItem_SKILL_MEDICAL_EMT => '急救員 (EMT)';

  @override
  String get supplyItem_SKILL_MEDICAL_FIRSTAID => '急救證照持有者';

  @override
  String get supplyItem_SKILL_MEDICAL_PHARMACIST => '藥劑師';

  @override
  String get supplyItem_SKILL_RESCUE_FIREFIGHTER => '消防/搜救專業';

  @override
  String get supplyItem_SKILL_RESCUE_DIVER => '潛水搜救';

  @override
  String get supplyItem_SKILL_RESCUE_K9 => '搜救犬領犬員';

  @override
  String get supplyItem_SKILL_RESCUE_MOUNTAIN => '山域搜救/嚮導';

  @override
  String get supplyItem_SKILL_LANG_EN => '英語翻譯';

  @override
  String get supplyItem_SKILL_LANG_JP => '日語翻譯';

  @override
  String get supplyItem_SKILL_LANG_SEA => '東南亞語翻譯';

  @override
  String get supplyItem_SKILL_LANG_SIGN => '手語翻譯';

  @override
  String get supplyItem_SKILL_PSYCH_COUNSELOR => '心理諮商師';

  @override
  String get supplyItem_SKILL_PSYCH_SOCIAL => '社工人員';

  @override
  String get supplyItem_SKILL_CARE_BABY => '嬰幼兒托育';

  @override
  String get supplyItem_SKILL_CARE_ELDER => '老人照護';

  @override
  String get supplyItem_SKILL_CARE_DISABLED => '行動不便者照護';

  @override
  String get supplyItem_SKILL_CARE_SPECIAL => '特殊需求陪伴 (失智/身障)';

  @override
  String get supplyItem_SKILL_TECH_ELECTRIC => '電工/電力修復';

  @override
  String get supplyItem_SKILL_TECH_PLUMB => '水管/給水修復';

  @override
  String get supplyItem_SKILL_TECH_STRUCT => '結構安全評估';

  @override
  String get supplyItem_SKILL_TECH_COMM => '通訊工程/網路架設';

  @override
  String get supplyItem_SKILL_TECH_LABOR => '壯丁/勞力需求';

  @override
  String get supplyItem_SKILL_LOG_TRUCK => '大貨車駕駛';

  @override
  String get supplyItem_SKILL_LOG_4WD => '四輪傳動車/越野駕駛';

  @override
  String get supplyItem_SKILL_LOG_MOTO => '機車外送/快遞 (殘破道路)';

  @override
  String get supplyItem_SKILL_LOG_FORKLIFT => '堆高機操作';

  @override
  String get supplyItem_SKILL_LOG_HEAVYOP => '重機具操作員 (怪手/吊車)';

  @override
  String get supplyItem_SKILL_LOG_MANAGE => '物流管理/倉儲調度';

  @override
  String get itemConditionNew => '全新未拆封';

  @override
  String get itemConditionOpenedUnused => '已拆封未使用';

  @override
  String get itemConditionUsedFunctional => '二手堪用';

  @override
  String get commonCancel => '取消';

  @override
  String get commonBack => '返回';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonRetry => '重試';

  @override
  String get commonLoading => '載入中...';

  @override
  String get commonQtyUnit => '份';

  @override
  String get tierLabel1Standard => '標準模式 (Tier 1)';

  @override
  String get tierLabel1Force => '全速模式 (Tier 1)';

  @override
  String get tierLabel2EcoRelay => '省電中繼模式 (Tier 2)';

  @override
  String get tierLabel3UltraEco => '極省電模式 (Tier 3)';

  @override
  String get supplyCategory_MEDICINE => '藥品/急救';

  @override
  String get supplyCategory_PPE => '防護裝備';

  @override
  String get supplySubCategory_WATER_TANK => '儲水設備';

  @override
  String get supplySubCategory_FOOD_DRY => '乾糧';

  @override
  String get supplySubCategory_FOOD_SPECIAL => '特殊飲食';

  @override
  String get supplySubCategory_FOOD_DRINK => '飲品/電解質';

  @override
  String get supplySubCategory_MED_ANTIBIOTIC => '抗生素/抗感染';

  @override
  String get supplySubCategory_MED_KIT => '急救包/器材';

  @override
  String get supplySubCategory_MED_OTHER => '其他藥品';

  @override
  String get supplySubCategory_HYG_DIAPER => '尿布/排泄處理';

  @override
  String get supplySubCategory_HYG_CLEAN => '清潔衛生';

  @override
  String get supplySubCategory_HYG_PEST => '防蚊防蟲';

  @override
  String get supplySubCategory_HYG_DISINFECT => '環境消毒';

  @override
  String get supplySubCategory_PPE_HEAD => '頭部防護';

  @override
  String get supplySubCategory_PPE_RESP => '呼吸防護';

  @override
  String get supplySubCategory_PPE_HAND => '手部防護';

  @override
  String get supplySubCategory_PPE_BODY => '身體防護';

  @override
  String get supplySubCategory_PPE_WEATHER => '氣候防護/衣物';

  @override
  String get supplySubCategory_SHELTER_TENT => '帳篷/遮蔽';

  @override
  String get supplySubCategory_SHELTER_SLEEP => '保暖寢具';

  @override
  String get supplySubCategory_SHELTER_THERMAL => '緊急禦寒';

  @override
  String get supplySubCategory_SHELTER_SPACE => '空間提供';

  @override
  String get supplySubCategory_SHELTER_SUPPLY => '收容所耗材';

  @override
  String get supplySubCategory_TOOL_LIGHT => '照明';

  @override
  String get supplySubCategory_TOOL_BATTERY => '乾電池 (圓筒型)';

  @override
  String get supplySubCategory_TOOL_BATTERY_COIN => '鈕扣電池';

  @override
  String get supplySubCategory_TOOL_HAND => '手工具';

  @override
  String get supplySubCategory_TOOL_REPAIR => '修繕耗材';

  @override
  String get supplySubCategory_TOOL_HEAVY => '重型機具';

  @override
  String get supplySubCategory_TOOL_DEMOLITION => '破拆工具';

  @override
  String get supplySubCategory_TOOL_CLEANING => '清理設備';

  @override
  String get supplySubCategory_TOOL_SIGNAL => '求救信號';

  @override
  String get supplyItem_WATER_BOTTLE_20L => '20L 大桶 (家庭/收容所)';

  @override
  String get supplyItem_WATER_PURIFY_FILTER => '攜帶型濾水器';

  @override
  String get supplyItem_WATER_TANK_BARREL => '儲水桶';

  @override
  String get supplyItem_WATER_TANK_BAG => '可折疊水袋';

  @override
  String get supplyItem_FOOD_READY_NOODLE => '即食麵/泡麵';

  @override
  String get supplyItem_FOOD_READY_BAR => '能量棒/餅乾';

  @override
  String get supplyItem_FOOD_DRY_RICE => '乾飯/米';

  @override
  String get supplyItem_FOOD_DRY_BREAD => '麵包/吐司';

  @override
  String get supplyItem_FOOD_DRY_NUTS => '堅果/果乾';

  @override
  String get supplyItem_FOOD_SPECIAL_HALAL => '清真食品';

  @override
  String get supplyItem_FOOD_SPECIAL_VEGAN => '素食';

  @override
  String get supplyItem_FOOD_SPECIAL_GLUTEN => '無麩質食品';

  @override
  String get supplyItem_FOOD_SPECIAL_DIABETIC => '低糖/糖尿病適用';

  @override
  String get supplyItem_FOOD_COOK_GAS => '卡式瓦斯罐';

  @override
  String get supplyItem_FOOD_COOK_SOLID => '固體酒精/酒精膏';

  @override
  String get supplyItem_FOOD_COOK_LIGHTER => '防風打火機/防水火柴';

  @override
  String get supplyItem_FOOD_COOK_POT => '野炊鍋組/鋼杯';

  @override
  String get supplyItem_FOOD_DRINK_ELECTRO => '運動飲料/電解質粉';

  @override
  String get supplyItem_FOOD_DRINK_COFFEE => '即溶咖啡/茶包';

  @override
  String get supplyItem_FOOD_DRINK_JUICE => '保久乳/果汁';

  @override
  String get supplyItem_MED_PAIN_ASPIRIN => '阿斯匹靈';

  @override
  String get supplyItem_MED_ANTIBIOTIC_AMOX => '阿莫西林';

  @override
  String get supplyItem_MED_ANTIBIOTIC_AZITHRO => '日舒 (阿奇黴素)';

  @override
  String get supplyItem_MED_ANTIBIOTIC_OINTMENT => '抗生素藥膏';

  @override
  String get supplyItem_MED_CHRONIC_INSULIN => '胰島素';

  @override
  String get supplyItem_MED_CHRONIC_ASTHMA => '氣喘吸入劑';

  @override
  String get supplyItem_MED_CHRONIC_THYROID => '甲狀腺藥物';

  @override
  String get supplyItem_MED_WOUND_DISINFECT => '消毒液/碘酒';

  @override
  String get supplyItem_MED_WOUND_SUTURE => '縫合膠帶';

  @override
  String get supplyItem_MED_WOUND_SALINE => '生理食鹽水 (沖洗傷口)';

  @override
  String get supplyItem_MED_WOUND_BURN => '燒燙傷藥膏/敷料';

  @override
  String get supplyItem_MED_WOUND_SPLINT => '固定夾板 (骨折臨時固定)';

  @override
  String get supplyItem_MED_KIT_TRAUMA => '外傷急救包';

  @override
  String get supplyItem_MED_KIT_STRETCHER => '摺疊擔架/軟式擔架';

  @override
  String get supplyItem_MED_OTHER_ANTIDIARRHEAL => '止瀉藥';

  @override
  String get supplyItem_MED_OTHER_ANTIHISTAMINE => '抗組織胺 (過敏)';

  @override
  String get supplyItem_MED_OTHER_REHYDRATION => '口服補液鹽';

  @override
  String get supplyItem_MED_OTHER_EYEDROP => '眼藥水/人工淚液';

  @override
  String get supplyItem_MED_OTHER_INSECT_BITE => '蚊蟲叮咬藥膏';

  @override
  String get supplyItem_HYG_FEM_PAD_DAY => '日用衛生棉';

  @override
  String get supplyItem_HYG_FEM_PAD_NIGHT => '夜用衛生棉';

  @override
  String get supplyItem_HYG_FEM_LINER => '護墊';

  @override
  String get supplyItem_HYG_DIAPER_BABY_S => '嬰兒尿布 S (3-6kg)';

  @override
  String get supplyItem_HYG_DIAPER_BABY_M => '嬰兒尿布 M (6-11kg)';

  @override
  String get supplyItem_HYG_DIAPER_BABY_L => '嬰兒尿布 L (9-14kg)';

  @override
  String get supplyItem_HYG_DIAPER_BABY_XL => '嬰兒尿布 XL (12-17kg)';

  @override
  String get supplyItem_HYG_DIAPER_ADULT => '成人紙尿褲';

  @override
  String get supplyItem_HYG_DIAPER_PORTABLE_TOILET => '攜帶式馬桶/行動廁所';

  @override
  String get supplyItem_HYG_DIAPER_SOLIDIFIER => '排泄物凝固劑';

  @override
  String get supplyItem_HYG_DIAPER_TRASH_BAG => '黑色大垃圾袋';

  @override
  String get supplyItem_HYG_CLEAN_WET_WIPE => '抗菌濕紙巾';

  @override
  String get supplyItem_HYG_CLEAN_HAND_GEL => '乾洗手液';

  @override
  String get supplyItem_HYG_CLEAN_SOAP => '肥皂';

  @override
  String get supplyItem_HYG_CLEAN_TOOTH => '牙刷牙膏組';

  @override
  String get supplyItem_HYG_CLEAN_SHAMPOO => '乾洗髮/洗髮乳';

  @override
  String get supplyItem_HYG_CLEAN_TOWEL => '速乾毛巾';

  @override
  String get supplyItem_HYG_PEST_REPELLENT => '防蚊液 (DEET/派卡瑞丁)';

  @override
  String get supplyItem_HYG_PEST_COIL => '蚊香/電蚊香';

  @override
  String get supplyItem_HYG_PEST_NET => '蚊帳';

  @override
  String get supplyItem_HYG_PEST_ROACH => '殺蟲劑 (蟑螂/蒼蠅)';

  @override
  String get supplyItem_HYG_DISINFECT_BLEACH => '漂白水/次氯酸鈉';

  @override
  String get supplyItem_HYG_DISINFECT_ALCOHOL => '75%酒精 (消毒用)';

  @override
  String get supplyItem_HYG_DISINFECT_SPRAY => '環境消毒噴劑';

  @override
  String get supplyItem_PPE_HEAD_HELMET => '工程安全帽';

  @override
  String get supplyItem_PPE_HEAD_GOGGLES => '護目鏡/防塵眼鏡';

  @override
  String get supplyItem_PPE_RESP_N95 => 'N95 口罩';

  @override
  String get supplyItem_PPE_RESP_DUST => '一般防塵口罩';

  @override
  String get supplyItem_PPE_RESP_GAS => '防毒面罩 (化學/火災)';

  @override
  String get supplyItem_PPE_HAND_CUT => '防割工作手套';

  @override
  String get supplyItem_PPE_HAND_RUBBER => '橡膠手套 (清淤/消毒)';

  @override
  String get supplyItem_PPE_HAND_LATEX => '醫療乳膠手套';

  @override
  String get supplyItem_PPE_BODY_VEST => '反光背心';

  @override
  String get supplyItem_PPE_BODY_COVERALL => '連身防護衣';

  @override
  String get supplyItem_PPE_BODY_BOOTS => '安全鞋/鋼頭雨靴';

  @override
  String get supplyItem_PPE_WEATHER_PONCHO => '輕便雨衣 (拋棄式)';

  @override
  String get supplyItem_PPE_WEATHER_RAINSUIT => '兩截式雨衣';

  @override
  String get supplyItem_PPE_WEATHER_RAINBOOT => '雨鞋/防水靴';

  @override
  String get supplyItem_PPE_WEATHER_WARM => '保暖衣物/發熱衣';

  @override
  String get supplyItem_PPE_WEATHER_JACKET => '防水外套/風衣';

  @override
  String get supplyItem_PPE_WEATHER_HAT => '保暖帽/遮陽帽';

  @override
  String get supplyItem_SHELTER_TENT_2P => '2人帳篷';

  @override
  String get supplyItem_SHELTER_TENT_4P => '4人帳篷';

  @override
  String get supplyItem_SHELTER_TENT_TARP => '防水天幕';

  @override
  String get supplyItem_SHELTER_TENT_PLASTIC => '防水帆布/塑膠布';

  @override
  String get supplyItem_SHELTER_SLEEP_BAG => '睡袋';

  @override
  String get supplyItem_SHELTER_SLEEP_BLANKET => '保暖毯';

  @override
  String get supplyItem_SHELTER_SLEEP_MAT => '睡墊';

  @override
  String get supplyItem_SHELTER_SLEEP_AIR => '充氣床墊';

  @override
  String get supplyItem_SHELTER_THERM_SPACE => '急救保溫毯 (Space Blanket)';

  @override
  String get supplyItem_SHELTER_THERM_HANDWARMER => '暖暖包';

  @override
  String get supplyItem_SHELTER_THERM_COAT => '保暖外套/二手衣物';

  @override
  String get supplyItem_SHELTER_SPACE_ROOM => '可提供房間';

  @override
  String get supplyItem_SHELTER_SPACE_GARAGE => '可提供車庫/倉庫';

  @override
  String get supplyItem_SHELTER_SPACE_LAND => '可提供空地 (搭帳篷/停車)';

  @override
  String get supplyItem_SHELTER_SUPPLY_TABLE => '摺疊桌椅';

  @override
  String get supplyItem_SHELTER_SUPPLY_PARTITION => '隔間屏風/隔簾';

  @override
  String get supplyItem_SHELTER_SUPPLY_FAN => '攜帶式風扇/USB風扇';

  @override
  String get supplyItem_TOOL_LIGHT_FLASH => '手電筒';

  @override
  String get supplyItem_TOOL_LIGHT_LANTERN => '露營燈';

  @override
  String get supplyItem_TOOL_LIGHT_HEADLAMP => '頭燈';

  @override
  String get supplyItem_TOOL_LIGHT_GLOWSTICK => '螢光棒 (不需電力)';

  @override
  String get supplyItem_TOOL_POWER_BANK => '行動電源';

  @override
  String get supplyItem_TOOL_POWER_EXTENSION => '延長線/排插';

  @override
  String get supplyItem_TOOL_BAT_AA => '3號電池 (AA 1.5V)';

  @override
  String get supplyItem_TOOL_BAT_AAA => '4號電池 (AAA 1.5V)';

  @override
  String get supplyItem_TOOL_BAT_C => '2號電池 (C 1.5V)';

  @override
  String get supplyItem_TOOL_BAT_D => '1號電池 (D 1.5V)';

  @override
  String get supplyItem_TOOL_BAT_9V => '9V 方型電池';

  @override
  String get supplyItem_TOOL_BAT_18650 => '18650 鋰電池 (3.7V)';

  @override
  String get supplyItem_TOOL_COIN_CR2032 => 'CR2032 (3V 最常見)';

  @override
  String get supplyItem_TOOL_COIN_CR2025 => 'CR2025 (3V)';

  @override
  String get supplyItem_TOOL_COIN_CR2016 => 'CR2016 (3V)';

  @override
  String get supplyItem_TOOL_COIN_LR44 => 'LR44 / AG13 (1.5V)';

  @override
  String get supplyItem_TOOL_COIN_SR626 => 'SR626SW (手錶電池 1.55V)';

  @override
  String get supplyItem_TOOL_COMM_WALKIE => '對講機';

  @override
  String get supplyItem_TOOL_COMM_SAT => '衛星通訊器';

  @override
  String get supplyItem_TOOL_RESCUE_ROPE => '繩索';

  @override
  String get supplyItem_TOOL_RESCUE_AXE => '斧頭/撬棒';

  @override
  String get supplyItem_TOOL_RESCUE_PARACORD => '傘繩 (Paracord)';

  @override
  String get supplyItem_TOOL_RESCUE_SPRAYPAINT => '噴漆 (建物搜救標記)';

  @override
  String get supplyItem_TOOL_HAND_SCREWDRIVER_PH => '十字螺絲起子';

  @override
  String get supplyItem_TOOL_HAND_SCREWDRIVER_FLAT => '一字螺絲起子';

  @override
  String get supplyItem_TOOL_HAND_WRENCH => '活動扳手';

  @override
  String get supplyItem_TOOL_HAND_HAMMER => '鐵鎚';

  @override
  String get supplyItem_TOOL_HAND_SHOVEL => '鏟子/圓鍬';

  @override
  String get supplyItem_TOOL_HAND_MULTITOOL => '多功能工具鉗/瑞士刀';

  @override
  String get supplyItem_TOOL_HAND_PLIER => '鉗子/老虎鉗';

  @override
  String get supplyItem_TOOL_REPAIR_DUCT => '大力膠帶 (Duct Tape)';

  @override
  String get supplyItem_TOOL_REPAIR_ZIPTIE => '束線帶/紮帶';

  @override
  String get supplyItem_TOOL_REPAIR_WIRE => '鐵絲/綁線';

  @override
  String get supplyItem_TOOL_REPAIR_SEALANT => '防水膠/矽利康';

  @override
  String get supplyItem_TOOL_REPAIR_TARP_TAPE => '帆布修補膠帶';

  @override
  String get supplyItem_TOOL_TRANSPORT_CAR => '車輛 (機動)';

  @override
  String get supplyItem_TOOL_TRANSPORT_BIKE => '腳踏車';

  @override
  String get supplyItem_TOOL_TRANSPORT_CART => '推車';

  @override
  String get supplyItem_TOOL_TRANSPORT_WHEELBARROW => '手推車/獨輪車 (搬運瓦礫)';

  @override
  String get supplyItem_TOOL_HEAVY_EXCAVATOR_MINI => '微型怪手 (可入戶/狹窄巷弄)';

  @override
  String get supplyItem_TOOL_HEAVY_EXCAVATOR_STD => '標準怪手 (大型挖掘)';

  @override
  String get supplyItem_TOOL_HEAVY_BOBCAT_MINI => '微型山貓 (可入戶/滑移裝載)';

  @override
  String get supplyItem_TOOL_HEAVY_BOBCAT_STD => '標準山貓 (滑移裝載機)';

  @override
  String get supplyItem_TOOL_HEAVY_CRANE => '吊車/起重機';

  @override
  String get supplyItem_TOOL_HEAVY_LOADER => '鏟土機/推土機';

  @override
  String get supplyItem_TOOL_DEMO_JACKHAMMER => '電動/氣動打石機';

  @override
  String get supplyItem_TOOL_DEMO_CONCRETE_SAW => '混凝土切割機/引擎砂輪機';

  @override
  String get supplyItem_TOOL_DEMO_HYDRAULIC => '液壓破壞剪/撐開器 (重型救援)';

  @override
  String get supplyItem_TOOL_DEMO_CHAINSAW => '動力鏈鋸 (伐木/路樹清理)';

  @override
  String get supplyItem_TOOL_CLEANING_WASHER => '高壓清洗機';

  @override
  String get supplyItem_TOOL_CLEANING_PUMP_CLEAN => '引擎抽水馬達 (清水泵)';

  @override
  String get supplyItem_TOOL_CLEANING_PUMP_SLUDGE => '污泥泵 (廢水/污泥專用)';

  @override
  String get supplyItem_TOOL_CLEANING_BLOWER => '工業排風機 (地下室排煙/換氣)';

  @override
  String get supplyItem_TOOL_SIGNAL_FLARE => '信號彈';

  @override
  String get supplyItem_TOOL_SIGNAL_MIRROR => '信號鏡 (反光求救)';

  @override
  String get supplyItem_TOOL_SIGNAL_FLAG => '求救旗幟/布條';

  @override
  String get supplyItem_TOOL_SIGNAL_STROBE => '閃光求救燈';
}
