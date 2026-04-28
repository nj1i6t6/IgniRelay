// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'IgniRelay';

  @override
  String get mainStartupLoading => 'IgniRelay Starting...';

  @override
  String get mainBluetoothDialogTitle => 'Bluetooth Required';

  @override
  String get mainBluetoothDialogContent =>
      'IgniRelay uses Bluetooth to build an offline Mesh network\nfor transmitting SOS signals and supply matching.\n\nPlease enable Bluetooth to activate full functionality.';

  @override
  String get mainBluetoothDialogCancel => 'Later';

  @override
  String get mainBluetoothDialogConfirm => 'Enable Bluetooth';

  @override
  String mainBleFailSnack(String error) {
    return 'BLE Mesh failed to start: $error';
  }

  @override
  String get mainPermissionSnack =>
      'Bluetooth and location permissions are required for Mesh networking';

  @override
  String get tabMap => 'Offline Map';

  @override
  String get tabMeshGuard => 'Mesh Guard';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabMatch => 'Supply Match';

  @override
  String get tabProfile => 'Identity';

  @override
  String mainTabSosYellowSnack(String desc) {
    return 'Help signal received: $desc';
  }

  @override
  String get mainTabSosYellowAction => 'View Map';

  @override
  String get mainTabSosRedDialogTitle => 'Emergency SOS Signal!';

  @override
  String get mainTabSosRedDialogFallback =>
      'Someone nearby sent an emergency SOS';

  @override
  String get mainTabSosRedDialogContent =>
      'This signal was transmitted via Mesh network. The sender may be nearby.\nPlease check the map for location info.';

  @override
  String get mainTabSosRedDialogDismiss => 'Got it';

  @override
  String get mainTabSosRedDialogViewMap => 'View Map';

  @override
  String get mainTabMatchNotifProvider =>
      'Someone is willing to provide what you need! Tap to view.';

  @override
  String get mainTabMatchNotifRequester =>
      'Someone needs your supplies! Tap to view.';

  @override
  String get mainTabMatchNotifAction => 'View Match';

  @override
  String get onboardingBadgeL0 => 'Anonymous (L0)';

  @override
  String get onboardingBadgeL1 => 'Phone Verified (L1)';

  @override
  String get onboardingBadgeL2 => 'Community Endorsed (L2)';

  @override
  String get onboardingBadgeL3 => 'Gov. Verified (L3)';

  @override
  String onboardingDeviceId(String pubKeyHex) {
    return 'Device ID: $pubKeyHex...';
  }

  @override
  String get onboardingTitle =>
      'IgniRelay\nOffline Mesh Disaster Relief System';

  @override
  String get onboardingDesc =>
      'Build a self-organizing network via BLE Mesh even without internet.\nTransmit SOS and supply matching messages in real time.';

  @override
  String get onboardingNicknameHint => 'Set your nickname (optional)';

  @override
  String get onboardingUpgradeDialogTitle => 'Phone Verification (L1)';

  @override
  String get onboardingUpgradeDialogContent =>
      'Verify your phone number via SMS OTP\nto upgrade trust level to L1 (Bronze).\n\nMore features will be unlocked after verification.';

  @override
  String get onboardingUpgradeDialogConfirm => 'Confirm Upgrade';

  @override
  String get onboardingUpgradeSnack =>
      'Upgraded to L1 (Bronze) - Phone Verified';

  @override
  String get onboardingUpgradeButton => 'Upgrade to L1 (Phone Verification)';

  @override
  String get onboardingStartButton => 'Start Using IgniRelay';

  @override
  String get profileTitle => 'Identity & Trust';

  @override
  String get profileBadgeDescL0 =>
      'Auto-generated Ed25519 key, no network needed';

  @override
  String get profileBadgeDescL1 => 'Phone number linked, trust level increased';

  @override
  String get profileBadgeDescL2 => 'Endorsed by 3+ users';

  @override
  String get profileBadgeDescL3 => 'Verified via TW FidO government identity';

  @override
  String get profileAnonymous => 'Anonymous User';

  @override
  String get profileNicknameDialogTitle => 'Edit Nickname';

  @override
  String get profileNicknameDialogHint => 'Enter new nickname';

  @override
  String get profileNicknameDialogCancel => 'Cancel';

  @override
  String get profileNicknameDialogSave => 'Save';

  @override
  String profileNicknameUpdated(String nickname) {
    return 'Nickname updated to \"$nickname\"';
  }

  @override
  String get profileNicknameCleared => 'Nickname cleared';

  @override
  String get profilePubKeyLabel => 'Public Key (Ed25519)';

  @override
  String get profilePubKeyLoading => 'Loading...';

  @override
  String get profileBatteryButton =>
      'Background / Battery Optimization Settings';

  @override
  String get profileMedicalCardEdit => 'Edit Medical Card';

  @override
  String get profileMedicalCardCreate => 'Create Medical Card';

  @override
  String get profileTrustPhoneVerify => 'Phone Verification';

  @override
  String get profileTrustNotOpen => 'Not yet available';

  @override
  String get profileUpgradeSnack =>
      'Upgraded to Phone Verified (L1) (pending backend SMS OTP integration)';

  @override
  String get profileLanguageLabel => 'Language';

  @override
  String get mapTitle => 'Offline Map';

  @override
  String get mapLayerControlTooltip => 'Layer Control';

  @override
  String get mapLegendTooltip => 'Legend';

  @override
  String get mapRefreshTooltip => 'Refresh';

  @override
  String get mapLoading => 'Loading offline map...';

  @override
  String get mapLoadingNote =>
      '(First launch: extracting 201MB map takes a moment)';

  @override
  String get mapErrorTitle => 'Offline Map Unavailable';

  @override
  String get mapErrorUnknown => 'Unknown error';

  @override
  String get mapErrorAssetNote =>
      'Please verify assets/maps/taiwan_ignirelay.mbtiles is properly bundled';

  @override
  String get mapRetryButton => 'Retry';

  @override
  String get mapMbtilesNotFound =>
      'Offline map file not found (taiwan_ignirelay.mbtiles)';

  @override
  String mapMbtilesLoadFail(String error) {
    return 'Map loading failed: $error';
  }

  @override
  String get mapHazardRoadblock => 'Road Blocked';

  @override
  String get mapHazardFire => 'Fire';

  @override
  String get mapHazardChemical => 'Chemical/Toxic';

  @override
  String get mapHazardFlood => 'Flood';

  @override
  String get mapHazardCollapse => 'Building Collapse';

  @override
  String get mapHazardLandslide => 'Landslide';

  @override
  String get mapEventSosRed => 'SOS Emergency';

  @override
  String get mapEventSosYellow => 'Help Request';

  @override
  String get mapEventSupply => 'Supply';

  @override
  String get mapEventInfo => 'Info';

  @override
  String get mapEventTypeSupply => 'Supply Available';

  @override
  String get mapEventTypeRequest => 'Supply Request';

  @override
  String mapEventTypeUnknown(int eventType) {
    return 'Event (type=$eventType)';
  }

  @override
  String get mapPoiHospital => 'Hospital';

  @override
  String get mapPoiClinic => 'Clinic';

  @override
  String get mapPoiNursingHome => 'Nursing Home';

  @override
  String get mapPoiPharmacy => 'Pharmacy';

  @override
  String get mapPoiPolice => 'Police Station';

  @override
  String get mapPoiFireStation => 'Fire Station';

  @override
  String get mapPoiSchool => 'School';

  @override
  String get mapPoiUniversity => 'University';

  @override
  String get mapPoiSupermarket => 'Supermarket';

  @override
  String get mapPoiConvenience => 'Convenience Store';

  @override
  String get mapPoiMall => 'Mall';

  @override
  String get mapPoiGasStation => 'Gas Station';

  @override
  String get mapPoiRestaurant => 'Restaurant';

  @override
  String get mapPoiCafe => 'Café';

  @override
  String get mapPoiBank => 'Bank';

  @override
  String get mapPoiPostOffice => 'Post Office';

  @override
  String get mapPoiReligious => 'Place of Worship';

  @override
  String get mapPoiParking => 'Parking';

  @override
  String get mapPoiShop => 'Shop';

  @override
  String get mapPoiInfoAddress => 'Address';

  @override
  String get mapPoiInfoPhone => 'Phone';

  @override
  String get mapPoiInfoOpen => 'Open';

  @override
  String get mapPoiInfoNoDetail => '(No details available for this location)';

  @override
  String get mapDayMonday => 'Monday';

  @override
  String get mapDayTuesday => 'Tuesday';

  @override
  String get mapDayWednesday => 'Wednesday';

  @override
  String get mapDayThursday => 'Thursday';

  @override
  String get mapDayFriday => 'Friday';

  @override
  String get mapDaySaturday => 'Saturday';

  @override
  String get mapDaySunday => 'Sunday';

  @override
  String get mapDayHoliday => 'Public Holiday';

  @override
  String get mapDayClosed => 'Closed';

  @override
  String get mapCredibilityConfirmed => 'Confirmed';

  @override
  String get mapCredibilityCredible => 'Credible';

  @override
  String get mapCredibilityEndorsed => 'Endorsed';

  @override
  String get mapCredibilityUnverified => 'Unverified';

  @override
  String mapTimeAgoMinutes(int mins) {
    return '$mins min ago';
  }

  @override
  String mapTimeAgoHours(int hours) {
    return '$hours hr ago';
  }

  @override
  String mapTimeAgoDays(int days) {
    return '$days days ago';
  }

  @override
  String get mapMarkingNearbyExists => 'Nearby report exists';

  @override
  String mapMarkingNearbyContent(
      int distanceMeters, String typeLabel, int confirmCount) {
    return 'A \"$typeLabel\" hazard was reported ${distanceMeters}m away ($confirmCount confirmation(s)).\n\nTap \'Confirm\' to increase credibility, or create a new marker.';
  }

  @override
  String get mapMarkingCreateNew => 'Create new marker';

  @override
  String get mapMarkingConfirmReport => 'Confirm report';

  @override
  String get mapMarkingEditTitle => 'Edit Hazard Marker';

  @override
  String get mapMarkingNewTitle => 'Mark Hazard Zone';

  @override
  String get mapMarkingTapHint => '  Tap the map to move marker position';

  @override
  String get mapMarkingSeverityLabel => ' Severity';

  @override
  String get mapMarkingRadiusLabel => ' Radius';

  @override
  String get mapMarkingDescHint => 'Describe the situation (optional)';

  @override
  String get mapMarkingUpdateButton => 'Update Marker';

  @override
  String get mapMarkingPublishButton => 'Publish to Mesh';

  @override
  String get mapHazardUpdatedSnack => 'Hazard marker updated';

  @override
  String get mapHazardPublishedSnack => 'Hazard marker published to Mesh';

  @override
  String get mapHazardDeleteTitle => 'Clear Hazard Marker?';

  @override
  String get mapHazardDeleteContent =>
      'This marker will be removed from the map.';

  @override
  String get mapHazardDeleteCancel => 'Cancel';

  @override
  String get mapHazardDeleteConfirm => 'Clear';

  @override
  String get mapHazardDeletedSnack => 'Hazard marker cleared';

  @override
  String get mapHazardInfoSeverity => 'Severity';

  @override
  String mapHazardInfoRadius(int radius) {
    return 'Affected area: ${radius}m';
  }

  @override
  String mapHazardInfoDesc(String desc) {
    return 'Description: $desc';
  }

  @override
  String mapHazardInfoTime(String timeAgo) {
    return 'Reported: $timeAgo';
  }

  @override
  String get mapHazardInfoMine => 'Your report';

  @override
  String get mapHazardInfoEditButton => 'Edit';

  @override
  String get mapHazardInfoConfirmButton => 'Confirm this report';

  @override
  String mapHazardConfirmSnack(String typeLabel, int count) {
    return 'Confirmed \"$typeLabel\" report ($count people)';
  }

  @override
  String mapEventInfoDistance(String distance) {
    return 'Distance: $distance';
  }

  @override
  String mapEventInfoTime(String timeAgo) {
    return 'Time: $timeAgo';
  }

  @override
  String get mapLongPressHint => 'Long press map → Mark hazard zone';

  @override
  String get mapSosSentLabel => 'SOS Sent  ✕ Cancel';

  @override
  String get mapSosButton => 'SOS';

  @override
  String get mapSosHoldHint => 'Hold 1.5s to send SOS';

  @override
  String get mapCancelSosTitle => 'Cancel SOS';

  @override
  String get mapCancelSosContent =>
      'Are you sure you want to cancel the SOS signal?\nOther devices will be notified.';

  @override
  String get mapCancelSosBack => 'Back';

  @override
  String get mapCancelSosConfirm => 'Confirm Cancel';

  @override
  String get mapSosCancelledPrefix => '[SOS Cancelled]';

  @override
  String get mapSosCancelledSnack => 'SOS Cancelled';

  @override
  String mapSosCancelFailSnack(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get mapGpsNotReady =>
      'GPS not ready. Please ensure location services are enabled';

  @override
  String get mapTriageBroadcastLabel0 => 'Info';

  @override
  String get mapTriageBroadcastLabel1 => 'Supply Request';

  @override
  String get mapTriageBroadcastLabel2 => 'Help (Yellow)';

  @override
  String get mapTriageBroadcastLabel3 => 'Emergency SOS (Red)';

  @override
  String mapTriageBroadcastSnack(String label, String desc) {
    return 'Broadcast $label: $desc';
  }

  @override
  String get mapLegendTitle => 'Relief Landmarks (Offline Tiles)';

  @override
  String get mapLegendZoomHint => 'Zoom to street level to load POIs';

  @override
  String get mapLegendHospital => 'Hospital/Clinic';

  @override
  String get mapLegendPolice => 'Police/Fire Station';

  @override
  String get mapLegendSchool => 'School (Shelter)';

  @override
  String get mapLegendPharmacy => 'Pharmacy (Medical Supplies)';

  @override
  String get mapLegendSupermarket => 'Supermarket/Convenience Store';

  @override
  String get mapLegendMeshEvents => 'Mesh Events';

  @override
  String mapPayloadQtyUnit(String name, int qty, String unit) {
    return '$name $qty $unit';
  }

  @override
  String mapPayloadQtyPcs(String name, int qty) {
    return '$name $qty pcs';
  }

  @override
  String get mapLayerTitle => 'Layer Control';

  @override
  String get mapLayerPoiSection => 'POI Icons';

  @override
  String get mapLayerHazardSection => 'Hazard Zones';

  @override
  String get mapLayerPoiHospital => 'Hospital/Clinic';

  @override
  String get mapLayerPoiPharmacy => 'Pharmacy';

  @override
  String get mapLayerPoiPolice => 'Police/Fire Station';

  @override
  String get mapLayerPoiSchool => 'School (Shelter)';

  @override
  String get mapLayerPoiSupermarket => 'Supermarket/Store';

  @override
  String get mapLayerHazardShowOthers => 'Show others\' reports';

  @override
  String get mapLayerHazardMinCredibility => 'Min. credibility';

  @override
  String get mapLayerCredAll => 'Show all';

  @override
  String get mapLayerCredAllDesc => 'Including unverified';

  @override
  String get mapLayerCred2 => '2+ people';

  @override
  String get mapLayerCred2Desc => 'Endorsed';

  @override
  String get mapLayerCred3 => '3+ people';

  @override
  String get mapLayerCred3Desc => 'Multiple reports';

  @override
  String get mapLayerCred5 => 'Confirmed (5+)';

  @override
  String get mapLayerCred5Desc => 'Highly credible';

  @override
  String get triageTitle => 'Emergency Broadcast';

  @override
  String get triageDescHint =>
      'Describe needs or supplies (e.g., need water, have first aid kit)';

  @override
  String get triageMedicalCardToggle => 'Include medical card info';

  @override
  String get triageMedicalCardOn => 'Enabled';

  @override
  String get triageMedicalCardOff => 'Disabled';

  @override
  String get triageSosYellowButton => 'Help (SOS_YELLOW)';

  @override
  String get triageSosRedButton => 'Send SOS_RED Emergency Now';

  @override
  String triageSosRedCountdown(int seconds) {
    return 'Holding... ${seconds}s remaining';
  }

  @override
  String get triageSosRedHoldHint =>
      'Hold 3 seconds to unlock critical SOS (SOS_RED)';

  @override
  String get hazardDialogTitle => 'Mark Hazard Zone';

  @override
  String hazardDialogCoordinate(String lat, String lng) {
    return 'Coordinates: $lat, $lng';
  }

  @override
  String get hazardDialogTypeLabel => 'Hazard Type';

  @override
  String get hazardDialogSeverityLabel => 'Severity';

  @override
  String get hazardDialogSeverityMin => 'Minor';

  @override
  String get hazardDialogSeverityMax => 'Critical';

  @override
  String get hazardDialogRadiusLabel => 'Affected Radius';

  @override
  String get hazardDialogDescHint => 'Describe the situation (optional)';

  @override
  String get hazardDialogCancel => 'Cancel';

  @override
  String get hazardDialogPublish => 'Publish to Mesh';

  @override
  String get matchTitle => 'Supply Matching';

  @override
  String get matchTabSupplies => 'My Supplies';

  @override
  String get matchTabRequests => 'My Requests';

  @override
  String get matchTabNegotiations => 'Active';

  @override
  String get matchTabCommunity => 'Community';

  @override
  String get matchFabRegisterSupply => 'Register Supply';

  @override
  String get matchFabPublishRequest => 'Publish Request';

  @override
  String get matchNegAcceptedSnack => 'Negotiation accepted';

  @override
  String get matchNegDeclinedSnack => 'Negotiation declined';

  @override
  String get matchNegCancelledSnack => 'Negotiation cancelled';

  @override
  String get matchHandoffCompleteSnack => 'Handoff complete';

  @override
  String get matchNegExpiredSnack => 'Negotiation expired';

  @override
  String get matchOverQuantityWarning => 'Over-quantity warning';

  @override
  String matchLoadError(String error) {
    return 'Load error: $error';
  }

  @override
  String get matchGpsOpenSettings => 'Open Settings';

  @override
  String get matchGpsEnableLocation => 'Enable Location';

  @override
  String get matchRetry => 'Retry';

  @override
  String get matchUrgencyEmergency => 'Emergency SOS';

  @override
  String get matchUrgencyHelp => 'Help';

  @override
  String get matchUrgencySupply => 'Supply';

  @override
  String get matchUrgencyInfo => 'Info';

  @override
  String get matchCountdownExpired => 'Expired';

  @override
  String matchCancelSupplySnack(String name) {
    return 'Supply cancelled: $name';
  }

  @override
  String matchCancelRequestSnack(String name) {
    return 'Request cancelled: $name';
  }

  @override
  String matchCancelFailSnack(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get matchAcceptSnack => 'Negotiation accepted';

  @override
  String matchAcceptFailSnack(String error) {
    return 'Accept failed: $error';
  }

  @override
  String get matchDeclineSnack => 'Negotiation declined';

  @override
  String matchDeclineFailSnack(String error) {
    return 'Decline failed: $error';
  }

  @override
  String matchCommunityRequestSnack(int qty, String name) {
    return 'Published request for $qty pcs \"$name\"';
  }

  @override
  String matchCommunitySupplySnack(int qty, String name) {
    return 'Registered supply of $qty pcs \"$name\"';
  }

  @override
  String matchCommunityFailSnack(String error) {
    return 'Publish failed: $error';
  }

  @override
  String get matchCommunityNote => 'Respond to community supply';

  @override
  String get suppliesEmptyTitle => 'No supplies registered';

  @override
  String get suppliesEmptySubtitle =>
      'Tap the button below to register supplies you can provide';

  @override
  String get suppliesStatusExhausted => 'Exhausted';

  @override
  String get suppliesStatusPartial => 'Partially Committed';

  @override
  String get suppliesStatusAvailable => 'Available';

  @override
  String get suppliesDeliveryDeliver => 'Can deliver';

  @override
  String get suppliesDeliveryPickup => 'Requester picks up';

  @override
  String get suppliesQtyTotal => 'Total';

  @override
  String get suppliesQtyAvailable => 'Available';

  @override
  String get suppliesQtyCommitted => 'Committed';

  @override
  String get suppliesCancelButton => 'Cancel';

  @override
  String get suppliesCancelDialogTitle => 'Cancel Supply';

  @override
  String suppliesCancelDialogContent(String name) {
    return 'Are you sure you want to cancel \"$name\"?\nIt will be removed from the Mesh network.';
  }

  @override
  String get suppliesCancelDialogBack => 'Back';

  @override
  String get suppliesCancelDialogConfirm => 'Confirm Cancel';

  @override
  String get suppliesNotFoundSnack =>
      'Could not find the corresponding publish record';

  @override
  String get requestsEmptyTitle => 'No requests published';

  @override
  String get requestsEmptySubtitle =>
      'Tap the button below to publish supply requests';

  @override
  String get requestsStatusMatching => 'Matching';

  @override
  String get requestsStatusFulfilled => 'Fulfilled';

  @override
  String get requestsStatusWaiting => 'Waiting';

  @override
  String get requestsQtyNeeded => 'Needed';

  @override
  String get requestsQtyRemaining => 'Remaining';

  @override
  String get requestsQtyFulfilled => 'Fulfilled';

  @override
  String get requestsQtyUnit => 'pcs';

  @override
  String get requestsProposalsTitle => 'Received proposals:';

  @override
  String requestsProposalOffer(int qty) {
    return 'Offering $qty pcs';
  }

  @override
  String requestsProposalRemaining(String remaining) {
    return 'Remaining $remaining';
  }

  @override
  String get requestsAcceptButton => 'Accept';

  @override
  String get requestsDeclineButton => 'Decline';

  @override
  String get requestsCancelButton => 'Cancel';

  @override
  String get requestsCancelDialogTitle => 'Cancel Request';

  @override
  String requestsCancelDialogContent(String name) {
    return 'Are you sure you want to cancel \"$name\"?\nIt will be removed from the Mesh network.';
  }

  @override
  String get requestsCancelDialogBack => 'Back';

  @override
  String get requestsCancelDialogConfirm => 'Confirm Cancel';

  @override
  String get negEmptyTitle => 'No active negotiations';

  @override
  String get negEmptySubtitle =>
      'Negotiations will appear here when someone responds to your supply or request';

  @override
  String get negStatusPending => 'Pending';

  @override
  String get negStatusAccepted => 'Accepted';

  @override
  String get negStatusNavigating => 'Navigating';

  @override
  String get negRoleRequester => 'Requester';

  @override
  String get negRoleProvider => 'Provider';

  @override
  String get negRoleMeProvider => 'I provide';

  @override
  String get negRoleMeRequester => 'I need';

  @override
  String get negScoreUnit => 'pts';

  @override
  String get negStaleLabel => 'Stale';

  @override
  String get negViewMapButton => 'View Map';

  @override
  String get negCancelButton => 'Cancel';

  @override
  String get negCancelDialogTitle => 'Cancel Negotiation';

  @override
  String get negCancelDialogContent =>
      'Are you sure you want to cancel this negotiation?';

  @override
  String get negCancelDialogBack => 'Back';

  @override
  String get negCancelDialogConfirm => 'Confirm Cancel';

  @override
  String negQtyUnit(int qty) {
    return '$qty pcs';
  }

  @override
  String get communityEmptyTitle => 'No community activity';

  @override
  String get communityEmptySubtitle =>
      'Supply and request activity from nearby users will appear here';

  @override
  String get communityTypeSupply => 'Available';

  @override
  String get communityTypeRequest => 'Needed';

  @override
  String get communityActionNeed => 'I need this';

  @override
  String get communityActionHelp => 'I can help';

  @override
  String get communityDialogConfirmNeed => 'Confirm needed quantity';

  @override
  String get communityDialogConfirmSupply => 'Confirm supply quantity';

  @override
  String communityDialogSupplyInfo(String name, int qty) {
    return 'Someone can provide \"$name\" — $qty pcs';
  }

  @override
  String communityDialogRequestInfo(String name, int qty) {
    return 'Someone needs \"$name\" — $qty pcs';
  }

  @override
  String get communityDialogHowManyNeed => 'How many do you need?';

  @override
  String get communityDialogHowManySupply => 'How many can you provide?';

  @override
  String get communityDialogQtyHint => 'Quantity';

  @override
  String get communityDialogQtySuffix => 'pcs';

  @override
  String get communityDialogCancel => 'Cancel';

  @override
  String get communityDialogConfirmNeedButton => 'Confirm Request';

  @override
  String get communityDialogConfirmSupplyButton => 'Confirm Supply';

  @override
  String get communityDialogQtyError => 'Quantity must be greater than 0';

  @override
  String get supplyRegTitle => 'Register Supply';

  @override
  String get supplyRegCategoryLabel => 'Supply Category';

  @override
  String supplyRegSubCategoryLabel(String categoryLabel) {
    return '→ $categoryLabel Sub-category';
  }

  @override
  String get supplyRegItemLabel => 'Specific Item (optional)';

  @override
  String get supplyRegExpiryLabel => 'Expiry Date';

  @override
  String get supplyRegExpiryHint => 'Tap to select expiry date (optional)';

  @override
  String get supplyRegConditionLabel => 'Item Condition';

  @override
  String get supplyRegQtyLabel => 'Quantity';

  @override
  String get supplyRegQtyValidator => 'Please enter a quantity';

  @override
  String get supplyRegDeliverySection => 'Handoff Method (multi-select)';

  @override
  String get supplyRegDeliveryDeliver => 'I\'ll deliver';

  @override
  String get supplyRegDeliveryDeliverDesc =>
      'Deliver supplies to the requester\'s location';

  @override
  String get supplyRegDeliveryPickup => 'Requester picks up';

  @override
  String get supplyRegDeliveryPickupDesc => 'Requester comes to my location';

  @override
  String get supplyRegDeliveryDropoff => 'Drop-off';

  @override
  String get supplyRegDeliveryDropoffDesc =>
      'Contactless handoff — place and notify for pickup';

  @override
  String get supplyRegNoteHint => 'Notes (optional)';

  @override
  String supplyRegRange(String km) {
    return 'Coverage radius: $km km';
  }

  @override
  String get supplyRegRangeNote =>
      '* Auto-suggested based on terrain; adjustable manually';

  @override
  String get supplyRegPublishing => 'Publishing...';

  @override
  String get supplyRegPublishButton => 'Publish to Mesh Network';

  @override
  String get supplyRegSuccessSnack => 'Supply published successfully!';

  @override
  String supplyRegFailSnack(String error) {
    return 'Publish failed: $error';
  }

  @override
  String get reqSheetTitle => 'Publish Supply Request';

  @override
  String get reqSheetCategoryLabel => 'What supplies do you need?';

  @override
  String get reqSheetSubCategoryLabel => '→ Sub-category';

  @override
  String get reqSheetItemLabel => 'Specific Item (optional)';

  @override
  String get reqSheetQtyLabel => 'Quantity Needed';

  @override
  String get reqSheetMobilitySection => 'Handoff Method';

  @override
  String get reqSheetMobilityPickup => 'I can pick up';

  @override
  String get reqSheetMobilityPickupDesc => 'I can travel to collect supplies';

  @override
  String get reqSheetMobilityDelivery => 'Need delivery';

  @override
  String get reqSheetMobilityDeliveryDesc =>
      'Unable to move; need someone to deliver';

  @override
  String get reqSheetMobilityDropoff => 'Contactless handoff';

  @override
  String get reqSheetMobilityDropoffDesc =>
      'Provider drops off supplies; I pick up later';

  @override
  String reqSheetRange(String km) {
    return 'Search radius: $km km';
  }

  @override
  String get reqSheetNoteHint => 'Notes (optional)';

  @override
  String get reqSheetPublishing => 'Broadcasting...';

  @override
  String get reqSheetPublishButton => 'Publish Request to Mesh Network';

  @override
  String get reqSheetSuccessSnack => 'Request broadcast to Mesh network!';

  @override
  String reqSheetFailSnack(String error) {
    return 'Publish failed: $error';
  }

  @override
  String get navTitle => 'Navigation Guide';

  @override
  String get navDirectionProviderToReq => 'Provider to Requester';

  @override
  String get navDirectionReqToProvider => 'Requester to Provider';

  @override
  String navSupplyInfo(int supplyQty, int requestQty, int ratio) {
    return 'Supply: $supplyQty pcs ←→ Request: $requestQty pcs (fill rate $ratio%)';
  }

  @override
  String get navGpsLocating => 'GPS locating...';

  @override
  String get navBleDetected => 'Mesh node detected';

  @override
  String navBleSignal(String strength) {
    return 'Signal $strength';
  }

  @override
  String get navBleSignalStrong => 'Strong (very close)';

  @override
  String get navBleSignalMedium => 'Medium (nearby)';

  @override
  String get navBleSignalWeak => 'Weak (far away)';

  @override
  String get navBleScanning =>
      'Scanning Bluetooth... Auto-detect when approaching the other party';

  @override
  String get navHandoffButton => 'Start Handoff';

  @override
  String get navHandoffWaiting => 'Waiting for Bluetooth detection...';

  @override
  String get navCancelDialogTitle => 'Match Cancelled';

  @override
  String get navCancelDialogContent =>
      'The other party has cancelled this match.';

  @override
  String get navCancelDialogBack => 'Back to Home';

  @override
  String get navCompleteSnack => 'Handoff complete!';

  @override
  String get handoffTitle => 'Physical Handoff Confirmation';

  @override
  String handoffProviderResource(String resourceType) {
    return 'Supply: $resourceType';
  }

  @override
  String get handoffProviderPinLabel => 'Tell the other party this PIN code';

  @override
  String handoffProviderTimeout(String timeout) {
    return 'Supplies will auto-return if not completed within $timeout';
  }

  @override
  String get handoffProviderWaiting =>
      'Waiting for the other party to enter PIN via BLE to confirm receipt...';

  @override
  String get handoffProviderGattNote =>
      '(GATT handoff broadcast active on this device)';

  @override
  String get handoffRequesterPinPrompt =>
      'Enter the 4-digit PIN shown by the provider';

  @override
  String handoffRequesterLockout(int seconds) {
    return 'Too many incorrect attempts. Please wait ${seconds}s...';
  }

  @override
  String handoffRequesterWrong(int remaining) {
    return 'Incorrect! Remaining attempts: $remaining / 6';
  }

  @override
  String get handoffRequesterConfirmButton => 'Confirm Receipt';

  @override
  String get handoffDropoffProviderTitle =>
      'Contactless Handoff — Place Supplies';

  @override
  String get handoffDropoffLocationLabel => 'Drop-off Location';

  @override
  String get handoffDropoffUseCurrentLocation => 'Tap to use current location';

  @override
  String get handoffDropoffLocateButton => 'Locate';

  @override
  String get handoffDropoffDescLabel =>
      'Drop-off description / photo notes (optional)';

  @override
  String get handoffDropoffDescHint =>
      'e.g., Left beside the box at the front door';

  @override
  String get handoffDropoffWaitingButton => 'Placed — Waiting for pickup';

  @override
  String get handoffDropoffConfirmButton => 'Confirm Drop-off';

  @override
  String get handoffDropoffRequesterTitle => 'Contactless Handoff';

  @override
  String get handoffDropoffRequesterContent =>
      'The provider has placed the supplies at the designated location.\nPlease go pick them up and confirm.';

  @override
  String get handoffDropoffRequesterConfirm => 'Supplies Received';

  @override
  String get handoffSuccessTitle => 'Handoff Complete!';

  @override
  String handoffSuccessContent(String resourceType) {
    return '$resourceType successfully transferred';
  }

  @override
  String get handoffSuccessBack => 'Back';

  @override
  String get handoffCancelledTitle => 'Handoff Cancelled';

  @override
  String get handoffCancelledContent => 'Supplies returned to available status';

  @override
  String get handoffCancelledBack => 'Back';

  @override
  String get handoffTimeout30min => '30 minutes';

  @override
  String get handoffTimeout4hr => '4 hours';

  @override
  String get medicalTitle => 'Medical Card';

  @override
  String get medicalSosInfo =>
      'Fields with broadcast icons will be transmitted\nvia Mesh network to nearby rescuers during SOS';

  @override
  String get medicalPresetLabel => 'Quick Preset';

  @override
  String get medicalPresetMinimal => 'Minimal Disclosure';

  @override
  String get medicalPresetRecommended => 'Recommended';

  @override
  String get medicalPresetFull => 'Share All';

  @override
  String medicalPresetApplied(String presetName) {
    return 'Applied \"$presetName\" preset';
  }

  @override
  String get medicalSectionBasic => 'Basic Physiological';

  @override
  String get medicalSectionBackground => 'Medical Background';

  @override
  String get medicalSectionEmergency => 'Emergency Info';

  @override
  String get medicalFieldName => 'Name';

  @override
  String get medicalFieldAge => 'Age';

  @override
  String get medicalFieldHeight => 'Height (cm)';

  @override
  String get medicalFieldWeight => 'Weight (kg)';

  @override
  String get medicalFieldBloodType => 'Blood Type';

  @override
  String get medicalFieldConditions => 'Medical Conditions';

  @override
  String get medicalFieldAllergies => 'Allergies';

  @override
  String get medicalFieldMedications => 'Current Medications';

  @override
  String get medicalFieldEmergencyContact => 'Emergency Contact';

  @override
  String get medicalFieldOrganDonor => 'Organ Donor';

  @override
  String get medicalFieldPrimaryLanguage => 'Primary Language';

  @override
  String get medicalHintName => 'Your name';

  @override
  String get medicalHintAge => 'Age';

  @override
  String get medicalSuffixAge => 'yrs';

  @override
  String get medicalHintHeight => 'Height';

  @override
  String get medicalSuffixHeight => 'cm';

  @override
  String get medicalHintWeight => 'Weight';

  @override
  String get medicalSuffixWeight => 'kg';

  @override
  String get medicalHintConditions =>
      'e.g., Diabetes, Epilepsy, Asthma (comma-separated)';

  @override
  String get medicalHintMedications =>
      'e.g., Insulin, BP medication (comma-separated)';

  @override
  String get medicalHintLanguage => 'e.g., English, 繁體中文';

  @override
  String get medicalBloodTypeNone => 'Not selected';

  @override
  String get medicalAllergenLabel => 'Allergen';

  @override
  String get medicalAllergenHint => 'Allergen';

  @override
  String get medicalReactionHint => 'Reaction symptoms';

  @override
  String get medicalReactionUnknown => 'Unknown reaction';

  @override
  String get medicalEcPhoneLabel => 'Emergency Contact Phone';

  @override
  String get medicalEcPhoneHint => 'e.g., +1-234-567-8901';

  @override
  String get medicalEcRelationLabel => 'Relationship';

  @override
  String get medicalEcRelationHint => 'e.g., Mother, Spouse';

  @override
  String get medicalOrganDonorLabel => 'Organ Donor Status';

  @override
  String get medicalOrganDonorNone => 'Not set';

  @override
  String get medicalOrganDonorYes => 'Yes';

  @override
  String get medicalOrganDonorNo => 'No';

  @override
  String get medicalHealthImportButton => 'Import from Health Connect';

  @override
  String get medicalHealthConnectRequired => 'Health Connect Required';

  @override
  String get medicalHealthConnectInstallGuide =>
      'This feature requires Google Health Connect.\n\nPlease install \"Health Connect\" from Google Play Store.\n\nAfter installation, add your health data (height, weight, blood type) in Health Connect, then return here to import.';

  @override
  String get medicalHealthConnectDismiss => 'OK';

  @override
  String get medicalHealthConnectInstall => 'Install';

  @override
  String get medicalHealthConnectAuthFail => 'Authorization Failed';

  @override
  String get medicalHealthConnectAuthGuide =>
      'Health Connect read permission not granted.\n\nPlease authorize manually:\n1. Open \"Health Connect\" app\n2. Tap \"App permissions\"\n3. Find \"IgniRelay\" and allow reading height, weight, blood type';

  @override
  String get medicalHealthConnectNoData =>
      'No health data found in Health Connect';

  @override
  String medicalHealthConnectImported(int count) {
    return 'Imported $count items from Health Connect';
  }

  @override
  String get medicalHealthConnectNoNewData =>
      'No new data imported (fields already filled or no data available)';

  @override
  String medicalHealthConnectFailSnack(String error) {
    return 'Health Connect import failed: $error\nPlease ensure Health Connect is installed';
  }

  @override
  String get medicalSaving => 'Saving...';

  @override
  String get medicalSaveButton => 'Save Medical Card';

  @override
  String get medicalSavedSnack => 'Medical card saved';

  @override
  String medicalSaveFailSnack(String error) {
    return 'Save failed: $error';
  }

  @override
  String get medicalSosToggleOn => 'ON';

  @override
  String get medicalSosToggleOff => 'OFF';

  @override
  String get chatListTitle => 'Chat Rooms';

  @override
  String get chatListRefreshTooltip => 'Refresh';

  @override
  String get chatListRoomNational => 'National Announcements';

  @override
  String get chatListRoomCounty => 'County Announcements';

  @override
  String get chatListRoomTownship => 'Township Announcements';

  @override
  String get chatListRoomVillage => 'Village Chat';

  @override
  String get chatListRoomCustom => 'Custom Channel';

  @override
  String get chatListEmptyTitle => 'No chat rooms joined';

  @override
  String get chatListEmptySubtitle => 'Tap the + button below to join or scan';

  @override
  String get chatListAutoJoin => 'Auto-join local chat room';

  @override
  String get chatListAutoJoinSuccess => 'Auto-joined local village chat room';

  @override
  String get chatListAutoJoinFail =>
      'Unable to get location. Please join manually';

  @override
  String get chatListFabTooltip => 'Join Chat Room';

  @override
  String get chatListAdminBadge => 'Announcement Channel';

  @override
  String get chatListLeaveTitle => 'Leave Chat Room';

  @override
  String chatListLeaveContent(String roomName) {
    return 'Are you sure you want to leave \"$roomName\"? Chat history will be cleared.';
  }

  @override
  String get chatListLeaveCancel => 'Cancel';

  @override
  String get chatListLeaveConfirm => 'Leave';

  @override
  String chatRoomMessageCount(int count) {
    return '$count messages';
  }

  @override
  String get chatRoomEmpty => 'No messages yet';

  @override
  String get chatRoomReply => 'Reply';

  @override
  String get chatRoomAdminLock =>
      'Announcement channel — Only admins (L3) can post';

  @override
  String get chatRoomInputHint => 'Type a message...';

  @override
  String chatRoomSendCooldown(int seconds) {
    return 'Send failed. Please wait ${seconds}s before retrying';
  }

  @override
  String get chatRoomAnonymous => 'Anonymous';

  @override
  String get chatJoinTitle => 'Join Chat Room';

  @override
  String get chatJoinAutoSection => 'Auto Join';

  @override
  String get chatJoinAutoDesc =>
      'Auto-join local village chat and district announcement channels based on GPS location';

  @override
  String get chatJoinGpsLocating => 'Getting GPS location...';

  @override
  String chatJoinGpsWaiting(int seconds) {
    return 'Waiting for GPS fix... (${seconds}s)';
  }

  @override
  String get chatJoinGpsQuerying => 'Querying current district...';

  @override
  String get chatJoinGpsFail =>
      'GPS fix failed. Please ensure GPS is enabled, or use manual setup below';

  @override
  String get chatJoinAutoSuccess =>
      'Joined local village chat and announcement channels';

  @override
  String get chatJoinAutoFailRegion =>
      'Unable to identify current district. Please use manual setup';

  @override
  String get chatJoinAutoButton => 'Detect & Join Village Chat';

  @override
  String get chatJoinManualSection => 'Manual Area Selection';

  @override
  String get chatJoinManualDesc =>
      'Search by county, township, or village name, then select to join the corresponding chat room';

  @override
  String get chatJoinSearchHint =>
      'e.g., Xinxing Dist., Ankang Village, Kaohsiung';

  @override
  String get chatJoinSearchButton => 'Search';

  @override
  String chatJoinSearchResults(int count) {
    return 'Results ($count)';
  }

  @override
  String chatJoinSearchVillcode(String villcode) {
    return 'Code: $villcode';
  }

  @override
  String get chatJoinSearchNoResults =>
      'No matching villages found. Try different keywords';

  @override
  String chatJoinSuccess(String fullName) {
    return 'Joined $fullName chat and announcement channels';
  }

  @override
  String chatJoinFail(String error) {
    return 'Join failed: $error';
  }

  @override
  String get chatJoinInviteSection => 'Enter Invite Code';

  @override
  String get chatJoinInviteDesc =>
      'Enter a chat room ID or invite code to join a custom channel';

  @override
  String get chatJoinInviteHint => 'Chat room ID or ID:password';

  @override
  String get chatJoinInviteButton => 'Join';

  @override
  String get chatJoinInviteSuccess => 'Joined chat room';

  @override
  String get chatJoinInfoSection => 'Chat Room Info';

  @override
  String get chatJoinInfoVillage =>
      '- Village chat: everyone can post, once every 3 minutes';

  @override
  String get chatJoinInfoAdmin =>
      '- Township/County/National: only admins (L3) can broadcast';

  @override
  String get chatJoinInfoCustom =>
      '- Custom channels: join via QR code or invite code';

  @override
  String get chatJoinInfoMesh =>
      '- All messages propagate via BLE Mesh, auto-deleted after 48 hours';

  @override
  String get chatJoinInfoSwitch =>
      '- Switching areas removes the old area\'s chat rooms';

  @override
  String get survivalListening =>
      'Listening for nearby SOS and supply signals...';

  @override
  String survivalBattery(int level) {
    return 'Battery: $level%';
  }

  @override
  String get survivalDataMuleDisable => 'Disable Data Mule';

  @override
  String get survivalDataMuleEnable => 'Enable Data Mule';

  @override
  String get survivalBlePause => 'Pause BLE';

  @override
  String get survivalBleResume => 'Resume BLE';

  @override
  String get survivalStatsLocalEvents => 'Local Events';

  @override
  String get survivalStatsBleConnections => 'BLE Connections';

  @override
  String get survivalRecentEvents => 'Recent Mesh Events';

  @override
  String get survivalDataMuleFailSnack =>
      'Data Mule service failed to start\nBLE Mesh layer continues operating';

  @override
  String survivalBleFailSnack(String error) {
    return 'BLE failed to start: $error\nPlease ensure Bluetooth is enabled and permissions granted';
  }

  @override
  String get survivalDataMuleDialogTitle => 'What is Data Mule?';

  @override
  String get survivalDataMuleDialogDismiss => 'OK';

  @override
  String get survivalExportButton => 'Export Full Log';

  @override
  String survivalExportSuccess(String filename) {
    return 'Log saved to Downloads: $filename';
  }

  @override
  String survivalExportFail(String error) {
    return 'Export failed: $error';
  }

  @override
  String survivalMeshReceived(int bytes) {
    return '[Mesh] received $bytes bytes';
  }

  @override
  String get survivalDataMuleDialogContent =>
      'Data Mule is an offline relay mode:\n\n• Your phone continuously receives SOS and supply signals from nearby devices\n• As you move to different areas, stored data is automatically forwarded to newly encountered devices\n• Ideal for volunteers or rescue workers moving through disaster zones to help messages cross offline areas\n\nOnce enabled, runs as an Android foreground service — won\'t be killed even when the screen is off.\n\nPower usage: Moderate (continuous BLE scan+broadcast)';

  @override
  String get stationTitle => 'Station Supply Management';

  @override
  String get stationAuthRequired => 'Requires L2+ identity level';

  @override
  String stationAuthCurrentLevel(int level) {
    return 'Current level: L$level';
  }

  @override
  String get stationAuthDesc =>
      'Station supply management is only available to verified users.\nPlease upgrade your identity level through physical cross-verification.';

  @override
  String get stationTabAdd => 'Add Station Supply';

  @override
  String get stationTabManage => 'Manage Registered';

  @override
  String get stationCategoryLabel => 'Supply Category';

  @override
  String get stationSubCategoryLabel => '→ Sub-category';

  @override
  String get stationItemLabel => 'Specific Item (optional)';

  @override
  String get stationQtyLabel => 'Stock Quantity';

  @override
  String get stationTotalQtyLabel => 'Total Stock Quantity';

  @override
  String get stationQuotaSection => 'Per-person Quota Settings';

  @override
  String get stationQuotaCategoryLimit => 'Per-person per-category limit';

  @override
  String get stationQuotaTotalLimit => 'Per-person total limit';

  @override
  String get stationResetCycleLabel => 'Quota Reset Cycle';

  @override
  String get stationResetChip6h => '6 hours';

  @override
  String get stationResetChip12h => '12 hours';

  @override
  String get stationResetChip24h => '24 hours';

  @override
  String get stationResetChip48h => '48 hours';

  @override
  String get stationResetChip72h => '72 hours';

  @override
  String get stationResetChipNone => 'No reset';

  @override
  String stationResetNoteInterval(int hours) {
    return 'Quota auto-resets every $hours hours';
  }

  @override
  String get stationResetNoteNone => 'Quota is one-time only; no auto-reset';

  @override
  String get stationVisibilityLabel => 'Supply Visibility';

  @override
  String get stationVisibilityVillage => 'Specific villages';

  @override
  String get stationVisibilityVillageDesc => 'Select multiple nearby villages';

  @override
  String get stationVisibilityTownship => 'Entire township';

  @override
  String get stationVisibilityTownshipDesc => 'Visible to the entire district';

  @override
  String get stationVisibilityNoVillages => 'Unable to get nearby village info';

  @override
  String get stationVisibilityVillageNote =>
      '* Nearby villages listed based on current location; multiple selectable';

  @override
  String get stationVisibilityTownNotLocated => 'Not yet located';

  @override
  String get stationVisibilityTownNote =>
      '* Uses current township as visibility scope';

  @override
  String get stationQtyValidator => 'Please enter a valid quantity';

  @override
  String get stationFieldRequired => 'Required';

  @override
  String get stationPublishing => 'Publishing...';

  @override
  String get stationPublishButton => 'Publish Station Supply';

  @override
  String get stationPublishSuccess => 'Station supply published successfully!';

  @override
  String get stationManageEmptyTitle => 'No station supplies';

  @override
  String get stationManageEmptySubtitle =>
      'Switch to the \"Add Station Supply\" tab to get started';

  @override
  String get stationStatusSufficient => 'Sufficient';

  @override
  String get stationStatusLow => 'Low Stock';

  @override
  String get stationStatusCritical => 'Critical';

  @override
  String get stationStatusDepleted => 'Depleted';

  @override
  String get stationInfoTotalQty => 'Total Stock';

  @override
  String get stationInfoUsed => 'Distributed';

  @override
  String get stationInfoRemaining => 'Remaining';

  @override
  String get stationInfoUsers => 'Recipients';

  @override
  String stationInfoQtyUnit(int qty) {
    return '$qty pcs';
  }

  @override
  String stationInfoUsersUnit(int count) {
    return '$count people';
  }

  @override
  String get stationQuotaRulesLabel => 'Quota Rules';

  @override
  String get stationQuotaCategoryLimitInfo => 'Per-person per-category limit';

  @override
  String get stationQuotaTotalLimitInfo => 'Per-person total limit';

  @override
  String get stationQuotaResetCycleInfo => 'Reset cycle';

  @override
  String stationQuotaResetHours(int hours) {
    return '$hours hours';
  }

  @override
  String get stationQuotaResetNone => 'No reset';

  @override
  String get stationVisibleZones => 'Visible zones';

  @override
  String stationVisibleZonesCount(int count) {
    return '$count villages';
  }

  @override
  String stationVisibleTownship(String township) {
    return 'Township $township';
  }

  @override
  String get stationQuotaDetailButton => 'Quota Details';

  @override
  String get stationQuotaResetButton => 'Reset Quota';

  @override
  String get stationRemoveButton => 'Remove';

  @override
  String get stationQuotaDetailEmpty => 'No distribution records';

  @override
  String stationQuotaDetailTitle(String name) {
    return 'Quota Details — $name';
  }

  @override
  String stationQuotaUserLabel(String keyHex) {
    return 'User $keyHex...';
  }

  @override
  String stationQuotaUsedTotal(int used, int total) {
    return 'Period used: $used / Total: $total';
  }

  @override
  String stationQuotaLastReset(String date) {
    return 'Last reset: $date';
  }

  @override
  String get stationResetAllDialogTitle => 'Reset All Quotas';

  @override
  String get stationResetAllDialogContent =>
      'Are you sure you want to reset all user quotas for this supply?\nAll distributed amounts will be reset to zero.';

  @override
  String get stationResetAllDialogCancel => 'Cancel';

  @override
  String get stationResetAllDialogConfirm => 'Confirm Reset';

  @override
  String get stationResetSuccessSnack => 'Quotas reset';

  @override
  String stationResetFailSnack(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get stationRemoveDialogTitle => 'Remove Station Supply';

  @override
  String stationRemoveDialogContent(String name) {
    return 'Are you sure you want to remove \"$name\"?\nThis will mark the supply as consumed.';
  }

  @override
  String get stationRemoveDialogCancel => 'Cancel';

  @override
  String get stationRemoveDialogConfirm => 'Confirm Remove';

  @override
  String get stationRemoveSuccessSnack => 'Supply removed';

  @override
  String stationRemoveFailSnack(String error) {
    return 'Remove failed: $error';
  }

  @override
  String get batteryAndroidOnly =>
      'This feature is only available on Android devices';

  @override
  String get batteryIntroTitle =>
      'Important! Mesh network needs to run in the background';

  @override
  String get batteryIntroAppName => 'IgniRelay';

  @override
  String get batteryIntroConsequence1 => 'Cannot receive nearby SOS signals';

  @override
  String get batteryIntroConsequence2 => 'Cannot serve as Data Mule relay node';

  @override
  String get batteryIntroConsequence3 =>
      'Cannot auto-sync supply matching info';

  @override
  String get batteryIntroGuide =>
      'The following 1-2 steps will ensure the Mesh network stays active.';

  @override
  String get batteryStep1Label => 'Step 1/2';

  @override
  String get batteryStep1Title => 'System Battery Optimization Exemption';

  @override
  String get batteryStep1Button => 'Enable Battery Exemption';

  @override
  String get batteryStep1Done => 'Done';

  @override
  String get batteryStep1Success => 'Battery optimization exemption granted';

  @override
  String get batteryLaterButton => 'Later';

  @override
  String get batteryStartButton => 'Start Setup';

  @override
  String get batterySkipButton => 'Skip';

  @override
  String get batteryNextButton => 'Next';

  @override
  String get batteryFinishButton => 'Finish';

  @override
  String get batteryDoneTitle => 'Setup Complete!';

  @override
  String get batteryDoneContent => 'Background settings configured!';

  @override
  String get batteryDoneNote =>
      'Foreground service notification will appear when Mesh Guard starts';

  @override
  String get batteryGuideTitle => 'Background Execution Settings';

  @override
  String get batteryIntroBody =>
      'IgniRelay relies on Bluetooth Mesh to continuously broadcast and relay rescue information in the background.\n\nIf Android kills the app, your device will:';

  @override
  String get batteryStep1Desc =>
      'Tap the button below. A system dialog will appear.\nSelect \'Allow\' to exempt IgniRelay from Doze battery restrictions.';

  @override
  String get batteryStep2Label => 'Step 2/2';

  @override
  String batteryStep2Title(String manufacturer) {
    return '$manufacturer Background Settings';
  }

  @override
  String get batteryGoSettings => 'Open Settings';

  @override
  String get batteryOpenedSettings => 'Settings Opened';

  @override
  String get batteryReturnNote =>
      'Complete the steps in settings, then return here';

  @override
  String get batteryManufacturerXiaomi => 'Xiaomi / Redmi';

  @override
  String get batteryManufacturerHuawei => 'Huawei';

  @override
  String get batteryManufacturerHonor => 'Honor';

  @override
  String get batteryManufacturerOppo => 'OPPO';

  @override
  String get batteryManufacturerRealme => 'realme';

  @override
  String get batteryManufacturerVivo => 'vivo';

  @override
  String get batteryManufacturerSamsung => 'Samsung';

  @override
  String get batteryManufacturerAsus => 'ASUS';

  @override
  String get batteryInstructionXiaomi =>
      'In \'Autostart Management\', find IgniRelay → Enable autostart\nAlso in \'Battery Saver\' → Select \'No restrictions\'';

  @override
  String get batteryInstructionHuawei =>
      'In \'App Launch\', find IgniRelay\n→ Disable \'Manage automatically\' → Enable all toggles manually\nAlso in \'Lock screen cleanup\', don\'t clean this app';

  @override
  String get batteryInstructionHonor =>
      'In \'App Launch\', find IgniRelay\n→ Disable \'Manage automatically\' → Enable all toggles manually';

  @override
  String get batteryInstructionOppo =>
      'In \'Auto-start Management\', allow IgniRelay to autostart\nAlso in \'Battery\' → \'App Battery Management\' → Select \'Don\'t optimize\'';

  @override
  String get batteryInstructionRealme =>
      'In \'Auto-start Management\', allow IgniRelay to autostart\nAlso in \'Battery\' → \'App Battery Management\' → Select \'Don\'t optimize\'';

  @override
  String get batteryInstructionVivo =>
      'In \'Background App Manage\', allow IgniRelay high power usage\nAlso in \'Autostart\', enable this app';

  @override
  String get batteryInstructionSamsung =>
      'In \'Battery\' → \'Background usage limits\'\n→ Remove IgniRelay from \'Sleeping apps\'\nOr add to \'Never sleeping apps\'';

  @override
  String get batteryInstructionAsus =>
      'In \'Auto-start Manager\', allow IgniRelay\nAlso in \'Battery\', select \'Unrestricted\'';

  @override
  String get batteryInstructionDefault =>
      'Go to phone \'Settings\' → \'Battery\' → \'Background Activity Management\'\nAllow IgniRelay to run in the background.';

  @override
  String get batteryDoneBody =>
      'IgniRelay can now run Mesh networking in the background,\nreceiving and relaying rescue information even when the screen is off.';

  @override
  String get locationGpsDisabled =>
      'GPS is disabled. Please enable location services in system settings';

  @override
  String get locationGpsDeniedForever =>
      'GPS permission permanently denied. Please go to Settings → Apps → Grant location permission';

  @override
  String get locationGpsDenied =>
      'Please grant GPS permission for more accurate matching results';

  @override
  String get locationGpsTimeout =>
      'GPS timed out. Please ensure location is enabled or move to an open area';

  @override
  String locationGpsFail(String error) {
    return 'GPS failed: $error';
  }

  @override
  String locationInitFail(String error) {
    return 'Location service init failed: $error';
  }

  @override
  String get locationDirectionN => 'North';

  @override
  String get locationDirectionNE => 'Northeast';

  @override
  String get locationDirectionE => 'East';

  @override
  String get locationDirectionSE => 'Southeast';

  @override
  String get locationDirectionS => 'South';

  @override
  String get locationDirectionSW => 'Southwest';

  @override
  String get locationDirectionW => 'West';

  @override
  String get locationDirectionNW => 'Northwest';

  @override
  String get supplyCategory_WATER => 'Drinking Water';

  @override
  String get supplyCategory_FOOD => 'Food';

  @override
  String get supplyCategory_MEDICAL => 'Medical/First Aid';

  @override
  String get supplyCategory_HYGIENE => 'Hygiene/Sanitary';

  @override
  String get supplyCategory_PROTECTION => 'Protective Gear';

  @override
  String get supplyCategory_SHELTER => 'Shelter/Housing';

  @override
  String get supplyCategory_TOOL => 'Tools/Equipment';

  @override
  String get supplyCategory_PETS => 'Pet Supplies';

  @override
  String get supplyCategory_SKILL => 'Skills/Services';

  @override
  String get supplySubCategory_WATER_BOTTLE => 'Bottled Water';

  @override
  String get supplySubCategory_WATER_PURIFY => 'Water Purification';

  @override
  String get supplySubCategory_WATER_CONTAINER => 'Water Storage';

  @override
  String get supplySubCategory_FOOD_READY => 'Ready-to-Eat';

  @override
  String get supplySubCategory_FOOD_STAPLE => 'Staple Foods/Dry Goods';

  @override
  String get supplySubCategory_FOOD_BABY => 'Baby Food';

  @override
  String get supplySubCategory_FOOD_SUPPLEMENT => 'Nutritional Supplements';

  @override
  String get supplySubCategory_FOOD_COOKING => 'Cooking Equipment';

  @override
  String get supplySubCategory_MED_PAIN => 'Pain/Fever Relief';

  @override
  String get supplySubCategory_MED_WOUND => 'Wound Care';

  @override
  String get supplySubCategory_MED_CHRONIC => 'Chronic Medication';

  @override
  String get supplySubCategory_MED_RESPIRATORY => 'Respiratory';

  @override
  String get supplySubCategory_MED_GI => 'Gastrointestinal';

  @override
  String get supplySubCategory_MED_FIRSTAID_KIT => 'First Aid Kits';

  @override
  String get supplySubCategory_HYG_FEMININE => 'Feminine Hygiene';

  @override
  String get supplySubCategory_HYG_BABY => 'Baby Hygiene';

  @override
  String get supplySubCategory_HYG_PERSONAL => 'Personal Care';

  @override
  String get supplySubCategory_HYG_SANITATION => 'Environmental Sanitation';

  @override
  String get supplySubCategory_PROT_RESPIRATORY => 'Respiratory Protection';

  @override
  String get supplySubCategory_PROT_BODY => 'Body Protection';

  @override
  String get supplySubCategory_PROT_LIGHT => 'Lighting/Energy';

  @override
  String get supplySubCategory_SHELTER_TEMP => 'Temporary Shelter';

  @override
  String get supplySubCategory_SHELTER_BEDDING => 'Bedding/Warmth';

  @override
  String get supplySubCategory_SHELTER_CLOTHING => 'Clothing';

  @override
  String get supplySubCategory_TOOL_COMM => 'Communication Tools';

  @override
  String get supplySubCategory_TOOL_RESCUE => 'Rescue Tools';

  @override
  String get supplySubCategory_TOOL_POWER => 'Power Equipment';

  @override
  String get supplySubCategory_TOOL_TRANSPORT => 'Transport Equipment';

  @override
  String get supplySubCategory_PET_FOOD => 'Pet Food';

  @override
  String get supplySubCategory_PET_CARE => 'Pet Housing & Care';

  @override
  String get supplySubCategory_SKILL_MEDICAL => 'Medical';

  @override
  String get supplySubCategory_SKILL_RESCUE => 'Search & Rescue';

  @override
  String get supplySubCategory_SKILL_LANG => 'Translation/Language';

  @override
  String get supplySubCategory_SKILL_PSYCH => 'Psychological Counseling';

  @override
  String get supplySubCategory_SKILL_CARE => 'Care Services';

  @override
  String get supplySubCategory_SKILL_TECH => 'Technical';

  @override
  String get supplySubCategory_SKILL_LOGISTICS => 'Logistics/Driving';

  @override
  String get profileSubtitle => 'Identity · Settings · Medical';

  @override
  String get profileQuickActionMedicalCardCreate => 'Create medical card';

  @override
  String get profileQuickActionMedicalCard => 'Medical card';

  @override
  String get profileSectionMesh => 'Mesh status';

  @override
  String get profileSectionTrust => 'Trust level';

  @override
  String get profileSectionSettings => 'Settings';

  @override
  String get profilePubKeyCopied => 'Public key copied';

  @override
  String get profileSettingsAppearance => 'Appearance';

  @override
  String get profileSettingsTextScale => 'Text size';

  @override
  String get profileSettingsLanguage => 'Language';

  @override
  String get profileSettingsBattery => 'Background / Battery';

  @override
  String get profileSettingsPrivacy => 'Privacy & data';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileTextScaleStandard => 'Standard';

  @override
  String get profileTextScaleLarge => 'Large';

  @override
  String get profileTextScaleXLarge => 'X-Large';

  @override
  String get profileTextScaleHuge => 'Huge';

  @override
  String get profileMeshBatteryLabel => 'Battery';

  @override
  String get profileMeshAdvancedLabel => 'Advanced';

  @override
  String profileFooterVersion(String version, String build) {
    return 'IgniRelay v$version · BUILD $build';
  }

  @override
  String get profileFooterTagline => 'OFFLINE · MESH · PRIVATE';

  @override
  String matchHeaderItemsSubtitle(int count) {
    return '$count community items';
  }

  @override
  String get mapAttributionLabel => '© OpenStreetMap contributors';

  @override
  String get supplyItem_WATER_BOTTLE_500 => 'Bottled Water 500ml';

  @override
  String get supplyItem_WATER_BOTTLE_1500 => 'Bottled Water 1.5L';

  @override
  String get supplyItem_WATER_BOTTLE_5000 => 'Bulk Water 5L+';

  @override
  String get supplyItem_WATER_PURIFY_TABLET => 'Water Purification Tablets';

  @override
  String get supplyItem_WATER_PURIFY_STRAW => 'Portable Water Filter';

  @override
  String get supplyItem_WATER_PURIFY_PUMP => 'Hand Pump Water Purifier';

  @override
  String get supplyItem_WATER_CONTAINER_FOLD => 'Collapsible Water Bag (5-20L)';

  @override
  String get supplyItem_WATER_CONTAINER_JERRY => 'Jerry Can (20L)';

  @override
  String get supplyItem_FOOD_READY_CRACKER => 'Crackers/Energy Bars';

  @override
  String get supplyItem_FOOD_READY_CAN => 'Canned Food (meat/beans)';

  @override
  String get supplyItem_FOOD_READY_RETORT => 'Retort Pouch (heat-and-eat)';

  @override
  String get supplyItem_FOOD_READY_MRE => 'MRE (Meal Ready-to-Eat)';

  @override
  String get supplyItem_FOOD_STAPLE_RICE => 'Rice';

  @override
  String get supplyItem_FOOD_STAPLE_NOODLE => 'Instant Noodles';

  @override
  String get supplyItem_FOOD_STAPLE_OATS => 'Oats/Grain Powder';

  @override
  String get supplyItem_FOOD_BABY_FORMULA => 'Baby Formula';

  @override
  String get supplyItem_FOOD_BABY_PUREE => 'Baby Purée';

  @override
  String get supplyItem_FOOD_BABY_BOTTLE => 'Baby Bottle/Cup (with sterilizer)';

  @override
  String get supplyItem_FOOD_SUPP_ELECTROLYTE => 'Electrolyte Powder/ORS';

  @override
  String get supplyItem_FOOD_SUPP_VITAMIN => 'Multivitamins';

  @override
  String get supplyItem_FOOD_SUPP_PROTEIN => 'Protein Drink';

  @override
  String get supplyItem_FOOD_COOK_STOVE => 'Portable Stove';

  @override
  String get supplyItem_FOOD_COOK_FUEL => 'Butane Canister/Fuel';

  @override
  String get supplyItem_FOOD_COOK_UTENSIL =>
      'Disposable Utensils / Foldable Cookware';

  @override
  String get supplyItem_MED_PAIN_ACETAMINOPHEN => 'Acetaminophen (Tylenol)';

  @override
  String get supplyItem_MED_PAIN_IBUPROFEN => 'Ibuprofen';

  @override
  String get supplyItem_MED_PAIN_PATCH => 'Pain Relief Patches/Ointment';

  @override
  String get supplyItem_MED_WOUND_BANDAGE => 'Gauze/Elastic Bandage';

  @override
  String get supplyItem_MED_WOUND_GAUZE => 'Sterile Gauze Pads (4×4)';

  @override
  String get supplyItem_MED_WOUND_ANTISEPTIC => 'Iodine/Saline Solution';

  @override
  String get supplyItem_MED_WOUND_TAPE => 'Medical Tape';

  @override
  String get supplyItem_MED_WOUND_TOURNIQUET => 'Tourniquet (CAT)';

  @override
  String get supplyItem_MED_CHRONIC_BP =>
      'Blood Pressure Medication (as prescribed)';

  @override
  String get supplyItem_MED_CHRONIC_DIABETES => 'Insulin/Diabetes Medication';

  @override
  String get supplyItem_MED_CHRONIC_HEART =>
      'Cardiac Medication (Nitroglycerin, etc.)';

  @override
  String get supplyItem_MED_CHRONIC_EPILEPSY => 'Anti-epileptic Medication';

  @override
  String get supplyItem_MED_RESP_INHALER => 'Asthma Inhaler';

  @override
  String get supplyItem_MED_RESP_MASK_O2 => 'Oxygen Mask/Portable Oxygen';

  @override
  String get supplyItem_MED_GI_ORS => 'Oral Rehydration Salts (ORS)';

  @override
  String get supplyItem_MED_GI_ANTACID => 'Antacid';

  @override
  String get supplyItem_MED_GI_CHARCOAL =>
      'Activated Charcoal (poisoning emergency)';

  @override
  String get supplyItem_MED_KIT_BASIC => 'Basic First Aid Kit';

  @override
  String get supplyItem_MED_KIT_SPLINT => 'Splint/Triangular Bandage';

  @override
  String get supplyItem_MED_KIT_AED => 'AED (Automated External Defibrillator)';

  @override
  String get supplyItem_HYG_FEM_PAD => 'Sanitary Pads';

  @override
  String get supplyItem_HYG_FEM_TAMPON => 'Tampons';

  @override
  String get supplyItem_HYG_FEM_CUP => 'Menstrual Cup (reusable)';

  @override
  String get supplyItem_HYG_BABY_DIAPER => 'Diapers (S/M/L/XL)';

  @override
  String get supplyItem_HYG_BABY_WIPE => 'Baby Wipes (thick)';

  @override
  String get supplyItem_HYG_BABY_CREAM => 'Diaper Cream';

  @override
  String get supplyItem_HYG_PERS_SOAP => 'Soap/Hand Wash';

  @override
  String get supplyItem_HYG_PERS_TOOTH => 'Toothbrush & Toothpaste Set';

  @override
  String get supplyItem_HYG_PERS_TISSUE => 'Toilet Paper/Tissues';

  @override
  String get supplyItem_HYG_PERS_TOWEL => 'Quick-dry Towel';

  @override
  String get supplyItem_HYG_SAN_BLEACH => 'Bleach (disinfection)';

  @override
  String get supplyItem_HYG_SAN_TRASH => 'Heavy-duty Garbage Bags';

  @override
  String get supplyItem_HYG_SAN_GLOVE => 'Disposable Gloves';

  @override
  String get supplyItem_HYG_SAN_BUCKET => 'Collapsible Bucket (cleaning)';

  @override
  String get supplyItem_PROT_RESP_N95 => 'N95 Mask';

  @override
  String get supplyItem_PROT_RESP_SURGICAL => 'Surgical Mask';

  @override
  String get supplyItem_PROT_RESP_GAS => 'Gas Mask/Filter Cartridge';

  @override
  String get supplyItem_PROT_BODY_GLOVES => 'Work Gloves (cut/slip resistant)';

  @override
  String get supplyItem_PROT_BODY_HELMET => 'Hard Hat/Safety Helmet';

  @override
  String get supplyItem_PROT_BODY_BOOTS => 'Safety Boots/Rain Boots';

  @override
  String get supplyItem_PROT_BODY_GOGGLES => 'Safety Goggles';

  @override
  String get supplyItem_PROT_BODY_VEST => 'Reflective Vest';

  @override
  String get supplyItem_PROT_LIGHT_FLASHLIGHT => 'Flashlight/Headlamp';

  @override
  String get supplyItem_PROT_LIGHT_LANTERN => 'Lantern/LED Light';

  @override
  String get supplyItem_PROT_LIGHT_BATTERY => 'Batteries (AA/AAA/D)';

  @override
  String get supplyItem_PROT_LIGHT_CANDLE => 'Candles/Windproof Lighter';

  @override
  String get supplyItem_SHELTER_TEMP_TENT => 'Tent/Tarp Shelter';

  @override
  String get supplyItem_SHELTER_TEMP_TARP =>
      'Waterproof Tarpaulin/Ground Sheet';

  @override
  String get supplyItem_SHELTER_TEMP_ROPE => 'Guy Rope/Tie-down Straps';

  @override
  String get supplyItem_SHELTER_BED_BAG => 'Sleeping Bag';

  @override
  String get supplyItem_SHELTER_BED_MAT => 'Inflatable Pad/Yoga Mat';

  @override
  String get supplyItem_SHELTER_BED_BLANKET => 'Blanket/Emergency Blanket';

  @override
  String get supplyItem_SHELTER_CLOTH_RAIN => 'Raincoat/Waterproof Jacket';

  @override
  String get supplyItem_SHELTER_CLOTH_WARM => 'Thermal Underwear/Fleece Jacket';

  @override
  String get supplyItem_SHELTER_CLOTH_CHANGE => 'Change of Clothes Set';

  @override
  String get supplyItem_TOOL_COMM_RADIO => 'Two-way Radio (UHF/VHF)';

  @override
  String get supplyItem_TOOL_COMM_CHARGER => 'Hand-crank/Solar Charger';

  @override
  String get supplyItem_TOOL_COMM_POWERBANK => 'Power Bank (10000mAh+)';

  @override
  String get supplyItem_TOOL_COMM_WHISTLE => 'Emergency Whistle';

  @override
  String get supplyItem_TOOL_RESCUE_CROWBAR => 'Crowbar/Bolt Cutters';

  @override
  String get supplyItem_TOOL_RESCUE_SHOVEL => 'Folding Shovel';

  @override
  String get supplyItem_TOOL_RESCUE_SAW => 'Folding Hand Saw';

  @override
  String get supplyItem_TOOL_RESCUE_MULTI => 'Multi-tool Pliers';

  @override
  String get supplyItem_TOOL_POWER_GENERATOR => 'Generator';

  @override
  String get supplyItem_TOOL_POWER_SOLAR => 'Solar Charging Panel';

  @override
  String get supplyItem_TOOL_POWER_INVERTER => 'Inverter (12V→110V)';

  @override
  String get supplyItem_TOOL_POWER_EXT => 'Extension Cord/Cable Reel';

  @override
  String get supplyItem_TOOL_TRANS_CART => 'Folding Cart/Hand Truck';

  @override
  String get supplyItem_TOOL_TRANS_STRETCHER => 'Simple Stretcher';

  @override
  String get supplyItem_PET_FOOD_DOG_DRY => 'Dry Dog Food';

  @override
  String get supplyItem_PET_FOOD_DOG_CAN => 'Canned Dog Food';

  @override
  String get supplyItem_PET_FOOD_CAT_DRY => 'Dry Cat Food';

  @override
  String get supplyItem_PET_FOOD_CAT_CAN => 'Canned Cat Food';

  @override
  String get supplyItem_PET_FOOD_BOWL => 'Pet Water/Food Bowl (collapsible)';

  @override
  String get supplyItem_PET_CARE_CRATE => 'Pet Carrier/Crate';

  @override
  String get supplyItem_PET_CARE_LEASH => 'Leash/Harness';

  @override
  String get supplyItem_PET_CARE_PAD => 'Pet Pee Pads';

  @override
  String get supplyItem_PET_CARE_MED => 'Basic Pet Medication (deworming/skin)';

  @override
  String get supplyItem_PET_CARE_TAG => 'Pet ID Tag/Microchip Sticker';

  @override
  String get supplyItem_SKILL_MEDICAL_DOCTOR => 'Doctor';

  @override
  String get supplyItem_SKILL_MEDICAL_NURSE => 'Nurse';

  @override
  String get supplyItem_SKILL_MEDICAL_EMT =>
      'EMT (Emergency Medical Technician)';

  @override
  String get supplyItem_SKILL_MEDICAL_FIRSTAID => 'First Aid Certified';

  @override
  String get supplyItem_SKILL_MEDICAL_PHARMACIST => 'Pharmacist';

  @override
  String get supplyItem_SKILL_RESCUE_FIREFIGHTER =>
      'Firefighter/Rescue Specialist';

  @override
  String get supplyItem_SKILL_RESCUE_DIVER => 'Dive Rescue';

  @override
  String get supplyItem_SKILL_RESCUE_K9 => 'K9 Search & Rescue Handler';

  @override
  String get supplyItem_SKILL_RESCUE_MOUNTAIN => 'Mountain Rescue/Guide';

  @override
  String get supplyItem_SKILL_LANG_EN => 'English Translator';

  @override
  String get supplyItem_SKILL_LANG_JP => 'Japanese Translator';

  @override
  String get supplyItem_SKILL_LANG_SEA => 'Southeast Asian Language Translator';

  @override
  String get supplyItem_SKILL_LANG_SIGN => 'Sign Language Interpreter';

  @override
  String get supplyItem_SKILL_PSYCH_COUNSELOR => 'Psychological Counselor';

  @override
  String get supplyItem_SKILL_PSYCH_SOCIAL => 'Social Worker';

  @override
  String get supplyItem_SKILL_CARE_BABY => 'Infant/Toddler Care';

  @override
  String get supplyItem_SKILL_CARE_ELDER => 'Elderly Care';

  @override
  String get supplyItem_SKILL_CARE_DISABLED => 'Mobility-impaired Care';

  @override
  String get supplyItem_SKILL_CARE_SPECIAL =>
      'Special Needs Companion (dementia/disability)';

  @override
  String get supplyItem_SKILL_TECH_ELECTRIC => 'Electrician/Power Restoration';

  @override
  String get supplyItem_SKILL_TECH_PLUMB => 'Plumber/Water Supply Repair';

  @override
  String get supplyItem_SKILL_TECH_STRUCT => 'Structural Safety Assessment';

  @override
  String get supplyItem_SKILL_TECH_COMM => 'Communications/Network Setup';

  @override
  String get supplyItem_SKILL_TECH_LABOR => 'Manual Labor';

  @override
  String get supplyItem_SKILL_LOG_TRUCK => 'Truck Driver';

  @override
  String get supplyItem_SKILL_LOG_4WD => '4WD/Off-road Driver';

  @override
  String get supplyItem_SKILL_LOG_MOTO => 'Motorcycle Courier (damaged roads)';

  @override
  String get supplyItem_SKILL_LOG_FORKLIFT => 'Forklift Operator';

  @override
  String get supplyItem_SKILL_LOG_HEAVYOP =>
      'Heavy Equipment Operator (excavator/crane)';

  @override
  String get supplyItem_SKILL_LOG_MANAGE => 'Logistics/Warehouse Coordination';

  @override
  String get itemConditionNew => 'Brand New (sealed)';

  @override
  String get itemConditionOpenedUnused => 'Opened but Unused';

  @override
  String get itemConditionUsedFunctional => 'Used but Functional';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonQtyUnit => 'pcs';

  @override
  String get tierLabel1Standard => 'Standard Mode (Tier 1)';

  @override
  String get tierLabel1Force => 'Full Speed Mode (Tier 1)';

  @override
  String get tierLabel2EcoRelay => 'Eco Relay Mode (Tier 2)';

  @override
  String get tierLabel3UltraEco => 'Ultra Eco Mode (Tier 3)';

  @override
  String get supplyCategory_MEDICINE => 'Medical/First Aid';

  @override
  String get supplyCategory_PPE => 'Protective Gear';

  @override
  String get supplySubCategory_WATER_TANK => 'Water Storage Containers';

  @override
  String get supplySubCategory_FOOD_DRY => 'Dry Goods';

  @override
  String get supplySubCategory_FOOD_SPECIAL => 'Special Dietary Needs';

  @override
  String get supplySubCategory_FOOD_DRINK => 'Beverages/Electrolytes';

  @override
  String get supplySubCategory_MED_ANTIBIOTIC => 'Antibiotics/Anti-infection';

  @override
  String get supplySubCategory_MED_KIT => 'First Aid Kits & Equipment';

  @override
  String get supplySubCategory_MED_OTHER => 'Other Medications';

  @override
  String get supplySubCategory_HYG_DIAPER => 'Diapers/Waste Management';

  @override
  String get supplySubCategory_HYG_CLEAN => 'Cleaning & Hygiene';

  @override
  String get supplySubCategory_HYG_PEST => 'Mosquito/Pest Control';

  @override
  String get supplySubCategory_HYG_DISINFECT => 'Environmental Disinfection';

  @override
  String get supplySubCategory_PPE_HEAD => 'Head Protection';

  @override
  String get supplySubCategory_PPE_RESP => 'Respiratory Protection';

  @override
  String get supplySubCategory_PPE_HAND => 'Hand Protection';

  @override
  String get supplySubCategory_PPE_BODY => 'Body Protection';

  @override
  String get supplySubCategory_PPE_WEATHER => 'Weather Protection/Clothing';

  @override
  String get supplySubCategory_SHELTER_TENT => 'Tents/Tarps';

  @override
  String get supplySubCategory_SHELTER_SLEEP => 'Sleeping/Bedding';

  @override
  String get supplySubCategory_SHELTER_THERMAL => 'Emergency Warmth';

  @override
  String get supplySubCategory_SHELTER_SPACE => 'Space Provision';

  @override
  String get supplySubCategory_SHELTER_SUPPLY => 'Shelter Supplies';

  @override
  String get supplySubCategory_TOOL_LIGHT => 'Lighting';

  @override
  String get supplySubCategory_TOOL_BATTERY => 'Batteries (Cylindrical)';

  @override
  String get supplySubCategory_TOOL_BATTERY_COIN => 'Button/Coin Batteries';

  @override
  String get supplySubCategory_TOOL_HAND => 'Hand Tools';

  @override
  String get supplySubCategory_TOOL_REPAIR => 'Repair Supplies';

  @override
  String get supplySubCategory_TOOL_HEAVY => 'Heavy Equipment';

  @override
  String get supplySubCategory_TOOL_DEMOLITION => 'Demolition Tools';

  @override
  String get supplySubCategory_TOOL_CLEANING => 'Cleaning Equipment';

  @override
  String get supplySubCategory_TOOL_SIGNAL => 'Distress Signals';

  @override
  String get supplyItem_WATER_BOTTLE_20L => '20L Large Barrel (Family/Shelter)';

  @override
  String get supplyItem_WATER_PURIFY_FILTER => 'Portable Water Filter';

  @override
  String get supplyItem_WATER_TANK_BARREL => 'Water Storage Barrel';

  @override
  String get supplyItem_WATER_TANK_BAG => 'Collapsible Water Bag';

  @override
  String get supplyItem_FOOD_READY_NOODLE => 'Instant Noodles/Cup Noodles';

  @override
  String get supplyItem_FOOD_READY_BAR => 'Energy Bar/Crackers';

  @override
  String get supplyItem_FOOD_DRY_RICE => 'Dry Rice/Grain';

  @override
  String get supplyItem_FOOD_DRY_BREAD => 'Bread/Toast';

  @override
  String get supplyItem_FOOD_DRY_NUTS => 'Nuts/Dried Fruit';

  @override
  String get supplyItem_FOOD_SPECIAL_HALAL => 'Halal Food';

  @override
  String get supplyItem_FOOD_SPECIAL_VEGAN => 'Vegetarian/Vegan Food';

  @override
  String get supplyItem_FOOD_SPECIAL_GLUTEN => 'Gluten-Free Food';

  @override
  String get supplyItem_FOOD_SPECIAL_DIABETIC =>
      'Low-Sugar/Diabetic-Friendly Food';

  @override
  String get supplyItem_FOOD_COOK_GAS => 'Camping Gas Cartridge';

  @override
  String get supplyItem_FOOD_COOK_SOLID => 'Solid Alcohol/Fuel Gel';

  @override
  String get supplyItem_FOOD_COOK_LIGHTER =>
      'Windproof Lighter/Waterproof Matches';

  @override
  String get supplyItem_FOOD_COOK_POT => 'Camp Cookset/Steel Cup';

  @override
  String get supplyItem_FOOD_DRINK_ELECTRO => 'Sports Drink/Electrolyte Powder';

  @override
  String get supplyItem_FOOD_DRINK_COFFEE => 'Instant Coffee/Tea Bags';

  @override
  String get supplyItem_FOOD_DRINK_JUICE => 'UHT Milk/Juice';

  @override
  String get supplyItem_MED_PAIN_ASPIRIN => 'Aspirin';

  @override
  String get supplyItem_MED_ANTIBIOTIC_AMOX => 'Amoxicillin';

  @override
  String get supplyItem_MED_ANTIBIOTIC_AZITHRO => 'Azithromycin (Z-Pak)';

  @override
  String get supplyItem_MED_ANTIBIOTIC_OINTMENT => 'Antibiotic Ointment';

  @override
  String get supplyItem_MED_CHRONIC_INSULIN => 'Insulin';

  @override
  String get supplyItem_MED_CHRONIC_ASTHMA => 'Asthma Inhaler';

  @override
  String get supplyItem_MED_CHRONIC_THYROID => 'Thyroid Medication';

  @override
  String get supplyItem_MED_WOUND_DISINFECT => 'Disinfectant/Iodine';

  @override
  String get supplyItem_MED_WOUND_SUTURE => 'Steri-Strips/Closure Tape';

  @override
  String get supplyItem_MED_WOUND_SALINE =>
      'Saline Solution (wound irrigation)';

  @override
  String get supplyItem_MED_WOUND_BURN => 'Burn Ointment/Dressing';

  @override
  String get supplyItem_MED_WOUND_SPLINT =>
      'Splint (temporary fracture immobilization)';

  @override
  String get supplyItem_MED_KIT_TRAUMA => 'Trauma First Aid Kit';

  @override
  String get supplyItem_MED_KIT_STRETCHER => 'Folding/Flexible Stretcher';

  @override
  String get supplyItem_MED_OTHER_ANTIDIARRHEAL => 'Anti-diarrheal Medication';

  @override
  String get supplyItem_MED_OTHER_ANTIHISTAMINE => 'Antihistamine (allergy)';

  @override
  String get supplyItem_MED_OTHER_REHYDRATION => 'Oral Rehydration Salts';

  @override
  String get supplyItem_MED_OTHER_EYEDROP => 'Eye Drops/Artificial Tears';

  @override
  String get supplyItem_MED_OTHER_INSECT_BITE => 'Insect Bite Cream';

  @override
  String get supplyItem_HYG_FEM_PAD_DAY => 'Day Pads';

  @override
  String get supplyItem_HYG_FEM_PAD_NIGHT => 'Night Pads';

  @override
  String get supplyItem_HYG_FEM_LINER => 'Panty Liners';

  @override
  String get supplyItem_HYG_DIAPER_BABY_S => 'Baby Diapers S (3-6kg)';

  @override
  String get supplyItem_HYG_DIAPER_BABY_M => 'Baby Diapers M (6-11kg)';

  @override
  String get supplyItem_HYG_DIAPER_BABY_L => 'Baby Diapers L (9-14kg)';

  @override
  String get supplyItem_HYG_DIAPER_BABY_XL => 'Baby Diapers XL (12-17kg)';

  @override
  String get supplyItem_HYG_DIAPER_ADULT => 'Adult Diapers';

  @override
  String get supplyItem_HYG_DIAPER_PORTABLE_TOILET => 'Portable Toilet';

  @override
  String get supplyItem_HYG_DIAPER_SOLIDIFIER => 'Waste Solidifier';

  @override
  String get supplyItem_HYG_DIAPER_TRASH_BAG => 'Large Black Garbage Bags';

  @override
  String get supplyItem_HYG_CLEAN_WET_WIPE => 'Antibacterial Wet Wipes';

  @override
  String get supplyItem_HYG_CLEAN_HAND_GEL => 'Hand Sanitizer Gel';

  @override
  String get supplyItem_HYG_CLEAN_SOAP => 'Bar Soap';

  @override
  String get supplyItem_HYG_CLEAN_TOOTH => 'Toothbrush & Toothpaste Set';

  @override
  String get supplyItem_HYG_CLEAN_SHAMPOO => 'Dry Shampoo/Shampoo';

  @override
  String get supplyItem_HYG_CLEAN_TOWEL => 'Quick-Dry Towel';

  @override
  String get supplyItem_HYG_PEST_REPELLENT =>
      'Insect Repellent (DEET/Picaridin)';

  @override
  String get supplyItem_HYG_PEST_COIL => 'Mosquito Coil/Electric Repellent';

  @override
  String get supplyItem_HYG_PEST_NET => 'Mosquito Net';

  @override
  String get supplyItem_HYG_PEST_ROACH => 'Insecticide (cockroach/fly)';

  @override
  String get supplyItem_HYG_DISINFECT_BLEACH => 'Bleach/Sodium Hypochlorite';

  @override
  String get supplyItem_HYG_DISINFECT_ALCOHOL => '75% Alcohol (disinfecting)';

  @override
  String get supplyItem_HYG_DISINFECT_SPRAY =>
      'Environmental Disinfectant Spray';

  @override
  String get supplyItem_PPE_HEAD_HELMET => 'Hard Hat/Safety Helmet';

  @override
  String get supplyItem_PPE_HEAD_GOGGLES => 'Safety Goggles/Dust Glasses';

  @override
  String get supplyItem_PPE_RESP_N95 => 'N95 Respirator Mask';

  @override
  String get supplyItem_PPE_RESP_DUST => 'Standard Dust Mask';

  @override
  String get supplyItem_PPE_RESP_GAS => 'Gas Mask (chemical/fire)';

  @override
  String get supplyItem_PPE_HAND_CUT => 'Cut-Resistant Work Gloves';

  @override
  String get supplyItem_PPE_HAND_RUBBER =>
      'Rubber Gloves (cleaning/disinfecting)';

  @override
  String get supplyItem_PPE_HAND_LATEX => 'Medical Latex Gloves';

  @override
  String get supplyItem_PPE_BODY_VEST => 'Reflective Safety Vest';

  @override
  String get supplyItem_PPE_BODY_COVERALL => 'Full-Body Protective Suit';

  @override
  String get supplyItem_PPE_BODY_BOOTS => 'Safety Boots/Steel-Toe Rain Boots';

  @override
  String get supplyItem_PPE_WEATHER_PONCHO => 'Disposable Rain Poncho';

  @override
  String get supplyItem_PPE_WEATHER_RAINSUIT => 'Two-Piece Rain Suit';

  @override
  String get supplyItem_PPE_WEATHER_RAINBOOT => 'Rain Boots/Waterproof Boots';

  @override
  String get supplyItem_PPE_WEATHER_WARM => 'Thermal Clothing/Heat Undershirt';

  @override
  String get supplyItem_PPE_WEATHER_JACKET => 'Waterproof Jacket/Windbreaker';

  @override
  String get supplyItem_PPE_WEATHER_HAT => 'Warm Hat/Sun Hat';

  @override
  String get supplyItem_SHELTER_TENT_2P => '2-Person Tent';

  @override
  String get supplyItem_SHELTER_TENT_4P => '4-Person Tent';

  @override
  String get supplyItem_SHELTER_TENT_TARP => 'Waterproof Tarp';

  @override
  String get supplyItem_SHELTER_TENT_PLASTIC =>
      'Waterproof Canvas/Plastic Sheet';

  @override
  String get supplyItem_SHELTER_SLEEP_BAG => 'Sleeping Bag';

  @override
  String get supplyItem_SHELTER_SLEEP_BLANKET => 'Warm Blanket';

  @override
  String get supplyItem_SHELTER_SLEEP_MAT => 'Sleeping Pad';

  @override
  String get supplyItem_SHELTER_SLEEP_AIR => 'Inflatable Air Mattress';

  @override
  String get supplyItem_SHELTER_THERM_SPACE => 'Emergency Space Blanket (foil)';

  @override
  String get supplyItem_SHELTER_THERM_HANDWARMER => 'Hand Warmers';

  @override
  String get supplyItem_SHELTER_THERM_COAT => 'Warm Jacket/Used Clothing';

  @override
  String get supplyItem_SHELTER_SPACE_ROOM => 'Room Available';

  @override
  String get supplyItem_SHELTER_SPACE_GARAGE => 'Garage/Warehouse Available';

  @override
  String get supplyItem_SHELTER_SPACE_LAND =>
      'Open Land Available (tent/parking)';

  @override
  String get supplyItem_SHELTER_SUPPLY_TABLE => 'Folding Tables & Chairs';

  @override
  String get supplyItem_SHELTER_SUPPLY_PARTITION =>
      'Privacy Screen/Curtain Divider';

  @override
  String get supplyItem_SHELTER_SUPPLY_FAN => 'Portable Fan/USB Fan';

  @override
  String get supplyItem_TOOL_LIGHT_FLASH => 'Flashlight';

  @override
  String get supplyItem_TOOL_LIGHT_LANTERN => 'Camping Lantern';

  @override
  String get supplyItem_TOOL_LIGHT_HEADLAMP => 'Headlamp';

  @override
  String get supplyItem_TOOL_LIGHT_GLOWSTICK => 'Glow Stick (no power needed)';

  @override
  String get supplyItem_TOOL_POWER_BANK => 'Power Bank';

  @override
  String get supplyItem_TOOL_POWER_EXTENSION => 'Extension Cord/Power Strip';

  @override
  String get supplyItem_TOOL_BAT_AA => 'AA Batteries (1.5V)';

  @override
  String get supplyItem_TOOL_BAT_AAA => 'AAA Batteries (1.5V)';

  @override
  String get supplyItem_TOOL_BAT_C => 'C Batteries (1.5V)';

  @override
  String get supplyItem_TOOL_BAT_D => 'D Batteries (1.5V)';

  @override
  String get supplyItem_TOOL_BAT_9V => '9V Block Batteries';

  @override
  String get supplyItem_TOOL_BAT_18650 => '18650 Li-ion Batteries (3.7V)';

  @override
  String get supplyItem_TOOL_COIN_CR2032 => 'CR2032 (3V, most common)';

  @override
  String get supplyItem_TOOL_COIN_CR2025 => 'CR2025 (3V)';

  @override
  String get supplyItem_TOOL_COIN_CR2016 => 'CR2016 (3V)';

  @override
  String get supplyItem_TOOL_COIN_LR44 => 'LR44 / AG13 (1.5V)';

  @override
  String get supplyItem_TOOL_COIN_SR626 => 'SR626SW (watch battery 1.55V)';

  @override
  String get supplyItem_TOOL_COMM_WALKIE => 'Walkie-Talkie';

  @override
  String get supplyItem_TOOL_COMM_SAT => 'Satellite Communicator';

  @override
  String get supplyItem_TOOL_RESCUE_ROPE => 'Rope';

  @override
  String get supplyItem_TOOL_RESCUE_AXE => 'Axe/Crowbar';

  @override
  String get supplyItem_TOOL_RESCUE_PARACORD => 'Paracord';

  @override
  String get supplyItem_TOOL_RESCUE_SPRAYPAINT =>
      'Spray Paint (search/rescue marking)';

  @override
  String get supplyItem_TOOL_HAND_SCREWDRIVER_PH => 'Phillips Screwdriver';

  @override
  String get supplyItem_TOOL_HAND_SCREWDRIVER_FLAT => 'Flathead Screwdriver';

  @override
  String get supplyItem_TOOL_HAND_WRENCH => 'Adjustable Wrench';

  @override
  String get supplyItem_TOOL_HAND_HAMMER => 'Hammer';

  @override
  String get supplyItem_TOOL_HAND_SHOVEL => 'Shovel/Spade';

  @override
  String get supplyItem_TOOL_HAND_MULTITOOL => 'Multi-tool/Swiss Army Knife';

  @override
  String get supplyItem_TOOL_HAND_PLIER => 'Pliers/Locking Pliers';

  @override
  String get supplyItem_TOOL_REPAIR_DUCT => 'Duct Tape';

  @override
  String get supplyItem_TOOL_REPAIR_ZIPTIE => 'Zip Ties/Cable Ties';

  @override
  String get supplyItem_TOOL_REPAIR_WIRE => 'Metal Wire/Binding Wire';

  @override
  String get supplyItem_TOOL_REPAIR_SEALANT =>
      'Waterproof Adhesive/Silicone Sealant';

  @override
  String get supplyItem_TOOL_REPAIR_TARP_TAPE => 'Canvas Repair Tape';

  @override
  String get supplyItem_TOOL_TRANSPORT_CAR => 'Vehicle (motorized)';

  @override
  String get supplyItem_TOOL_TRANSPORT_BIKE => 'Bicycle';

  @override
  String get supplyItem_TOOL_TRANSPORT_CART => 'Push Cart/Hand Truck';

  @override
  String get supplyItem_TOOL_TRANSPORT_WHEELBARROW =>
      'Wheelbarrow (rubble transport)';

  @override
  String get supplyItem_TOOL_HEAVY_EXCAVATOR_MINI =>
      'Mini Excavator (narrow access)';

  @override
  String get supplyItem_TOOL_HEAVY_EXCAVATOR_STD => 'Standard Excavator';

  @override
  String get supplyItem_TOOL_HEAVY_BOBCAT_MINI =>
      'Mini Skid Steer (narrow access)';

  @override
  String get supplyItem_TOOL_HEAVY_BOBCAT_STD => 'Standard Skid Steer';

  @override
  String get supplyItem_TOOL_HEAVY_CRANE => 'Crane/Hoist';

  @override
  String get supplyItem_TOOL_HEAVY_LOADER => 'Bulldozer/Loader';

  @override
  String get supplyItem_TOOL_DEMO_JACKHAMMER => 'Electric/Pneumatic Jackhammer';

  @override
  String get supplyItem_TOOL_DEMO_CONCRETE_SAW => 'Concrete Saw/Angle Grinder';

  @override
  String get supplyItem_TOOL_DEMO_HYDRAULIC =>
      'Hydraulic Spreader/Cutter (heavy rescue)';

  @override
  String get supplyItem_TOOL_DEMO_CHAINSAW => 'Chainsaw (tree/brush clearing)';

  @override
  String get supplyItem_TOOL_CLEANING_WASHER => 'Pressure Washer';

  @override
  String get supplyItem_TOOL_CLEANING_PUMP_CLEAN =>
      'Engine Water Pump (clean water)';

  @override
  String get supplyItem_TOOL_CLEANING_PUMP_SLUDGE =>
      'Sludge Pump (wastewater/debris)';

  @override
  String get supplyItem_TOOL_CLEANING_BLOWER =>
      'Industrial Blower (ventilation)';

  @override
  String get supplyItem_TOOL_SIGNAL_FLARE => 'Signal Flare';

  @override
  String get supplyItem_TOOL_SIGNAL_MIRROR => 'Signal Mirror';

  @override
  String get supplyItem_TOOL_SIGNAL_FLAG => 'Distress Flag/Banner';

  @override
  String get supplyItem_TOOL_SIGNAL_STROBE => 'Strobe Emergency Light';
}
