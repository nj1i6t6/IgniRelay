import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 4d Round 2：POI 分類 helper。
///
/// 來源：`map_screen.dart` 原 `_poiCategoryLabel / _poiCategoryId /
/// _poiCategoryColor / _poiCategoryIcon`（約 L878-938）。四個函式都是 pure
/// 資料映射，不依賴 state，抽成 static helper 後可被 `PoiInfoSheet`、
/// `_buildPoiMarkers` 共用。
///
/// 使用模式對齊 `PinPalette`（靜態方法聚合 class）。
class PoiCategories {
  PoiCategories._();

  /// i18n 分類名稱（顯示於 sheet 頂部徽章）。
  static String label(BuildContext context, String cls, String sub) {
    final l = context.l10n;
    if (cls == 'hospital' || sub == 'hospital') return l.mapPoiHospital;
    if (sub == 'clinic' || sub == 'doctors') return l.mapPoiClinic;
    if (sub == 'nursing_home') return l.mapPoiNursingHome;
    if (cls == 'pharmacy' || sub == 'pharmacy') return l.mapPoiPharmacy;
    if (sub == 'police') return l.mapPoiPolice;
    if (sub == 'fire_station') return l.mapPoiFireStation;
    if (sub == 'school' || sub == 'kindergarten') return l.mapPoiSchool;
    if (sub == 'college' || sub == 'university') return l.mapPoiUniversity;
    if (sub == 'supermarket') return l.mapPoiSupermarket;
    if (sub == 'convenience') return l.mapPoiConvenience;
    if (sub == 'mall' || sub == 'department_store') return l.mapPoiMall;
    if (sub == 'fuel') return l.mapPoiGasStation;
    if (sub == 'restaurant') return l.mapPoiRestaurant;
    if (sub == 'cafe') return l.mapPoiCafe;
    if (sub == 'bank') return l.mapPoiBank;
    if (sub == 'post_office') return l.mapPoiPostOffice;
    if (sub == 'place_of_worship') return l.mapPoiReligious;
    if (sub == 'parking') return l.mapPoiParking;
    if (cls == 'shop') return l.mapPoiShop;
    return sub.isNotEmpty ? sub : cls;
  }

  /// 判斷 POI 是否屬於五大救災類別，不屬於則回 null（外部用來過濾）。
  static String? id(String cls, String sub) {
    if (cls == 'hospital' ||
        sub == 'hospital' ||
        sub == 'clinic' ||
        sub == 'doctors' ||
        sub == 'nursing_home') {
      return 'resq_hospital';
    }
    if (cls == 'pharmacy' || sub == 'pharmacy') return 'resq_pharmacy';
    if (sub == 'police' || sub == 'fire_station') return 'resq_police';
    if (sub == 'school' ||
        sub == 'kindergarten' ||
        sub == 'college' ||
        sub == 'university') {
      return 'resq_school';
    }
    if (sub == 'supermarket' ||
        sub == 'convenience' ||
        cls == 'grocery') {
      return 'resq_grocery';
    }
    return null;
  }

  /// 類別底色（marker 圓點 + sheet 徽章共用）。
  static Color color(String cls, String sub) {
    switch (id(cls, sub)) {
      case 'resq_hospital':
        return Colors.red;
      case 'resq_pharmacy':
        return Colors.purple;
      case 'resq_police':
        return const Color(0xFF3366ff);
      case 'resq_school':
        return Colors.orange;
      case 'resq_grocery':
        return Colors.green;
      default:
        return Colors.cyan;
    }
  }

  /// 類別 icon（marker + sheet 共用）。
  static IconData icon(String cls, String sub) {
    if (cls == 'hospital' || sub == 'hospital') return Icons.local_hospital;
    if (sub == 'clinic' || sub == 'doctors') return Icons.medical_services;
    if (sub == 'nursing_home') return Icons.elderly;
    if (cls == 'pharmacy' || sub == 'pharmacy') return Icons.local_pharmacy;
    if (sub == 'police') return Icons.local_police;
    if (sub == 'fire_station') return Icons.fire_truck;
    if (sub == 'school' || sub == 'kindergarten') return Icons.school;
    if (sub == 'college' || sub == 'university') return Icons.account_balance;
    if (sub == 'supermarket' || sub == 'convenience') {
      return Icons.shopping_cart;
    }
    if (cls == 'grocery') return Icons.store;
    return Icons.place;
  }
}
