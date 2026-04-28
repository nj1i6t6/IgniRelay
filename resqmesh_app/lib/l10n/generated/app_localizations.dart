import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'烽傳 IgniRelay'**
  String get appTitle;

  /// No description provided for @mainStartupLoading.
  ///
  /// In zh, this message translates to:
  /// **'烽傳 啟動中...'**
  String get mainStartupLoading;

  /// No description provided for @mainBluetoothDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要開啟藍牙'**
  String get mainBluetoothDialogTitle;

  /// No description provided for @mainBluetoothDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'烽傳使用藍牙建立 Mesh 離線網路，\n用於傳遞求救訊號與物資媒合。\n\n請開啟藍牙以啟用完整功能。'**
  String get mainBluetoothDialogContent;

  /// No description provided for @mainBluetoothDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'稍後'**
  String get mainBluetoothDialogCancel;

  /// No description provided for @mainBluetoothDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'開啟藍牙'**
  String get mainBluetoothDialogConfirm;

  /// No description provided for @mainBleFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'BLE Mesh 啟動失敗：{error}'**
  String mainBleFailSnack(String error);

  /// No description provided for @mainPermissionSnack.
  ///
  /// In zh, this message translates to:
  /// **'需要藍牙與位置權限才能啟用 Mesh 網路'**
  String get mainPermissionSnack;

  /// No description provided for @tabMap.
  ///
  /// In zh, this message translates to:
  /// **'離線地圖'**
  String get tabMap;

  /// No description provided for @tabMeshGuard.
  ///
  /// In zh, this message translates to:
  /// **'Mesh 守護'**
  String get tabMeshGuard;

  /// No description provided for @tabChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get tabChat;

  /// No description provided for @tabMatch.
  ///
  /// In zh, this message translates to:
  /// **'物資媒合'**
  String get tabMatch;

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'身分信任'**
  String get tabProfile;

  /// No description provided for @mainTabSosYellowSnack.
  ///
  /// In zh, this message translates to:
  /// **'收到求助訊號：{desc}'**
  String mainTabSosYellowSnack(String desc);

  /// No description provided for @mainTabSosYellowAction.
  ///
  /// In zh, this message translates to:
  /// **'查看地圖'**
  String get mainTabSosYellowAction;

  /// No description provided for @mainTabSosRedDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'緊急求救訊號！'**
  String get mainTabSosRedDialogTitle;

  /// No description provided for @mainTabSosRedDialogFallback.
  ///
  /// In zh, this message translates to:
  /// **'附近有人發出緊急求救'**
  String get mainTabSosRedDialogFallback;

  /// No description provided for @mainTabSosRedDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'此訊號透過 Mesh 網路傳遞，發送者可能在附近。\n請前往地圖查看位置資訊。'**
  String get mainTabSosRedDialogContent;

  /// No description provided for @mainTabSosRedDialogDismiss.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get mainTabSosRedDialogDismiss;

  /// No description provided for @mainTabSosRedDialogViewMap.
  ///
  /// In zh, this message translates to:
  /// **'查看地圖'**
  String get mainTabSosRedDialogViewMap;

  /// No description provided for @mainTabMatchNotifProvider.
  ///
  /// In zh, this message translates to:
  /// **'有人願意提供你需要的物資！點擊查看。'**
  String get mainTabMatchNotifProvider;

  /// No description provided for @mainTabMatchNotifRequester.
  ///
  /// In zh, this message translates to:
  /// **'有人需要你的物資！點擊查看。'**
  String get mainTabMatchNotifRequester;

  /// No description provided for @mainTabMatchNotifAction.
  ///
  /// In zh, this message translates to:
  /// **'查看媒合'**
  String get mainTabMatchNotifAction;

  /// No description provided for @onboardingBadgeL0.
  ///
  /// In zh, this message translates to:
  /// **'匿名 (L0)'**
  String get onboardingBadgeL0;

  /// No description provided for @onboardingBadgeL1.
  ///
  /// In zh, this message translates to:
  /// **'手機驗證 (L1)'**
  String get onboardingBadgeL1;

  /// No description provided for @onboardingBadgeL2.
  ///
  /// In zh, this message translates to:
  /// **'社群背書 (L2)'**
  String get onboardingBadgeL2;

  /// No description provided for @onboardingBadgeL3.
  ///
  /// In zh, this message translates to:
  /// **'政府身分 (L3)'**
  String get onboardingBadgeL3;

  /// No description provided for @onboardingDeviceId.
  ///
  /// In zh, this message translates to:
  /// **'裝置 ID: {pubKeyHex}...'**
  String onboardingDeviceId(String pubKeyHex);

  /// No description provided for @onboardingTitle.
  ///
  /// In zh, this message translates to:
  /// **'烽傳 IgniRelay\n離線 Mesh 災難應急系統'**
  String get onboardingTitle;

  /// No description provided for @onboardingDesc.
  ///
  /// In zh, this message translates to:
  /// **'無網路時仍可透過 BLE Mesh 組成自組織網路，\n即時傳遞求救與物資配對訊息。'**
  String get onboardingDesc;

  /// No description provided for @onboardingNicknameHint.
  ///
  /// In zh, this message translates to:
  /// **'設定你的暱稱（可選）'**
  String get onboardingNicknameHint;

  /// No description provided for @onboardingUpgradeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'手機驗證 (L1)'**
  String get onboardingUpgradeDialogTitle;

  /// No description provided for @onboardingUpgradeDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'透過 SMS OTP 驗證手機號碼，\n提升信任等級至 L1（銅牌）。\n\n驗證後可解鎖更多功能。'**
  String get onboardingUpgradeDialogContent;

  /// No description provided for @onboardingUpgradeDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認升級'**
  String get onboardingUpgradeDialogConfirm;

  /// No description provided for @onboardingUpgradeSnack.
  ///
  /// In zh, this message translates to:
  /// **'已升級至 L1 (銅牌) - 手機驗證'**
  String get onboardingUpgradeSnack;

  /// No description provided for @onboardingUpgradeButton.
  ///
  /// In zh, this message translates to:
  /// **'升級至 L1（手機驗證）'**
  String get onboardingUpgradeButton;

  /// No description provided for @onboardingStartButton.
  ///
  /// In zh, this message translates to:
  /// **'開始使用烽傳'**
  String get onboardingStartButton;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'身分與信任'**
  String get profileTitle;

  /// No description provided for @profileBadgeDescL0.
  ///
  /// In zh, this message translates to:
  /// **'自動生成 Ed25519 金鑰，無需網路'**
  String get profileBadgeDescL0;

  /// No description provided for @profileBadgeDescL1.
  ///
  /// In zh, this message translates to:
  /// **'已綁定手機號碼，信任度提升'**
  String get profileBadgeDescL1;

  /// No description provided for @profileBadgeDescL2.
  ///
  /// In zh, this message translates to:
  /// **'已獲 3 位以上用戶背書'**
  String get profileBadgeDescL2;

  /// No description provided for @profileBadgeDescL3.
  ///
  /// In zh, this message translates to:
  /// **'已通過 TW FidO 政府身分驗證'**
  String get profileBadgeDescL3;

  /// No description provided for @profileAnonymous.
  ///
  /// In zh, this message translates to:
  /// **'匿名用戶'**
  String get profileAnonymous;

  /// No description provided for @profileNicknameDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改暱稱'**
  String get profileNicknameDialogTitle;

  /// No description provided for @profileNicknameDialogHint.
  ///
  /// In zh, this message translates to:
  /// **'輸入新暱稱'**
  String get profileNicknameDialogHint;

  /// No description provided for @profileNicknameDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get profileNicknameDialogCancel;

  /// No description provided for @profileNicknameDialogSave.
  ///
  /// In zh, this message translates to:
  /// **'儲存'**
  String get profileNicknameDialogSave;

  /// No description provided for @profileNicknameUpdated.
  ///
  /// In zh, this message translates to:
  /// **'暱稱已更新為「{nickname}」'**
  String profileNicknameUpdated(String nickname);

  /// No description provided for @profileNicknameCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除暱稱'**
  String get profileNicknameCleared;

  /// No description provided for @profilePubKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'公鑰 (Ed25519)'**
  String get profilePubKeyLabel;

  /// No description provided for @profilePubKeyLoading.
  ///
  /// In zh, this message translates to:
  /// **'載入中...'**
  String get profilePubKeyLoading;

  /// No description provided for @profileBatteryButton.
  ///
  /// In zh, this message translates to:
  /// **'背景執行 / 電池優化設定'**
  String get profileBatteryButton;

  /// No description provided for @profileMedicalCardEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯醫療卡'**
  String get profileMedicalCardEdit;

  /// No description provided for @profileMedicalCardCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立醫療卡'**
  String get profileMedicalCardCreate;

  /// No description provided for @profileTrustPhoneVerify.
  ///
  /// In zh, this message translates to:
  /// **'手機驗證'**
  String get profileTrustPhoneVerify;

  /// No description provided for @profileTrustNotOpen.
  ///
  /// In zh, this message translates to:
  /// **'尚未開放'**
  String get profileTrustNotOpen;

  /// No description provided for @profileUpgradeSnack.
  ///
  /// In zh, this message translates to:
  /// **'已升級至 手機驗證 (L1)（待後端 SMS OTP 串接）'**
  String get profileUpgradeSnack;

  /// No description provided for @profileLanguageLabel.
  ///
  /// In zh, this message translates to:
  /// **'語言'**
  String get profileLanguageLabel;

  /// No description provided for @mapTitle.
  ///
  /// In zh, this message translates to:
  /// **'離線地圖'**
  String get mapTitle;

  /// No description provided for @mapLayerControlTooltip.
  ///
  /// In zh, this message translates to:
  /// **'圖層控制'**
  String get mapLayerControlTooltip;

  /// No description provided for @mapLegendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'圖例'**
  String get mapLegendTooltip;

  /// No description provided for @mapRefreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重新整理'**
  String get mapRefreshTooltip;

  /// No description provided for @mapLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在載入離線地圖...'**
  String get mapLoading;

  /// No description provided for @mapLoadingNote.
  ///
  /// In zh, this message translates to:
  /// **'(首次啟動解壓 201MB 地圖需要一點時間)'**
  String get mapLoadingNote;

  /// No description provided for @mapErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'離線地圖不可用'**
  String get mapErrorTitle;

  /// No description provided for @mapErrorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知錯誤'**
  String get mapErrorUnknown;

  /// No description provided for @mapErrorAssetNote.
  ///
  /// In zh, this message translates to:
  /// **'請確認 assets/maps/taiwan_ignirelay.mbtiles 已正確打包'**
  String get mapErrorAssetNote;

  /// No description provided for @mapRetryButton.
  ///
  /// In zh, this message translates to:
  /// **'重試'**
  String get mapRetryButton;

  /// No description provided for @mapMbtilesNotFound.
  ///
  /// In zh, this message translates to:
  /// **'找不到離線地圖檔案 (taiwan_ignirelay.mbtiles)'**
  String get mapMbtilesNotFound;

  /// No description provided for @mapMbtilesLoadFail.
  ///
  /// In zh, this message translates to:
  /// **'地圖載入失敗: {error}'**
  String mapMbtilesLoadFail(String error);

  /// No description provided for @mapHazardRoadblock.
  ///
  /// In zh, this message translates to:
  /// **'道路封閉'**
  String get mapHazardRoadblock;

  /// No description provided for @mapHazardFire.
  ///
  /// In zh, this message translates to:
  /// **'火災'**
  String get mapHazardFire;

  /// No description provided for @mapHazardChemical.
  ///
  /// In zh, this message translates to:
  /// **'化學/毒氣'**
  String get mapHazardChemical;

  /// No description provided for @mapHazardFlood.
  ///
  /// In zh, this message translates to:
  /// **'水災/淹水'**
  String get mapHazardFlood;

  /// No description provided for @mapHazardCollapse.
  ///
  /// In zh, this message translates to:
  /// **'建物倒塌'**
  String get mapHazardCollapse;

  /// No description provided for @mapHazardLandslide.
  ///
  /// In zh, this message translates to:
  /// **'土石流'**
  String get mapHazardLandslide;

  /// No description provided for @mapEventSosRed.
  ///
  /// In zh, this message translates to:
  /// **'SOS 緊急求救'**
  String get mapEventSosRed;

  /// No description provided for @mapEventSosYellow.
  ///
  /// In zh, this message translates to:
  /// **'求助'**
  String get mapEventSosYellow;

  /// No description provided for @mapEventSupply.
  ///
  /// In zh, this message translates to:
  /// **'物資'**
  String get mapEventSupply;

  /// No description provided for @mapEventInfo.
  ///
  /// In zh, this message translates to:
  /// **'資訊'**
  String get mapEventInfo;

  /// No description provided for @mapEventTypeSupply.
  ///
  /// In zh, this message translates to:
  /// **'物資供給'**
  String get mapEventTypeSupply;

  /// No description provided for @mapEventTypeRequest.
  ///
  /// In zh, this message translates to:
  /// **'物資需求'**
  String get mapEventTypeRequest;

  /// No description provided for @mapEventTypeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'事件 (type={eventType})'**
  String mapEventTypeUnknown(int eventType);

  /// No description provided for @mapPoiHospital.
  ///
  /// In zh, this message translates to:
  /// **'醫院'**
  String get mapPoiHospital;

  /// No description provided for @mapPoiClinic.
  ///
  /// In zh, this message translates to:
  /// **'診所'**
  String get mapPoiClinic;

  /// No description provided for @mapPoiNursingHome.
  ///
  /// In zh, this message translates to:
  /// **'護理之家'**
  String get mapPoiNursingHome;

  /// No description provided for @mapPoiPharmacy.
  ///
  /// In zh, this message translates to:
  /// **'藥局'**
  String get mapPoiPharmacy;

  /// No description provided for @mapPoiPolice.
  ///
  /// In zh, this message translates to:
  /// **'警察局'**
  String get mapPoiPolice;

  /// No description provided for @mapPoiFireStation.
  ///
  /// In zh, this message translates to:
  /// **'消防隊'**
  String get mapPoiFireStation;

  /// No description provided for @mapPoiSchool.
  ///
  /// In zh, this message translates to:
  /// **'學校'**
  String get mapPoiSchool;

  /// No description provided for @mapPoiUniversity.
  ///
  /// In zh, this message translates to:
  /// **'大學'**
  String get mapPoiUniversity;

  /// No description provided for @mapPoiSupermarket.
  ///
  /// In zh, this message translates to:
  /// **'超市'**
  String get mapPoiSupermarket;

  /// No description provided for @mapPoiConvenience.
  ///
  /// In zh, this message translates to:
  /// **'便利商店'**
  String get mapPoiConvenience;

  /// No description provided for @mapPoiMall.
  ///
  /// In zh, this message translates to:
  /// **'商場'**
  String get mapPoiMall;

  /// No description provided for @mapPoiGasStation.
  ///
  /// In zh, this message translates to:
  /// **'加油站'**
  String get mapPoiGasStation;

  /// No description provided for @mapPoiRestaurant.
  ///
  /// In zh, this message translates to:
  /// **'餐廳'**
  String get mapPoiRestaurant;

  /// No description provided for @mapPoiCafe.
  ///
  /// In zh, this message translates to:
  /// **'咖啡廳'**
  String get mapPoiCafe;

  /// No description provided for @mapPoiBank.
  ///
  /// In zh, this message translates to:
  /// **'銀行'**
  String get mapPoiBank;

  /// No description provided for @mapPoiPostOffice.
  ///
  /// In zh, this message translates to:
  /// **'郵局'**
  String get mapPoiPostOffice;

  /// No description provided for @mapPoiReligious.
  ///
  /// In zh, this message translates to:
  /// **'宗教場所'**
  String get mapPoiReligious;

  /// No description provided for @mapPoiParking.
  ///
  /// In zh, this message translates to:
  /// **'停車場'**
  String get mapPoiParking;

  /// No description provided for @mapPoiShop.
  ///
  /// In zh, this message translates to:
  /// **'商店'**
  String get mapPoiShop;

  /// No description provided for @mapPoiInfoAddress.
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get mapPoiInfoAddress;

  /// No description provided for @mapPoiInfoPhone.
  ///
  /// In zh, this message translates to:
  /// **'電話'**
  String get mapPoiInfoPhone;

  /// No description provided for @mapPoiInfoOpen.
  ///
  /// In zh, this message translates to:
  /// **'營業'**
  String get mapPoiInfoOpen;

  /// No description provided for @mapPoiInfoNoDetail.
  ///
  /// In zh, this message translates to:
  /// **'（此地點未提供詳細資訊）'**
  String get mapPoiInfoNoDetail;

  /// No description provided for @mapDayMonday.
  ///
  /// In zh, this message translates to:
  /// **'週一'**
  String get mapDayMonday;

  /// No description provided for @mapDayTuesday.
  ///
  /// In zh, this message translates to:
  /// **'週二'**
  String get mapDayTuesday;

  /// No description provided for @mapDayWednesday.
  ///
  /// In zh, this message translates to:
  /// **'週三'**
  String get mapDayWednesday;

  /// No description provided for @mapDayThursday.
  ///
  /// In zh, this message translates to:
  /// **'週四'**
  String get mapDayThursday;

  /// No description provided for @mapDayFriday.
  ///
  /// In zh, this message translates to:
  /// **'週五'**
  String get mapDayFriday;

  /// No description provided for @mapDaySaturday.
  ///
  /// In zh, this message translates to:
  /// **'週六'**
  String get mapDaySaturday;

  /// No description provided for @mapDaySunday.
  ///
  /// In zh, this message translates to:
  /// **'週日'**
  String get mapDaySunday;

  /// No description provided for @mapDayHoliday.
  ///
  /// In zh, this message translates to:
  /// **'國定假日'**
  String get mapDayHoliday;

  /// No description provided for @mapDayClosed.
  ///
  /// In zh, this message translates to:
  /// **'公休'**
  String get mapDayClosed;

  /// No description provided for @mapCredibilityConfirmed.
  ///
  /// In zh, this message translates to:
  /// **'確信'**
  String get mapCredibilityConfirmed;

  /// No description provided for @mapCredibilityCredible.
  ///
  /// In zh, this message translates to:
  /// **'可信'**
  String get mapCredibilityCredible;

  /// No description provided for @mapCredibilityEndorsed.
  ///
  /// In zh, this message translates to:
  /// **'有附議'**
  String get mapCredibilityEndorsed;

  /// No description provided for @mapCredibilityUnverified.
  ///
  /// In zh, this message translates to:
  /// **'未驗證'**
  String get mapCredibilityUnverified;

  /// No description provided for @mapTimeAgoMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{mins} 分鐘前'**
  String mapTimeAgoMinutes(int mins);

  /// No description provided for @mapTimeAgoHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小時前'**
  String mapTimeAgoHours(int hours);

  /// No description provided for @mapTimeAgoDays.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前'**
  String mapTimeAgoDays(int days);

  /// No description provided for @mapMarkingNearbyExists.
  ///
  /// In zh, this message translates to:
  /// **'附近已有回報'**
  String get mapMarkingNearbyExists;

  /// No description provided for @mapMarkingNearbyContent.
  ///
  /// In zh, this message translates to:
  /// **'距離 {distanceMeters}m 處已有「{typeLabel}」回報，目前已有 {confirmCount} 人確認。\n\n你可以「確認」來增加可信度，或建立全新標記。'**
  String mapMarkingNearbyContent(
      int distanceMeters, String typeLabel, int confirmCount);

  /// No description provided for @mapMarkingCreateNew.
  ///
  /// In zh, this message translates to:
  /// **'建立新標記'**
  String get mapMarkingCreateNew;

  /// No description provided for @mapMarkingConfirmReport.
  ///
  /// In zh, this message translates to:
  /// **'確認回報'**
  String get mapMarkingConfirmReport;

  /// No description provided for @mapMarkingEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯危險標記'**
  String get mapMarkingEditTitle;

  /// No description provided for @mapMarkingNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'標記危險區域'**
  String get mapMarkingNewTitle;

  /// No description provided for @mapMarkingTapHint.
  ///
  /// In zh, this message translates to:
  /// **'  點擊地圖可移動標記位置'**
  String get mapMarkingTapHint;

  /// No description provided for @mapMarkingSeverityLabel.
  ///
  /// In zh, this message translates to:
  /// **' 嚴重度'**
  String get mapMarkingSeverityLabel;

  /// No description provided for @mapMarkingRadiusLabel.
  ///
  /// In zh, this message translates to:
  /// **' 半徑'**
  String get mapMarkingRadiusLabel;

  /// No description provided for @mapMarkingDescHint.
  ///
  /// In zh, this message translates to:
  /// **'簡述狀況 (選填)'**
  String get mapMarkingDescHint;

  /// No description provided for @mapMarkingUpdateButton.
  ///
  /// In zh, this message translates to:
  /// **'更新標記'**
  String get mapMarkingUpdateButton;

  /// No description provided for @mapMarkingPublishButton.
  ///
  /// In zh, this message translates to:
  /// **'發布至 Mesh'**
  String get mapMarkingPublishButton;

  /// No description provided for @mapHazardUpdatedSnack.
  ///
  /// In zh, this message translates to:
  /// **'危險標記已更新'**
  String get mapHazardUpdatedSnack;

  /// No description provided for @mapHazardPublishedSnack.
  ///
  /// In zh, this message translates to:
  /// **'危險標記已發布至 Mesh'**
  String get mapHazardPublishedSnack;

  /// No description provided for @mapHazardDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'解除危險標記？'**
  String get mapHazardDeleteTitle;

  /// No description provided for @mapHazardDeleteContent.
  ///
  /// In zh, this message translates to:
  /// **'解除後此標記將從地圖上移除。'**
  String get mapHazardDeleteContent;

  /// No description provided for @mapHazardDeleteCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get mapHazardDeleteCancel;

  /// No description provided for @mapHazardDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'解除'**
  String get mapHazardDeleteConfirm;

  /// No description provided for @mapHazardDeletedSnack.
  ///
  /// In zh, this message translates to:
  /// **'危險標記已解除'**
  String get mapHazardDeletedSnack;

  /// No description provided for @mapHazardInfoSeverity.
  ///
  /// In zh, this message translates to:
  /// **'嚴重度'**
  String get mapHazardInfoSeverity;

  /// No description provided for @mapHazardInfoRadius.
  ///
  /// In zh, this message translates to:
  /// **'影響範圍: {radius}m'**
  String mapHazardInfoRadius(int radius);

  /// No description provided for @mapHazardInfoDesc.
  ///
  /// In zh, this message translates to:
  /// **'描述: {desc}'**
  String mapHazardInfoDesc(String desc);

  /// No description provided for @mapHazardInfoTime.
  ///
  /// In zh, this message translates to:
  /// **'回報時間: {timeAgo}'**
  String mapHazardInfoTime(String timeAgo);

  /// No description provided for @mapHazardInfoMine.
  ///
  /// In zh, this message translates to:
  /// **'你的回報'**
  String get mapHazardInfoMine;

  /// No description provided for @mapHazardInfoEditButton.
  ///
  /// In zh, this message translates to:
  /// **'編輯'**
  String get mapHazardInfoEditButton;

  /// No description provided for @mapHazardInfoConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'確認此回報'**
  String get mapHazardInfoConfirmButton;

  /// No description provided for @mapHazardConfirmSnack.
  ///
  /// In zh, this message translates to:
  /// **'已確認「{typeLabel}」回報 ({count}人)'**
  String mapHazardConfirmSnack(String typeLabel, int count);

  /// No description provided for @mapEventInfoDistance.
  ///
  /// In zh, this message translates to:
  /// **'距離: {distance}'**
  String mapEventInfoDistance(String distance);

  /// No description provided for @mapEventInfoTime.
  ///
  /// In zh, this message translates to:
  /// **'時間: {timeAgo}'**
  String mapEventInfoTime(String timeAgo);

  /// No description provided for @mapLongPressHint.
  ///
  /// In zh, this message translates to:
  /// **'長按地圖 → 標記危險區域'**
  String get mapLongPressHint;

  /// No description provided for @mapSosSentLabel.
  ///
  /// In zh, this message translates to:
  /// **'SOS 已發送  ✕ 取消'**
  String get mapSosSentLabel;

  /// No description provided for @mapSosButton.
  ///
  /// In zh, this message translates to:
  /// **'求救 SOS'**
  String get mapSosButton;

  /// No description provided for @mapSosHoldHint.
  ///
  /// In zh, this message translates to:
  /// **'長按 1.5 秒以發出 SOS'**
  String get mapSosHoldHint;

  /// No description provided for @mapCancelSosTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消求救'**
  String get mapCancelSosTitle;

  /// No description provided for @mapCancelSosContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要取消 SOS 求救訊號嗎？\n取消後其他裝置會收到通知。'**
  String get mapCancelSosContent;

  /// No description provided for @mapCancelSosBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get mapCancelSosBack;

  /// No description provided for @mapCancelSosConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確定取消'**
  String get mapCancelSosConfirm;

  /// No description provided for @mapSosCancelledPrefix.
  ///
  /// In zh, this message translates to:
  /// **'【SOS 已取消】'**
  String get mapSosCancelledPrefix;

  /// No description provided for @mapSosCancelledSnack.
  ///
  /// In zh, this message translates to:
  /// **'SOS 已取消'**
  String get mapSosCancelledSnack;

  /// No description provided for @mapSosCancelFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'取消失敗: {error}'**
  String mapSosCancelFailSnack(String error);

  /// No description provided for @mapGpsNotReady.
  ///
  /// In zh, this message translates to:
  /// **'GPS 尚未定位，請確認已開啟位置服務'**
  String get mapGpsNotReady;

  /// No description provided for @mapTriageBroadcastLabel0.
  ///
  /// In zh, this message translates to:
  /// **'資訊'**
  String get mapTriageBroadcastLabel0;

  /// No description provided for @mapTriageBroadcastLabel1.
  ///
  /// In zh, this message translates to:
  /// **'物資需求'**
  String get mapTriageBroadcastLabel1;

  /// No description provided for @mapTriageBroadcastLabel2.
  ///
  /// In zh, this message translates to:
  /// **'求助 (黃)'**
  String get mapTriageBroadcastLabel2;

  /// No description provided for @mapTriageBroadcastLabel3.
  ///
  /// In zh, this message translates to:
  /// **'緊急求救 (紅)'**
  String get mapTriageBroadcastLabel3;

  /// No description provided for @mapTriageBroadcastSnack.
  ///
  /// In zh, this message translates to:
  /// **'已廣播 {label}：{desc}'**
  String mapTriageBroadcastSnack(String label, String desc);

  /// No description provided for @mapLegendTitle.
  ///
  /// In zh, this message translates to:
  /// **'救災地標 (離線圖磚)'**
  String get mapLegendTitle;

  /// No description provided for @mapLegendZoomHint.
  ///
  /// In zh, this message translates to:
  /// **'放大至街道層級可載入點位'**
  String get mapLegendZoomHint;

  /// No description provided for @mapLegendHospital.
  ///
  /// In zh, this message translates to:
  /// **'醫院/診所'**
  String get mapLegendHospital;

  /// No description provided for @mapLegendPolice.
  ///
  /// In zh, this message translates to:
  /// **'警消單位'**
  String get mapLegendPolice;

  /// No description provided for @mapLegendSchool.
  ///
  /// In zh, this message translates to:
  /// **'學校 (避難所)'**
  String get mapLegendSchool;

  /// No description provided for @mapLegendPharmacy.
  ///
  /// In zh, this message translates to:
  /// **'藥局 (醫療物資)'**
  String get mapLegendPharmacy;

  /// No description provided for @mapLegendSupermarket.
  ///
  /// In zh, this message translates to:
  /// **'超市/便利商店'**
  String get mapLegendSupermarket;

  /// No description provided for @mapLegendMeshEvents.
  ///
  /// In zh, this message translates to:
  /// **'Mesh 事件'**
  String get mapLegendMeshEvents;

  /// No description provided for @mapPayloadQtyUnit.
  ///
  /// In zh, this message translates to:
  /// **'{name} {qty} {unit}'**
  String mapPayloadQtyUnit(String name, int qty, String unit);

  /// No description provided for @mapPayloadQtyPcs.
  ///
  /// In zh, this message translates to:
  /// **'{name} {qty} 份'**
  String mapPayloadQtyPcs(String name, int qty);

  /// No description provided for @mapLayerTitle.
  ///
  /// In zh, this message translates to:
  /// **'圖層控制'**
  String get mapLayerTitle;

  /// No description provided for @mapLayerPoiSection.
  ///
  /// In zh, this message translates to:
  /// **'地點圖標'**
  String get mapLayerPoiSection;

  /// No description provided for @mapLayerHazardSection.
  ///
  /// In zh, this message translates to:
  /// **'危險區域'**
  String get mapLayerHazardSection;

  /// No description provided for @mapLayerPoiHospital.
  ///
  /// In zh, this message translates to:
  /// **'醫院/診所'**
  String get mapLayerPoiHospital;

  /// No description provided for @mapLayerPoiPharmacy.
  ///
  /// In zh, this message translates to:
  /// **'藥局'**
  String get mapLayerPoiPharmacy;

  /// No description provided for @mapLayerPoiPolice.
  ///
  /// In zh, this message translates to:
  /// **'警消單位'**
  String get mapLayerPoiPolice;

  /// No description provided for @mapLayerPoiSchool.
  ///
  /// In zh, this message translates to:
  /// **'學校（避難所）'**
  String get mapLayerPoiSchool;

  /// No description provided for @mapLayerPoiSupermarket.
  ///
  /// In zh, this message translates to:
  /// **'超市/商店'**
  String get mapLayerPoiSupermarket;

  /// No description provided for @mapLayerHazardShowOthers.
  ///
  /// In zh, this message translates to:
  /// **'顯示他人回報'**
  String get mapLayerHazardShowOthers;

  /// No description provided for @mapLayerHazardMinCredibility.
  ///
  /// In zh, this message translates to:
  /// **'最低可信度'**
  String get mapLayerHazardMinCredibility;

  /// No description provided for @mapLayerCredAll.
  ///
  /// In zh, this message translates to:
  /// **'全部顯示'**
  String get mapLayerCredAll;

  /// No description provided for @mapLayerCredAllDesc.
  ///
  /// In zh, this message translates to:
  /// **'包含未驗證'**
  String get mapLayerCredAllDesc;

  /// No description provided for @mapLayerCred2.
  ///
  /// In zh, this message translates to:
  /// **'2 人以上'**
  String get mapLayerCred2;

  /// No description provided for @mapLayerCred2Desc.
  ///
  /// In zh, this message translates to:
  /// **'有人附議'**
  String get mapLayerCred2Desc;

  /// No description provided for @mapLayerCred3.
  ///
  /// In zh, this message translates to:
  /// **'3 人以上'**
  String get mapLayerCred3;

  /// No description provided for @mapLayerCred3Desc.
  ///
  /// In zh, this message translates to:
  /// **'多人回報'**
  String get mapLayerCred3Desc;

  /// No description provided for @mapLayerCred5.
  ///
  /// In zh, this message translates to:
  /// **'確信 (5+)'**
  String get mapLayerCred5;

  /// No description provided for @mapLayerCred5Desc.
  ///
  /// In zh, this message translates to:
  /// **'高度可信'**
  String get mapLayerCred5Desc;

  /// No description provided for @triageTitle.
  ///
  /// In zh, this message translates to:
  /// **'緊急求救廣播'**
  String get triageTitle;

  /// No description provided for @triageDescHint.
  ///
  /// In zh, this message translates to:
  /// **'描述需求或物資 (如: 需要飲水、有急救箱)'**
  String get triageDescHint;

  /// No description provided for @triageMedicalCardToggle.
  ///
  /// In zh, this message translates to:
  /// **'附帶醫療卡資訊'**
  String get triageMedicalCardToggle;

  /// No description provided for @triageMedicalCardOn.
  ///
  /// In zh, this message translates to:
  /// **'已開啟'**
  String get triageMedicalCardOn;

  /// No description provided for @triageMedicalCardOff.
  ///
  /// In zh, this message translates to:
  /// **'已關閉'**
  String get triageMedicalCardOff;

  /// No description provided for @triageSosYellowButton.
  ///
  /// In zh, this message translates to:
  /// **'求助 (SOS_YELLOW)'**
  String get triageSosYellowButton;

  /// No description provided for @triageSosRedButton.
  ///
  /// In zh, this message translates to:
  /// **'立即發送 SOS_RED 緊急求救'**
  String get triageSosRedButton;

  /// No description provided for @triageSosRedCountdown.
  ///
  /// In zh, this message translates to:
  /// **'長按中... 剩 {seconds} 秒'**
  String triageSosRedCountdown(int seconds);

  /// No description provided for @triageSosRedHoldHint.
  ///
  /// In zh, this message translates to:
  /// **'長按 3 秒解鎖致命求救 (SOS_RED)'**
  String get triageSosRedHoldHint;

  /// No description provided for @hazardDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'標記危險區域'**
  String get hazardDialogTitle;

  /// No description provided for @hazardDialogCoordinate.
  ///
  /// In zh, this message translates to:
  /// **'座標: {lat}, {lng}'**
  String hazardDialogCoordinate(String lat, String lng);

  /// No description provided for @hazardDialogTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'危險類型'**
  String get hazardDialogTypeLabel;

  /// No description provided for @hazardDialogSeverityLabel.
  ///
  /// In zh, this message translates to:
  /// **'嚴重程度'**
  String get hazardDialogSeverityLabel;

  /// No description provided for @hazardDialogSeverityMin.
  ///
  /// In zh, this message translates to:
  /// **'輕微'**
  String get hazardDialogSeverityMin;

  /// No description provided for @hazardDialogSeverityMax.
  ///
  /// In zh, this message translates to:
  /// **'致命'**
  String get hazardDialogSeverityMax;

  /// No description provided for @hazardDialogRadiusLabel.
  ///
  /// In zh, this message translates to:
  /// **'影響半徑'**
  String get hazardDialogRadiusLabel;

  /// No description provided for @hazardDialogDescHint.
  ///
  /// In zh, this message translates to:
  /// **'簡述狀況 (選填)'**
  String get hazardDialogDescHint;

  /// No description provided for @hazardDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get hazardDialogCancel;

  /// No description provided for @hazardDialogPublish.
  ///
  /// In zh, this message translates to:
  /// **'發布至 Mesh'**
  String get hazardDialogPublish;

  /// No description provided for @matchTitle.
  ///
  /// In zh, this message translates to:
  /// **'物資媒合'**
  String get matchTitle;

  /// No description provided for @matchTabSupplies.
  ///
  /// In zh, this message translates to:
  /// **'我的物資'**
  String get matchTabSupplies;

  /// No description provided for @matchTabRequests.
  ///
  /// In zh, this message translates to:
  /// **'我的需求'**
  String get matchTabRequests;

  /// No description provided for @matchTabNegotiations.
  ///
  /// In zh, this message translates to:
  /// **'進行中'**
  String get matchTabNegotiations;

  /// No description provided for @matchTabCommunity.
  ///
  /// In zh, this message translates to:
  /// **'社區'**
  String get matchTabCommunity;

  /// No description provided for @matchFabRegisterSupply.
  ///
  /// In zh, this message translates to:
  /// **'登記物資供給'**
  String get matchFabRegisterSupply;

  /// No description provided for @matchFabPublishRequest.
  ///
  /// In zh, this message translates to:
  /// **'發布物資需求'**
  String get matchFabPublishRequest;

  /// No description provided for @matchNegAcceptedSnack.
  ///
  /// In zh, this message translates to:
  /// **'協商已接受'**
  String get matchNegAcceptedSnack;

  /// No description provided for @matchNegDeclinedSnack.
  ///
  /// In zh, this message translates to:
  /// **'協商已拒絕'**
  String get matchNegDeclinedSnack;

  /// No description provided for @matchNegCancelledSnack.
  ///
  /// In zh, this message translates to:
  /// **'協商已取消'**
  String get matchNegCancelledSnack;

  /// No description provided for @matchHandoffCompleteSnack.
  ///
  /// In zh, this message translates to:
  /// **'交接完成'**
  String get matchHandoffCompleteSnack;

  /// No description provided for @matchNegExpiredSnack.
  ///
  /// In zh, this message translates to:
  /// **'協商已逾期'**
  String get matchNegExpiredSnack;

  /// No description provided for @matchOverQuantityWarning.
  ///
  /// In zh, this message translates to:
  /// **'物資超量警告'**
  String get matchOverQuantityWarning;

  /// No description provided for @matchLoadError.
  ///
  /// In zh, this message translates to:
  /// **'載入錯誤: {error}'**
  String matchLoadError(String error);

  /// No description provided for @matchGpsOpenSettings.
  ///
  /// In zh, this message translates to:
  /// **'開啟設定'**
  String get matchGpsOpenSettings;

  /// No description provided for @matchGpsEnableLocation.
  ///
  /// In zh, this message translates to:
  /// **'開啟定位'**
  String get matchGpsEnableLocation;

  /// No description provided for @matchRetry.
  ///
  /// In zh, this message translates to:
  /// **'重試'**
  String get matchRetry;

  /// No description provided for @matchUrgencyEmergency.
  ///
  /// In zh, this message translates to:
  /// **'緊急求救'**
  String get matchUrgencyEmergency;

  /// No description provided for @matchUrgencyHelp.
  ///
  /// In zh, this message translates to:
  /// **'求助'**
  String get matchUrgencyHelp;

  /// No description provided for @matchUrgencySupply.
  ///
  /// In zh, this message translates to:
  /// **'物資'**
  String get matchUrgencySupply;

  /// No description provided for @matchUrgencyInfo.
  ///
  /// In zh, this message translates to:
  /// **'資訊'**
  String get matchUrgencyInfo;

  /// No description provided for @matchCountdownExpired.
  ///
  /// In zh, this message translates to:
  /// **'已逾期'**
  String get matchCountdownExpired;

  /// No description provided for @matchCancelSupplySnack.
  ///
  /// In zh, this message translates to:
  /// **'已取消供給：{name}'**
  String matchCancelSupplySnack(String name);

  /// No description provided for @matchCancelRequestSnack.
  ///
  /// In zh, this message translates to:
  /// **'已取消需求：{name}'**
  String matchCancelRequestSnack(String name);

  /// No description provided for @matchCancelFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'取消失敗: {error}'**
  String matchCancelFailSnack(String error);

  /// No description provided for @matchAcceptSnack.
  ///
  /// In zh, this message translates to:
  /// **'已接受協商'**
  String get matchAcceptSnack;

  /// No description provided for @matchAcceptFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'接受失敗: {error}'**
  String matchAcceptFailSnack(String error);

  /// No description provided for @matchDeclineSnack.
  ///
  /// In zh, this message translates to:
  /// **'已拒絕協商'**
  String get matchDeclineSnack;

  /// No description provided for @matchDeclineFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'拒絕失敗: {error}'**
  String matchDeclineFailSnack(String error);

  /// No description provided for @matchCommunityRequestSnack.
  ///
  /// In zh, this message translates to:
  /// **'已發布需求 {qty} 份「{name}」'**
  String matchCommunityRequestSnack(int qty, String name);

  /// No description provided for @matchCommunitySupplySnack.
  ///
  /// In zh, this message translates to:
  /// **'已登記供給 {qty} 份「{name}」'**
  String matchCommunitySupplySnack(int qty, String name);

  /// No description provided for @matchCommunityFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'發布失敗: {error}'**
  String matchCommunityFailSnack(String error);

  /// No description provided for @matchCommunityNote.
  ///
  /// In zh, this message translates to:
  /// **'回應社區供給'**
  String get matchCommunityNote;

  /// No description provided for @suppliesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未登記物資供給'**
  String get suppliesEmptyTitle;

  /// No description provided for @suppliesEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'點擊下方按鈕登記您可提供的物資'**
  String get suppliesEmptySubtitle;

  /// No description provided for @suppliesStatusExhausted.
  ///
  /// In zh, this message translates to:
  /// **'已耗盡'**
  String get suppliesStatusExhausted;

  /// No description provided for @suppliesStatusPartial.
  ///
  /// In zh, this message translates to:
  /// **'部分承諾'**
  String get suppliesStatusPartial;

  /// No description provided for @suppliesStatusAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可用'**
  String get suppliesStatusAvailable;

  /// No description provided for @suppliesDeliveryDeliver.
  ///
  /// In zh, this message translates to:
  /// **'可協助送達'**
  String get suppliesDeliveryDeliver;

  /// No description provided for @suppliesDeliveryPickup.
  ///
  /// In zh, this message translates to:
  /// **'需求者自取'**
  String get suppliesDeliveryPickup;

  /// No description provided for @suppliesQtyTotal.
  ///
  /// In zh, this message translates to:
  /// **'總量'**
  String get suppliesQtyTotal;

  /// No description provided for @suppliesQtyAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可用'**
  String get suppliesQtyAvailable;

  /// No description provided for @suppliesQtyCommitted.
  ///
  /// In zh, this message translates to:
  /// **'承諾中'**
  String get suppliesQtyCommitted;

  /// No description provided for @suppliesCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get suppliesCancelButton;

  /// No description provided for @suppliesCancelDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消物資供給'**
  String get suppliesCancelDialogTitle;

  /// No description provided for @suppliesCancelDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要取消「{name}」嗎？\n取消後將從 Mesh 網路移除。'**
  String suppliesCancelDialogContent(String name);

  /// No description provided for @suppliesCancelDialogBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get suppliesCancelDialogBack;

  /// No description provided for @suppliesCancelDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確定取消'**
  String get suppliesCancelDialogConfirm;

  /// No description provided for @suppliesNotFoundSnack.
  ///
  /// In zh, this message translates to:
  /// **'找不到對應的發布記錄'**
  String get suppliesNotFoundSnack;

  /// No description provided for @requestsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未發布物資需求'**
  String get requestsEmptyTitle;

  /// No description provided for @requestsEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'點擊下方按鈕發布您需要的物資'**
  String get requestsEmptySubtitle;

  /// No description provided for @requestsStatusMatching.
  ///
  /// In zh, this message translates to:
  /// **'媒合中'**
  String get requestsStatusMatching;

  /// No description provided for @requestsStatusFulfilled.
  ///
  /// In zh, this message translates to:
  /// **'已滿足'**
  String get requestsStatusFulfilled;

  /// No description provided for @requestsStatusWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get requestsStatusWaiting;

  /// No description provided for @requestsQtyNeeded.
  ///
  /// In zh, this message translates to:
  /// **'需求'**
  String get requestsQtyNeeded;

  /// No description provided for @requestsQtyRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩餘'**
  String get requestsQtyRemaining;

  /// No description provided for @requestsQtyFulfilled.
  ///
  /// In zh, this message translates to:
  /// **'已滿足'**
  String get requestsQtyFulfilled;

  /// No description provided for @requestsQtyUnit.
  ///
  /// In zh, this message translates to:
  /// **'份'**
  String get requestsQtyUnit;

  /// No description provided for @requestsProposalsTitle.
  ///
  /// In zh, this message translates to:
  /// **'收到的提議：'**
  String get requestsProposalsTitle;

  /// No description provided for @requestsProposalOffer.
  ///
  /// In zh, this message translates to:
  /// **'提供 {qty} 份'**
  String requestsProposalOffer(int qty);

  /// No description provided for @requestsProposalRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩餘 {remaining}'**
  String requestsProposalRemaining(String remaining);

  /// No description provided for @requestsAcceptButton.
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get requestsAcceptButton;

  /// No description provided for @requestsDeclineButton.
  ///
  /// In zh, this message translates to:
  /// **'拒絕'**
  String get requestsDeclineButton;

  /// No description provided for @requestsCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get requestsCancelButton;

  /// No description provided for @requestsCancelDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消物資需求'**
  String get requestsCancelDialogTitle;

  /// No description provided for @requestsCancelDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要取消「{name}」嗎？\n取消後將從 Mesh 網路移除。'**
  String requestsCancelDialogContent(String name);

  /// No description provided for @requestsCancelDialogBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get requestsCancelDialogBack;

  /// No description provided for @requestsCancelDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確定取消'**
  String get requestsCancelDialogConfirm;

  /// No description provided for @negEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'目前沒有進行中的協商'**
  String get negEmptyTitle;

  /// No description provided for @negEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'當有人回應您的物資或需求時，協商會顯示在這裡'**
  String get negEmptySubtitle;

  /// No description provided for @negStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'等待確認'**
  String get negStatusPending;

  /// No description provided for @negStatusAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已接受'**
  String get negStatusAccepted;

  /// No description provided for @negStatusNavigating.
  ///
  /// In zh, this message translates to:
  /// **'導航中'**
  String get negStatusNavigating;

  /// No description provided for @negRoleRequester.
  ///
  /// In zh, this message translates to:
  /// **'需求方'**
  String get negRoleRequester;

  /// No description provided for @negRoleProvider.
  ///
  /// In zh, this message translates to:
  /// **'供給方'**
  String get negRoleProvider;

  /// No description provided for @negRoleMeProvider.
  ///
  /// In zh, this message translates to:
  /// **'我提供'**
  String get negRoleMeProvider;

  /// No description provided for @negRoleMeRequester.
  ///
  /// In zh, this message translates to:
  /// **'我需要'**
  String get negRoleMeRequester;

  /// No description provided for @negScoreUnit.
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get negScoreUnit;

  /// No description provided for @negStaleLabel.
  ///
  /// In zh, this message translates to:
  /// **'超時'**
  String get negStaleLabel;

  /// No description provided for @negViewMapButton.
  ///
  /// In zh, this message translates to:
  /// **'查看地圖'**
  String get negViewMapButton;

  /// No description provided for @negCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get negCancelButton;

  /// No description provided for @negCancelDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消協商'**
  String get negCancelDialogTitle;

  /// No description provided for @negCancelDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要取消此協商嗎？'**
  String get negCancelDialogContent;

  /// No description provided for @negCancelDialogBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get negCancelDialogBack;

  /// No description provided for @negCancelDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確定取消'**
  String get negCancelDialogConfirm;

  /// No description provided for @negQtyUnit.
  ///
  /// In zh, this message translates to:
  /// **'{qty} 份'**
  String negQtyUnit(int qty);

  /// No description provided for @communityEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚無社區動態'**
  String get communityEmptyTitle;

  /// No description provided for @communityEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同區域其他用戶的物資供給與需求會顯示在這裡'**
  String get communityEmptySubtitle;

  /// No description provided for @communityTypeSupply.
  ///
  /// In zh, this message translates to:
  /// **'有人可提供'**
  String get communityTypeSupply;

  /// No description provided for @communityTypeRequest.
  ///
  /// In zh, this message translates to:
  /// **'有人需要'**
  String get communityTypeRequest;

  /// No description provided for @communityActionNeed.
  ///
  /// In zh, this message translates to:
  /// **'我需要'**
  String get communityActionNeed;

  /// No description provided for @communityActionHelp.
  ///
  /// In zh, this message translates to:
  /// **'我想幫忙'**
  String get communityActionHelp;

  /// No description provided for @communityDialogConfirmNeed.
  ///
  /// In zh, this message translates to:
  /// **'確認需求數量'**
  String get communityDialogConfirmNeed;

  /// No description provided for @communityDialogConfirmSupply.
  ///
  /// In zh, this message translates to:
  /// **'確認提供數量'**
  String get communityDialogConfirmSupply;

  /// No description provided for @communityDialogSupplyInfo.
  ///
  /// In zh, this message translates to:
  /// **'有人可以提供「{name}」{qty} 份'**
  String communityDialogSupplyInfo(String name, int qty);

  /// No description provided for @communityDialogRequestInfo.
  ///
  /// In zh, this message translates to:
  /// **'有人需要「{name}」{qty} 份'**
  String communityDialogRequestInfo(String name, int qty);

  /// No description provided for @communityDialogHowManyNeed.
  ///
  /// In zh, this message translates to:
  /// **'您需要幾份？'**
  String get communityDialogHowManyNeed;

  /// No description provided for @communityDialogHowManySupply.
  ///
  /// In zh, this message translates to:
  /// **'您可以提供幾份？'**
  String get communityDialogHowManySupply;

  /// No description provided for @communityDialogQtyHint.
  ///
  /// In zh, this message translates to:
  /// **'數量'**
  String get communityDialogQtyHint;

  /// No description provided for @communityDialogQtySuffix.
  ///
  /// In zh, this message translates to:
  /// **'份'**
  String get communityDialogQtySuffix;

  /// No description provided for @communityDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get communityDialogCancel;

  /// No description provided for @communityDialogConfirmNeedButton.
  ///
  /// In zh, this message translates to:
  /// **'確認需求'**
  String get communityDialogConfirmNeedButton;

  /// No description provided for @communityDialogConfirmSupplyButton.
  ///
  /// In zh, this message translates to:
  /// **'確認提供'**
  String get communityDialogConfirmSupplyButton;

  /// No description provided for @communityDialogQtyError.
  ///
  /// In zh, this message translates to:
  /// **'數量必須大於 0'**
  String get communityDialogQtyError;

  /// No description provided for @supplyRegTitle.
  ///
  /// In zh, this message translates to:
  /// **'登記物資供給'**
  String get supplyRegTitle;

  /// No description provided for @supplyRegCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'物資大類'**
  String get supplyRegCategoryLabel;

  /// No description provided for @supplyRegSubCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'→ {categoryLabel} 子類別'**
  String supplyRegSubCategoryLabel(String categoryLabel);

  /// No description provided for @supplyRegItemLabel.
  ///
  /// In zh, this message translates to:
  /// **'具體品項 (可選)'**
  String get supplyRegItemLabel;

  /// No description provided for @supplyRegExpiryLabel.
  ///
  /// In zh, this message translates to:
  /// **'有效期限'**
  String get supplyRegExpiryLabel;

  /// No description provided for @supplyRegExpiryHint.
  ///
  /// In zh, this message translates to:
  /// **'點擊選擇有效期限 (選填)'**
  String get supplyRegExpiryHint;

  /// No description provided for @supplyRegConditionLabel.
  ///
  /// In zh, this message translates to:
  /// **'物品狀態'**
  String get supplyRegConditionLabel;

  /// No description provided for @supplyRegQtyLabel.
  ///
  /// In zh, this message translates to:
  /// **'數量'**
  String get supplyRegQtyLabel;

  /// No description provided for @supplyRegQtyValidator.
  ///
  /// In zh, this message translates to:
  /// **'請輸入數量'**
  String get supplyRegQtyValidator;

  /// No description provided for @supplyRegDeliverySection.
  ///
  /// In zh, this message translates to:
  /// **'交接方式（可複選）'**
  String get supplyRegDeliverySection;

  /// No description provided for @supplyRegDeliveryDeliver.
  ///
  /// In zh, this message translates to:
  /// **'我送過去'**
  String get supplyRegDeliveryDeliver;

  /// No description provided for @supplyRegDeliveryDeliverDesc.
  ///
  /// In zh, this message translates to:
  /// **'主動將物資送到對方位置'**
  String get supplyRegDeliveryDeliverDesc;

  /// No description provided for @supplyRegDeliveryPickup.
  ///
  /// In zh, this message translates to:
  /// **'對方來取'**
  String get supplyRegDeliveryPickup;

  /// No description provided for @supplyRegDeliveryPickupDesc.
  ///
  /// In zh, this message translates to:
  /// **'對方來我這裡取物資'**
  String get supplyRegDeliveryPickupDesc;

  /// No description provided for @supplyRegDeliveryDropoff.
  ///
  /// In zh, this message translates to:
  /// **'放置物資'**
  String get supplyRegDeliveryDropoff;

  /// No description provided for @supplyRegDeliveryDropoffDesc.
  ///
  /// In zh, this message translates to:
  /// **'無接觸交接 — 放置後通知對方自取'**
  String get supplyRegDeliveryDropoffDesc;

  /// No description provided for @supplyRegNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'備註描述 (選填)'**
  String get supplyRegNoteHint;

  /// No description provided for @supplyRegRange.
  ///
  /// In zh, this message translates to:
  /// **'覆蓋半徑: {km} km'**
  String supplyRegRange(String km);

  /// No description provided for @supplyRegRangeNote.
  ///
  /// In zh, this message translates to:
  /// **'* 由地理環境自動建議，可手動調整'**
  String get supplyRegRangeNote;

  /// No description provided for @supplyRegPublishing.
  ///
  /// In zh, this message translates to:
  /// **'發布中...'**
  String get supplyRegPublishing;

  /// No description provided for @supplyRegPublishButton.
  ///
  /// In zh, this message translates to:
  /// **'發布至 Mesh 網路'**
  String get supplyRegPublishButton;

  /// No description provided for @supplyRegSuccessSnack.
  ///
  /// In zh, this message translates to:
  /// **'物資已成功發布！'**
  String get supplyRegSuccessSnack;

  /// No description provided for @supplyRegFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'發布失敗: {error}'**
  String supplyRegFailSnack(String error);

  /// No description provided for @reqSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'發佈物資需求'**
  String get reqSheetTitle;

  /// No description provided for @reqSheetCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'需要什麼物資？'**
  String get reqSheetCategoryLabel;

  /// No description provided for @reqSheetSubCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'→ 子類別'**
  String get reqSheetSubCategoryLabel;

  /// No description provided for @reqSheetItemLabel.
  ///
  /// In zh, this message translates to:
  /// **'具體品項 (可選)'**
  String get reqSheetItemLabel;

  /// No description provided for @reqSheetQtyLabel.
  ///
  /// In zh, this message translates to:
  /// **'需求數量'**
  String get reqSheetQtyLabel;

  /// No description provided for @reqSheetMobilitySection.
  ///
  /// In zh, this message translates to:
  /// **'交接方式'**
  String get reqSheetMobilitySection;

  /// No description provided for @reqSheetMobilityPickup.
  ///
  /// In zh, this message translates to:
  /// **'我可以過去拿'**
  String get reqSheetMobilityPickup;

  /// No description provided for @reqSheetMobilityPickupDesc.
  ///
  /// In zh, this message translates to:
  /// **'我可以移動去取物資'**
  String get reqSheetMobilityPickupDesc;

  /// No description provided for @reqSheetMobilityDelivery.
  ///
  /// In zh, this message translates to:
  /// **'需要送過來'**
  String get reqSheetMobilityDelivery;

  /// No description provided for @reqSheetMobilityDeliveryDesc.
  ///
  /// In zh, this message translates to:
  /// **'無法移動，需要人送來'**
  String get reqSheetMobilityDeliveryDesc;

  /// No description provided for @reqSheetMobilityDropoff.
  ///
  /// In zh, this message translates to:
  /// **'無接觸交接'**
  String get reqSheetMobilityDropoff;

  /// No description provided for @reqSheetMobilityDropoffDesc.
  ///
  /// In zh, this message translates to:
  /// **'供給方放置物資，我自行取回'**
  String get reqSheetMobilityDropoffDesc;

  /// No description provided for @reqSheetRange.
  ///
  /// In zh, this message translates to:
  /// **'搜尋半徑: {km} km'**
  String reqSheetRange(String km);

  /// No description provided for @reqSheetNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'備註描述 (選填)'**
  String get reqSheetNoteHint;

  /// No description provided for @reqSheetPublishing.
  ///
  /// In zh, this message translates to:
  /// **'廣播中...'**
  String get reqSheetPublishing;

  /// No description provided for @reqSheetPublishButton.
  ///
  /// In zh, this message translates to:
  /// **'發布需求至 Mesh 網路'**
  String get reqSheetPublishButton;

  /// No description provided for @reqSheetSuccessSnack.
  ///
  /// In zh, this message translates to:
  /// **'需求已廣播至 Mesh 網路！'**
  String get reqSheetSuccessSnack;

  /// No description provided for @reqSheetFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'發布失敗: {error}'**
  String reqSheetFailSnack(String error);

  /// No description provided for @navTitle.
  ///
  /// In zh, this message translates to:
  /// **'導航指引'**
  String get navTitle;

  /// No description provided for @navDirectionProviderToReq.
  ///
  /// In zh, this message translates to:
  /// **'供給者前往需求者'**
  String get navDirectionProviderToReq;

  /// No description provided for @navDirectionReqToProvider.
  ///
  /// In zh, this message translates to:
  /// **'需求者前往供給者'**
  String get navDirectionReqToProvider;

  /// No description provided for @navSupplyInfo.
  ///
  /// In zh, this message translates to:
  /// **'供給: {supplyQty} 份 ←→ 需求: {requestQty} 份 (滿足率 {ratio}%)'**
  String navSupplyInfo(int supplyQty, int requestQty, int ratio);

  /// No description provided for @navGpsLocating.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位中...'**
  String get navGpsLocating;

  /// No description provided for @navBleDetected.
  ///
  /// In zh, this message translates to:
  /// **'偵測到 Mesh 節點'**
  String get navBleDetected;

  /// No description provided for @navBleSignal.
  ///
  /// In zh, this message translates to:
  /// **'信號 {strength}'**
  String navBleSignal(String strength);

  /// No description provided for @navBleSignalStrong.
  ///
  /// In zh, this message translates to:
  /// **'強 (很近)'**
  String get navBleSignalStrong;

  /// No description provided for @navBleSignalMedium.
  ///
  /// In zh, this message translates to:
  /// **'中 (附近)'**
  String get navBleSignalMedium;

  /// No description provided for @navBleSignalWeak.
  ///
  /// In zh, this message translates to:
  /// **'弱 (較遠)'**
  String get navBleSignalWeak;

  /// No description provided for @navBleScanning.
  ///
  /// In zh, this message translates to:
  /// **'掃描藍牙中... 接近對方時會自動偵測'**
  String get navBleScanning;

  /// No description provided for @navHandoffButton.
  ///
  /// In zh, this message translates to:
  /// **'開始交接'**
  String get navHandoffButton;

  /// No description provided for @navHandoffWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待偵測到對方藍牙...'**
  String get navHandoffWaiting;

  /// No description provided for @navCancelDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'媒合已取消'**
  String get navCancelDialogTitle;

  /// No description provided for @navCancelDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'對方已取消此次媒合。'**
  String get navCancelDialogContent;

  /// No description provided for @navCancelDialogBack.
  ///
  /// In zh, this message translates to:
  /// **'返回首頁'**
  String get navCancelDialogBack;

  /// No description provided for @navCompleteSnack.
  ///
  /// In zh, this message translates to:
  /// **'交接完成！'**
  String get navCompleteSnack;

  /// No description provided for @handoffTitle.
  ///
  /// In zh, this message translates to:
  /// **'實體交接確認'**
  String get handoffTitle;

  /// No description provided for @handoffProviderResource.
  ///
  /// In zh, this message translates to:
  /// **'物資：{resourceType}'**
  String handoffProviderResource(String resourceType);

  /// No description provided for @handoffProviderPinLabel.
  ///
  /// In zh, this message translates to:
  /// **'告訴對方以下 PIN 碼'**
  String get handoffProviderPinLabel;

  /// No description provided for @handoffProviderTimeout.
  ///
  /// In zh, this message translates to:
  /// **'若 {timeout} 內未完成，物資將自動歸還'**
  String handoffProviderTimeout(String timeout);

  /// No description provided for @handoffProviderWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待對方透過 BLE 輸入 PIN 確認收到物資...'**
  String get handoffProviderWaiting;

  /// No description provided for @handoffProviderGattNote.
  ///
  /// In zh, this message translates to:
  /// **'(本裝置已開啟 GATT 交接廣播)'**
  String get handoffProviderGattNote;

  /// No description provided for @handoffRequesterPinPrompt.
  ///
  /// In zh, this message translates to:
  /// **'請輸入供給方顯示的 4 位 PIN'**
  String get handoffRequesterPinPrompt;

  /// No description provided for @handoffRequesterLockout.
  ///
  /// In zh, this message translates to:
  /// **'輸入錯誤次數過多，請等待 {seconds} 秒...'**
  String handoffRequesterLockout(int seconds);

  /// No description provided for @handoffRequesterWrong.
  ///
  /// In zh, this message translates to:
  /// **'錯誤！剩餘嘗試次數: {remaining} / 6'**
  String handoffRequesterWrong(int remaining);

  /// No description provided for @handoffRequesterConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'確認收到物資'**
  String get handoffRequesterConfirmButton;

  /// No description provided for @handoffDropoffProviderTitle.
  ///
  /// In zh, this message translates to:
  /// **'無接觸交接 — 放置物資'**
  String get handoffDropoffProviderTitle;

  /// No description provided for @handoffDropoffLocationLabel.
  ///
  /// In zh, this message translates to:
  /// **'放置位置'**
  String get handoffDropoffLocationLabel;

  /// No description provided for @handoffDropoffUseCurrentLocation.
  ///
  /// In zh, this message translates to:
  /// **'點擊使用目前位置'**
  String get handoffDropoffUseCurrentLocation;

  /// No description provided for @handoffDropoffLocateButton.
  ///
  /// In zh, this message translates to:
  /// **'定位'**
  String get handoffDropoffLocateButton;

  /// No description provided for @handoffDropoffDescLabel.
  ///
  /// In zh, this message translates to:
  /// **'放置描述 / 照片備註（選填）'**
  String get handoffDropoffDescLabel;

  /// No description provided for @handoffDropoffDescHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：放在大門左側紙箱旁'**
  String get handoffDropoffDescHint;

  /// No description provided for @handoffDropoffWaitingButton.
  ///
  /// In zh, this message translates to:
  /// **'已放置，等待對方取回'**
  String get handoffDropoffWaitingButton;

  /// No description provided for @handoffDropoffConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'確認放置物資'**
  String get handoffDropoffConfirmButton;

  /// No description provided for @handoffDropoffRequesterTitle.
  ///
  /// In zh, this message translates to:
  /// **'無接觸交接'**
  String get handoffDropoffRequesterTitle;

  /// No description provided for @handoffDropoffRequesterContent.
  ///
  /// In zh, this message translates to:
  /// **'供給方已將物資放置於指定位置，\n請前往取回後確認。'**
  String get handoffDropoffRequesterContent;

  /// No description provided for @handoffDropoffRequesterConfirm.
  ///
  /// In zh, this message translates to:
  /// **'已取得物資'**
  String get handoffDropoffRequesterConfirm;

  /// No description provided for @handoffSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'交接完成！'**
  String get handoffSuccessTitle;

  /// No description provided for @handoffSuccessContent.
  ///
  /// In zh, this message translates to:
  /// **'{resourceType} 已成功轉交'**
  String handoffSuccessContent(String resourceType);

  /// No description provided for @handoffSuccessBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get handoffSuccessBack;

  /// No description provided for @handoffCancelledTitle.
  ///
  /// In zh, this message translates to:
  /// **'交接已取消'**
  String get handoffCancelledTitle;

  /// No description provided for @handoffCancelledContent.
  ///
  /// In zh, this message translates to:
  /// **'物資已歸還至可用狀態'**
  String get handoffCancelledContent;

  /// No description provided for @handoffCancelledBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get handoffCancelledBack;

  /// No description provided for @handoffTimeout30min.
  ///
  /// In zh, this message translates to:
  /// **'30 分鐘'**
  String get handoffTimeout30min;

  /// No description provided for @handoffTimeout4hr.
  ///
  /// In zh, this message translates to:
  /// **'4 小時'**
  String get handoffTimeout4hr;

  /// No description provided for @medicalTitle.
  ///
  /// In zh, this message translates to:
  /// **'醫療卡'**
  String get medicalTitle;

  /// No description provided for @medicalSosInfo.
  ///
  /// In zh, this message translates to:
  /// **'帶有廣播圖標的欄位會在 SOS 求救時\n隨訊號一起透過 Mesh 網路傳送給附近救援者'**
  String get medicalSosInfo;

  /// No description provided for @medicalPresetLabel.
  ///
  /// In zh, this message translates to:
  /// **'快速預設'**
  String get medicalPresetLabel;

  /// No description provided for @medicalPresetMinimal.
  ///
  /// In zh, this message translates to:
  /// **'最小揭露'**
  String get medicalPresetMinimal;

  /// No description provided for @medicalPresetRecommended.
  ///
  /// In zh, this message translates to:
  /// **'建議設定'**
  String get medicalPresetRecommended;

  /// No description provided for @medicalPresetFull.
  ///
  /// In zh, this message translates to:
  /// **'全部分享'**
  String get medicalPresetFull;

  /// No description provided for @medicalPresetApplied.
  ///
  /// In zh, this message translates to:
  /// **'已套用「{presetName}」預設'**
  String medicalPresetApplied(String presetName);

  /// No description provided for @medicalSectionBasic.
  ///
  /// In zh, this message translates to:
  /// **'基本生理'**
  String get medicalSectionBasic;

  /// No description provided for @medicalSectionBackground.
  ///
  /// In zh, this message translates to:
  /// **'醫療背景'**
  String get medicalSectionBackground;

  /// No description provided for @medicalSectionEmergency.
  ///
  /// In zh, this message translates to:
  /// **'急救資訊'**
  String get medicalSectionEmergency;

  /// No description provided for @medicalFieldName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get medicalFieldName;

  /// No description provided for @medicalFieldAge.
  ///
  /// In zh, this message translates to:
  /// **'年齡'**
  String get medicalFieldAge;

  /// No description provided for @medicalFieldHeight.
  ///
  /// In zh, this message translates to:
  /// **'身高 (cm)'**
  String get medicalFieldHeight;

  /// No description provided for @medicalFieldWeight.
  ///
  /// In zh, this message translates to:
  /// **'體重 (kg)'**
  String get medicalFieldWeight;

  /// No description provided for @medicalFieldBloodType.
  ///
  /// In zh, this message translates to:
  /// **'血型'**
  String get medicalFieldBloodType;

  /// No description provided for @medicalFieldConditions.
  ///
  /// In zh, this message translates to:
  /// **'醫療狀況'**
  String get medicalFieldConditions;

  /// No description provided for @medicalFieldAllergies.
  ///
  /// In zh, this message translates to:
  /// **'過敏原'**
  String get medicalFieldAllergies;

  /// No description provided for @medicalFieldMedications.
  ///
  /// In zh, this message translates to:
  /// **'目前藥物'**
  String get medicalFieldMedications;

  /// No description provided for @medicalFieldEmergencyContact.
  ///
  /// In zh, this message translates to:
  /// **'緊急聯絡人'**
  String get medicalFieldEmergencyContact;

  /// No description provided for @medicalFieldOrganDonor.
  ///
  /// In zh, this message translates to:
  /// **'器官捐贈意願'**
  String get medicalFieldOrganDonor;

  /// No description provided for @medicalFieldPrimaryLanguage.
  ///
  /// In zh, this message translates to:
  /// **'主要語言'**
  String get medicalFieldPrimaryLanguage;

  /// No description provided for @medicalHintName.
  ///
  /// In zh, this message translates to:
  /// **'你的姓名'**
  String get medicalHintName;

  /// No description provided for @medicalHintAge.
  ///
  /// In zh, this message translates to:
  /// **'年齡'**
  String get medicalHintAge;

  /// No description provided for @medicalSuffixAge.
  ///
  /// In zh, this message translates to:
  /// **'歲'**
  String get medicalSuffixAge;

  /// No description provided for @medicalHintHeight.
  ///
  /// In zh, this message translates to:
  /// **'身高'**
  String get medicalHintHeight;

  /// No description provided for @medicalSuffixHeight.
  ///
  /// In zh, this message translates to:
  /// **'cm'**
  String get medicalSuffixHeight;

  /// No description provided for @medicalHintWeight.
  ///
  /// In zh, this message translates to:
  /// **'體重'**
  String get medicalHintWeight;

  /// No description provided for @medicalSuffixWeight.
  ///
  /// In zh, this message translates to:
  /// **'kg'**
  String get medicalSuffixWeight;

  /// No description provided for @medicalHintConditions.
  ///
  /// In zh, this message translates to:
  /// **'如：糖尿病、癲癇、氣喘（用頓號分隔）'**
  String get medicalHintConditions;

  /// No description provided for @medicalHintMedications.
  ///
  /// In zh, this message translates to:
  /// **'如：胰島素、降血壓藥（用頓號分隔）'**
  String get medicalHintMedications;

  /// No description provided for @medicalHintLanguage.
  ///
  /// In zh, this message translates to:
  /// **'如：繁體中文、English'**
  String get medicalHintLanguage;

  /// No description provided for @medicalBloodTypeNone.
  ///
  /// In zh, this message translates to:
  /// **'未選擇'**
  String get medicalBloodTypeNone;

  /// No description provided for @medicalAllergenLabel.
  ///
  /// In zh, this message translates to:
  /// **'過敏原'**
  String get medicalAllergenLabel;

  /// No description provided for @medicalAllergenHint.
  ///
  /// In zh, this message translates to:
  /// **'過敏原'**
  String get medicalAllergenHint;

  /// No description provided for @medicalReactionHint.
  ///
  /// In zh, this message translates to:
  /// **'反應症狀'**
  String get medicalReactionHint;

  /// No description provided for @medicalReactionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知反應'**
  String get medicalReactionUnknown;

  /// No description provided for @medicalEcPhoneLabel.
  ///
  /// In zh, this message translates to:
  /// **'緊急聯絡人電話'**
  String get medicalEcPhoneLabel;

  /// No description provided for @medicalEcPhoneHint.
  ///
  /// In zh, this message translates to:
  /// **'0912-345-678'**
  String get medicalEcPhoneHint;

  /// No description provided for @medicalEcRelationLabel.
  ///
  /// In zh, this message translates to:
  /// **'與你的關係'**
  String get medicalEcRelationLabel;

  /// No description provided for @medicalEcRelationHint.
  ///
  /// In zh, this message translates to:
  /// **'如：母親、配偶'**
  String get medicalEcRelationHint;

  /// No description provided for @medicalOrganDonorLabel.
  ///
  /// In zh, this message translates to:
  /// **'器官捐贈意願'**
  String get medicalOrganDonorLabel;

  /// No description provided for @medicalOrganDonorNone.
  ///
  /// In zh, this message translates to:
  /// **'未設定'**
  String get medicalOrganDonorNone;

  /// No description provided for @medicalOrganDonorYes.
  ///
  /// In zh, this message translates to:
  /// **'願意'**
  String get medicalOrganDonorYes;

  /// No description provided for @medicalOrganDonorNo.
  ///
  /// In zh, this message translates to:
  /// **'不願意'**
  String get medicalOrganDonorNo;

  /// No description provided for @medicalHealthImportButton.
  ///
  /// In zh, this message translates to:
  /// **'從 Health Connect 匯入'**
  String get medicalHealthImportButton;

  /// No description provided for @medicalHealthConnectRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要 Health Connect'**
  String get medicalHealthConnectRequired;

  /// No description provided for @medicalHealthConnectInstallGuide.
  ///
  /// In zh, this message translates to:
  /// **'此功能需要 Google Health Connect 應用。\n\n請前往 Google Play 商店安裝「Health Connect」後再試。\n\n安裝後，請先在 Health Connect 中新增您的健康資料（身高、體重、血型），然後回到此頁面匯入。'**
  String get medicalHealthConnectInstallGuide;

  /// No description provided for @medicalHealthConnectDismiss.
  ///
  /// In zh, this message translates to:
  /// **'了解'**
  String get medicalHealthConnectDismiss;

  /// No description provided for @medicalHealthConnectInstall.
  ///
  /// In zh, this message translates to:
  /// **'前往安裝'**
  String get medicalHealthConnectInstall;

  /// No description provided for @medicalHealthConnectAuthFail.
  ///
  /// In zh, this message translates to:
  /// **'授權失敗'**
  String get medicalHealthConnectAuthFail;

  /// No description provided for @medicalHealthConnectAuthGuide.
  ///
  /// In zh, this message translates to:
  /// **'未獲得 Health Connect 讀取權限。\n\n請手動授權：\n1. 開啟「Health Connect」應用\n2. 點選「應用程式權限」\n3. 找到「烽傳」並允許讀取身高、體重、血型'**
  String get medicalHealthConnectAuthGuide;

  /// No description provided for @medicalHealthConnectNoData.
  ///
  /// In zh, this message translates to:
  /// **'Health Connect 中沒有找到健康資料'**
  String get medicalHealthConnectNoData;

  /// No description provided for @medicalHealthConnectImported.
  ///
  /// In zh, this message translates to:
  /// **'已從 Health Connect 匯入 {count} 項資料'**
  String medicalHealthConnectImported(int count);

  /// No description provided for @medicalHealthConnectNoNewData.
  ///
  /// In zh, this message translates to:
  /// **'未匯入新資料（欄位已有值或無可用資料）'**
  String get medicalHealthConnectNoNewData;

  /// No description provided for @medicalHealthConnectFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'Health Connect 匯入失敗：{error}\n請確認已安裝 Health Connect 應用'**
  String medicalHealthConnectFailSnack(String error);

  /// No description provided for @medicalSaving.
  ///
  /// In zh, this message translates to:
  /// **'儲存中...'**
  String get medicalSaving;

  /// No description provided for @medicalSaveButton.
  ///
  /// In zh, this message translates to:
  /// **'儲存醫療卡'**
  String get medicalSaveButton;

  /// No description provided for @medicalSavedSnack.
  ///
  /// In zh, this message translates to:
  /// **'醫療卡已儲存'**
  String get medicalSavedSnack;

  /// No description provided for @medicalSaveFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'儲存失敗: {error}'**
  String medicalSaveFailSnack(String error);

  /// No description provided for @medicalSosToggleOn.
  ///
  /// In zh, this message translates to:
  /// **'ON'**
  String get medicalSosToggleOn;

  /// No description provided for @medicalSosToggleOff.
  ///
  /// In zh, this message translates to:
  /// **'OFF'**
  String get medicalSosToggleOff;

  /// No description provided for @chatListTitle.
  ///
  /// In zh, this message translates to:
  /// **'聊天室'**
  String get chatListTitle;

  /// No description provided for @chatListRefreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重新整理'**
  String get chatListRefreshTooltip;

  /// No description provided for @chatListRoomNational.
  ///
  /// In zh, this message translates to:
  /// **'全國公告'**
  String get chatListRoomNational;

  /// No description provided for @chatListRoomCounty.
  ///
  /// In zh, this message translates to:
  /// **'縣市公告'**
  String get chatListRoomCounty;

  /// No description provided for @chatListRoomTownship.
  ///
  /// In zh, this message translates to:
  /// **'鄉鎮區公告'**
  String get chatListRoomTownship;

  /// No description provided for @chatListRoomVillage.
  ///
  /// In zh, this message translates to:
  /// **'里聊天室'**
  String get chatListRoomVillage;

  /// No description provided for @chatListRoomCustom.
  ///
  /// In zh, this message translates to:
  /// **'自訂頻道'**
  String get chatListRoomCustom;

  /// No description provided for @chatListEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未加入任何聊天室'**
  String get chatListEmptyTitle;

  /// No description provided for @chatListEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'點擊右下角 + 加入或掃碼'**
  String get chatListEmptySubtitle;

  /// No description provided for @chatListAutoJoin.
  ///
  /// In zh, this message translates to:
  /// **'自動加入所在里聊天室'**
  String get chatListAutoJoin;

  /// No description provided for @chatListAutoJoinSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已自動加入所在里的聊天室'**
  String get chatListAutoJoinSuccess;

  /// No description provided for @chatListAutoJoinFail.
  ///
  /// In zh, this message translates to:
  /// **'無法取得位置資訊，請手動加入'**
  String get chatListAutoJoinFail;

  /// No description provided for @chatListFabTooltip.
  ///
  /// In zh, this message translates to:
  /// **'加入聊天室'**
  String get chatListFabTooltip;

  /// No description provided for @chatListAdminBadge.
  ///
  /// In zh, this message translates to:
  /// **'公告頻道'**
  String get chatListAdminBadge;

  /// No description provided for @chatListLeaveTitle.
  ///
  /// In zh, this message translates to:
  /// **'離開聊天室'**
  String get chatListLeaveTitle;

  /// No description provided for @chatListLeaveContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要離開「{roomName}」嗎？歷史訊息將被清除。'**
  String chatListLeaveContent(String roomName);

  /// No description provided for @chatListLeaveCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get chatListLeaveCancel;

  /// No description provided for @chatListLeaveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'離開'**
  String get chatListLeaveConfirm;

  /// No description provided for @chatRoomMessageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 則訊息'**
  String chatRoomMessageCount(int count);

  /// No description provided for @chatRoomEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有訊息'**
  String get chatRoomEmpty;

  /// No description provided for @chatRoomReply.
  ///
  /// In zh, this message translates to:
  /// **'回覆訊息'**
  String get chatRoomReply;

  /// No description provided for @chatRoomAdminLock.
  ///
  /// In zh, this message translates to:
  /// **'公告頻道 — 僅管理員（L3）可發言'**
  String get chatRoomAdminLock;

  /// No description provided for @chatRoomInputHint.
  ///
  /// In zh, this message translates to:
  /// **'輸入訊息...'**
  String get chatRoomInputHint;

  /// No description provided for @chatRoomSendCooldown.
  ///
  /// In zh, this message translates to:
  /// **'發送失敗，請等待 {seconds} 秒後再試'**
  String chatRoomSendCooldown(int seconds);

  /// No description provided for @chatRoomAnonymous.
  ///
  /// In zh, this message translates to:
  /// **'匿名'**
  String get chatRoomAnonymous;

  /// No description provided for @chatJoinTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入聊天室'**
  String get chatJoinTitle;

  /// No description provided for @chatJoinAutoSection.
  ///
  /// In zh, this message translates to:
  /// **'自動加入'**
  String get chatJoinAutoSection;

  /// No description provided for @chatJoinAutoDesc.
  ///
  /// In zh, this message translates to:
  /// **'根據 GPS 位置自動加入所在里聊天室及行政區公告頻道'**
  String get chatJoinAutoDesc;

  /// No description provided for @chatJoinGpsLocating.
  ///
  /// In zh, this message translates to:
  /// **'正在取得 GPS 位置...'**
  String get chatJoinGpsLocating;

  /// No description provided for @chatJoinGpsWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待 GPS 定位中... ({seconds}s)'**
  String chatJoinGpsWaiting(int seconds);

  /// No description provided for @chatJoinGpsQuerying.
  ///
  /// In zh, this message translates to:
  /// **'正在查詢所在行政區...'**
  String get chatJoinGpsQuerying;

  /// No description provided for @chatJoinGpsFail.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位失敗，請確認 GPS 已開啟，或使用下方手動設定'**
  String get chatJoinGpsFail;

  /// No description provided for @chatJoinAutoSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已加入所在里聊天室及公告頻道'**
  String get chatJoinAutoSuccess;

  /// No description provided for @chatJoinAutoFailRegion.
  ///
  /// In zh, this message translates to:
  /// **'無法識別所在行政區，請使用手動設定'**
  String get chatJoinAutoFailRegion;

  /// No description provided for @chatJoinAutoButton.
  ///
  /// In zh, this message translates to:
  /// **'偵測並加入里聊天室'**
  String get chatJoinAutoButton;

  /// No description provided for @chatJoinManualSection.
  ///
  /// In zh, this message translates to:
  /// **'手動設定所在區域'**
  String get chatJoinManualSection;

  /// No description provided for @chatJoinManualDesc.
  ///
  /// In zh, this message translates to:
  /// **'輸入縣市、鄉鎮區或里名稱搜尋，選擇後加入對應聊天室'**
  String get chatJoinManualDesc;

  /// No description provided for @chatJoinSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'例：新興區、安康里、高雄市'**
  String get chatJoinSearchHint;

  /// No description provided for @chatJoinSearchButton.
  ///
  /// In zh, this message translates to:
  /// **'搜尋'**
  String get chatJoinSearchButton;

  /// No description provided for @chatJoinSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'搜尋結果（{count} 筆）'**
  String chatJoinSearchResults(int count);

  /// No description provided for @chatJoinSearchVillcode.
  ///
  /// In zh, this message translates to:
  /// **'代碼: {villcode}'**
  String chatJoinSearchVillcode(String villcode);

  /// No description provided for @chatJoinSearchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'找不到符合的村里，請嘗試其他關鍵字'**
  String get chatJoinSearchNoResults;

  /// No description provided for @chatJoinSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已加入 {fullName} 聊天室及公告頻道'**
  String chatJoinSuccess(String fullName);

  /// No description provided for @chatJoinFail.
  ///
  /// In zh, this message translates to:
  /// **'加入失敗: {error}'**
  String chatJoinFail(String error);

  /// No description provided for @chatJoinInviteSection.
  ///
  /// In zh, this message translates to:
  /// **'輸入邀請碼'**
  String get chatJoinInviteSection;

  /// No description provided for @chatJoinInviteDesc.
  ///
  /// In zh, this message translates to:
  /// **'輸入聊天室 ID 或邀請碼加入自訂頻道'**
  String get chatJoinInviteDesc;

  /// No description provided for @chatJoinInviteHint.
  ///
  /// In zh, this message translates to:
  /// **'聊天室 ID 或 ID:密碼'**
  String get chatJoinInviteHint;

  /// No description provided for @chatJoinInviteButton.
  ///
  /// In zh, this message translates to:
  /// **'加入'**
  String get chatJoinInviteButton;

  /// No description provided for @chatJoinInviteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已加入聊天室'**
  String get chatJoinInviteSuccess;

  /// No description provided for @chatJoinInfoSection.
  ///
  /// In zh, this message translates to:
  /// **'聊天室說明'**
  String get chatJoinInfoSection;

  /// No description provided for @chatJoinInfoVillage.
  ///
  /// In zh, this message translates to:
  /// **'- 里聊天室：所有人皆可發言，每 3 分鐘可發一則'**
  String get chatJoinInfoVillage;

  /// No description provided for @chatJoinInfoAdmin.
  ///
  /// In zh, this message translates to:
  /// **'- 鄉鎮區/縣市/全國：僅管理員（L3）可發布公告'**
  String get chatJoinInfoAdmin;

  /// No description provided for @chatJoinInfoCustom.
  ///
  /// In zh, this message translates to:
  /// **'- 自訂頻道：需掃碼或輸入邀請碼加入'**
  String get chatJoinInfoCustom;

  /// No description provided for @chatJoinInfoMesh.
  ///
  /// In zh, this message translates to:
  /// **'- 所有訊息透過 BLE Mesh 傳播，48 小時後自動清除'**
  String get chatJoinInfoMesh;

  /// No description provided for @chatJoinInfoSwitch.
  ///
  /// In zh, this message translates to:
  /// **'- 切換區域後，舊區域的聊天室會被移除'**
  String get chatJoinInfoSwitch;

  /// No description provided for @survivalListening.
  ///
  /// In zh, this message translates to:
  /// **'正在監聽周遭求救與物資訊號...'**
  String get survivalListening;

  /// No description provided for @survivalBattery.
  ///
  /// In zh, this message translates to:
  /// **'電量: {level}%'**
  String survivalBattery(int level);

  /// No description provided for @survivalDataMuleDisable.
  ///
  /// In zh, this message translates to:
  /// **'停用 Data Mule'**
  String get survivalDataMuleDisable;

  /// No description provided for @survivalDataMuleEnable.
  ///
  /// In zh, this message translates to:
  /// **'啟用 Data Mule'**
  String get survivalDataMuleEnable;

  /// No description provided for @survivalBlePause.
  ///
  /// In zh, this message translates to:
  /// **'暫停 BLE'**
  String get survivalBlePause;

  /// No description provided for @survivalBleResume.
  ///
  /// In zh, this message translates to:
  /// **'恢復 BLE'**
  String get survivalBleResume;

  /// No description provided for @survivalStatsLocalEvents.
  ///
  /// In zh, this message translates to:
  /// **'本機事件'**
  String get survivalStatsLocalEvents;

  /// No description provided for @survivalStatsBleConnections.
  ///
  /// In zh, this message translates to:
  /// **'BLE 連線'**
  String get survivalStatsBleConnections;

  /// No description provided for @survivalRecentEvents.
  ///
  /// In zh, this message translates to:
  /// **'最近 Mesh 事件'**
  String get survivalRecentEvents;

  /// No description provided for @survivalDataMuleFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'Data Mule 服務啟動失敗\nBLE Mesh 層仍持續運作中'**
  String get survivalDataMuleFailSnack;

  /// No description provided for @survivalBleFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'BLE 啟動失敗：{error}\n請確認藍牙已開啟且已授予權限'**
  String survivalBleFailSnack(String error);

  /// No description provided for @survivalDataMuleDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'什麼是 Data Mule？'**
  String get survivalDataMuleDialogTitle;

  /// No description provided for @survivalDataMuleDialogDismiss.
  ///
  /// In zh, this message translates to:
  /// **'了解'**
  String get survivalDataMuleDialogDismiss;

  /// No description provided for @survivalExportButton.
  ///
  /// In zh, this message translates to:
  /// **'匯出完整日誌'**
  String get survivalExportButton;

  /// No description provided for @survivalExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'日誌已存到「下載」：{filename}'**
  String survivalExportSuccess(String filename);

  /// No description provided for @survivalExportFail.
  ///
  /// In zh, this message translates to:
  /// **'匯出失敗：{error}'**
  String survivalExportFail(String error);

  /// No description provided for @survivalMeshReceived.
  ///
  /// In zh, this message translates to:
  /// **'[Mesh] 收到 {bytes} bytes'**
  String survivalMeshReceived(int bytes);

  /// No description provided for @survivalDataMuleDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'Data Mule（資料騾）是一種離線中繼模式：\n\n• 你的手機會持續接收周圍裝置的求救與物資訊號\n• 即使你移動到不同區域，攜帶的資料會自動轉發給新遇到的裝置\n• 適合在災區移動的志工或救難人員，幫助訊息跨越斷網區域\n\n啟用後會以 Android 前景服務保持運作，即使螢幕關閉也不會被系統終止。\n\n耗電量：中等（持續 BLE 掃描+廣播）'**
  String get survivalDataMuleDialogContent;

  /// No description provided for @stationTitle.
  ///
  /// In zh, this message translates to:
  /// **'據點物資管理'**
  String get stationTitle;

  /// No description provided for @stationAuthRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要 L2 以上身分等級'**
  String get stationAuthRequired;

  /// No description provided for @stationAuthCurrentLevel.
  ///
  /// In zh, this message translates to:
  /// **'目前等級: L{level}'**
  String stationAuthCurrentLevel(int level);

  /// No description provided for @stationAuthDesc.
  ///
  /// In zh, this message translates to:
  /// **'據點物資管理功能僅限經過驗證的用戶使用。\n請透過實體交叉驗證提升身分等級。'**
  String get stationAuthDesc;

  /// No description provided for @stationTabAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增據點物資'**
  String get stationTabAdd;

  /// No description provided for @stationTabManage.
  ///
  /// In zh, this message translates to:
  /// **'管理已註冊'**
  String get stationTabManage;

  /// No description provided for @stationCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'物資大類'**
  String get stationCategoryLabel;

  /// No description provided for @stationSubCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'→ 子類別'**
  String get stationSubCategoryLabel;

  /// No description provided for @stationItemLabel.
  ///
  /// In zh, this message translates to:
  /// **'具體品項 (可選)'**
  String get stationItemLabel;

  /// No description provided for @stationQtyLabel.
  ///
  /// In zh, this message translates to:
  /// **'庫存數量'**
  String get stationQtyLabel;

  /// No description provided for @stationTotalQtyLabel.
  ///
  /// In zh, this message translates to:
  /// **'總庫存數量'**
  String get stationTotalQtyLabel;

  /// No description provided for @stationQuotaSection.
  ///
  /// In zh, this message translates to:
  /// **'個人配額設定'**
  String get stationQuotaSection;

  /// No description provided for @stationQuotaCategoryLimit.
  ///
  /// In zh, this message translates to:
  /// **'每人每類上限'**
  String get stationQuotaCategoryLimit;

  /// No description provided for @stationQuotaTotalLimit.
  ///
  /// In zh, this message translates to:
  /// **'每人總量上限'**
  String get stationQuotaTotalLimit;

  /// No description provided for @stationResetCycleLabel.
  ///
  /// In zh, this message translates to:
  /// **'配額重設週期'**
  String get stationResetCycleLabel;

  /// No description provided for @stationResetChip6h.
  ///
  /// In zh, this message translates to:
  /// **'6 小時'**
  String get stationResetChip6h;

  /// No description provided for @stationResetChip12h.
  ///
  /// In zh, this message translates to:
  /// **'12 小時'**
  String get stationResetChip12h;

  /// No description provided for @stationResetChip24h.
  ///
  /// In zh, this message translates to:
  /// **'24 小時'**
  String get stationResetChip24h;

  /// No description provided for @stationResetChip48h.
  ///
  /// In zh, this message translates to:
  /// **'48 小時'**
  String get stationResetChip48h;

  /// No description provided for @stationResetChip72h.
  ///
  /// In zh, this message translates to:
  /// **'72 小時'**
  String get stationResetChip72h;

  /// No description provided for @stationResetChipNone.
  ///
  /// In zh, this message translates to:
  /// **'不重設'**
  String get stationResetChipNone;

  /// No description provided for @stationResetNoteInterval.
  ///
  /// In zh, this message translates to:
  /// **'每 {hours} 小時自動重設個人已領取額度'**
  String stationResetNoteInterval(int hours);

  /// No description provided for @stationResetNoteNone.
  ///
  /// In zh, this message translates to:
  /// **'配額用完即止，不會自動重設'**
  String get stationResetNoteNone;

  /// No description provided for @stationVisibilityLabel.
  ///
  /// In zh, this message translates to:
  /// **'物資可見範圍'**
  String get stationVisibilityLabel;

  /// No description provided for @stationVisibilityVillage.
  ///
  /// In zh, this message translates to:
  /// **'指定村里'**
  String get stationVisibilityVillage;

  /// No description provided for @stationVisibilityVillageDesc.
  ///
  /// In zh, this message translates to:
  /// **'可多選鄰近村里'**
  String get stationVisibilityVillageDesc;

  /// No description provided for @stationVisibilityTownship.
  ///
  /// In zh, this message translates to:
  /// **'整個鄉鎮區'**
  String get stationVisibilityTownship;

  /// No description provided for @stationVisibilityTownshipDesc.
  ///
  /// In zh, this message translates to:
  /// **'該行政區全部可見'**
  String get stationVisibilityTownshipDesc;

  /// No description provided for @stationVisibilityNoVillages.
  ///
  /// In zh, this message translates to:
  /// **'無法取得附近村里資訊'**
  String get stationVisibilityNoVillages;

  /// No description provided for @stationVisibilityVillageNote.
  ///
  /// In zh, this message translates to:
  /// **'* 已根據目前位置列出鄰近村里，可勾選多個'**
  String get stationVisibilityVillageNote;

  /// No description provided for @stationVisibilityTownNotLocated.
  ///
  /// In zh, this message translates to:
  /// **'尚未定位'**
  String get stationVisibilityTownNotLocated;

  /// No description provided for @stationVisibilityTownNote.
  ///
  /// In zh, this message translates to:
  /// **'* 將以目前定位的鄉鎮市區為可見範圍'**
  String get stationVisibilityTownNote;

  /// No description provided for @stationQtyValidator.
  ///
  /// In zh, this message translates to:
  /// **'請輸入有效數量'**
  String get stationQtyValidator;

  /// No description provided for @stationFieldRequired.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get stationFieldRequired;

  /// No description provided for @stationPublishing.
  ///
  /// In zh, this message translates to:
  /// **'發布中...'**
  String get stationPublishing;

  /// No description provided for @stationPublishButton.
  ///
  /// In zh, this message translates to:
  /// **'發布據點物資'**
  String get stationPublishButton;

  /// No description provided for @stationPublishSuccess.
  ///
  /// In zh, this message translates to:
  /// **'據點物資已成功發布！'**
  String get stationPublishSuccess;

  /// No description provided for @stationManageEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚無據點物資'**
  String get stationManageEmptyTitle;

  /// No description provided for @stationManageEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切換到「新增據點物資」頁面開始註冊'**
  String get stationManageEmptySubtitle;

  /// No description provided for @stationStatusSufficient.
  ///
  /// In zh, this message translates to:
  /// **'充足'**
  String get stationStatusSufficient;

  /// No description provided for @stationStatusLow.
  ///
  /// In zh, this message translates to:
  /// **'低庫存'**
  String get stationStatusLow;

  /// No description provided for @stationStatusCritical.
  ///
  /// In zh, this message translates to:
  /// **'即將用盡'**
  String get stationStatusCritical;

  /// No description provided for @stationStatusDepleted.
  ///
  /// In zh, this message translates to:
  /// **'已用盡'**
  String get stationStatusDepleted;

  /// No description provided for @stationInfoTotalQty.
  ///
  /// In zh, this message translates to:
  /// **'總庫存'**
  String get stationInfoTotalQty;

  /// No description provided for @stationInfoUsed.
  ///
  /// In zh, this message translates to:
  /// **'已領取'**
  String get stationInfoUsed;

  /// No description provided for @stationInfoRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩餘'**
  String get stationInfoRemaining;

  /// No description provided for @stationInfoUsers.
  ///
  /// In zh, this message translates to:
  /// **'領取人數'**
  String get stationInfoUsers;

  /// No description provided for @stationInfoQtyUnit.
  ///
  /// In zh, this message translates to:
  /// **'{qty} 份'**
  String stationInfoQtyUnit(int qty);

  /// No description provided for @stationInfoUsersUnit.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人'**
  String stationInfoUsersUnit(int count);

  /// No description provided for @stationQuotaRulesLabel.
  ///
  /// In zh, this message translates to:
  /// **'配額規則'**
  String get stationQuotaRulesLabel;

  /// No description provided for @stationQuotaCategoryLimitInfo.
  ///
  /// In zh, this message translates to:
  /// **'每人每類上限'**
  String get stationQuotaCategoryLimitInfo;

  /// No description provided for @stationQuotaTotalLimitInfo.
  ///
  /// In zh, this message translates to:
  /// **'每人總量上限'**
  String get stationQuotaTotalLimitInfo;

  /// No description provided for @stationQuotaResetCycleInfo.
  ///
  /// In zh, this message translates to:
  /// **'重設週期'**
  String get stationQuotaResetCycleInfo;

  /// No description provided for @stationQuotaResetHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小時'**
  String stationQuotaResetHours(int hours);

  /// No description provided for @stationQuotaResetNone.
  ///
  /// In zh, this message translates to:
  /// **'不重設'**
  String get stationQuotaResetNone;

  /// No description provided for @stationVisibleZones.
  ///
  /// In zh, this message translates to:
  /// **'可見範圍'**
  String get stationVisibleZones;

  /// No description provided for @stationVisibleZonesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個村里'**
  String stationVisibleZonesCount(int count);

  /// No description provided for @stationVisibleTownship.
  ///
  /// In zh, this message translates to:
  /// **'鄉鎮區 {township}'**
  String stationVisibleTownship(String township);

  /// No description provided for @stationQuotaDetailButton.
  ///
  /// In zh, this message translates to:
  /// **'額度明細'**
  String get stationQuotaDetailButton;

  /// No description provided for @stationQuotaResetButton.
  ///
  /// In zh, this message translates to:
  /// **'重設額度'**
  String get stationQuotaResetButton;

  /// No description provided for @stationRemoveButton.
  ///
  /// In zh, this message translates to:
  /// **'下架'**
  String get stationRemoveButton;

  /// No description provided for @stationQuotaDetailEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚無領取紀錄'**
  String get stationQuotaDetailEmpty;

  /// No description provided for @stationQuotaDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'額度明細 — {name}'**
  String stationQuotaDetailTitle(String name);

  /// No description provided for @stationQuotaUserLabel.
  ///
  /// In zh, this message translates to:
  /// **'用戶 {keyHex}...'**
  String stationQuotaUserLabel(String keyHex);

  /// No description provided for @stationQuotaUsedTotal.
  ///
  /// In zh, this message translates to:
  /// **'本期已領: {used} / 總計: {total}'**
  String stationQuotaUsedTotal(int used, int total);

  /// No description provided for @stationQuotaLastReset.
  ///
  /// In zh, this message translates to:
  /// **'上次重設: {date}'**
  String stationQuotaLastReset(String date);

  /// No description provided for @stationResetAllDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'重設所有額度'**
  String get stationResetAllDialogTitle;

  /// No description provided for @stationResetAllDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要重設此物資的所有用戶額度嗎？\n重設後所有人的已領取數量將歸零。'**
  String get stationResetAllDialogContent;

  /// No description provided for @stationResetAllDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get stationResetAllDialogCancel;

  /// No description provided for @stationResetAllDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認重設'**
  String get stationResetAllDialogConfirm;

  /// No description provided for @stationResetSuccessSnack.
  ///
  /// In zh, this message translates to:
  /// **'額度已重設'**
  String get stationResetSuccessSnack;

  /// No description provided for @stationResetFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'重設失敗: {error}'**
  String stationResetFailSnack(String error);

  /// No description provided for @stationRemoveDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'下架據點物資'**
  String get stationRemoveDialogTitle;

  /// No description provided for @stationRemoveDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'確定要下架「{name}」嗎？\n此操作會將該物資標記為已消耗。'**
  String stationRemoveDialogContent(String name);

  /// No description provided for @stationRemoveDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get stationRemoveDialogCancel;

  /// No description provided for @stationRemoveDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認下架'**
  String get stationRemoveDialogConfirm;

  /// No description provided for @stationRemoveSuccessSnack.
  ///
  /// In zh, this message translates to:
  /// **'物資已下架'**
  String get stationRemoveSuccessSnack;

  /// No description provided for @stationRemoveFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'下架失敗: {error}'**
  String stationRemoveFailSnack(String error);

  /// No description provided for @batteryAndroidOnly.
  ///
  /// In zh, this message translates to:
  /// **'此功能僅適用 Android 裝置'**
  String get batteryAndroidOnly;

  /// No description provided for @batteryIntroTitle.
  ///
  /// In zh, this message translates to:
  /// **'重要！Mesh 網路需要在後台持續運行'**
  String get batteryIntroTitle;

  /// No description provided for @batteryIntroAppName.
  ///
  /// In zh, this message translates to:
  /// **'烽傳'**
  String get batteryIntroAppName;

  /// No description provided for @batteryIntroConsequence1.
  ///
  /// In zh, this message translates to:
  /// **'無法接收附近求救訊號'**
  String get batteryIntroConsequence1;

  /// No description provided for @batteryIntroConsequence2.
  ///
  /// In zh, this message translates to:
  /// **'無法擔任 Data Mule 中繼節點'**
  String get batteryIntroConsequence2;

  /// No description provided for @batteryIntroConsequence3.
  ///
  /// In zh, this message translates to:
  /// **'無法自動同步物資媒合資訊'**
  String get batteryIntroConsequence3;

  /// No description provided for @batteryIntroGuide.
  ///
  /// In zh, this message translates to:
  /// **'接下來會引導您完成 1-2 步設定，確保 Mesh 網路持續運作。'**
  String get batteryIntroGuide;

  /// No description provided for @batteryStep1Label.
  ///
  /// In zh, this message translates to:
  /// **'步驟 1/2'**
  String get batteryStep1Label;

  /// No description provided for @batteryStep1Title.
  ///
  /// In zh, this message translates to:
  /// **'系統電池優化豁免'**
  String get batteryStep1Title;

  /// No description provided for @batteryStep1Button.
  ///
  /// In zh, this message translates to:
  /// **'開啟電池優化豁免'**
  String get batteryStep1Button;

  /// No description provided for @batteryStep1Done.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get batteryStep1Done;

  /// No description provided for @batteryStep1Success.
  ///
  /// In zh, this message translates to:
  /// **'已成功豁免電池優化'**
  String get batteryStep1Success;

  /// No description provided for @batteryLaterButton.
  ///
  /// In zh, this message translates to:
  /// **'稍後再說'**
  String get batteryLaterButton;

  /// No description provided for @batteryStartButton.
  ///
  /// In zh, this message translates to:
  /// **'開始設定'**
  String get batteryStartButton;

  /// No description provided for @batterySkipButton.
  ///
  /// In zh, this message translates to:
  /// **'跳過此步'**
  String get batterySkipButton;

  /// No description provided for @batteryNextButton.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get batteryNextButton;

  /// No description provided for @batteryFinishButton.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get batteryFinishButton;

  /// No description provided for @batteryDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'設定完成！'**
  String get batteryDoneTitle;

  /// No description provided for @batteryDoneContent.
  ///
  /// In zh, this message translates to:
  /// **'背景執行設定完成！'**
  String get batteryDoneContent;

  /// No description provided for @batteryDoneNote.
  ///
  /// In zh, this message translates to:
  /// **'前景服務通知會在 Mesh 守護啟動後出現'**
  String get batteryDoneNote;

  /// No description provided for @batteryGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景執行設定'**
  String get batteryGuideTitle;

  /// No description provided for @batteryIntroBody.
  ///
  /// In zh, this message translates to:
  /// **'烽傳 依賴藍牙 Mesh 在背景持續廣播與中繼救援資訊。\n\n若 Android 系統將 App 殺掉，您的裝置將：'**
  String get batteryIntroBody;

  /// No description provided for @batteryStep1Desc.
  ///
  /// In zh, this message translates to:
  /// **'點擊下方按鈕，系統會彈出確認視窗。\n請選擇「允許」，讓 烽傳 不受 Doze 省電限制。'**
  String get batteryStep1Desc;

  /// No description provided for @batteryStep2Label.
  ///
  /// In zh, this message translates to:
  /// **'步驟 2/2'**
  String get batteryStep2Label;

  /// No description provided for @batteryStep2Title.
  ///
  /// In zh, this message translates to:
  /// **'{manufacturer} 背景執行設定'**
  String batteryStep2Title(String manufacturer);

  /// No description provided for @batteryGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往設定'**
  String get batteryGoSettings;

  /// No description provided for @batteryOpenedSettings.
  ///
  /// In zh, this message translates to:
  /// **'已開啟設定'**
  String get batteryOpenedSettings;

  /// No description provided for @batteryReturnNote.
  ///
  /// In zh, this message translates to:
  /// **'請在設定頁面完成操作後返回此畫面'**
  String get batteryReturnNote;

  /// No description provided for @batteryManufacturerXiaomi.
  ///
  /// In zh, this message translates to:
  /// **'小米 / Redmi'**
  String get batteryManufacturerXiaomi;

  /// No description provided for @batteryManufacturerHuawei.
  ///
  /// In zh, this message translates to:
  /// **'華為'**
  String get batteryManufacturerHuawei;

  /// No description provided for @batteryManufacturerHonor.
  ///
  /// In zh, this message translates to:
  /// **'榮耀'**
  String get batteryManufacturerHonor;

  /// No description provided for @batteryManufacturerOppo.
  ///
  /// In zh, this message translates to:
  /// **'OPPO'**
  String get batteryManufacturerOppo;

  /// No description provided for @batteryManufacturerRealme.
  ///
  /// In zh, this message translates to:
  /// **'realme'**
  String get batteryManufacturerRealme;

  /// No description provided for @batteryManufacturerVivo.
  ///
  /// In zh, this message translates to:
  /// **'vivo'**
  String get batteryManufacturerVivo;

  /// No description provided for @batteryManufacturerSamsung.
  ///
  /// In zh, this message translates to:
  /// **'三星 Samsung'**
  String get batteryManufacturerSamsung;

  /// No description provided for @batteryManufacturerAsus.
  ///
  /// In zh, this message translates to:
  /// **'華碩 ASUS'**
  String get batteryManufacturerAsus;

  /// No description provided for @batteryInstructionXiaomi.
  ///
  /// In zh, this message translates to:
  /// **'請在「自啟動管理」中找到 烽傳 → 開啟自啟動\n另外在「省電策略」→ 選擇「無限制」'**
  String get batteryInstructionXiaomi;

  /// No description provided for @batteryInstructionHuawei.
  ///
  /// In zh, this message translates to:
  /// **'請在「啟動管理」中找到 烽傳\n→ 關閉「自動管理」→ 手動開啟所有開關\n另在「鎖屏清理」中不要清理本 App'**
  String get batteryInstructionHuawei;

  /// No description provided for @batteryInstructionHonor.
  ///
  /// In zh, this message translates to:
  /// **'請在「啟動管理」中找到 烽傳\n→ 關閉「自動管理」→ 手動開啟所有開關'**
  String get batteryInstructionHonor;

  /// No description provided for @batteryInstructionOppo.
  ///
  /// In zh, this message translates to:
  /// **'請在「自啟動管理」中允許 烽傳 自啟動\n另在「省電」→「App 電池管理」→ 選擇「不優化」'**
  String get batteryInstructionOppo;

  /// No description provided for @batteryInstructionRealme.
  ///
  /// In zh, this message translates to:
  /// **'請在「自啟動管理」中允許 烽傳 自啟動\n另在「省電」→「App 電池管理」→ 選擇「不優化」'**
  String get batteryInstructionRealme;

  /// No description provided for @batteryInstructionVivo.
  ///
  /// In zh, this message translates to:
  /// **'請在「後臺管理」中允許 烽傳 高耗電運行\n另在「自啟動」中開啟本 App'**
  String get batteryInstructionVivo;

  /// No description provided for @batteryInstructionSamsung.
  ///
  /// In zh, this message translates to:
  /// **'請在「電池」→「背景使用限制」\n→ 將 烽傳 從「受限 App」清單移除\n或加入「永不進入休眠」清單'**
  String get batteryInstructionSamsung;

  /// No description provided for @batteryInstructionAsus.
  ///
  /// In zh, this message translates to:
  /// **'請在「自動啟動管理員」中允許 烽傳\n另在「電池」中選擇「不受限」'**
  String get batteryInstructionAsus;

  /// No description provided for @batteryInstructionDefault.
  ///
  /// In zh, this message translates to:
  /// **'請到手機的「設定」→「電池」→「背景執行管理」中\n允許 烽傳 在背景運行。'**
  String get batteryInstructionDefault;

  /// No description provided for @batteryDoneBody.
  ///
  /// In zh, this message translates to:
  /// **'烽傳 現在可以在背景持續運行 Mesh 網路，\n即使螢幕關閉也能接收並中繼救援資訊。'**
  String get batteryDoneBody;

  /// No description provided for @locationGpsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'GPS 服務未開啟，請前往系統設定啟用定位功能'**
  String get locationGpsDisabled;

  /// No description provided for @locationGpsDeniedForever.
  ///
  /// In zh, this message translates to:
  /// **'GPS 權限已被永久拒絕，請前往系統設定 → 應用程式 → 授予定位權限'**
  String get locationGpsDeniedForever;

  /// No description provided for @locationGpsDenied.
  ///
  /// In zh, this message translates to:
  /// **'請授予 GPS 定位權限以取得更準確的媒合結果'**
  String get locationGpsDenied;

  /// No description provided for @locationGpsTimeout.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位逾時，請確認已開啟定位功能或移到開闊處'**
  String get locationGpsTimeout;

  /// No description provided for @locationGpsFail.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位失敗: {error}'**
  String locationGpsFail(String error);

  /// No description provided for @locationInitFail.
  ///
  /// In zh, this message translates to:
  /// **'定位服務初始化失敗: {error}'**
  String locationInitFail(String error);

  /// No description provided for @locationDirectionN.
  ///
  /// In zh, this message translates to:
  /// **'北方'**
  String get locationDirectionN;

  /// No description provided for @locationDirectionNE.
  ///
  /// In zh, this message translates to:
  /// **'東北方'**
  String get locationDirectionNE;

  /// No description provided for @locationDirectionE.
  ///
  /// In zh, this message translates to:
  /// **'東方'**
  String get locationDirectionE;

  /// No description provided for @locationDirectionSE.
  ///
  /// In zh, this message translates to:
  /// **'東南方'**
  String get locationDirectionSE;

  /// No description provided for @locationDirectionS.
  ///
  /// In zh, this message translates to:
  /// **'南方'**
  String get locationDirectionS;

  /// No description provided for @locationDirectionSW.
  ///
  /// In zh, this message translates to:
  /// **'西南方'**
  String get locationDirectionSW;

  /// No description provided for @locationDirectionW.
  ///
  /// In zh, this message translates to:
  /// **'西方'**
  String get locationDirectionW;

  /// No description provided for @locationDirectionNW.
  ///
  /// In zh, this message translates to:
  /// **'西北方'**
  String get locationDirectionNW;

  /// No description provided for @supplyCategory_WATER.
  ///
  /// In zh, this message translates to:
  /// **'飲用水'**
  String get supplyCategory_WATER;

  /// No description provided for @supplyCategory_FOOD.
  ///
  /// In zh, this message translates to:
  /// **'食物'**
  String get supplyCategory_FOOD;

  /// No description provided for @supplyCategory_MEDICAL.
  ///
  /// In zh, this message translates to:
  /// **'藥品/急救'**
  String get supplyCategory_MEDICAL;

  /// No description provided for @supplyCategory_HYGIENE.
  ///
  /// In zh, this message translates to:
  /// **'衛生/生理'**
  String get supplyCategory_HYGIENE;

  /// No description provided for @supplyCategory_PROTECTION.
  ///
  /// In zh, this message translates to:
  /// **'防護裝備'**
  String get supplyCategory_PROTECTION;

  /// No description provided for @supplyCategory_SHELTER.
  ///
  /// In zh, this message translates to:
  /// **'住所/避難'**
  String get supplyCategory_SHELTER;

  /// No description provided for @supplyCategory_TOOL.
  ///
  /// In zh, this message translates to:
  /// **'工具/設備'**
  String get supplyCategory_TOOL;

  /// No description provided for @supplyCategory_PETS.
  ///
  /// In zh, this message translates to:
  /// **'寵物用品'**
  String get supplyCategory_PETS;

  /// No description provided for @supplyCategory_SKILL.
  ///
  /// In zh, this message translates to:
  /// **'技能服務'**
  String get supplyCategory_SKILL;

  /// No description provided for @supplySubCategory_WATER_BOTTLE.
  ///
  /// In zh, this message translates to:
  /// **'瓶裝水'**
  String get supplySubCategory_WATER_BOTTLE;

  /// No description provided for @supplySubCategory_WATER_PURIFY.
  ///
  /// In zh, this message translates to:
  /// **'淨水設備'**
  String get supplySubCategory_WATER_PURIFY;

  /// No description provided for @supplySubCategory_WATER_CONTAINER.
  ///
  /// In zh, this message translates to:
  /// **'儲水容器'**
  String get supplySubCategory_WATER_CONTAINER;

  /// No description provided for @supplySubCategory_FOOD_READY.
  ///
  /// In zh, this message translates to:
  /// **'即食食品'**
  String get supplySubCategory_FOOD_READY;

  /// No description provided for @supplySubCategory_FOOD_STAPLE.
  ///
  /// In zh, this message translates to:
  /// **'主食/乾糧'**
  String get supplySubCategory_FOOD_STAPLE;

  /// No description provided for @supplySubCategory_FOOD_BABY.
  ///
  /// In zh, this message translates to:
  /// **'嬰幼兒食品'**
  String get supplySubCategory_FOOD_BABY;

  /// No description provided for @supplySubCategory_FOOD_SUPPLEMENT.
  ///
  /// In zh, this message translates to:
  /// **'營養補充'**
  String get supplySubCategory_FOOD_SUPPLEMENT;

  /// No description provided for @supplySubCategory_FOOD_COOKING.
  ///
  /// In zh, this message translates to:
  /// **'炊事用具'**
  String get supplySubCategory_FOOD_COOKING;

  /// No description provided for @supplySubCategory_MED_PAIN.
  ///
  /// In zh, this message translates to:
  /// **'止痛退燒'**
  String get supplySubCategory_MED_PAIN;

  /// No description provided for @supplySubCategory_MED_WOUND.
  ///
  /// In zh, this message translates to:
  /// **'傷口處理'**
  String get supplySubCategory_MED_WOUND;

  /// No description provided for @supplySubCategory_MED_CHRONIC.
  ///
  /// In zh, this message translates to:
  /// **'慢性病藥'**
  String get supplySubCategory_MED_CHRONIC;

  /// No description provided for @supplySubCategory_MED_RESPIRATORY.
  ///
  /// In zh, this message translates to:
  /// **'呼吸道'**
  String get supplySubCategory_MED_RESPIRATORY;

  /// No description provided for @supplySubCategory_MED_GI.
  ///
  /// In zh, this message translates to:
  /// **'腸胃道'**
  String get supplySubCategory_MED_GI;

  /// No description provided for @supplySubCategory_MED_FIRSTAID_KIT.
  ///
  /// In zh, this message translates to:
  /// **'急救包/器材'**
  String get supplySubCategory_MED_FIRSTAID_KIT;

  /// No description provided for @supplySubCategory_HYG_FEMININE.
  ///
  /// In zh, this message translates to:
  /// **'女性生理'**
  String get supplySubCategory_HYG_FEMININE;

  /// No description provided for @supplySubCategory_HYG_BABY.
  ///
  /// In zh, this message translates to:
  /// **'嬰幼兒衛生'**
  String get supplySubCategory_HYG_BABY;

  /// No description provided for @supplySubCategory_HYG_PERSONAL.
  ///
  /// In zh, this message translates to:
  /// **'個人清潔'**
  String get supplySubCategory_HYG_PERSONAL;

  /// No description provided for @supplySubCategory_HYG_SANITATION.
  ///
  /// In zh, this message translates to:
  /// **'環境衛生'**
  String get supplySubCategory_HYG_SANITATION;

  /// No description provided for @supplySubCategory_PROT_RESPIRATORY.
  ///
  /// In zh, this message translates to:
  /// **'呼吸防護'**
  String get supplySubCategory_PROT_RESPIRATORY;

  /// No description provided for @supplySubCategory_PROT_BODY.
  ///
  /// In zh, this message translates to:
  /// **'身體防護'**
  String get supplySubCategory_PROT_BODY;

  /// No description provided for @supplySubCategory_PROT_LIGHT.
  ///
  /// In zh, this message translates to:
  /// **'照明/能源'**
  String get supplySubCategory_PROT_LIGHT;

  /// No description provided for @supplySubCategory_SHELTER_TEMP.
  ///
  /// In zh, this message translates to:
  /// **'臨時避所'**
  String get supplySubCategory_SHELTER_TEMP;

  /// No description provided for @supplySubCategory_SHELTER_BEDDING.
  ///
  /// In zh, this message translates to:
  /// **'寢具保暖'**
  String get supplySubCategory_SHELTER_BEDDING;

  /// No description provided for @supplySubCategory_SHELTER_CLOTHING.
  ///
  /// In zh, this message translates to:
  /// **'衣物'**
  String get supplySubCategory_SHELTER_CLOTHING;

  /// No description provided for @supplySubCategory_TOOL_COMM.
  ///
  /// In zh, this message translates to:
  /// **'通訊工具'**
  String get supplySubCategory_TOOL_COMM;

  /// No description provided for @supplySubCategory_TOOL_RESCUE.
  ///
  /// In zh, this message translates to:
  /// **'救難工具'**
  String get supplySubCategory_TOOL_RESCUE;

  /// No description provided for @supplySubCategory_TOOL_POWER.
  ///
  /// In zh, this message translates to:
  /// **'電力設備'**
  String get supplySubCategory_TOOL_POWER;

  /// No description provided for @supplySubCategory_TOOL_TRANSPORT.
  ///
  /// In zh, this message translates to:
  /// **'搬運工具'**
  String get supplySubCategory_TOOL_TRANSPORT;

  /// No description provided for @supplySubCategory_PET_FOOD.
  ///
  /// In zh, this message translates to:
  /// **'寵物食品'**
  String get supplySubCategory_PET_FOOD;

  /// No description provided for @supplySubCategory_PET_CARE.
  ///
  /// In zh, this message translates to:
  /// **'安置與照護'**
  String get supplySubCategory_PET_CARE;

  /// No description provided for @supplySubCategory_SKILL_MEDICAL.
  ///
  /// In zh, this message translates to:
  /// **'醫療'**
  String get supplySubCategory_SKILL_MEDICAL;

  /// No description provided for @supplySubCategory_SKILL_RESCUE.
  ///
  /// In zh, this message translates to:
  /// **'搜救'**
  String get supplySubCategory_SKILL_RESCUE;

  /// No description provided for @supplySubCategory_SKILL_LANG.
  ///
  /// In zh, this message translates to:
  /// **'翻譯/語言'**
  String get supplySubCategory_SKILL_LANG;

  /// No description provided for @supplySubCategory_SKILL_PSYCH.
  ///
  /// In zh, this message translates to:
  /// **'心理輔導'**
  String get supplySubCategory_SKILL_PSYCH;

  /// No description provided for @supplySubCategory_SKILL_CARE.
  ///
  /// In zh, this message translates to:
  /// **'照護服務'**
  String get supplySubCategory_SKILL_CARE;

  /// No description provided for @supplySubCategory_SKILL_TECH.
  ///
  /// In zh, this message translates to:
  /// **'技術'**
  String get supplySubCategory_SKILL_TECH;

  /// No description provided for @supplySubCategory_SKILL_LOGISTICS.
  ///
  /// In zh, this message translates to:
  /// **'後勤/駕駛'**
  String get supplySubCategory_SKILL_LOGISTICS;

  /// No description provided for @profileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'身分 · 設定 · 醫療資訊'**
  String get profileSubtitle;

  /// No description provided for @profileQuickActionMedicalCardCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立醫療卡'**
  String get profileQuickActionMedicalCardCreate;

  /// No description provided for @profileQuickActionMedicalCard.
  ///
  /// In zh, this message translates to:
  /// **'醫療卡'**
  String get profileQuickActionMedicalCard;

  /// No description provided for @profileSectionMesh.
  ///
  /// In zh, this message translates to:
  /// **'Mesh 狀態'**
  String get profileSectionMesh;

  /// No description provided for @profileSectionTrust.
  ///
  /// In zh, this message translates to:
  /// **'信任等級'**
  String get profileSectionTrust;

  /// No description provided for @profileSectionSettings.
  ///
  /// In zh, this message translates to:
  /// **'設定'**
  String get profileSectionSettings;

  /// No description provided for @profilePubKeyCopied.
  ///
  /// In zh, this message translates to:
  /// **'公鑰已複製'**
  String get profilePubKeyCopied;

  /// No description provided for @profileSettingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外觀'**
  String get profileSettingsAppearance;

  /// No description provided for @profileSettingsTextScale.
  ///
  /// In zh, this message translates to:
  /// **'字體大小'**
  String get profileSettingsTextScale;

  /// No description provided for @profileSettingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'語言'**
  String get profileSettingsLanguage;

  /// No description provided for @profileSettingsBattery.
  ///
  /// In zh, this message translates to:
  /// **'背景執行 / 電池優化'**
  String get profileSettingsBattery;

  /// No description provided for @profileSettingsPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隱私與資料'**
  String get profileSettingsPrivacy;

  /// No description provided for @profileThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get profileThemeDark;

  /// No description provided for @profileThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'淺色'**
  String get profileThemeLight;

  /// No description provided for @profileTextScaleStandard.
  ///
  /// In zh, this message translates to:
  /// **'標準'**
  String get profileTextScaleStandard;

  /// No description provided for @profileTextScaleLarge.
  ///
  /// In zh, this message translates to:
  /// **'大字'**
  String get profileTextScaleLarge;

  /// No description provided for @profileTextScaleXLarge.
  ///
  /// In zh, this message translates to:
  /// **'特大字'**
  String get profileTextScaleXLarge;

  /// No description provided for @profileTextScaleHuge.
  ///
  /// In zh, this message translates to:
  /// **'超大字'**
  String get profileTextScaleHuge;

  /// No description provided for @profileMeshBatteryLabel.
  ///
  /// In zh, this message translates to:
  /// **'裝置電量'**
  String get profileMeshBatteryLabel;

  /// No description provided for @profileMeshAdvancedLabel.
  ///
  /// In zh, this message translates to:
  /// **'進階控制'**
  String get profileMeshAdvancedLabel;

  /// No description provided for @profileFooterVersion.
  ///
  /// In zh, this message translates to:
  /// **'烽傳 v{version} · BUILD {build}'**
  String profileFooterVersion(String version, String build);

  /// No description provided for @profileFooterTagline.
  ///
  /// In zh, this message translates to:
  /// **'OFFLINE · MESH · PRIVATE'**
  String get profileFooterTagline;

  /// No description provided for @matchHeaderItemsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項社區資源'**
  String matchHeaderItemsSubtitle(int count);

  /// No description provided for @mapAttributionLabel.
  ///
  /// In zh, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttributionLabel;

  /// No description provided for @supplyItem_WATER_BOTTLE_500.
  ///
  /// In zh, this message translates to:
  /// **'瓶裝水 500ml'**
  String get supplyItem_WATER_BOTTLE_500;

  /// No description provided for @supplyItem_WATER_BOTTLE_1500.
  ///
  /// In zh, this message translates to:
  /// **'瓶裝水 1.5L'**
  String get supplyItem_WATER_BOTTLE_1500;

  /// No description provided for @supplyItem_WATER_BOTTLE_5000.
  ///
  /// In zh, this message translates to:
  /// **'桶裝水 5L+'**
  String get supplyItem_WATER_BOTTLE_5000;

  /// No description provided for @supplyItem_WATER_PURIFY_TABLET.
  ///
  /// In zh, this message translates to:
  /// **'淨水錠'**
  String get supplyItem_WATER_PURIFY_TABLET;

  /// No description provided for @supplyItem_WATER_PURIFY_STRAW.
  ///
  /// In zh, this message translates to:
  /// **'攜帶式濾水器'**
  String get supplyItem_WATER_PURIFY_STRAW;

  /// No description provided for @supplyItem_WATER_PURIFY_PUMP.
  ///
  /// In zh, this message translates to:
  /// **'手壓式淨水器'**
  String get supplyItem_WATER_PURIFY_PUMP;

  /// No description provided for @supplyItem_WATER_CONTAINER_FOLD.
  ///
  /// In zh, this message translates to:
  /// **'折疊水袋 (5-20L)'**
  String get supplyItem_WATER_CONTAINER_FOLD;

  /// No description provided for @supplyItem_WATER_CONTAINER_JERRY.
  ///
  /// In zh, this message translates to:
  /// **'硬殼儲水桶 (20L)'**
  String get supplyItem_WATER_CONTAINER_JERRY;

  /// No description provided for @supplyItem_FOOD_READY_CRACKER.
  ///
  /// In zh, this message translates to:
  /// **'蘇打餅乾/能量棒'**
  String get supplyItem_FOOD_READY_CRACKER;

  /// No description provided for @supplyItem_FOOD_READY_CAN.
  ///
  /// In zh, this message translates to:
  /// **'罐頭食品 (含肉/豆)'**
  String get supplyItem_FOOD_READY_CAN;

  /// No description provided for @supplyItem_FOOD_READY_RETORT.
  ///
  /// In zh, this message translates to:
  /// **'調理包 (加熱即食)'**
  String get supplyItem_FOOD_READY_RETORT;

  /// No description provided for @supplyItem_FOOD_READY_MRE.
  ///
  /// In zh, this message translates to:
  /// **'軍用/災備即食餐 (MRE)'**
  String get supplyItem_FOOD_READY_MRE;

  /// No description provided for @supplyItem_FOOD_STAPLE_RICE.
  ///
  /// In zh, this message translates to:
  /// **'白米/免洗米'**
  String get supplyItem_FOOD_STAPLE_RICE;

  /// No description provided for @supplyItem_FOOD_STAPLE_NOODLE.
  ///
  /// In zh, this message translates to:
  /// **'乾拌麵/泡麵'**
  String get supplyItem_FOOD_STAPLE_NOODLE;

  /// No description provided for @supplyItem_FOOD_STAPLE_OATS.
  ///
  /// In zh, this message translates to:
  /// **'麥片/穀粉'**
  String get supplyItem_FOOD_STAPLE_OATS;

  /// No description provided for @supplyItem_FOOD_BABY_FORMULA.
  ///
  /// In zh, this message translates to:
  /// **'嬰兒奶粉'**
  String get supplyItem_FOOD_BABY_FORMULA;

  /// No description provided for @supplyItem_FOOD_BABY_PUREE.
  ///
  /// In zh, this message translates to:
  /// **'寶寶副食品泥'**
  String get supplyItem_FOOD_BABY_PUREE;

  /// No description provided for @supplyItem_FOOD_BABY_BOTTLE.
  ///
  /// In zh, this message translates to:
  /// **'奶瓶/水杯 (清潔消毒用品)'**
  String get supplyItem_FOOD_BABY_BOTTLE;

  /// No description provided for @supplyItem_FOOD_SUPP_ELECTROLYTE.
  ///
  /// In zh, this message translates to:
  /// **'電解質沖泡粉/口服補液鹽'**
  String get supplyItem_FOOD_SUPP_ELECTROLYTE;

  /// No description provided for @supplyItem_FOOD_SUPP_VITAMIN.
  ///
  /// In zh, this message translates to:
  /// **'綜合維他命'**
  String get supplyItem_FOOD_SUPP_VITAMIN;

  /// No description provided for @supplyItem_FOOD_SUPP_PROTEIN.
  ///
  /// In zh, this message translates to:
  /// **'高蛋白飲品'**
  String get supplyItem_FOOD_SUPP_PROTEIN;

  /// No description provided for @supplyItem_FOOD_COOK_STOVE.
  ///
  /// In zh, this message translates to:
  /// **'攜帶型瓦斯爐/酒精爐'**
  String get supplyItem_FOOD_COOK_STOVE;

  /// No description provided for @supplyItem_FOOD_COOK_FUEL.
  ///
  /// In zh, this message translates to:
  /// **'卡式瓦斯罐/燃料'**
  String get supplyItem_FOOD_COOK_FUEL;

  /// No description provided for @supplyItem_FOOD_COOK_UTENSIL.
  ///
  /// In zh, this message translates to:
  /// **'免洗餐具 / 折疊鍋組'**
  String get supplyItem_FOOD_COOK_UTENSIL;

  /// No description provided for @supplyItem_MED_PAIN_ACETAMINOPHEN.
  ///
  /// In zh, this message translates to:
  /// **'普拿疼 (乙醯胺酚)'**
  String get supplyItem_MED_PAIN_ACETAMINOPHEN;

  /// No description provided for @supplyItem_MED_PAIN_IBUPROFEN.
  ///
  /// In zh, this message translates to:
  /// **'布洛芬 (Ibuprofen)'**
  String get supplyItem_MED_PAIN_IBUPROFEN;

  /// No description provided for @supplyItem_MED_PAIN_PATCH.
  ///
  /// In zh, this message translates to:
  /// **'痠痛貼布/藥膏'**
  String get supplyItem_MED_PAIN_PATCH;

  /// No description provided for @supplyItem_MED_WOUND_BANDAGE.
  ///
  /// In zh, this message translates to:
  /// **'紗布/彈性繃帶'**
  String get supplyItem_MED_WOUND_BANDAGE;

  /// No description provided for @supplyItem_MED_WOUND_GAUZE.
  ///
  /// In zh, this message translates to:
  /// **'無菌紗布墊 (4×4)'**
  String get supplyItem_MED_WOUND_GAUZE;

  /// No description provided for @supplyItem_MED_WOUND_ANTISEPTIC.
  ///
  /// In zh, this message translates to:
  /// **'碘酒/生理食鹽水'**
  String get supplyItem_MED_WOUND_ANTISEPTIC;

  /// No description provided for @supplyItem_MED_WOUND_TAPE.
  ///
  /// In zh, this message translates to:
  /// **'醫用膠帶/透氣膠帶'**
  String get supplyItem_MED_WOUND_TAPE;

  /// No description provided for @supplyItem_MED_WOUND_TOURNIQUET.
  ///
  /// In zh, this message translates to:
  /// **'止血帶 (CAT)'**
  String get supplyItem_MED_WOUND_TOURNIQUET;

  /// No description provided for @supplyItem_MED_CHRONIC_BP.
  ///
  /// In zh, this message translates to:
  /// **'降血壓藥 (依醫囑)'**
  String get supplyItem_MED_CHRONIC_BP;

  /// No description provided for @supplyItem_MED_CHRONIC_DIABETES.
  ///
  /// In zh, this message translates to:
  /// **'胰島素/降血糖藥'**
  String get supplyItem_MED_CHRONIC_DIABETES;

  /// No description provided for @supplyItem_MED_CHRONIC_HEART.
  ///
  /// In zh, this message translates to:
  /// **'心臟用藥 (硝化甘油等)'**
  String get supplyItem_MED_CHRONIC_HEART;

  /// No description provided for @supplyItem_MED_CHRONIC_EPILEPSY.
  ///
  /// In zh, this message translates to:
  /// **'抗癲癇藥'**
  String get supplyItem_MED_CHRONIC_EPILEPSY;

  /// No description provided for @supplyItem_MED_RESP_INHALER.
  ///
  /// In zh, this message translates to:
  /// **'氣喘吸入劑'**
  String get supplyItem_MED_RESP_INHALER;

  /// No description provided for @supplyItem_MED_RESP_MASK_O2.
  ///
  /// In zh, this message translates to:
  /// **'氧氣面罩/攜帶氧氣瓶'**
  String get supplyItem_MED_RESP_MASK_O2;

  /// No description provided for @supplyItem_MED_GI_ORS.
  ///
  /// In zh, this message translates to:
  /// **'口服補液鹽 (ORS)'**
  String get supplyItem_MED_GI_ORS;

  /// No description provided for @supplyItem_MED_GI_ANTACID.
  ///
  /// In zh, this message translates to:
  /// **'胃藥/制酸劑'**
  String get supplyItem_MED_GI_ANTACID;

  /// No description provided for @supplyItem_MED_GI_CHARCOAL.
  ///
  /// In zh, this message translates to:
  /// **'活性碳 (中毒急救)'**
  String get supplyItem_MED_GI_CHARCOAL;

  /// No description provided for @supplyItem_MED_KIT_BASIC.
  ///
  /// In zh, this message translates to:
  /// **'基礎急救包'**
  String get supplyItem_MED_KIT_BASIC;

  /// No description provided for @supplyItem_MED_KIT_SPLINT.
  ///
  /// In zh, this message translates to:
  /// **'固定夾板/三角巾'**
  String get supplyItem_MED_KIT_SPLINT;

  /// No description provided for @supplyItem_MED_KIT_AED.
  ///
  /// In zh, this message translates to:
  /// **'AED (自動體外心臟去顫器)'**
  String get supplyItem_MED_KIT_AED;

  /// No description provided for @supplyItem_HYG_FEM_PAD.
  ///
  /// In zh, this message translates to:
  /// **'衛生棉'**
  String get supplyItem_HYG_FEM_PAD;

  /// No description provided for @supplyItem_HYG_FEM_TAMPON.
  ///
  /// In zh, this message translates to:
  /// **'棉條'**
  String get supplyItem_HYG_FEM_TAMPON;

  /// No description provided for @supplyItem_HYG_FEM_CUP.
  ///
  /// In zh, this message translates to:
  /// **'月亮杯 (可重複使用)'**
  String get supplyItem_HYG_FEM_CUP;

  /// No description provided for @supplyItem_HYG_BABY_DIAPER.
  ///
  /// In zh, this message translates to:
  /// **'尿布 (S/M/L/XL)'**
  String get supplyItem_HYG_BABY_DIAPER;

  /// No description provided for @supplyItem_HYG_BABY_WIPE.
  ///
  /// In zh, this message translates to:
  /// **'濕紙巾 (厚型)'**
  String get supplyItem_HYG_BABY_WIPE;

  /// No description provided for @supplyItem_HYG_BABY_CREAM.
  ///
  /// In zh, this message translates to:
  /// **'屁屁膏/護膚膏'**
  String get supplyItem_HYG_BABY_CREAM;

  /// No description provided for @supplyItem_HYG_PERS_SOAP.
  ///
  /// In zh, this message translates to:
  /// **'肥皂/洗手乳'**
  String get supplyItem_HYG_PERS_SOAP;

  /// No description provided for @supplyItem_HYG_PERS_TOOTH.
  ///
  /// In zh, this message translates to:
  /// **'牙刷牙膏組'**
  String get supplyItem_HYG_PERS_TOOTH;

  /// No description provided for @supplyItem_HYG_PERS_TISSUE.
  ///
  /// In zh, this message translates to:
  /// **'衛生紙/面紙'**
  String get supplyItem_HYG_PERS_TISSUE;

  /// No description provided for @supplyItem_HYG_PERS_TOWEL.
  ///
  /// In zh, this message translates to:
  /// **'快乾毛巾'**
  String get supplyItem_HYG_PERS_TOWEL;

  /// No description provided for @supplyItem_HYG_SAN_BLEACH.
  ///
  /// In zh, this message translates to:
  /// **'漂白水 (環境消毒)'**
  String get supplyItem_HYG_SAN_BLEACH;

  /// No description provided for @supplyItem_HYG_SAN_TRASH.
  ///
  /// In zh, this message translates to:
  /// **'垃圾袋 (大/厚)'**
  String get supplyItem_HYG_SAN_TRASH;

  /// No description provided for @supplyItem_HYG_SAN_GLOVE.
  ///
  /// In zh, this message translates to:
  /// **'拋棄式手套'**
  String get supplyItem_HYG_SAN_GLOVE;

  /// No description provided for @supplyItem_HYG_SAN_BUCKET.
  ///
  /// In zh, this message translates to:
  /// **'摺疊水桶 (清潔用)'**
  String get supplyItem_HYG_SAN_BUCKET;

  /// No description provided for @supplyItem_PROT_RESP_N95.
  ///
  /// In zh, this message translates to:
  /// **'N95 口罩'**
  String get supplyItem_PROT_RESP_N95;

  /// No description provided for @supplyItem_PROT_RESP_SURGICAL.
  ///
  /// In zh, this message translates to:
  /// **'醫用口罩'**
  String get supplyItem_PROT_RESP_SURGICAL;

  /// No description provided for @supplyItem_PROT_RESP_GAS.
  ///
  /// In zh, this message translates to:
  /// **'防毒面具/濾罐'**
  String get supplyItem_PROT_RESP_GAS;

  /// No description provided for @supplyItem_PROT_BODY_GLOVES.
  ///
  /// In zh, this message translates to:
  /// **'工作手套 (防割/防滑)'**
  String get supplyItem_PROT_BODY_GLOVES;

  /// No description provided for @supplyItem_PROT_BODY_HELMET.
  ///
  /// In zh, this message translates to:
  /// **'安全帽/工程帽'**
  String get supplyItem_PROT_BODY_HELMET;

  /// No description provided for @supplyItem_PROT_BODY_BOOTS.
  ///
  /// In zh, this message translates to:
  /// **'安全雨鞋/工作鞋'**
  String get supplyItem_PROT_BODY_BOOTS;

  /// No description provided for @supplyItem_PROT_BODY_GOGGLES.
  ///
  /// In zh, this message translates to:
  /// **'護目鏡/防塵眼鏡'**
  String get supplyItem_PROT_BODY_GOGGLES;

  /// No description provided for @supplyItem_PROT_BODY_VEST.
  ///
  /// In zh, this message translates to:
  /// **'反光背心'**
  String get supplyItem_PROT_BODY_VEST;

  /// No description provided for @supplyItem_PROT_LIGHT_FLASHLIGHT.
  ///
  /// In zh, this message translates to:
  /// **'手電筒/頭燈'**
  String get supplyItem_PROT_LIGHT_FLASHLIGHT;

  /// No description provided for @supplyItem_PROT_LIGHT_LANTERN.
  ///
  /// In zh, this message translates to:
  /// **'營燈/LED 掛燈'**
  String get supplyItem_PROT_LIGHT_LANTERN;

  /// No description provided for @supplyItem_PROT_LIGHT_BATTERY.
  ///
  /// In zh, this message translates to:
  /// **'乾電池 (AA/AAA/D)'**
  String get supplyItem_PROT_LIGHT_BATTERY;

  /// No description provided for @supplyItem_PROT_LIGHT_CANDLE.
  ///
  /// In zh, this message translates to:
  /// **'蠟燭/防風打火機'**
  String get supplyItem_PROT_LIGHT_CANDLE;

  /// No description provided for @supplyItem_SHELTER_TEMP_TENT.
  ///
  /// In zh, this message translates to:
  /// **'帳篷/天幕'**
  String get supplyItem_SHELTER_TEMP_TENT;

  /// No description provided for @supplyItem_SHELTER_TEMP_TARP.
  ///
  /// In zh, this message translates to:
  /// **'防水帆布/地布'**
  String get supplyItem_SHELTER_TEMP_TARP;

  /// No description provided for @supplyItem_SHELTER_TEMP_ROPE.
  ///
  /// In zh, this message translates to:
  /// **'營繩/繫固帶'**
  String get supplyItem_SHELTER_TEMP_ROPE;

  /// No description provided for @supplyItem_SHELTER_BED_BAG.
  ///
  /// In zh, this message translates to:
  /// **'睡袋'**
  String get supplyItem_SHELTER_BED_BAG;

  /// No description provided for @supplyItem_SHELTER_BED_MAT.
  ///
  /// In zh, this message translates to:
  /// **'充氣睡墊/瑜珈墊'**
  String get supplyItem_SHELTER_BED_MAT;

  /// No description provided for @supplyItem_SHELTER_BED_BLANKET.
  ///
  /// In zh, this message translates to:
  /// **'毛毯/太空毯'**
  String get supplyItem_SHELTER_BED_BLANKET;

  /// No description provided for @supplyItem_SHELTER_CLOTH_RAIN.
  ///
  /// In zh, this message translates to:
  /// **'雨衣/防水外套'**
  String get supplyItem_SHELTER_CLOTH_RAIN;

  /// No description provided for @supplyItem_SHELTER_CLOTH_WARM.
  ///
  /// In zh, this message translates to:
  /// **'保暖內衣/刷毛外套'**
  String get supplyItem_SHELTER_CLOTH_WARM;

  /// No description provided for @supplyItem_SHELTER_CLOTH_CHANGE.
  ///
  /// In zh, this message translates to:
  /// **'換洗衣物套組'**
  String get supplyItem_SHELTER_CLOTH_CHANGE;

  /// No description provided for @supplyItem_TOOL_COMM_RADIO.
  ///
  /// In zh, this message translates to:
  /// **'對講機 (UHF/VHF)'**
  String get supplyItem_TOOL_COMM_RADIO;

  /// No description provided for @supplyItem_TOOL_COMM_CHARGER.
  ///
  /// In zh, this message translates to:
  /// **'手搖/太陽能充電器'**
  String get supplyItem_TOOL_COMM_CHARGER;

  /// No description provided for @supplyItem_TOOL_COMM_POWERBANK.
  ///
  /// In zh, this message translates to:
  /// **'行動電源 (10000mAh+)'**
  String get supplyItem_TOOL_COMM_POWERBANK;

  /// No description provided for @supplyItem_TOOL_COMM_WHISTLE.
  ///
  /// In zh, this message translates to:
  /// **'緊急哨子'**
  String get supplyItem_TOOL_COMM_WHISTLE;

  /// No description provided for @supplyItem_TOOL_RESCUE_CROWBAR.
  ///
  /// In zh, this message translates to:
  /// **'撬棒/破壞鉗'**
  String get supplyItem_TOOL_RESCUE_CROWBAR;

  /// No description provided for @supplyItem_TOOL_RESCUE_SHOVEL.
  ///
  /// In zh, this message translates to:
  /// **'折疊鏟'**
  String get supplyItem_TOOL_RESCUE_SHOVEL;

  /// No description provided for @supplyItem_TOOL_RESCUE_SAW.
  ///
  /// In zh, this message translates to:
  /// **'折疊手鋸'**
  String get supplyItem_TOOL_RESCUE_SAW;

  /// No description provided for @supplyItem_TOOL_RESCUE_MULTI.
  ///
  /// In zh, this message translates to:
  /// **'多功能工具鉗'**
  String get supplyItem_TOOL_RESCUE_MULTI;

  /// No description provided for @supplyItem_TOOL_POWER_GENERATOR.
  ///
  /// In zh, this message translates to:
  /// **'發電機'**
  String get supplyItem_TOOL_POWER_GENERATOR;

  /// No description provided for @supplyItem_TOOL_POWER_SOLAR.
  ///
  /// In zh, this message translates to:
  /// **'太陽能充電板'**
  String get supplyItem_TOOL_POWER_SOLAR;

  /// No description provided for @supplyItem_TOOL_POWER_INVERTER.
  ///
  /// In zh, this message translates to:
  /// **'逆變器 (12V→110V)'**
  String get supplyItem_TOOL_POWER_INVERTER;

  /// No description provided for @supplyItem_TOOL_POWER_EXT.
  ///
  /// In zh, this message translates to:
  /// **'延長線/電線捲'**
  String get supplyItem_TOOL_POWER_EXT;

  /// No description provided for @supplyItem_TOOL_TRANS_CART.
  ///
  /// In zh, this message translates to:
  /// **'折疊推車/手拉車'**
  String get supplyItem_TOOL_TRANS_CART;

  /// No description provided for @supplyItem_TOOL_TRANS_STRETCHER.
  ///
  /// In zh, this message translates to:
  /// **'簡易擔架'**
  String get supplyItem_TOOL_TRANS_STRETCHER;

  /// No description provided for @supplyItem_PET_FOOD_DOG_DRY.
  ///
  /// In zh, this message translates to:
  /// **'狗乾糧'**
  String get supplyItem_PET_FOOD_DOG_DRY;

  /// No description provided for @supplyItem_PET_FOOD_DOG_CAN.
  ///
  /// In zh, this message translates to:
  /// **'狗罐頭'**
  String get supplyItem_PET_FOOD_DOG_CAN;

  /// No description provided for @supplyItem_PET_FOOD_CAT_DRY.
  ///
  /// In zh, this message translates to:
  /// **'貓乾糧'**
  String get supplyItem_PET_FOOD_CAT_DRY;

  /// No description provided for @supplyItem_PET_FOOD_CAT_CAN.
  ///
  /// In zh, this message translates to:
  /// **'貓罐頭'**
  String get supplyItem_PET_FOOD_CAT_CAN;

  /// No description provided for @supplyItem_PET_FOOD_BOWL.
  ///
  /// In zh, this message translates to:
  /// **'寵物飲水/食碗 (可折疊)'**
  String get supplyItem_PET_FOOD_BOWL;

  /// No description provided for @supplyItem_PET_CARE_CRATE.
  ///
  /// In zh, this message translates to:
  /// **'外出籠/寵物提包'**
  String get supplyItem_PET_CARE_CRATE;

  /// No description provided for @supplyItem_PET_CARE_LEASH.
  ///
  /// In zh, this message translates to:
  /// **'牽繩/胸背帶'**
  String get supplyItem_PET_CARE_LEASH;

  /// No description provided for @supplyItem_PET_CARE_PAD.
  ///
  /// In zh, this message translates to:
  /// **'寵物尿布墊'**
  String get supplyItem_PET_CARE_PAD;

  /// No description provided for @supplyItem_PET_CARE_MED.
  ///
  /// In zh, this message translates to:
  /// **'寵物基礎藥品 (驅蟲/皮膚)'**
  String get supplyItem_PET_CARE_MED;

  /// No description provided for @supplyItem_PET_CARE_TAG.
  ///
  /// In zh, this message translates to:
  /// **'防走失吊牌/晶片貼紙'**
  String get supplyItem_PET_CARE_TAG;

  /// No description provided for @supplyItem_SKILL_MEDICAL_DOCTOR.
  ///
  /// In zh, this message translates to:
  /// **'醫師'**
  String get supplyItem_SKILL_MEDICAL_DOCTOR;

  /// No description provided for @supplyItem_SKILL_MEDICAL_NURSE.
  ///
  /// In zh, this message translates to:
  /// **'護理師'**
  String get supplyItem_SKILL_MEDICAL_NURSE;

  /// No description provided for @supplyItem_SKILL_MEDICAL_EMT.
  ///
  /// In zh, this message translates to:
  /// **'急救員 (EMT)'**
  String get supplyItem_SKILL_MEDICAL_EMT;

  /// No description provided for @supplyItem_SKILL_MEDICAL_FIRSTAID.
  ///
  /// In zh, this message translates to:
  /// **'急救證照持有者'**
  String get supplyItem_SKILL_MEDICAL_FIRSTAID;

  /// No description provided for @supplyItem_SKILL_MEDICAL_PHARMACIST.
  ///
  /// In zh, this message translates to:
  /// **'藥劑師'**
  String get supplyItem_SKILL_MEDICAL_PHARMACIST;

  /// No description provided for @supplyItem_SKILL_RESCUE_FIREFIGHTER.
  ///
  /// In zh, this message translates to:
  /// **'消防/搜救專業'**
  String get supplyItem_SKILL_RESCUE_FIREFIGHTER;

  /// No description provided for @supplyItem_SKILL_RESCUE_DIVER.
  ///
  /// In zh, this message translates to:
  /// **'潛水搜救'**
  String get supplyItem_SKILL_RESCUE_DIVER;

  /// No description provided for @supplyItem_SKILL_RESCUE_K9.
  ///
  /// In zh, this message translates to:
  /// **'搜救犬領犬員'**
  String get supplyItem_SKILL_RESCUE_K9;

  /// No description provided for @supplyItem_SKILL_RESCUE_MOUNTAIN.
  ///
  /// In zh, this message translates to:
  /// **'山域搜救/嚮導'**
  String get supplyItem_SKILL_RESCUE_MOUNTAIN;

  /// No description provided for @supplyItem_SKILL_LANG_EN.
  ///
  /// In zh, this message translates to:
  /// **'英語翻譯'**
  String get supplyItem_SKILL_LANG_EN;

  /// No description provided for @supplyItem_SKILL_LANG_JP.
  ///
  /// In zh, this message translates to:
  /// **'日語翻譯'**
  String get supplyItem_SKILL_LANG_JP;

  /// No description provided for @supplyItem_SKILL_LANG_SEA.
  ///
  /// In zh, this message translates to:
  /// **'東南亞語翻譯'**
  String get supplyItem_SKILL_LANG_SEA;

  /// No description provided for @supplyItem_SKILL_LANG_SIGN.
  ///
  /// In zh, this message translates to:
  /// **'手語翻譯'**
  String get supplyItem_SKILL_LANG_SIGN;

  /// No description provided for @supplyItem_SKILL_PSYCH_COUNSELOR.
  ///
  /// In zh, this message translates to:
  /// **'心理諮商師'**
  String get supplyItem_SKILL_PSYCH_COUNSELOR;

  /// No description provided for @supplyItem_SKILL_PSYCH_SOCIAL.
  ///
  /// In zh, this message translates to:
  /// **'社工人員'**
  String get supplyItem_SKILL_PSYCH_SOCIAL;

  /// No description provided for @supplyItem_SKILL_CARE_BABY.
  ///
  /// In zh, this message translates to:
  /// **'嬰幼兒托育'**
  String get supplyItem_SKILL_CARE_BABY;

  /// No description provided for @supplyItem_SKILL_CARE_ELDER.
  ///
  /// In zh, this message translates to:
  /// **'老人照護'**
  String get supplyItem_SKILL_CARE_ELDER;

  /// No description provided for @supplyItem_SKILL_CARE_DISABLED.
  ///
  /// In zh, this message translates to:
  /// **'行動不便者照護'**
  String get supplyItem_SKILL_CARE_DISABLED;

  /// No description provided for @supplyItem_SKILL_CARE_SPECIAL.
  ///
  /// In zh, this message translates to:
  /// **'特殊需求陪伴 (失智/身障)'**
  String get supplyItem_SKILL_CARE_SPECIAL;

  /// No description provided for @supplyItem_SKILL_TECH_ELECTRIC.
  ///
  /// In zh, this message translates to:
  /// **'電工/電力修復'**
  String get supplyItem_SKILL_TECH_ELECTRIC;

  /// No description provided for @supplyItem_SKILL_TECH_PLUMB.
  ///
  /// In zh, this message translates to:
  /// **'水管/給水修復'**
  String get supplyItem_SKILL_TECH_PLUMB;

  /// No description provided for @supplyItem_SKILL_TECH_STRUCT.
  ///
  /// In zh, this message translates to:
  /// **'結構安全評估'**
  String get supplyItem_SKILL_TECH_STRUCT;

  /// No description provided for @supplyItem_SKILL_TECH_COMM.
  ///
  /// In zh, this message translates to:
  /// **'通訊工程/網路架設'**
  String get supplyItem_SKILL_TECH_COMM;

  /// No description provided for @supplyItem_SKILL_TECH_LABOR.
  ///
  /// In zh, this message translates to:
  /// **'壯丁/勞力需求'**
  String get supplyItem_SKILL_TECH_LABOR;

  /// No description provided for @supplyItem_SKILL_LOG_TRUCK.
  ///
  /// In zh, this message translates to:
  /// **'大貨車駕駛'**
  String get supplyItem_SKILL_LOG_TRUCK;

  /// No description provided for @supplyItem_SKILL_LOG_4WD.
  ///
  /// In zh, this message translates to:
  /// **'四輪傳動車/越野駕駛'**
  String get supplyItem_SKILL_LOG_4WD;

  /// No description provided for @supplyItem_SKILL_LOG_MOTO.
  ///
  /// In zh, this message translates to:
  /// **'機車外送/快遞 (殘破道路)'**
  String get supplyItem_SKILL_LOG_MOTO;

  /// No description provided for @supplyItem_SKILL_LOG_FORKLIFT.
  ///
  /// In zh, this message translates to:
  /// **'堆高機操作'**
  String get supplyItem_SKILL_LOG_FORKLIFT;

  /// No description provided for @supplyItem_SKILL_LOG_HEAVYOP.
  ///
  /// In zh, this message translates to:
  /// **'重機具操作員 (怪手/吊車)'**
  String get supplyItem_SKILL_LOG_HEAVYOP;

  /// No description provided for @supplyItem_SKILL_LOG_MANAGE.
  ///
  /// In zh, this message translates to:
  /// **'物流管理/倉儲調度'**
  String get supplyItem_SKILL_LOG_MANAGE;

  /// No description provided for @itemConditionNew.
  ///
  /// In zh, this message translates to:
  /// **'全新未拆封'**
  String get itemConditionNew;

  /// No description provided for @itemConditionOpenedUnused.
  ///
  /// In zh, this message translates to:
  /// **'已拆封未使用'**
  String get itemConditionOpenedUnused;

  /// No description provided for @itemConditionUsedFunctional.
  ///
  /// In zh, this message translates to:
  /// **'二手堪用'**
  String get itemConditionUsedFunctional;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重試'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'載入中...'**
  String get commonLoading;

  /// No description provided for @commonQtyUnit.
  ///
  /// In zh, this message translates to:
  /// **'份'**
  String get commonQtyUnit;

  /// No description provided for @tierLabel1Standard.
  ///
  /// In zh, this message translates to:
  /// **'標準模式 (Tier 1)'**
  String get tierLabel1Standard;

  /// No description provided for @tierLabel1Force.
  ///
  /// In zh, this message translates to:
  /// **'全速模式 (Tier 1)'**
  String get tierLabel1Force;

  /// No description provided for @tierLabel2EcoRelay.
  ///
  /// In zh, this message translates to:
  /// **'省電中繼模式 (Tier 2)'**
  String get tierLabel2EcoRelay;

  /// No description provided for @tierLabel3UltraEco.
  ///
  /// In zh, this message translates to:
  /// **'極省電模式 (Tier 3)'**
  String get tierLabel3UltraEco;

  /// No description provided for @supplyCategory_MEDICINE.
  ///
  /// In zh, this message translates to:
  /// **'藥品/急救'**
  String get supplyCategory_MEDICINE;

  /// No description provided for @supplyCategory_PPE.
  ///
  /// In zh, this message translates to:
  /// **'防護裝備'**
  String get supplyCategory_PPE;

  /// No description provided for @supplySubCategory_WATER_TANK.
  ///
  /// In zh, this message translates to:
  /// **'儲水設備'**
  String get supplySubCategory_WATER_TANK;

  /// No description provided for @supplySubCategory_FOOD_DRY.
  ///
  /// In zh, this message translates to:
  /// **'乾糧'**
  String get supplySubCategory_FOOD_DRY;

  /// No description provided for @supplySubCategory_FOOD_SPECIAL.
  ///
  /// In zh, this message translates to:
  /// **'特殊飲食'**
  String get supplySubCategory_FOOD_SPECIAL;

  /// No description provided for @supplySubCategory_FOOD_DRINK.
  ///
  /// In zh, this message translates to:
  /// **'飲品/電解質'**
  String get supplySubCategory_FOOD_DRINK;

  /// No description provided for @supplySubCategory_MED_ANTIBIOTIC.
  ///
  /// In zh, this message translates to:
  /// **'抗生素/抗感染'**
  String get supplySubCategory_MED_ANTIBIOTIC;

  /// No description provided for @supplySubCategory_MED_KIT.
  ///
  /// In zh, this message translates to:
  /// **'急救包/器材'**
  String get supplySubCategory_MED_KIT;

  /// No description provided for @supplySubCategory_MED_OTHER.
  ///
  /// In zh, this message translates to:
  /// **'其他藥品'**
  String get supplySubCategory_MED_OTHER;

  /// No description provided for @supplySubCategory_HYG_DIAPER.
  ///
  /// In zh, this message translates to:
  /// **'尿布/排泄處理'**
  String get supplySubCategory_HYG_DIAPER;

  /// No description provided for @supplySubCategory_HYG_CLEAN.
  ///
  /// In zh, this message translates to:
  /// **'清潔衛生'**
  String get supplySubCategory_HYG_CLEAN;

  /// No description provided for @supplySubCategory_HYG_PEST.
  ///
  /// In zh, this message translates to:
  /// **'防蚊防蟲'**
  String get supplySubCategory_HYG_PEST;

  /// No description provided for @supplySubCategory_HYG_DISINFECT.
  ///
  /// In zh, this message translates to:
  /// **'環境消毒'**
  String get supplySubCategory_HYG_DISINFECT;

  /// No description provided for @supplySubCategory_PPE_HEAD.
  ///
  /// In zh, this message translates to:
  /// **'頭部防護'**
  String get supplySubCategory_PPE_HEAD;

  /// No description provided for @supplySubCategory_PPE_RESP.
  ///
  /// In zh, this message translates to:
  /// **'呼吸防護'**
  String get supplySubCategory_PPE_RESP;

  /// No description provided for @supplySubCategory_PPE_HAND.
  ///
  /// In zh, this message translates to:
  /// **'手部防護'**
  String get supplySubCategory_PPE_HAND;

  /// No description provided for @supplySubCategory_PPE_BODY.
  ///
  /// In zh, this message translates to:
  /// **'身體防護'**
  String get supplySubCategory_PPE_BODY;

  /// No description provided for @supplySubCategory_PPE_WEATHER.
  ///
  /// In zh, this message translates to:
  /// **'氣候防護/衣物'**
  String get supplySubCategory_PPE_WEATHER;

  /// No description provided for @supplySubCategory_SHELTER_TENT.
  ///
  /// In zh, this message translates to:
  /// **'帳篷/遮蔽'**
  String get supplySubCategory_SHELTER_TENT;

  /// No description provided for @supplySubCategory_SHELTER_SLEEP.
  ///
  /// In zh, this message translates to:
  /// **'保暖寢具'**
  String get supplySubCategory_SHELTER_SLEEP;

  /// No description provided for @supplySubCategory_SHELTER_THERMAL.
  ///
  /// In zh, this message translates to:
  /// **'緊急禦寒'**
  String get supplySubCategory_SHELTER_THERMAL;

  /// No description provided for @supplySubCategory_SHELTER_SPACE.
  ///
  /// In zh, this message translates to:
  /// **'空間提供'**
  String get supplySubCategory_SHELTER_SPACE;

  /// No description provided for @supplySubCategory_SHELTER_SUPPLY.
  ///
  /// In zh, this message translates to:
  /// **'收容所耗材'**
  String get supplySubCategory_SHELTER_SUPPLY;

  /// No description provided for @supplySubCategory_TOOL_LIGHT.
  ///
  /// In zh, this message translates to:
  /// **'照明'**
  String get supplySubCategory_TOOL_LIGHT;

  /// No description provided for @supplySubCategory_TOOL_BATTERY.
  ///
  /// In zh, this message translates to:
  /// **'乾電池 (圓筒型)'**
  String get supplySubCategory_TOOL_BATTERY;

  /// No description provided for @supplySubCategory_TOOL_BATTERY_COIN.
  ///
  /// In zh, this message translates to:
  /// **'鈕扣電池'**
  String get supplySubCategory_TOOL_BATTERY_COIN;

  /// No description provided for @supplySubCategory_TOOL_HAND.
  ///
  /// In zh, this message translates to:
  /// **'手工具'**
  String get supplySubCategory_TOOL_HAND;

  /// No description provided for @supplySubCategory_TOOL_REPAIR.
  ///
  /// In zh, this message translates to:
  /// **'修繕耗材'**
  String get supplySubCategory_TOOL_REPAIR;

  /// No description provided for @supplySubCategory_TOOL_HEAVY.
  ///
  /// In zh, this message translates to:
  /// **'重型機具'**
  String get supplySubCategory_TOOL_HEAVY;

  /// No description provided for @supplySubCategory_TOOL_DEMOLITION.
  ///
  /// In zh, this message translates to:
  /// **'破拆工具'**
  String get supplySubCategory_TOOL_DEMOLITION;

  /// No description provided for @supplySubCategory_TOOL_CLEANING.
  ///
  /// In zh, this message translates to:
  /// **'清理設備'**
  String get supplySubCategory_TOOL_CLEANING;

  /// No description provided for @supplySubCategory_TOOL_SIGNAL.
  ///
  /// In zh, this message translates to:
  /// **'求救信號'**
  String get supplySubCategory_TOOL_SIGNAL;

  /// No description provided for @supplyItem_WATER_BOTTLE_20L.
  ///
  /// In zh, this message translates to:
  /// **'20L 大桶 (家庭/收容所)'**
  String get supplyItem_WATER_BOTTLE_20L;

  /// No description provided for @supplyItem_WATER_PURIFY_FILTER.
  ///
  /// In zh, this message translates to:
  /// **'攜帶型濾水器'**
  String get supplyItem_WATER_PURIFY_FILTER;

  /// No description provided for @supplyItem_WATER_TANK_BARREL.
  ///
  /// In zh, this message translates to:
  /// **'儲水桶'**
  String get supplyItem_WATER_TANK_BARREL;

  /// No description provided for @supplyItem_WATER_TANK_BAG.
  ///
  /// In zh, this message translates to:
  /// **'可折疊水袋'**
  String get supplyItem_WATER_TANK_BAG;

  /// No description provided for @supplyItem_FOOD_READY_NOODLE.
  ///
  /// In zh, this message translates to:
  /// **'即食麵/泡麵'**
  String get supplyItem_FOOD_READY_NOODLE;

  /// No description provided for @supplyItem_FOOD_READY_BAR.
  ///
  /// In zh, this message translates to:
  /// **'能量棒/餅乾'**
  String get supplyItem_FOOD_READY_BAR;

  /// No description provided for @supplyItem_FOOD_DRY_RICE.
  ///
  /// In zh, this message translates to:
  /// **'乾飯/米'**
  String get supplyItem_FOOD_DRY_RICE;

  /// No description provided for @supplyItem_FOOD_DRY_BREAD.
  ///
  /// In zh, this message translates to:
  /// **'麵包/吐司'**
  String get supplyItem_FOOD_DRY_BREAD;

  /// No description provided for @supplyItem_FOOD_DRY_NUTS.
  ///
  /// In zh, this message translates to:
  /// **'堅果/果乾'**
  String get supplyItem_FOOD_DRY_NUTS;

  /// No description provided for @supplyItem_FOOD_SPECIAL_HALAL.
  ///
  /// In zh, this message translates to:
  /// **'清真食品'**
  String get supplyItem_FOOD_SPECIAL_HALAL;

  /// No description provided for @supplyItem_FOOD_SPECIAL_VEGAN.
  ///
  /// In zh, this message translates to:
  /// **'素食'**
  String get supplyItem_FOOD_SPECIAL_VEGAN;

  /// No description provided for @supplyItem_FOOD_SPECIAL_GLUTEN.
  ///
  /// In zh, this message translates to:
  /// **'無麩質食品'**
  String get supplyItem_FOOD_SPECIAL_GLUTEN;

  /// No description provided for @supplyItem_FOOD_SPECIAL_DIABETIC.
  ///
  /// In zh, this message translates to:
  /// **'低糖/糖尿病適用'**
  String get supplyItem_FOOD_SPECIAL_DIABETIC;

  /// No description provided for @supplyItem_FOOD_COOK_GAS.
  ///
  /// In zh, this message translates to:
  /// **'卡式瓦斯罐'**
  String get supplyItem_FOOD_COOK_GAS;

  /// No description provided for @supplyItem_FOOD_COOK_SOLID.
  ///
  /// In zh, this message translates to:
  /// **'固體酒精/酒精膏'**
  String get supplyItem_FOOD_COOK_SOLID;

  /// No description provided for @supplyItem_FOOD_COOK_LIGHTER.
  ///
  /// In zh, this message translates to:
  /// **'防風打火機/防水火柴'**
  String get supplyItem_FOOD_COOK_LIGHTER;

  /// No description provided for @supplyItem_FOOD_COOK_POT.
  ///
  /// In zh, this message translates to:
  /// **'野炊鍋組/鋼杯'**
  String get supplyItem_FOOD_COOK_POT;

  /// No description provided for @supplyItem_FOOD_DRINK_ELECTRO.
  ///
  /// In zh, this message translates to:
  /// **'運動飲料/電解質粉'**
  String get supplyItem_FOOD_DRINK_ELECTRO;

  /// No description provided for @supplyItem_FOOD_DRINK_COFFEE.
  ///
  /// In zh, this message translates to:
  /// **'即溶咖啡/茶包'**
  String get supplyItem_FOOD_DRINK_COFFEE;

  /// No description provided for @supplyItem_FOOD_DRINK_JUICE.
  ///
  /// In zh, this message translates to:
  /// **'保久乳/果汁'**
  String get supplyItem_FOOD_DRINK_JUICE;

  /// No description provided for @supplyItem_MED_PAIN_ASPIRIN.
  ///
  /// In zh, this message translates to:
  /// **'阿斯匹靈'**
  String get supplyItem_MED_PAIN_ASPIRIN;

  /// No description provided for @supplyItem_MED_ANTIBIOTIC_AMOX.
  ///
  /// In zh, this message translates to:
  /// **'阿莫西林'**
  String get supplyItem_MED_ANTIBIOTIC_AMOX;

  /// No description provided for @supplyItem_MED_ANTIBIOTIC_AZITHRO.
  ///
  /// In zh, this message translates to:
  /// **'日舒 (阿奇黴素)'**
  String get supplyItem_MED_ANTIBIOTIC_AZITHRO;

  /// No description provided for @supplyItem_MED_ANTIBIOTIC_OINTMENT.
  ///
  /// In zh, this message translates to:
  /// **'抗生素藥膏'**
  String get supplyItem_MED_ANTIBIOTIC_OINTMENT;

  /// No description provided for @supplyItem_MED_CHRONIC_INSULIN.
  ///
  /// In zh, this message translates to:
  /// **'胰島素'**
  String get supplyItem_MED_CHRONIC_INSULIN;

  /// No description provided for @supplyItem_MED_CHRONIC_ASTHMA.
  ///
  /// In zh, this message translates to:
  /// **'氣喘吸入劑'**
  String get supplyItem_MED_CHRONIC_ASTHMA;

  /// No description provided for @supplyItem_MED_CHRONIC_THYROID.
  ///
  /// In zh, this message translates to:
  /// **'甲狀腺藥物'**
  String get supplyItem_MED_CHRONIC_THYROID;

  /// No description provided for @supplyItem_MED_WOUND_DISINFECT.
  ///
  /// In zh, this message translates to:
  /// **'消毒液/碘酒'**
  String get supplyItem_MED_WOUND_DISINFECT;

  /// No description provided for @supplyItem_MED_WOUND_SUTURE.
  ///
  /// In zh, this message translates to:
  /// **'縫合膠帶'**
  String get supplyItem_MED_WOUND_SUTURE;

  /// No description provided for @supplyItem_MED_WOUND_SALINE.
  ///
  /// In zh, this message translates to:
  /// **'生理食鹽水 (沖洗傷口)'**
  String get supplyItem_MED_WOUND_SALINE;

  /// No description provided for @supplyItem_MED_WOUND_BURN.
  ///
  /// In zh, this message translates to:
  /// **'燒燙傷藥膏/敷料'**
  String get supplyItem_MED_WOUND_BURN;

  /// No description provided for @supplyItem_MED_WOUND_SPLINT.
  ///
  /// In zh, this message translates to:
  /// **'固定夾板 (骨折臨時固定)'**
  String get supplyItem_MED_WOUND_SPLINT;

  /// No description provided for @supplyItem_MED_KIT_TRAUMA.
  ///
  /// In zh, this message translates to:
  /// **'外傷急救包'**
  String get supplyItem_MED_KIT_TRAUMA;

  /// No description provided for @supplyItem_MED_KIT_STRETCHER.
  ///
  /// In zh, this message translates to:
  /// **'摺疊擔架/軟式擔架'**
  String get supplyItem_MED_KIT_STRETCHER;

  /// No description provided for @supplyItem_MED_OTHER_ANTIDIARRHEAL.
  ///
  /// In zh, this message translates to:
  /// **'止瀉藥'**
  String get supplyItem_MED_OTHER_ANTIDIARRHEAL;

  /// No description provided for @supplyItem_MED_OTHER_ANTIHISTAMINE.
  ///
  /// In zh, this message translates to:
  /// **'抗組織胺 (過敏)'**
  String get supplyItem_MED_OTHER_ANTIHISTAMINE;

  /// No description provided for @supplyItem_MED_OTHER_REHYDRATION.
  ///
  /// In zh, this message translates to:
  /// **'口服補液鹽'**
  String get supplyItem_MED_OTHER_REHYDRATION;

  /// No description provided for @supplyItem_MED_OTHER_EYEDROP.
  ///
  /// In zh, this message translates to:
  /// **'眼藥水/人工淚液'**
  String get supplyItem_MED_OTHER_EYEDROP;

  /// No description provided for @supplyItem_MED_OTHER_INSECT_BITE.
  ///
  /// In zh, this message translates to:
  /// **'蚊蟲叮咬藥膏'**
  String get supplyItem_MED_OTHER_INSECT_BITE;

  /// No description provided for @supplyItem_HYG_FEM_PAD_DAY.
  ///
  /// In zh, this message translates to:
  /// **'日用衛生棉'**
  String get supplyItem_HYG_FEM_PAD_DAY;

  /// No description provided for @supplyItem_HYG_FEM_PAD_NIGHT.
  ///
  /// In zh, this message translates to:
  /// **'夜用衛生棉'**
  String get supplyItem_HYG_FEM_PAD_NIGHT;

  /// No description provided for @supplyItem_HYG_FEM_LINER.
  ///
  /// In zh, this message translates to:
  /// **'護墊'**
  String get supplyItem_HYG_FEM_LINER;

  /// No description provided for @supplyItem_HYG_DIAPER_BABY_S.
  ///
  /// In zh, this message translates to:
  /// **'嬰兒尿布 S (3-6kg)'**
  String get supplyItem_HYG_DIAPER_BABY_S;

  /// No description provided for @supplyItem_HYG_DIAPER_BABY_M.
  ///
  /// In zh, this message translates to:
  /// **'嬰兒尿布 M (6-11kg)'**
  String get supplyItem_HYG_DIAPER_BABY_M;

  /// No description provided for @supplyItem_HYG_DIAPER_BABY_L.
  ///
  /// In zh, this message translates to:
  /// **'嬰兒尿布 L (9-14kg)'**
  String get supplyItem_HYG_DIAPER_BABY_L;

  /// No description provided for @supplyItem_HYG_DIAPER_BABY_XL.
  ///
  /// In zh, this message translates to:
  /// **'嬰兒尿布 XL (12-17kg)'**
  String get supplyItem_HYG_DIAPER_BABY_XL;

  /// No description provided for @supplyItem_HYG_DIAPER_ADULT.
  ///
  /// In zh, this message translates to:
  /// **'成人紙尿褲'**
  String get supplyItem_HYG_DIAPER_ADULT;

  /// No description provided for @supplyItem_HYG_DIAPER_PORTABLE_TOILET.
  ///
  /// In zh, this message translates to:
  /// **'攜帶式馬桶/行動廁所'**
  String get supplyItem_HYG_DIAPER_PORTABLE_TOILET;

  /// No description provided for @supplyItem_HYG_DIAPER_SOLIDIFIER.
  ///
  /// In zh, this message translates to:
  /// **'排泄物凝固劑'**
  String get supplyItem_HYG_DIAPER_SOLIDIFIER;

  /// No description provided for @supplyItem_HYG_DIAPER_TRASH_BAG.
  ///
  /// In zh, this message translates to:
  /// **'黑色大垃圾袋'**
  String get supplyItem_HYG_DIAPER_TRASH_BAG;

  /// No description provided for @supplyItem_HYG_CLEAN_WET_WIPE.
  ///
  /// In zh, this message translates to:
  /// **'抗菌濕紙巾'**
  String get supplyItem_HYG_CLEAN_WET_WIPE;

  /// No description provided for @supplyItem_HYG_CLEAN_HAND_GEL.
  ///
  /// In zh, this message translates to:
  /// **'乾洗手液'**
  String get supplyItem_HYG_CLEAN_HAND_GEL;

  /// No description provided for @supplyItem_HYG_CLEAN_SOAP.
  ///
  /// In zh, this message translates to:
  /// **'肥皂'**
  String get supplyItem_HYG_CLEAN_SOAP;

  /// No description provided for @supplyItem_HYG_CLEAN_TOOTH.
  ///
  /// In zh, this message translates to:
  /// **'牙刷牙膏組'**
  String get supplyItem_HYG_CLEAN_TOOTH;

  /// No description provided for @supplyItem_HYG_CLEAN_SHAMPOO.
  ///
  /// In zh, this message translates to:
  /// **'乾洗髮/洗髮乳'**
  String get supplyItem_HYG_CLEAN_SHAMPOO;

  /// No description provided for @supplyItem_HYG_CLEAN_TOWEL.
  ///
  /// In zh, this message translates to:
  /// **'速乾毛巾'**
  String get supplyItem_HYG_CLEAN_TOWEL;

  /// No description provided for @supplyItem_HYG_PEST_REPELLENT.
  ///
  /// In zh, this message translates to:
  /// **'防蚊液 (DEET/派卡瑞丁)'**
  String get supplyItem_HYG_PEST_REPELLENT;

  /// No description provided for @supplyItem_HYG_PEST_COIL.
  ///
  /// In zh, this message translates to:
  /// **'蚊香/電蚊香'**
  String get supplyItem_HYG_PEST_COIL;

  /// No description provided for @supplyItem_HYG_PEST_NET.
  ///
  /// In zh, this message translates to:
  /// **'蚊帳'**
  String get supplyItem_HYG_PEST_NET;

  /// No description provided for @supplyItem_HYG_PEST_ROACH.
  ///
  /// In zh, this message translates to:
  /// **'殺蟲劑 (蟑螂/蒼蠅)'**
  String get supplyItem_HYG_PEST_ROACH;

  /// No description provided for @supplyItem_HYG_DISINFECT_BLEACH.
  ///
  /// In zh, this message translates to:
  /// **'漂白水/次氯酸鈉'**
  String get supplyItem_HYG_DISINFECT_BLEACH;

  /// No description provided for @supplyItem_HYG_DISINFECT_ALCOHOL.
  ///
  /// In zh, this message translates to:
  /// **'75%酒精 (消毒用)'**
  String get supplyItem_HYG_DISINFECT_ALCOHOL;

  /// No description provided for @supplyItem_HYG_DISINFECT_SPRAY.
  ///
  /// In zh, this message translates to:
  /// **'環境消毒噴劑'**
  String get supplyItem_HYG_DISINFECT_SPRAY;

  /// No description provided for @supplyItem_PPE_HEAD_HELMET.
  ///
  /// In zh, this message translates to:
  /// **'工程安全帽'**
  String get supplyItem_PPE_HEAD_HELMET;

  /// No description provided for @supplyItem_PPE_HEAD_GOGGLES.
  ///
  /// In zh, this message translates to:
  /// **'護目鏡/防塵眼鏡'**
  String get supplyItem_PPE_HEAD_GOGGLES;

  /// No description provided for @supplyItem_PPE_RESP_N95.
  ///
  /// In zh, this message translates to:
  /// **'N95 口罩'**
  String get supplyItem_PPE_RESP_N95;

  /// No description provided for @supplyItem_PPE_RESP_DUST.
  ///
  /// In zh, this message translates to:
  /// **'一般防塵口罩'**
  String get supplyItem_PPE_RESP_DUST;

  /// No description provided for @supplyItem_PPE_RESP_GAS.
  ///
  /// In zh, this message translates to:
  /// **'防毒面罩 (化學/火災)'**
  String get supplyItem_PPE_RESP_GAS;

  /// No description provided for @supplyItem_PPE_HAND_CUT.
  ///
  /// In zh, this message translates to:
  /// **'防割工作手套'**
  String get supplyItem_PPE_HAND_CUT;

  /// No description provided for @supplyItem_PPE_HAND_RUBBER.
  ///
  /// In zh, this message translates to:
  /// **'橡膠手套 (清淤/消毒)'**
  String get supplyItem_PPE_HAND_RUBBER;

  /// No description provided for @supplyItem_PPE_HAND_LATEX.
  ///
  /// In zh, this message translates to:
  /// **'醫療乳膠手套'**
  String get supplyItem_PPE_HAND_LATEX;

  /// No description provided for @supplyItem_PPE_BODY_VEST.
  ///
  /// In zh, this message translates to:
  /// **'反光背心'**
  String get supplyItem_PPE_BODY_VEST;

  /// No description provided for @supplyItem_PPE_BODY_COVERALL.
  ///
  /// In zh, this message translates to:
  /// **'連身防護衣'**
  String get supplyItem_PPE_BODY_COVERALL;

  /// No description provided for @supplyItem_PPE_BODY_BOOTS.
  ///
  /// In zh, this message translates to:
  /// **'安全鞋/鋼頭雨靴'**
  String get supplyItem_PPE_BODY_BOOTS;

  /// No description provided for @supplyItem_PPE_WEATHER_PONCHO.
  ///
  /// In zh, this message translates to:
  /// **'輕便雨衣 (拋棄式)'**
  String get supplyItem_PPE_WEATHER_PONCHO;

  /// No description provided for @supplyItem_PPE_WEATHER_RAINSUIT.
  ///
  /// In zh, this message translates to:
  /// **'兩截式雨衣'**
  String get supplyItem_PPE_WEATHER_RAINSUIT;

  /// No description provided for @supplyItem_PPE_WEATHER_RAINBOOT.
  ///
  /// In zh, this message translates to:
  /// **'雨鞋/防水靴'**
  String get supplyItem_PPE_WEATHER_RAINBOOT;

  /// No description provided for @supplyItem_PPE_WEATHER_WARM.
  ///
  /// In zh, this message translates to:
  /// **'保暖衣物/發熱衣'**
  String get supplyItem_PPE_WEATHER_WARM;

  /// No description provided for @supplyItem_PPE_WEATHER_JACKET.
  ///
  /// In zh, this message translates to:
  /// **'防水外套/風衣'**
  String get supplyItem_PPE_WEATHER_JACKET;

  /// No description provided for @supplyItem_PPE_WEATHER_HAT.
  ///
  /// In zh, this message translates to:
  /// **'保暖帽/遮陽帽'**
  String get supplyItem_PPE_WEATHER_HAT;

  /// No description provided for @supplyItem_SHELTER_TENT_2P.
  ///
  /// In zh, this message translates to:
  /// **'2人帳篷'**
  String get supplyItem_SHELTER_TENT_2P;

  /// No description provided for @supplyItem_SHELTER_TENT_4P.
  ///
  /// In zh, this message translates to:
  /// **'4人帳篷'**
  String get supplyItem_SHELTER_TENT_4P;

  /// No description provided for @supplyItem_SHELTER_TENT_TARP.
  ///
  /// In zh, this message translates to:
  /// **'防水天幕'**
  String get supplyItem_SHELTER_TENT_TARP;

  /// No description provided for @supplyItem_SHELTER_TENT_PLASTIC.
  ///
  /// In zh, this message translates to:
  /// **'防水帆布/塑膠布'**
  String get supplyItem_SHELTER_TENT_PLASTIC;

  /// No description provided for @supplyItem_SHELTER_SLEEP_BAG.
  ///
  /// In zh, this message translates to:
  /// **'睡袋'**
  String get supplyItem_SHELTER_SLEEP_BAG;

  /// No description provided for @supplyItem_SHELTER_SLEEP_BLANKET.
  ///
  /// In zh, this message translates to:
  /// **'保暖毯'**
  String get supplyItem_SHELTER_SLEEP_BLANKET;

  /// No description provided for @supplyItem_SHELTER_SLEEP_MAT.
  ///
  /// In zh, this message translates to:
  /// **'睡墊'**
  String get supplyItem_SHELTER_SLEEP_MAT;

  /// No description provided for @supplyItem_SHELTER_SLEEP_AIR.
  ///
  /// In zh, this message translates to:
  /// **'充氣床墊'**
  String get supplyItem_SHELTER_SLEEP_AIR;

  /// No description provided for @supplyItem_SHELTER_THERM_SPACE.
  ///
  /// In zh, this message translates to:
  /// **'急救保溫毯 (Space Blanket)'**
  String get supplyItem_SHELTER_THERM_SPACE;

  /// No description provided for @supplyItem_SHELTER_THERM_HANDWARMER.
  ///
  /// In zh, this message translates to:
  /// **'暖暖包'**
  String get supplyItem_SHELTER_THERM_HANDWARMER;

  /// No description provided for @supplyItem_SHELTER_THERM_COAT.
  ///
  /// In zh, this message translates to:
  /// **'保暖外套/二手衣物'**
  String get supplyItem_SHELTER_THERM_COAT;

  /// No description provided for @supplyItem_SHELTER_SPACE_ROOM.
  ///
  /// In zh, this message translates to:
  /// **'可提供房間'**
  String get supplyItem_SHELTER_SPACE_ROOM;

  /// No description provided for @supplyItem_SHELTER_SPACE_GARAGE.
  ///
  /// In zh, this message translates to:
  /// **'可提供車庫/倉庫'**
  String get supplyItem_SHELTER_SPACE_GARAGE;

  /// No description provided for @supplyItem_SHELTER_SPACE_LAND.
  ///
  /// In zh, this message translates to:
  /// **'可提供空地 (搭帳篷/停車)'**
  String get supplyItem_SHELTER_SPACE_LAND;

  /// No description provided for @supplyItem_SHELTER_SUPPLY_TABLE.
  ///
  /// In zh, this message translates to:
  /// **'摺疊桌椅'**
  String get supplyItem_SHELTER_SUPPLY_TABLE;

  /// No description provided for @supplyItem_SHELTER_SUPPLY_PARTITION.
  ///
  /// In zh, this message translates to:
  /// **'隔間屏風/隔簾'**
  String get supplyItem_SHELTER_SUPPLY_PARTITION;

  /// No description provided for @supplyItem_SHELTER_SUPPLY_FAN.
  ///
  /// In zh, this message translates to:
  /// **'攜帶式風扇/USB風扇'**
  String get supplyItem_SHELTER_SUPPLY_FAN;

  /// No description provided for @supplyItem_TOOL_LIGHT_FLASH.
  ///
  /// In zh, this message translates to:
  /// **'手電筒'**
  String get supplyItem_TOOL_LIGHT_FLASH;

  /// No description provided for @supplyItem_TOOL_LIGHT_LANTERN.
  ///
  /// In zh, this message translates to:
  /// **'露營燈'**
  String get supplyItem_TOOL_LIGHT_LANTERN;

  /// No description provided for @supplyItem_TOOL_LIGHT_HEADLAMP.
  ///
  /// In zh, this message translates to:
  /// **'頭燈'**
  String get supplyItem_TOOL_LIGHT_HEADLAMP;

  /// No description provided for @supplyItem_TOOL_LIGHT_GLOWSTICK.
  ///
  /// In zh, this message translates to:
  /// **'螢光棒 (不需電力)'**
  String get supplyItem_TOOL_LIGHT_GLOWSTICK;

  /// No description provided for @supplyItem_TOOL_POWER_BANK.
  ///
  /// In zh, this message translates to:
  /// **'行動電源'**
  String get supplyItem_TOOL_POWER_BANK;

  /// No description provided for @supplyItem_TOOL_POWER_EXTENSION.
  ///
  /// In zh, this message translates to:
  /// **'延長線/排插'**
  String get supplyItem_TOOL_POWER_EXTENSION;

  /// No description provided for @supplyItem_TOOL_BAT_AA.
  ///
  /// In zh, this message translates to:
  /// **'3號電池 (AA 1.5V)'**
  String get supplyItem_TOOL_BAT_AA;

  /// No description provided for @supplyItem_TOOL_BAT_AAA.
  ///
  /// In zh, this message translates to:
  /// **'4號電池 (AAA 1.5V)'**
  String get supplyItem_TOOL_BAT_AAA;

  /// No description provided for @supplyItem_TOOL_BAT_C.
  ///
  /// In zh, this message translates to:
  /// **'2號電池 (C 1.5V)'**
  String get supplyItem_TOOL_BAT_C;

  /// No description provided for @supplyItem_TOOL_BAT_D.
  ///
  /// In zh, this message translates to:
  /// **'1號電池 (D 1.5V)'**
  String get supplyItem_TOOL_BAT_D;

  /// No description provided for @supplyItem_TOOL_BAT_9V.
  ///
  /// In zh, this message translates to:
  /// **'9V 方型電池'**
  String get supplyItem_TOOL_BAT_9V;

  /// No description provided for @supplyItem_TOOL_BAT_18650.
  ///
  /// In zh, this message translates to:
  /// **'18650 鋰電池 (3.7V)'**
  String get supplyItem_TOOL_BAT_18650;

  /// No description provided for @supplyItem_TOOL_COIN_CR2032.
  ///
  /// In zh, this message translates to:
  /// **'CR2032 (3V 最常見)'**
  String get supplyItem_TOOL_COIN_CR2032;

  /// No description provided for @supplyItem_TOOL_COIN_CR2025.
  ///
  /// In zh, this message translates to:
  /// **'CR2025 (3V)'**
  String get supplyItem_TOOL_COIN_CR2025;

  /// No description provided for @supplyItem_TOOL_COIN_CR2016.
  ///
  /// In zh, this message translates to:
  /// **'CR2016 (3V)'**
  String get supplyItem_TOOL_COIN_CR2016;

  /// No description provided for @supplyItem_TOOL_COIN_LR44.
  ///
  /// In zh, this message translates to:
  /// **'LR44 / AG13 (1.5V)'**
  String get supplyItem_TOOL_COIN_LR44;

  /// No description provided for @supplyItem_TOOL_COIN_SR626.
  ///
  /// In zh, this message translates to:
  /// **'SR626SW (手錶電池 1.55V)'**
  String get supplyItem_TOOL_COIN_SR626;

  /// No description provided for @supplyItem_TOOL_COMM_WALKIE.
  ///
  /// In zh, this message translates to:
  /// **'對講機'**
  String get supplyItem_TOOL_COMM_WALKIE;

  /// No description provided for @supplyItem_TOOL_COMM_SAT.
  ///
  /// In zh, this message translates to:
  /// **'衛星通訊器'**
  String get supplyItem_TOOL_COMM_SAT;

  /// No description provided for @supplyItem_TOOL_RESCUE_ROPE.
  ///
  /// In zh, this message translates to:
  /// **'繩索'**
  String get supplyItem_TOOL_RESCUE_ROPE;

  /// No description provided for @supplyItem_TOOL_RESCUE_AXE.
  ///
  /// In zh, this message translates to:
  /// **'斧頭/撬棒'**
  String get supplyItem_TOOL_RESCUE_AXE;

  /// No description provided for @supplyItem_TOOL_RESCUE_PARACORD.
  ///
  /// In zh, this message translates to:
  /// **'傘繩 (Paracord)'**
  String get supplyItem_TOOL_RESCUE_PARACORD;

  /// No description provided for @supplyItem_TOOL_RESCUE_SPRAYPAINT.
  ///
  /// In zh, this message translates to:
  /// **'噴漆 (建物搜救標記)'**
  String get supplyItem_TOOL_RESCUE_SPRAYPAINT;

  /// No description provided for @supplyItem_TOOL_HAND_SCREWDRIVER_PH.
  ///
  /// In zh, this message translates to:
  /// **'十字螺絲起子'**
  String get supplyItem_TOOL_HAND_SCREWDRIVER_PH;

  /// No description provided for @supplyItem_TOOL_HAND_SCREWDRIVER_FLAT.
  ///
  /// In zh, this message translates to:
  /// **'一字螺絲起子'**
  String get supplyItem_TOOL_HAND_SCREWDRIVER_FLAT;

  /// No description provided for @supplyItem_TOOL_HAND_WRENCH.
  ///
  /// In zh, this message translates to:
  /// **'活動扳手'**
  String get supplyItem_TOOL_HAND_WRENCH;

  /// No description provided for @supplyItem_TOOL_HAND_HAMMER.
  ///
  /// In zh, this message translates to:
  /// **'鐵鎚'**
  String get supplyItem_TOOL_HAND_HAMMER;

  /// No description provided for @supplyItem_TOOL_HAND_SHOVEL.
  ///
  /// In zh, this message translates to:
  /// **'鏟子/圓鍬'**
  String get supplyItem_TOOL_HAND_SHOVEL;

  /// No description provided for @supplyItem_TOOL_HAND_MULTITOOL.
  ///
  /// In zh, this message translates to:
  /// **'多功能工具鉗/瑞士刀'**
  String get supplyItem_TOOL_HAND_MULTITOOL;

  /// No description provided for @supplyItem_TOOL_HAND_PLIER.
  ///
  /// In zh, this message translates to:
  /// **'鉗子/老虎鉗'**
  String get supplyItem_TOOL_HAND_PLIER;

  /// No description provided for @supplyItem_TOOL_REPAIR_DUCT.
  ///
  /// In zh, this message translates to:
  /// **'大力膠帶 (Duct Tape)'**
  String get supplyItem_TOOL_REPAIR_DUCT;

  /// No description provided for @supplyItem_TOOL_REPAIR_ZIPTIE.
  ///
  /// In zh, this message translates to:
  /// **'束線帶/紮帶'**
  String get supplyItem_TOOL_REPAIR_ZIPTIE;

  /// No description provided for @supplyItem_TOOL_REPAIR_WIRE.
  ///
  /// In zh, this message translates to:
  /// **'鐵絲/綁線'**
  String get supplyItem_TOOL_REPAIR_WIRE;

  /// No description provided for @supplyItem_TOOL_REPAIR_SEALANT.
  ///
  /// In zh, this message translates to:
  /// **'防水膠/矽利康'**
  String get supplyItem_TOOL_REPAIR_SEALANT;

  /// No description provided for @supplyItem_TOOL_REPAIR_TARP_TAPE.
  ///
  /// In zh, this message translates to:
  /// **'帆布修補膠帶'**
  String get supplyItem_TOOL_REPAIR_TARP_TAPE;

  /// No description provided for @supplyItem_TOOL_TRANSPORT_CAR.
  ///
  /// In zh, this message translates to:
  /// **'車輛 (機動)'**
  String get supplyItem_TOOL_TRANSPORT_CAR;

  /// No description provided for @supplyItem_TOOL_TRANSPORT_BIKE.
  ///
  /// In zh, this message translates to:
  /// **'腳踏車'**
  String get supplyItem_TOOL_TRANSPORT_BIKE;

  /// No description provided for @supplyItem_TOOL_TRANSPORT_CART.
  ///
  /// In zh, this message translates to:
  /// **'推車'**
  String get supplyItem_TOOL_TRANSPORT_CART;

  /// No description provided for @supplyItem_TOOL_TRANSPORT_WHEELBARROW.
  ///
  /// In zh, this message translates to:
  /// **'手推車/獨輪車 (搬運瓦礫)'**
  String get supplyItem_TOOL_TRANSPORT_WHEELBARROW;

  /// No description provided for @supplyItem_TOOL_HEAVY_EXCAVATOR_MINI.
  ///
  /// In zh, this message translates to:
  /// **'微型怪手 (可入戶/狹窄巷弄)'**
  String get supplyItem_TOOL_HEAVY_EXCAVATOR_MINI;

  /// No description provided for @supplyItem_TOOL_HEAVY_EXCAVATOR_STD.
  ///
  /// In zh, this message translates to:
  /// **'標準怪手 (大型挖掘)'**
  String get supplyItem_TOOL_HEAVY_EXCAVATOR_STD;

  /// No description provided for @supplyItem_TOOL_HEAVY_BOBCAT_MINI.
  ///
  /// In zh, this message translates to:
  /// **'微型山貓 (可入戶/滑移裝載)'**
  String get supplyItem_TOOL_HEAVY_BOBCAT_MINI;

  /// No description provided for @supplyItem_TOOL_HEAVY_BOBCAT_STD.
  ///
  /// In zh, this message translates to:
  /// **'標準山貓 (滑移裝載機)'**
  String get supplyItem_TOOL_HEAVY_BOBCAT_STD;

  /// No description provided for @supplyItem_TOOL_HEAVY_CRANE.
  ///
  /// In zh, this message translates to:
  /// **'吊車/起重機'**
  String get supplyItem_TOOL_HEAVY_CRANE;

  /// No description provided for @supplyItem_TOOL_HEAVY_LOADER.
  ///
  /// In zh, this message translates to:
  /// **'鏟土機/推土機'**
  String get supplyItem_TOOL_HEAVY_LOADER;

  /// No description provided for @supplyItem_TOOL_DEMO_JACKHAMMER.
  ///
  /// In zh, this message translates to:
  /// **'電動/氣動打石機'**
  String get supplyItem_TOOL_DEMO_JACKHAMMER;

  /// No description provided for @supplyItem_TOOL_DEMO_CONCRETE_SAW.
  ///
  /// In zh, this message translates to:
  /// **'混凝土切割機/引擎砂輪機'**
  String get supplyItem_TOOL_DEMO_CONCRETE_SAW;

  /// No description provided for @supplyItem_TOOL_DEMO_HYDRAULIC.
  ///
  /// In zh, this message translates to:
  /// **'液壓破壞剪/撐開器 (重型救援)'**
  String get supplyItem_TOOL_DEMO_HYDRAULIC;

  /// No description provided for @supplyItem_TOOL_DEMO_CHAINSAW.
  ///
  /// In zh, this message translates to:
  /// **'動力鏈鋸 (伐木/路樹清理)'**
  String get supplyItem_TOOL_DEMO_CHAINSAW;

  /// No description provided for @supplyItem_TOOL_CLEANING_WASHER.
  ///
  /// In zh, this message translates to:
  /// **'高壓清洗機'**
  String get supplyItem_TOOL_CLEANING_WASHER;

  /// No description provided for @supplyItem_TOOL_CLEANING_PUMP_CLEAN.
  ///
  /// In zh, this message translates to:
  /// **'引擎抽水馬達 (清水泵)'**
  String get supplyItem_TOOL_CLEANING_PUMP_CLEAN;

  /// No description provided for @supplyItem_TOOL_CLEANING_PUMP_SLUDGE.
  ///
  /// In zh, this message translates to:
  /// **'污泥泵 (廢水/污泥專用)'**
  String get supplyItem_TOOL_CLEANING_PUMP_SLUDGE;

  /// No description provided for @supplyItem_TOOL_CLEANING_BLOWER.
  ///
  /// In zh, this message translates to:
  /// **'工業排風機 (地下室排煙/換氣)'**
  String get supplyItem_TOOL_CLEANING_BLOWER;

  /// No description provided for @supplyItem_TOOL_SIGNAL_FLARE.
  ///
  /// In zh, this message translates to:
  /// **'信號彈'**
  String get supplyItem_TOOL_SIGNAL_FLARE;

  /// No description provided for @supplyItem_TOOL_SIGNAL_MIRROR.
  ///
  /// In zh, this message translates to:
  /// **'信號鏡 (反光求救)'**
  String get supplyItem_TOOL_SIGNAL_MIRROR;

  /// No description provided for @supplyItem_TOOL_SIGNAL_FLAG.
  ///
  /// In zh, this message translates to:
  /// **'求救旗幟/布條'**
  String get supplyItem_TOOL_SIGNAL_FLAG;

  /// No description provided for @supplyItem_TOOL_SIGNAL_STROBE.
  ///
  /// In zh, this message translates to:
  /// **'閃光求救燈'**
  String get supplyItem_TOOL_SIGNAL_STROBE;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
