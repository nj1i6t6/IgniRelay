import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// IgniRelay 烽傳物資類型三級分類資料
// ═══════════════════════════════════════════════════════════════════════════════
//
// 設計原則（基於災區實際需求時間軸）：
//   0-72h 生存期 → WATER, FOOD, MEDICINE, PPE
//   72h-2w 穩定期 → HYGIENE, SHELTER, TOOL
//   2w+   復原期 → SKILL, PETS
//
// 一級：大類別（目前 9 類）
// 二級：子分類（每個大類下數個）
// 三級：具體品項（選填，讓媒合更精確）
//
// 資料屬性：
//   hasExpiry      → 此子分類的品項通常有保存期限（食物、藥品）
//   trackCondition → 此子分類需追蹤品項狀態（全新/已拆封/二手）
// ═══════════════════════════════════════════════════════════════════════════════

class SupplyCategory {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final List<SupplySubCategory> subCategories;

  const SupplyCategory({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
    required this.subCategories,
  });
}

class SupplySubCategory {
  final String code;
  final String label;
  final List<SupplySpecificItem> items;

  /// 此子分類是否建議追蹤有效期限（食物、藥品、化學品等）
  final bool hasExpiry;

  /// 此子分類是否建議追蹤物品狀態（全新未拆封/已拆封/二手堪用）
  final bool trackCondition;

  const SupplySubCategory({
    required this.code,
    required this.label,
    this.items = const [],
    this.hasExpiry = false,
    this.trackCondition = false,
  });
}

class SupplySpecificItem {
  final String code;
  final String label;

  const SupplySpecificItem({required this.code, required this.label});
}

/// 物品狀態枚舉（供 trackCondition == true 的子分類使用）
enum ItemCondition {
  brandNew('全新未拆封'),
  openedUnused('已拆封未使用'),
  usedGood('二手堪用');

  final String label;
  const ItemCondition(this.label);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 全部物資分類樹
// ═══════════════════════════════════════════════════════════════════════════════

const List<SupplyCategory> supplyCategories = [
  // ─────────────────────────────────────────────────────────────────────────
  // 1. 飲用水 — 災後最優先，成人每日需 2-3L
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'WATER',
    label: '飲用水',
    icon: Icons.water_drop,
    color: Colors.blue,
    subCategories: [
      SupplySubCategory(
          code: 'WATER_BOTTLE',
          label: '瓶裝水',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'WATER_BOTTLE_500', label: '500ml'),
            SupplySpecificItem(code: 'WATER_BOTTLE_1500', label: '1.5L'),
            SupplySpecificItem(code: 'WATER_BOTTLE_5000', label: '5L 桶裝'),
            SupplySpecificItem(
                code: 'WATER_BOTTLE_20L', label: '20L 大桶 (家庭/收容所)'),
          ]),
      SupplySubCategory(
          code: 'WATER_PURIFY',
          label: '淨水用品',
          hasExpiry: true,
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'WATER_PURIFY_TABLET', label: '淨水片'),
            SupplySpecificItem(code: 'WATER_PURIFY_FILTER', label: '攜帶型濾水器'),
            SupplySpecificItem(code: 'WATER_PURIFY_STRAW', label: '淨水吸管'),
          ]),
      SupplySubCategory(code: 'WATER_TANK', label: '儲水設備', items: [
        SupplySpecificItem(code: 'WATER_TANK_BARREL', label: '儲水桶'),
        SupplySpecificItem(code: 'WATER_TANK_BAG', label: '可折疊水袋'),
      ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 2. 食物 — 含即食、乾糧、特殊需求、加熱烹飪
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'FOOD',
    label: '食物',
    icon: Icons.fastfood,
    color: Colors.orange,
    subCategories: [
      SupplySubCategory(
          code: 'FOOD_READY',
          label: '即食食品',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'FOOD_READY_CAN', label: '罐頭食品'),
            SupplySpecificItem(code: 'FOOD_READY_NOODLE', label: '即食麵/泡麵'),
            SupplySpecificItem(code: 'FOOD_READY_BAR', label: '能量棒/餅乾'),
            SupplySpecificItem(code: 'FOOD_READY_MRE', label: '自熱軍糧 MRE'),
          ]),
      SupplySubCategory(code: 'FOOD_DRY', label: '乾糧', hasExpiry: true, items: [
        SupplySpecificItem(code: 'FOOD_DRY_RICE', label: '乾飯/米'),
        SupplySpecificItem(code: 'FOOD_DRY_BREAD', label: '麵包/吐司'),
        SupplySpecificItem(code: 'FOOD_DRY_NUTS', label: '堅果/果乾'),
      ]),
      SupplySubCategory(
          code: 'FOOD_BABY',
          label: '嬰幼兒食品',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'FOOD_BABY_FORMULA', label: '奶粉'),
            SupplySpecificItem(code: 'FOOD_BABY_PUREE', label: '嬰兒副食品'),
            SupplySpecificItem(code: 'FOOD_BABY_BOTTLE', label: '奶瓶/安撫奶嘴'),
          ]),
      SupplySubCategory(
          code: 'FOOD_SPECIAL',
          label: '特殊飲食',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'FOOD_SPECIAL_HALAL', label: '清真食品'),
            SupplySpecificItem(code: 'FOOD_SPECIAL_VEGAN', label: '素食'),
            SupplySpecificItem(code: 'FOOD_SPECIAL_GLUTEN', label: '無麩質'),
            SupplySpecificItem(
                code: 'FOOD_SPECIAL_DIABETIC', label: '低糖/糖尿病適用'),
          ]),
      SupplySubCategory(code: 'FOOD_COOKING', label: '加熱與烹飪', items: [
        SupplySpecificItem(code: 'FOOD_COOK_STOVE', label: '卡式爐 (攜帶型瓦斯爐)'),
        SupplySpecificItem(code: 'FOOD_COOK_GAS', label: '卡式瓦斯罐'),
        SupplySpecificItem(code: 'FOOD_COOK_SOLID', label: '固體酒精/酒精膏'),
        SupplySpecificItem(code: 'FOOD_COOK_LIGHTER', label: '防風打火機/防水火柴'),
        SupplySpecificItem(code: 'FOOD_COOK_POT', label: '野炊鍋組/鋼杯'),
        SupplySpecificItem(code: 'FOOD_COOK_UTENSIL', label: '免洗餐具/環保餐具'),
      ]),
      SupplySubCategory(
          code: 'FOOD_DRINK',
          label: '飲品/電解質',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'FOOD_DRINK_ELECTRO', label: '運動飲料/電解質粉'),
            SupplySpecificItem(code: 'FOOD_DRINK_COFFEE', label: '即溶咖啡/茶包'),
            SupplySpecificItem(code: 'FOOD_DRINK_JUICE', label: '保久乳/果汁'),
          ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 3. 藥品/急救 — 外傷、慢性病、燒燙傷、感染預防
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'MEDICINE',
    label: '藥品/急救',
    icon: Icons.medication,
    color: Colors.red,
    subCategories: [
      SupplySubCategory(
          code: 'MED_PAIN',
          label: '止痛退燒',
          hasExpiry: true,
          items: [
            SupplySpecificItem(
                code: 'MED_PAIN_ACETAMINOPHEN', label: '普拿疼(乙醯胺酚)'),
            SupplySpecificItem(code: 'MED_PAIN_IBUPROFEN', label: '布洛芬'),
            SupplySpecificItem(code: 'MED_PAIN_ASPIRIN', label: '阿斯匹靈'),
          ]),
      SupplySubCategory(
          code: 'MED_ANTIBIOTIC',
          label: '抗生素/抗感染',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'MED_ANTIBIOTIC_AMOX', label: '阿莫西林'),
            SupplySpecificItem(
                code: 'MED_ANTIBIOTIC_AZITHRO', label: '日舒(阿奇黴素)'),
            SupplySpecificItem(code: 'MED_ANTIBIOTIC_OINTMENT', label: '抗生素藥膏'),
          ]),
      SupplySubCategory(
          code: 'MED_CHRONIC',
          label: '慢性病用藥',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'MED_CHRONIC_INSULIN', label: '胰島素'),
            SupplySpecificItem(code: 'MED_CHRONIC_BP', label: '降血壓藥'),
            SupplySpecificItem(code: 'MED_CHRONIC_HEART', label: '心臟病藥'),
            SupplySpecificItem(code: 'MED_CHRONIC_ASTHMA', label: '氣喘吸入劑'),
            SupplySpecificItem(code: 'MED_CHRONIC_EPILEPSY', label: '抗癲癇藥'),
            SupplySpecificItem(code: 'MED_CHRONIC_THYROID', label: '甲狀腺藥物'),
          ]),
      SupplySubCategory(
          code: 'MED_WOUND',
          label: '傷口處理',
          hasExpiry: true,
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'MED_WOUND_BANDAGE', label: '繃帶/紗布'),
            SupplySpecificItem(code: 'MED_WOUND_DISINFECT', label: '消毒液/碘酒'),
            SupplySpecificItem(code: 'MED_WOUND_SUTURE', label: '縫合膠帶'),
            SupplySpecificItem(code: 'MED_WOUND_TOURNIQUET', label: '止血帶'),
            SupplySpecificItem(code: 'MED_WOUND_SALINE', label: '生理食鹽水 (沖洗傷口)'),
            SupplySpecificItem(code: 'MED_WOUND_BURN', label: '燒燙傷藥膏/敷料'),
            SupplySpecificItem(
                code: 'MED_WOUND_SPLINT', label: '固定夾板 (骨折臨時固定)'),
          ]),
      SupplySubCategory(
          code: 'MED_KIT',
          label: '急救包',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'MED_KIT_BASIC', label: '基礎急救包'),
            SupplySpecificItem(code: 'MED_KIT_TRAUMA', label: '外傷急救包'),
            SupplySpecificItem(code: 'MED_KIT_AED', label: 'AED 除顫器'),
            SupplySpecificItem(code: 'MED_KIT_STRETCHER', label: '摺疊擔架/軟式擔架'),
          ]),
      SupplySubCategory(
          code: 'MED_OTHER',
          label: '其他藥品',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'MED_OTHER_ANTIDIARRHEAL', label: '止瀉藥'),
            SupplySpecificItem(
                code: 'MED_OTHER_ANTIHISTAMINE', label: '抗組織胺(過敏)'),
            SupplySpecificItem(code: 'MED_OTHER_REHYDRATION', label: '口服補液鹽'),
            SupplySpecificItem(code: 'MED_OTHER_EYEDROP', label: '眼藥水/人工淚液'),
            SupplySpecificItem(code: 'MED_OTHER_INSECT_BITE', label: '蚊蟲叮咬藥膏'),
          ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 4. 衛生/生理用品 — 防止傳染病爆發，維持災民尊嚴
  //    災區最容易被忽略，但疫情（腸胃炎/登革熱/皮膚感染）
  //    往往造成比災害本身更多的二次傷亡
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'HYGIENE',
    label: '衛生/生理',
    icon: Icons.clean_hands,
    color: Colors.teal,
    subCategories: [
      SupplySubCategory(
          code: 'HYG_FEMININE',
          label: '女性生理用品',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'HYG_FEM_PAD_DAY', label: '日用衛生棉'),
            SupplySpecificItem(code: 'HYG_FEM_PAD_NIGHT', label: '夜用衛生棉'),
            SupplySpecificItem(code: 'HYG_FEM_TAMPON', label: '衛生棉條'),
            SupplySpecificItem(code: 'HYG_FEM_LINER', label: '護墊'),
          ]),
      SupplySubCategory(
          code: 'HYG_DIAPER',
          label: '尿布/排泄處理',
          trackCondition: true,
          items: [
            SupplySpecificItem(
                code: 'HYG_DIAPER_BABY_S', label: '嬰兒尿布 S (3-6kg)'),
            SupplySpecificItem(
                code: 'HYG_DIAPER_BABY_M', label: '嬰兒尿布 M (6-11kg)'),
            SupplySpecificItem(
                code: 'HYG_DIAPER_BABY_L', label: '嬰兒尿布 L (9-14kg)'),
            SupplySpecificItem(
                code: 'HYG_DIAPER_BABY_XL', label: '嬰兒尿布 XL (12-17kg)'),
            SupplySpecificItem(code: 'HYG_DIAPER_ADULT', label: '成人紙尿褲'),
            SupplySpecificItem(
                code: 'HYG_DIAPER_PORTABLE_TOILET', label: '攜帶式馬桶/行動廁所'),
            SupplySpecificItem(code: 'HYG_DIAPER_SOLIDIFIER', label: '排泄物凝固劑'),
            SupplySpecificItem(
                code: 'HYG_DIAPER_TRASH_BAG', label: '黑色大垃圾袋 (裝廢棄物/遮蔽/防雨)'),
          ]),
      SupplySubCategory(code: 'HYG_CLEAN', label: '清潔消毒', items: [
        SupplySpecificItem(code: 'HYG_CLEAN_WET_WIPE', label: '抗菌濕紙巾 (缺水時擦澡)'),
        SupplySpecificItem(code: 'HYG_CLEAN_HAND_GEL', label: '乾洗手液'),
        SupplySpecificItem(code: 'HYG_CLEAN_SOAP', label: '肥皂'),
        SupplySpecificItem(code: 'HYG_CLEAN_TOOTH', label: '牙刷牙膏組'),
        SupplySpecificItem(code: 'HYG_CLEAN_SHAMPOO', label: '乾洗髮噴霧/洗髮乳'),
        SupplySpecificItem(code: 'HYG_CLEAN_TOWEL', label: '速乾毛巾'),
      ]),
      SupplySubCategory(code: 'HYG_PEST', label: '防蚊防蟲', items: [
        SupplySpecificItem(
            code: 'HYG_PEST_REPELLENT', label: '防蚊液 (DEET/派卡瑞丁)'),
        SupplySpecificItem(code: 'HYG_PEST_COIL', label: '蚊香/電蚊香'),
        SupplySpecificItem(code: 'HYG_PEST_NET', label: '蚊帳'),
        SupplySpecificItem(code: 'HYG_PEST_ROACH', label: '殺蟲劑 (水災後蟑螂/蒼蠅)'),
      ]),
      SupplySubCategory(
          code: 'HYG_DISINFECT',
          label: '環境消毒',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'HYG_DISINFECT_BLEACH', label: '漂白水/次氯酸鈉'),
            SupplySpecificItem(
                code: 'HYG_DISINFECT_ALCOHOL', label: '75%酒精 (消毒用)'),
            SupplySpecificItem(code: 'HYG_DISINFECT_SPRAY', label: '環境消毒噴劑'),
          ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 5. 個人防護裝備 (PPE) — 搜救/清理/逃生時的身體防護
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'PPE',
    label: '防護裝備',
    icon: Icons.shield,
    color: Colors.amber,
    subCategories: [
      SupplySubCategory(
          code: 'PPE_HEAD',
          label: '頭部防護',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'PPE_HEAD_HELMET', label: '工程安全帽'),
            SupplySpecificItem(code: 'PPE_HEAD_GOGGLES', label: '護目鏡/防塵眼鏡'),
          ]),
      SupplySubCategory(
          code: 'PPE_RESP',
          label: '呼吸防護',
          trackCondition: true,
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'PPE_RESP_N95', label: 'N95 口罩'),
            SupplySpecificItem(code: 'PPE_RESP_DUST', label: '一般防塵口罩'),
            SupplySpecificItem(code: 'PPE_RESP_GAS', label: '防毒面罩 (化學洩漏/火災)'),
          ]),
      SupplySubCategory(
          code: 'PPE_HAND',
          label: '手部防護',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'PPE_HAND_CUT', label: '防割工作手套 (搬運瓦礫必備)'),
            SupplySpecificItem(code: 'PPE_HAND_RUBBER', label: '橡膠手套 (清淤/消毒)'),
            SupplySpecificItem(code: 'PPE_HAND_LATEX', label: '醫療乳膠手套'),
          ]),
      SupplySubCategory(
          code: 'PPE_BODY',
          label: '身體防護',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'PPE_BODY_VEST', label: '反光背心'),
            SupplySpecificItem(code: 'PPE_BODY_COVERALL', label: '連身防護衣'),
            SupplySpecificItem(code: 'PPE_BODY_BOOTS', label: '安全鞋/鋼頭雨靴 (防刺穿)'),
          ]),
      SupplySubCategory(
          code: 'PPE_WEATHER',
          label: '氣候防護/衣物',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'PPE_WEATHER_PONCHO', label: '輕便雨衣 (拋棄式)'),
            SupplySpecificItem(code: 'PPE_WEATHER_RAINSUIT', label: '兩截式雨衣'),
            SupplySpecificItem(code: 'PPE_WEATHER_RAINBOOT', label: '雨鞋/防水靴'),
            SupplySpecificItem(code: 'PPE_WEATHER_WARM', label: '保暖衣物/發熱衣'),
            SupplySpecificItem(code: 'PPE_WEATHER_JACKET', label: '防水外套/風衣'),
            SupplySpecificItem(code: 'PPE_WEATHER_HAT', label: '保暖帽/遮陽帽'),
          ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 6. 住所/避難 — 帳篷、寢具、禦寒、空間提供
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'SHELTER',
    label: '住所/避難',
    icon: Icons.home,
    color: Colors.green,
    subCategories: [
      SupplySubCategory(
          code: 'SHELTER_TENT',
          label: '帳篷/遮蔽',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'SHELTER_TENT_2P', label: '2人帳篷'),
            SupplySpecificItem(code: 'SHELTER_TENT_4P', label: '4人帳篷'),
            SupplySpecificItem(code: 'SHELTER_TENT_TARP', label: '防水天幕'),
            SupplySpecificItem(
                code: 'SHELTER_TENT_PLASTIC', label: '防水帆布/塑膠布 (多用途)'),
          ]),
      SupplySubCategory(
          code: 'SHELTER_SLEEP',
          label: '保暖寢具',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'SHELTER_SLEEP_BAG', label: '睡袋'),
            SupplySpecificItem(code: 'SHELTER_SLEEP_BLANKET', label: '保暖毯'),
            SupplySpecificItem(code: 'SHELTER_SLEEP_MAT', label: '睡墊'),
            SupplySpecificItem(code: 'SHELTER_SLEEP_AIR', label: '充氣床墊'),
          ]),
      SupplySubCategory(code: 'SHELTER_THERMAL', label: '緊急禦寒', items: [
        SupplySpecificItem(
            code: 'SHELTER_THERM_SPACE', label: '急救保溫毯 (Space Blanket，鋁箔)'),
        SupplySpecificItem(code: 'SHELTER_THERM_HANDWARMER', label: '暖暖包'),
        SupplySpecificItem(code: 'SHELTER_THERM_COAT', label: '保暖外套/二手衣物'),
      ]),
      SupplySubCategory(code: 'SHELTER_SPACE', label: '空間提供', items: [
        SupplySpecificItem(code: 'SHELTER_SPACE_ROOM', label: '可提供房間'),
        SupplySpecificItem(code: 'SHELTER_SPACE_GARAGE', label: '可提供車庫/倉庫'),
        SupplySpecificItem(code: 'SHELTER_SPACE_LAND', label: '可提供空地 (搭帳篷/停車)'),
      ]),
      SupplySubCategory(code: 'SHELTER_SUPPLY', label: '收容所耗材', items: [
        SupplySpecificItem(code: 'SHELTER_SUPPLY_TABLE', label: '摺疊桌椅'),
        SupplySpecificItem(code: 'SHELTER_SUPPLY_PARTITION', label: '隔間屏風/隔簾'),
        SupplySpecificItem(code: 'SHELTER_SUPPLY_FAN', label: '攜帶式風扇/USB風扇'),
      ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 7. 工具/設備 — 照明、電力、通訊、搜救、手工具、修繕、重機具、清理
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'TOOL',
    label: '工具/設備',
    icon: Icons.build,
    color: Colors.grey,
    subCategories: [
      SupplySubCategory(
          code: 'TOOL_LIGHT',
          label: '照明',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'TOOL_LIGHT_FLASH', label: '手電筒'),
            SupplySpecificItem(code: 'TOOL_LIGHT_LANTERN', label: '露營燈'),
            SupplySpecificItem(code: 'TOOL_LIGHT_HEADLAMP', label: '頭燈'),
            SupplySpecificItem(
                code: 'TOOL_LIGHT_GLOWSTICK', label: '螢光棒 (不需電力)'),
          ]),
      SupplySubCategory(
          code: 'TOOL_POWER',
          label: '電力/能源',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'TOOL_POWER_BANK', label: '行動電源'),
            SupplySpecificItem(code: 'TOOL_POWER_SOLAR', label: '太陽能充電板'),
            SupplySpecificItem(code: 'TOOL_POWER_GENERATOR', label: '發電機'),
            SupplySpecificItem(code: 'TOOL_POWER_EXTENSION', label: '延長線/排插'),
          ]),
      SupplySubCategory(code: 'TOOL_BATTERY', label: '乾電池 (圓筒型)', items: [
        SupplySpecificItem(code: 'TOOL_BAT_AA', label: '3號電池 (AA 1.5V)'),
        SupplySpecificItem(code: 'TOOL_BAT_AAA', label: '4號電池 (AAA 1.5V)'),
        SupplySpecificItem(code: 'TOOL_BAT_C', label: '2號電池 (C 1.5V)'),
        SupplySpecificItem(code: 'TOOL_BAT_D', label: '1號電池 (D 1.5V)'),
        SupplySpecificItem(code: 'TOOL_BAT_9V', label: '9V 方型電池'),
        SupplySpecificItem(code: 'TOOL_BAT_18650', label: '18650 鋰電池 (3.7V)'),
      ]),
      SupplySubCategory(code: 'TOOL_BATTERY_COIN', label: '鈕扣電池', items: [
        SupplySpecificItem(code: 'TOOL_COIN_CR2032', label: 'CR2032 (3V 最常見)'),
        SupplySpecificItem(code: 'TOOL_COIN_CR2025', label: 'CR2025 (3V)'),
        SupplySpecificItem(code: 'TOOL_COIN_CR2016', label: 'CR2016 (3V)'),
        SupplySpecificItem(code: 'TOOL_COIN_LR44', label: 'LR44 / AG13 (1.5V)'),
        SupplySpecificItem(
            code: 'TOOL_COIN_SR626', label: 'SR626SW (手錶電池 1.55V)'),
      ]),
      SupplySubCategory(
          code: 'TOOL_COMM',
          label: '通訊',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'TOOL_COMM_RADIO', label: '收音機'),
            SupplySpecificItem(code: 'TOOL_COMM_WALKIE', label: '對講機'),
            SupplySpecificItem(code: 'TOOL_COMM_SAT', label: '衛星通訊器'),
            SupplySpecificItem(code: 'TOOL_COMM_WHISTLE', label: '求救哨子 (不需電力)'),
          ]),
      SupplySubCategory(
          code: 'TOOL_RESCUE',
          label: '搜救工具',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'TOOL_RESCUE_ROPE', label: '繩索'),
            SupplySpecificItem(code: 'TOOL_RESCUE_AXE', label: '斧頭/撬棒'),
            SupplySpecificItem(code: 'TOOL_RESCUE_SAW', label: '摺疊鋸'),
            SupplySpecificItem(
                code: 'TOOL_RESCUE_PARACORD', label: '傘繩 (Paracord)'),
            SupplySpecificItem(
                code: 'TOOL_RESCUE_SPRAYPAINT', label: '噴漆 (建物搜救標記)'),
          ]),
      SupplySubCategory(
          code: 'TOOL_HAND',
          label: '手工具',
          trackCondition: true,
          items: [
            SupplySpecificItem(
                code: 'TOOL_HAND_SCREWDRIVER_PH', label: '十字螺絲起子'),
            SupplySpecificItem(
                code: 'TOOL_HAND_SCREWDRIVER_FLAT', label: '一字螺絲起子'),
            SupplySpecificItem(code: 'TOOL_HAND_WRENCH', label: '活動扳手 (可調尺寸)'),
            SupplySpecificItem(code: 'TOOL_HAND_HAMMER', label: '鐵鎚'),
            SupplySpecificItem(code: 'TOOL_HAND_SHOVEL', label: '鏟子/圓鍬'),
            SupplySpecificItem(
                code: 'TOOL_HAND_MULTITOOL', label: '多功能工具鉗/瑞士刀'),
            SupplySpecificItem(code: 'TOOL_HAND_PLIER', label: '鉗子/老虎鉗'),
          ]),
      SupplySubCategory(code: 'TOOL_REPAIR', label: '修繕耗材', items: [
        SupplySpecificItem(code: 'TOOL_REPAIR_DUCT', label: '大力膠帶 (Duct Tape)'),
        SupplySpecificItem(code: 'TOOL_REPAIR_ZIPTIE', label: '束線帶/紮帶'),
        SupplySpecificItem(code: 'TOOL_REPAIR_WIRE', label: '鐵絲/綁線'),
        SupplySpecificItem(code: 'TOOL_REPAIR_SEALANT', label: '防水膠/矽利康'),
        SupplySpecificItem(code: 'TOOL_REPAIR_TARP_TAPE', label: '帆布修補膠帶'),
      ]),
      SupplySubCategory(code: 'TOOL_TRANSPORT', label: '運輸', items: [
        SupplySpecificItem(code: 'TOOL_TRANSPORT_CAR', label: '車輛(機動)'),
        SupplySpecificItem(code: 'TOOL_TRANSPORT_BIKE', label: '腳踏車'),
        SupplySpecificItem(code: 'TOOL_TRANSPORT_CART', label: '推車'),
        SupplySpecificItem(
            code: 'TOOL_TRANSPORT_WHEELBARROW', label: '手推車/獨輪車 (搬運瓦礫)'),
      ]),
      SupplySubCategory(code: 'TOOL_HEAVY', label: '重型機具 (工程車)', items: [
        SupplySpecificItem(
            code: 'TOOL_HEAVY_EXCAVATOR_MINI', label: '微型怪手 (可入戶/狹窄巷弄)'),
        SupplySpecificItem(
            code: 'TOOL_HEAVY_EXCAVATOR_STD', label: '標準怪手 (大型挖掘)'),
        SupplySpecificItem(
            code: 'TOOL_HEAVY_BOBCAT_MINI', label: '微型山貓 (可入戶/滑移裝載)'),
        SupplySpecificItem(
            code: 'TOOL_HEAVY_BOBCAT_STD', label: '標準山貓 (滑移裝載機)'),
        SupplySpecificItem(code: 'TOOL_HEAVY_CRANE', label: '吊車/起重機'),
        SupplySpecificItem(code: 'TOOL_HEAVY_LOADER', label: '鏟土機/推土機'),
      ]),
      SupplySubCategory(code: 'TOOL_DEMOLITION', label: '破拆與結構破壞', items: [
        SupplySpecificItem(code: 'TOOL_DEMO_JACKHAMMER', label: '電動/氣動打石機'),
        SupplySpecificItem(
            code: 'TOOL_DEMO_CONCRETE_SAW', label: '混凝土切割機/引擎砂輪機'),
        SupplySpecificItem(
            code: 'TOOL_DEMO_HYDRAULIC', label: '液壓破壞剪/撐開器 (重型救援)'),
        SupplySpecificItem(code: 'TOOL_DEMO_CHAINSAW', label: '動力鏈鋸 (伐木/路樹清理)'),
      ]),
      SupplySubCategory(code: 'TOOL_CLEANING', label: '清理與動力設備', items: [
        SupplySpecificItem(
            code: 'TOOL_CLEANING_WASHER', label: '高壓清洗機 (強力噴水槍)'),
        SupplySpecificItem(
            code: 'TOOL_CLEANING_PUMP_CLEAN', label: '引擎抽水馬達 (清水泵，高揚程)'),
        SupplySpecificItem(
            code: 'TOOL_CLEANING_PUMP_SLUDGE', label: '污泥泵 (廢水/污泥專用，耐雜質)'),
        SupplySpecificItem(
            code: 'TOOL_CLEANING_BLOWER', label: '工業排風機 (地下室排煙/換氣)'),
      ]),
      SupplySubCategory(code: 'TOOL_SIGNAL', label: '求救信號', items: [
        SupplySpecificItem(code: 'TOOL_SIGNAL_FLARE', label: '信號彈'),
        SupplySpecificItem(code: 'TOOL_SIGNAL_MIRROR', label: '信號鏡 (反光求救)'),
        SupplySpecificItem(code: 'TOOL_SIGNAL_FLAG', label: '求救旗幟/布條'),
        SupplySpecificItem(code: 'TOOL_SIGNAL_STROBE', label: '閃光求救燈'),
      ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 8. 寵物用品 — 許多災民因無法安置寵物而拒絕撤離
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'PETS',
    label: '寵物用品',
    icon: Icons.pets,
    color: Colors.brown,
    subCategories: [
      SupplySubCategory(
          code: 'PET_FOOD',
          label: '寵物食品',
          hasExpiry: true,
          items: [
            SupplySpecificItem(code: 'PET_FOOD_DOG_DRY', label: '狗乾糧'),
            SupplySpecificItem(code: 'PET_FOOD_DOG_CAN', label: '狗罐頭'),
            SupplySpecificItem(code: 'PET_FOOD_CAT_DRY', label: '貓乾糧'),
            SupplySpecificItem(code: 'PET_FOOD_CAT_CAN', label: '貓罐頭'),
            SupplySpecificItem(code: 'PET_FOOD_BOWL', label: '寵物飲水/食碗 (可折疊)'),
          ]),
      SupplySubCategory(
          code: 'PET_CARE',
          label: '安置與照護',
          trackCondition: true,
          items: [
            SupplySpecificItem(code: 'PET_CARE_CRATE', label: '外出籠/寵物提包'),
            SupplySpecificItem(code: 'PET_CARE_LEASH', label: '牽繩/胸背帶'),
            SupplySpecificItem(code: 'PET_CARE_PAD', label: '寵物尿布墊'),
            SupplySpecificItem(code: 'PET_CARE_MED', label: '寵物基礎藥品 (驅蟲/皮膚)'),
            SupplySpecificItem(code: 'PET_CARE_TAG', label: '防走失吊牌/晶片貼紙'),
          ]),
    ],
  ),

  // ─────────────────────────────────────────────────────────────────────────
  // 9. 技能服務 — 醫療、搜救、翻譯、心理、照護、後勤
  // ─────────────────────────────────────────────────────────────────────────
  SupplyCategory(
    code: 'SKILL',
    label: '技能服務',
    icon: Icons.volunteer_activism,
    color: Colors.purple,
    subCategories: [
      SupplySubCategory(code: 'SKILL_MEDICAL', label: '醫療', items: [
        SupplySpecificItem(code: 'SKILL_MEDICAL_DOCTOR', label: '醫師'),
        SupplySpecificItem(code: 'SKILL_MEDICAL_NURSE', label: '護理師'),
        SupplySpecificItem(code: 'SKILL_MEDICAL_EMT', label: '急救員 (EMT)'),
        SupplySpecificItem(code: 'SKILL_MEDICAL_FIRSTAID', label: '急救證照持有者'),
        SupplySpecificItem(code: 'SKILL_MEDICAL_PHARMACIST', label: '藥劑師'),
      ]),
      SupplySubCategory(code: 'SKILL_RESCUE', label: '搜救', items: [
        SupplySpecificItem(code: 'SKILL_RESCUE_FIREFIGHTER', label: '消防/搜救專業'),
        SupplySpecificItem(code: 'SKILL_RESCUE_DIVER', label: '潛水搜救'),
        SupplySpecificItem(code: 'SKILL_RESCUE_K9', label: '搜救犬領犬員'),
        SupplySpecificItem(code: 'SKILL_RESCUE_MOUNTAIN', label: '山域搜救/嚮導'),
      ]),
      SupplySubCategory(code: 'SKILL_LANG', label: '翻譯/語言', items: [
        SupplySpecificItem(code: 'SKILL_LANG_EN', label: '英語翻譯'),
        SupplySpecificItem(code: 'SKILL_LANG_JP', label: '日語翻譯'),
        SupplySpecificItem(code: 'SKILL_LANG_SEA', label: '東南亞語翻譯'),
        SupplySpecificItem(code: 'SKILL_LANG_SIGN', label: '手語翻譯'),
      ]),
      SupplySubCategory(code: 'SKILL_PSYCH', label: '心理輔導', items: [
        SupplySpecificItem(code: 'SKILL_PSYCH_COUNSELOR', label: '心理諮商師'),
        SupplySpecificItem(code: 'SKILL_PSYCH_SOCIAL', label: '社工人員'),
      ]),
      SupplySubCategory(code: 'SKILL_CARE', label: '照護服務', items: [
        SupplySpecificItem(code: 'SKILL_CARE_BABY', label: '嬰幼兒托育'),
        SupplySpecificItem(code: 'SKILL_CARE_ELDER', label: '老人照護'),
        SupplySpecificItem(code: 'SKILL_CARE_DISABLED', label: '行動不便者照護'),
        SupplySpecificItem(code: 'SKILL_CARE_SPECIAL', label: '特殊需求陪伴 (失智/身障)'),
      ]),
      SupplySubCategory(code: 'SKILL_TECH', label: '技術', items: [
        SupplySpecificItem(code: 'SKILL_TECH_ELECTRIC', label: '電工/電力修復'),
        SupplySpecificItem(code: 'SKILL_TECH_PLUMB', label: '水管/給水修復'),
        SupplySpecificItem(code: 'SKILL_TECH_STRUCT', label: '結構安全評估'),
        SupplySpecificItem(code: 'SKILL_TECH_COMM', label: '通訊工程/網路架設'),
        SupplySpecificItem(code: 'SKILL_TECH_LABOR', label: '壯丁/勞力需求'),
      ]),
      SupplySubCategory(code: 'SKILL_LOGISTICS', label: '後勤/駕駛', items: [
        SupplySpecificItem(code: 'SKILL_LOG_TRUCK', label: '大貨車駕駛'),
        SupplySpecificItem(code: 'SKILL_LOG_4WD', label: '四輪傳動車/越野駕駛'),
        SupplySpecificItem(code: 'SKILL_LOG_MOTO', label: '機車外送/快遞 (殘破道路)'),
        SupplySpecificItem(code: 'SKILL_LOG_FORKLIFT', label: '堆高機操作'),
        SupplySpecificItem(code: 'SKILL_LOG_HEAVYOP', label: '重機具操作員 (怪手/吊車)'),
        SupplySpecificItem(code: 'SKILL_LOG_MANAGE', label: '物流管理/倉儲調度'),
      ]),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// 輔助查詢函式
// ═══════════════════════════════════════════════════════════════════════════════

/// 根據 code 找到對應的分類
SupplyCategory? findCategory(String code) {
  try {
    return supplyCategories.firstWhere((c) => c.code == code);
  } catch (_) {
    return null;
  }
}

/// 根據 code 找到子分類
SupplySubCategory? findSubCategory(String categoryCode, String subCode) {
  final cat = findCategory(categoryCode);
  if (cat == null) return null;
  try {
    return cat.subCategories.firstWhere((s) => s.code == subCode);
  } catch (_) {
    return null;
  }
}

/// 取得完整的人可讀名稱 (例如 "藥品/急救 → 止痛退燒 → 普拿疼")
/// 支援多種格式：
///   - 單一 code: "WATER_BOTTLE_500"
///   - `/` 分隔的多層 code: "WATER/WATER_BOTTLE/WATER_BOTTLE_500"
String getReadableName(String fullCode) {
  // 如果包含 `/`，取最具體的（最後一段）來查詢
  final segments = fullCode.split('/');
  // 從最具體到最不具體依序嘗試
  for (int s = segments.length - 1; s >= 0; s--) {
    final code = segments[s];
    for (final cat in supplyCategories) {
      if (code == cat.code) return cat.label;
      for (final sub in cat.subCategories) {
        if (code == sub.code) return '${cat.label} → ${sub.label}';
        for (final item in sub.items) {
          if (code == item.code) {
            return '${cat.label} → ${sub.label} → ${item.label}';
          }
        }
      }
    }
  }
  return fullCode;
}

/// Locale-aware version of [getReadableName].
/// Returns translated labels using [SupplyCategoryLocalizer].
/// Falls back to [getReadableName] if context is unavailable.
String getLocalizedReadableName(String fullCode, BuildContext ctx) {
  final segments = fullCode.split('/');
  for (int s = segments.length - 1; s >= 0; s--) {
    final code = segments[s];
    for (final cat in supplyCategories) {
      if (code == cat.code) {
        return SupplyCategoryLocalizer.categoryLabel(ctx, cat.code);
      }
      for (final sub in cat.subCategories) {
        if (code == sub.code) {
          final catLabel = SupplyCategoryLocalizer.categoryLabel(ctx, cat.code);
          final subLabel = SupplyCategoryLocalizer.subCategoryLabel(ctx, sub.code);
          return '$catLabel → $subLabel';
        }
        for (final item in sub.items) {
          if (code == item.code) {
            final catLabel = SupplyCategoryLocalizer.categoryLabel(ctx, cat.code);
            final subLabel = SupplyCategoryLocalizer.subCategoryLabel(ctx, sub.code);
            final itemLabel = SupplyCategoryLocalizer.itemLabel(ctx, item.code);
            return '$catLabel → $subLabel → $itemLabel';
          }
        }
      }
    }
  }
  return fullCode;
}

/// 根據任意層級 code 找到對應的子分類（用於判斷 hasExpiry / trackCondition）
SupplySubCategory? findSubCategoryByItemCode(String code) {
  for (final cat in supplyCategories) {
    for (final sub in cat.subCategories) {
      if (sub.code == code) return sub;
      for (final item in sub.items) {
        if (item.code == code) return sub;
      }
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Localized label helpers (BuildContext-aware)
// ─────────────────────────────────────────────────────────────────────────────

extension ItemConditionL10n on ItemCondition {
  String localLabel(BuildContext context) {
    final l = context.l10n;
    switch (this) {
      case ItemCondition.brandNew: return l.itemConditionNew;
      case ItemCondition.openedUnused: return l.itemConditionOpenedUnused;
      case ItemCondition.usedGood: return l.itemConditionUsedFunctional;
    }
  }
}

class SupplyCategoryLocalizer {
  static String categoryLabel(BuildContext ctx, String code) {
    final l = ctx.l10n;
    switch (code) {
      case 'WATER': return l.supplyCategory_WATER;
      case 'FOOD': return l.supplyCategory_FOOD;
      case 'MEDICINE': return l.supplyCategory_MEDICINE;
      case 'MEDICAL': return l.supplyCategory_MEDICINE;   // backward compat
      case 'HYGIENE': return l.supplyCategory_HYGIENE;
      case 'PPE': return l.supplyCategory_PPE;
      case 'PROTECTION': return l.supplyCategory_PPE;      // backward compat
      case 'SHELTER': return l.supplyCategory_SHELTER;
      case 'TOOL': return l.supplyCategory_TOOL;
      case 'PETS': return l.supplyCategory_PETS;
      case 'SKILL': return l.supplyCategory_SKILL;
      default: return code;
    }
  }

  static String subCategoryLabel(BuildContext ctx, String code) {
    final l = ctx.l10n;
    switch (code) {
      // ── Water ──
      case 'WATER_BOTTLE': return l.supplySubCategory_WATER_BOTTLE;
      case 'WATER_PURIFY': return l.supplySubCategory_WATER_PURIFY;
      case 'WATER_TANK': return l.supplySubCategory_WATER_TANK;
      case 'WATER_CONTAINER': return l.supplySubCategory_WATER_TANK;       // backward compat
      // ── Food ──
      case 'FOOD_READY': return l.supplySubCategory_FOOD_READY;
      case 'FOOD_DRY': return l.supplySubCategory_FOOD_DRY;
      case 'FOOD_STAPLE': return l.supplySubCategory_FOOD_DRY;             // backward compat
      case 'FOOD_BABY': return l.supplySubCategory_FOOD_BABY;
      case 'FOOD_SPECIAL': return l.supplySubCategory_FOOD_SPECIAL;
      case 'FOOD_SUPPLEMENT': return l.supplySubCategory_FOOD_SPECIAL;     // backward compat
      case 'FOOD_COOKING': return l.supplySubCategory_FOOD_COOKING;
      case 'FOOD_DRINK': return l.supplySubCategory_FOOD_DRINK;
      // ── Medicine ──
      case 'MED_PAIN': return l.supplySubCategory_MED_PAIN;
      case 'MED_ANTIBIOTIC': return l.supplySubCategory_MED_ANTIBIOTIC;
      case 'MED_CHRONIC': return l.supplySubCategory_MED_CHRONIC;
      case 'MED_WOUND': return l.supplySubCategory_MED_WOUND;
      case 'MED_KIT': return l.supplySubCategory_MED_KIT;
      case 'MED_FIRSTAID_KIT': return l.supplySubCategory_MED_KIT;         // backward compat
      case 'MED_OTHER': return l.supplySubCategory_MED_OTHER;
      case 'MED_RESPIRATORY': return l.supplySubCategory_MED_RESPIRATORY;  // backward compat (old code kept in ARB)
      case 'MED_GI': return l.supplySubCategory_MED_GI;                   // backward compat
      // ── Hygiene ──
      case 'HYG_FEMININE': return l.supplySubCategory_HYG_FEMININE;
      case 'HYG_DIAPER': return l.supplySubCategory_HYG_DIAPER;
      case 'HYG_BABY': return l.supplySubCategory_HYG_DIAPER;             // backward compat
      case 'HYG_CLEAN': return l.supplySubCategory_HYG_CLEAN;
      case 'HYG_PERSONAL': return l.supplySubCategory_HYG_CLEAN;          // backward compat
      case 'HYG_PEST': return l.supplySubCategory_HYG_PEST;
      case 'HYG_DISINFECT': return l.supplySubCategory_HYG_DISINFECT;
      case 'HYG_SANITATION': return l.supplySubCategory_HYG_DISINFECT;    // backward compat
      // ── PPE ──
      case 'PPE_HEAD': return l.supplySubCategory_PPE_HEAD;
      case 'PPE_RESP': return l.supplySubCategory_PPE_RESP;
      case 'PROT_RESPIRATORY': return l.supplySubCategory_PPE_RESP;        // backward compat
      case 'PPE_HAND': return l.supplySubCategory_PPE_HAND;
      case 'PPE_BODY': return l.supplySubCategory_PPE_BODY;
      case 'PROT_BODY': return l.supplySubCategory_PPE_BODY;               // backward compat
      case 'PPE_WEATHER': return l.supplySubCategory_PPE_WEATHER;
      case 'PROT_LIGHT': return l.supplySubCategory_TOOL_LIGHT;            // backward compat → lighting
      // ── Shelter ──
      case 'SHELTER_TENT': return l.supplySubCategory_SHELTER_TENT;
      case 'SHELTER_TEMP': return l.supplySubCategory_SHELTER_TENT;        // backward compat
      case 'SHELTER_SLEEP': return l.supplySubCategory_SHELTER_SLEEP;
      case 'SHELTER_BEDDING': return l.supplySubCategory_SHELTER_SLEEP;    // backward compat
      case 'SHELTER_THERMAL': return l.supplySubCategory_SHELTER_THERMAL;
      case 'SHELTER_CLOTHING': return l.supplySubCategory_SHELTER_THERMAL; // backward compat
      case 'SHELTER_SPACE': return l.supplySubCategory_SHELTER_SPACE;
      case 'SHELTER_SUPPLY': return l.supplySubCategory_SHELTER_SUPPLY;
      // ── Tools ──
      case 'TOOL_LIGHT': return l.supplySubCategory_TOOL_LIGHT;
      case 'TOOL_POWER': return l.supplySubCategory_TOOL_POWER;
      case 'TOOL_BATTERY': return l.supplySubCategory_TOOL_BATTERY;
      case 'TOOL_BATTERY_COIN': return l.supplySubCategory_TOOL_BATTERY_COIN;
      case 'TOOL_COMM': return l.supplySubCategory_TOOL_COMM;
      case 'TOOL_RESCUE': return l.supplySubCategory_TOOL_RESCUE;
      case 'TOOL_HAND': return l.supplySubCategory_TOOL_HAND;
      case 'TOOL_REPAIR': return l.supplySubCategory_TOOL_REPAIR;
      case 'TOOL_TRANSPORT': return l.supplySubCategory_TOOL_TRANSPORT;
      case 'TOOL_HEAVY': return l.supplySubCategory_TOOL_HEAVY;
      case 'TOOL_DEMOLITION': return l.supplySubCategory_TOOL_DEMOLITION;
      case 'TOOL_CLEANING': return l.supplySubCategory_TOOL_CLEANING;
      case 'TOOL_SIGNAL': return l.supplySubCategory_TOOL_SIGNAL;
      // ── Pets ──
      case 'PET_FOOD': return l.supplySubCategory_PET_FOOD;
      case 'PET_CARE': return l.supplySubCategory_PET_CARE;
      // ── Skills ──
      case 'SKILL_MEDICAL': return l.supplySubCategory_SKILL_MEDICAL;
      case 'SKILL_RESCUE': return l.supplySubCategory_SKILL_RESCUE;
      case 'SKILL_LANG': return l.supplySubCategory_SKILL_LANG;
      case 'SKILL_PSYCH': return l.supplySubCategory_SKILL_PSYCH;
      case 'SKILL_CARE': return l.supplySubCategory_SKILL_CARE;
      case 'SKILL_TECH': return l.supplySubCategory_SKILL_TECH;
      case 'SKILL_LOGISTICS': return l.supplySubCategory_SKILL_LOGISTICS;
      default: return code;
    }
  }

  static String itemLabel(BuildContext ctx, String code) {
    final l = ctx.l10n;
    switch (code) {
      // ── Water ──
      case 'WATER_BOTTLE_500': return l.supplyItem_WATER_BOTTLE_500;
      case 'WATER_BOTTLE_1500': return l.supplyItem_WATER_BOTTLE_1500;
      case 'WATER_BOTTLE_5000': return l.supplyItem_WATER_BOTTLE_5000;
      case 'WATER_BOTTLE_20L': return l.supplyItem_WATER_BOTTLE_20L;
      case 'WATER_PURIFY_TABLET': return l.supplyItem_WATER_PURIFY_TABLET;
      case 'WATER_PURIFY_FILTER': return l.supplyItem_WATER_PURIFY_FILTER;
      case 'WATER_PURIFY_STRAW': return l.supplyItem_WATER_PURIFY_STRAW;
      case 'WATER_PURIFY_PUMP': return l.supplyItem_WATER_PURIFY_FILTER;   // backward compat
      case 'WATER_TANK_BARREL': return l.supplyItem_WATER_TANK_BARREL;
      case 'WATER_TANK_BAG': return l.supplyItem_WATER_TANK_BAG;
      case 'WATER_CONTAINER_FOLD': return l.supplyItem_WATER_TANK_BAG;     // backward compat
      case 'WATER_CONTAINER_JERRY': return l.supplyItem_WATER_TANK_BARREL; // backward compat
      // ── Food ──
      case 'FOOD_READY_CAN': return l.supplyItem_FOOD_READY_CAN;
      case 'FOOD_READY_NOODLE': return l.supplyItem_FOOD_READY_NOODLE;
      case 'FOOD_READY_BAR': return l.supplyItem_FOOD_READY_BAR;
      case 'FOOD_READY_MRE': return l.supplyItem_FOOD_READY_MRE;
      case 'FOOD_READY_CRACKER': return l.supplyItem_FOOD_READY_BAR;       // backward compat
      case 'FOOD_READY_RETORT': return l.supplyItem_FOOD_READY_MRE;        // backward compat
      case 'FOOD_DRY_RICE': return l.supplyItem_FOOD_DRY_RICE;
      case 'FOOD_DRY_BREAD': return l.supplyItem_FOOD_DRY_BREAD;
      case 'FOOD_DRY_NUTS': return l.supplyItem_FOOD_DRY_NUTS;
      case 'FOOD_STAPLE_RICE': return l.supplyItem_FOOD_DRY_RICE;          // backward compat
      case 'FOOD_STAPLE_NOODLE': return l.supplyItem_FOOD_READY_NOODLE;    // backward compat
      case 'FOOD_STAPLE_OATS': return l.supplyItem_FOOD_DRY_NUTS;          // backward compat
      case 'FOOD_BABY_FORMULA': return l.supplyItem_FOOD_BABY_FORMULA;
      case 'FOOD_BABY_PUREE': return l.supplyItem_FOOD_BABY_PUREE;
      case 'FOOD_BABY_BOTTLE': return l.supplyItem_FOOD_BABY_BOTTLE;
      case 'FOOD_SPECIAL_HALAL': return l.supplyItem_FOOD_SPECIAL_HALAL;
      case 'FOOD_SPECIAL_VEGAN': return l.supplyItem_FOOD_SPECIAL_VEGAN;
      case 'FOOD_SPECIAL_GLUTEN': return l.supplyItem_FOOD_SPECIAL_GLUTEN;
      case 'FOOD_SPECIAL_DIABETIC': return l.supplyItem_FOOD_SPECIAL_DIABETIC;
      case 'FOOD_COOK_STOVE': return l.supplyItem_FOOD_COOK_STOVE;
      case 'FOOD_COOK_GAS': return l.supplyItem_FOOD_COOK_GAS;
      case 'FOOD_COOK_SOLID': return l.supplyItem_FOOD_COOK_SOLID;
      case 'FOOD_COOK_LIGHTER': return l.supplyItem_FOOD_COOK_LIGHTER;
      case 'FOOD_COOK_POT': return l.supplyItem_FOOD_COOK_POT;
      case 'FOOD_COOK_UTENSIL': return l.supplyItem_FOOD_COOK_UTENSIL;
      case 'FOOD_COOK_FUEL': return l.supplyItem_FOOD_COOK_GAS;            // backward compat
      case 'FOOD_DRINK_ELECTRO': return l.supplyItem_FOOD_DRINK_ELECTRO;
      case 'FOOD_DRINK_COFFEE': return l.supplyItem_FOOD_DRINK_COFFEE;
      case 'FOOD_DRINK_JUICE': return l.supplyItem_FOOD_DRINK_JUICE;
      case 'FOOD_SUPP_ELECTROLYTE': return l.supplyItem_FOOD_DRINK_ELECTRO; // backward compat
      case 'FOOD_SUPP_VITAMIN': return l.supplyItem_FOOD_DRY_NUTS;          // backward compat (best match)
      case 'FOOD_SUPP_PROTEIN': return l.supplyItem_FOOD_DRY_NUTS;          // backward compat
      // ── Medicine ──
      case 'MED_PAIN_ACETAMINOPHEN': return l.supplyItem_MED_PAIN_ACETAMINOPHEN;
      case 'MED_PAIN_IBUPROFEN': return l.supplyItem_MED_PAIN_IBUPROFEN;
      case 'MED_PAIN_ASPIRIN': return l.supplyItem_MED_PAIN_ASPIRIN;
      case 'MED_PAIN_PATCH': return l.supplyItem_MED_PAIN_ACETAMINOPHEN;    // backward compat
      case 'MED_ANTIBIOTIC_AMOX': return l.supplyItem_MED_ANTIBIOTIC_AMOX;
      case 'MED_ANTIBIOTIC_AZITHRO': return l.supplyItem_MED_ANTIBIOTIC_AZITHRO;
      case 'MED_ANTIBIOTIC_OINTMENT': return l.supplyItem_MED_ANTIBIOTIC_OINTMENT;
      case 'MED_CHRONIC_INSULIN': return l.supplyItem_MED_CHRONIC_INSULIN;
      case 'MED_CHRONIC_BP': return l.supplyItem_MED_CHRONIC_BP;
      case 'MED_CHRONIC_HEART': return l.supplyItem_MED_CHRONIC_HEART;
      case 'MED_CHRONIC_ASTHMA': return l.supplyItem_MED_CHRONIC_ASTHMA;
      case 'MED_CHRONIC_EPILEPSY': return l.supplyItem_MED_CHRONIC_EPILEPSY;
      case 'MED_CHRONIC_THYROID': return l.supplyItem_MED_CHRONIC_THYROID;
      case 'MED_CHRONIC_DIABETES': return l.supplyItem_MED_CHRONIC_BP;      // backward compat
      case 'MED_WOUND_BANDAGE': return l.supplyItem_MED_WOUND_BANDAGE;
      case 'MED_WOUND_DISINFECT': return l.supplyItem_MED_WOUND_DISINFECT;
      case 'MED_WOUND_SUTURE': return l.supplyItem_MED_WOUND_SUTURE;
      case 'MED_WOUND_TOURNIQUET': return l.supplyItem_MED_WOUND_TOURNIQUET;
      case 'MED_WOUND_SALINE': return l.supplyItem_MED_WOUND_SALINE;
      case 'MED_WOUND_BURN': return l.supplyItem_MED_WOUND_BURN;
      case 'MED_WOUND_SPLINT': return l.supplyItem_MED_WOUND_SPLINT;
      case 'MED_WOUND_GAUZE': return l.supplyItem_MED_WOUND_BANDAGE;        // backward compat
      case 'MED_WOUND_ANTISEPTIC': return l.supplyItem_MED_WOUND_DISINFECT; // backward compat
      case 'MED_WOUND_TAPE': return l.supplyItem_MED_WOUND_SUTURE;          // backward compat
      case 'MED_KIT_BASIC': return l.supplyItem_MED_KIT_BASIC;
      case 'MED_KIT_TRAUMA': return l.supplyItem_MED_KIT_TRAUMA;
      case 'MED_KIT_AED': return l.supplyItem_MED_KIT_AED;
      case 'MED_KIT_STRETCHER': return l.supplyItem_MED_KIT_STRETCHER;
      case 'MED_KIT_SPLINT': return l.supplyItem_MED_WOUND_SPLINT;          // backward compat
      case 'MED_OTHER_ANTIDIARRHEAL': return l.supplyItem_MED_OTHER_ANTIDIARRHEAL;
      case 'MED_OTHER_ANTIHISTAMINE': return l.supplyItem_MED_OTHER_ANTIHISTAMINE;
      case 'MED_OTHER_REHYDRATION': return l.supplyItem_MED_OTHER_REHYDRATION;
      case 'MED_OTHER_EYEDROP': return l.supplyItem_MED_OTHER_EYEDROP;
      case 'MED_OTHER_INSECT_BITE': return l.supplyItem_MED_OTHER_INSECT_BITE;
      case 'MED_RESP_INHALER': return l.supplyItem_MED_CHRONIC_ASTHMA;      // backward compat
      case 'MED_RESP_MASK_O2': return l.supplyItem_PPE_RESP_N95;            // backward compat
      case 'MED_GI_ORS': return l.supplyItem_MED_OTHER_REHYDRATION;         // backward compat
      case 'MED_GI_ANTACID': return l.supplyItem_MED_OTHER_ANTIDIARRHEAL;   // backward compat
      case 'MED_GI_CHARCOAL': return l.supplyItem_MED_OTHER_ANTIDIARRHEAL;  // backward compat
      // ── Hygiene ──
      case 'HYG_FEM_PAD_DAY': return l.supplyItem_HYG_FEM_PAD_DAY;
      case 'HYG_FEM_PAD_NIGHT': return l.supplyItem_HYG_FEM_PAD_NIGHT;
      case 'HYG_FEM_TAMPON': return l.supplyItem_HYG_FEM_TAMPON;
      case 'HYG_FEM_LINER': return l.supplyItem_HYG_FEM_LINER;
      case 'HYG_FEM_PAD': return l.supplyItem_HYG_FEM_PAD_DAY;             // backward compat
      case 'HYG_FEM_CUP': return l.supplyItem_HYG_FEM_TAMPON;              // backward compat
      case 'HYG_DIAPER_BABY_S': return l.supplyItem_HYG_DIAPER_BABY_S;
      case 'HYG_DIAPER_BABY_M': return l.supplyItem_HYG_DIAPER_BABY_M;
      case 'HYG_DIAPER_BABY_L': return l.supplyItem_HYG_DIAPER_BABY_L;
      case 'HYG_DIAPER_BABY_XL': return l.supplyItem_HYG_DIAPER_BABY_XL;
      case 'HYG_DIAPER_ADULT': return l.supplyItem_HYG_DIAPER_ADULT;
      case 'HYG_DIAPER_PORTABLE_TOILET': return l.supplyItem_HYG_DIAPER_PORTABLE_TOILET;
      case 'HYG_DIAPER_SOLIDIFIER': return l.supplyItem_HYG_DIAPER_SOLIDIFIER;
      case 'HYG_DIAPER_TRASH_BAG': return l.supplyItem_HYG_DIAPER_TRASH_BAG;
      case 'HYG_BABY_DIAPER': return l.supplyItem_HYG_DIAPER_BABY_M;       // backward compat
      case 'HYG_BABY_WIPE': return l.supplyItem_HYG_CLEAN_WET_WIPE;        // backward compat
      case 'HYG_BABY_CREAM': return l.supplyItem_MED_OTHER_INSECT_BITE;     // backward compat
      case 'HYG_CLEAN_WET_WIPE': return l.supplyItem_HYG_CLEAN_WET_WIPE;
      case 'HYG_CLEAN_HAND_GEL': return l.supplyItem_HYG_CLEAN_HAND_GEL;
      case 'HYG_CLEAN_SOAP': return l.supplyItem_HYG_CLEAN_SOAP;
      case 'HYG_CLEAN_TOOTH': return l.supplyItem_HYG_CLEAN_TOOTH;
      case 'HYG_CLEAN_SHAMPOO': return l.supplyItem_HYG_CLEAN_SHAMPOO;
      case 'HYG_CLEAN_TOWEL': return l.supplyItem_HYG_CLEAN_TOWEL;
      case 'HYG_PERS_SOAP': return l.supplyItem_HYG_CLEAN_SOAP;            // backward compat
      case 'HYG_PERS_TOOTH': return l.supplyItem_HYG_CLEAN_TOOTH;          // backward compat
      case 'HYG_PERS_TISSUE': return l.supplyItem_HYG_CLEAN_WET_WIPE;      // backward compat
      case 'HYG_PERS_TOWEL': return l.supplyItem_HYG_CLEAN_TOWEL;          // backward compat
      case 'HYG_PEST_REPELLENT': return l.supplyItem_HYG_PEST_REPELLENT;
      case 'HYG_PEST_COIL': return l.supplyItem_HYG_PEST_COIL;
      case 'HYG_PEST_NET': return l.supplyItem_HYG_PEST_NET;
      case 'HYG_PEST_ROACH': return l.supplyItem_HYG_PEST_ROACH;
      case 'HYG_DISINFECT_BLEACH': return l.supplyItem_HYG_DISINFECT_BLEACH;
      case 'HYG_DISINFECT_ALCOHOL': return l.supplyItem_HYG_DISINFECT_ALCOHOL;
      case 'HYG_DISINFECT_SPRAY': return l.supplyItem_HYG_DISINFECT_SPRAY;
      case 'HYG_SAN_BLEACH': return l.supplyItem_HYG_DISINFECT_BLEACH;     // backward compat
      case 'HYG_SAN_TRASH': return l.supplyItem_HYG_DIAPER_TRASH_BAG;      // backward compat
      case 'HYG_SAN_GLOVE': return l.supplyItem_PPE_HAND_RUBBER;           // backward compat
      case 'HYG_SAN_BUCKET': return l.supplyItem_WATER_TANK_BARREL;        // backward compat
      // ── PPE ──
      case 'PPE_HEAD_HELMET': return l.supplyItem_PPE_HEAD_HELMET;
      case 'PPE_HEAD_GOGGLES': return l.supplyItem_PPE_HEAD_GOGGLES;
      case 'PPE_RESP_N95': return l.supplyItem_PPE_RESP_N95;
      case 'PPE_RESP_DUST': return l.supplyItem_PPE_RESP_DUST;
      case 'PPE_RESP_GAS': return l.supplyItem_PPE_RESP_GAS;
      case 'PPE_HAND_CUT': return l.supplyItem_PPE_HAND_CUT;
      case 'PPE_HAND_RUBBER': return l.supplyItem_PPE_HAND_RUBBER;
      case 'PPE_HAND_LATEX': return l.supplyItem_PPE_HAND_LATEX;
      case 'PPE_BODY_VEST': return l.supplyItem_PPE_BODY_VEST;
      case 'PPE_BODY_COVERALL': return l.supplyItem_PPE_BODY_COVERALL;
      case 'PPE_BODY_BOOTS': return l.supplyItem_PPE_BODY_BOOTS;
      case 'PPE_WEATHER_PONCHO': return l.supplyItem_PPE_WEATHER_PONCHO;
      case 'PPE_WEATHER_RAINSUIT': return l.supplyItem_PPE_WEATHER_RAINSUIT;
      case 'PPE_WEATHER_RAINBOOT': return l.supplyItem_PPE_WEATHER_RAINBOOT;
      case 'PPE_WEATHER_WARM': return l.supplyItem_PPE_WEATHER_WARM;
      case 'PPE_WEATHER_JACKET': return l.supplyItem_PPE_WEATHER_JACKET;
      case 'PPE_WEATHER_HAT': return l.supplyItem_PPE_WEATHER_HAT;
      case 'PROT_RESP_N95': return l.supplyItem_PPE_RESP_N95;              // backward compat
      case 'PROT_RESP_SURGICAL': return l.supplyItem_PPE_RESP_DUST;        // backward compat
      case 'PROT_RESP_GAS': return l.supplyItem_PPE_RESP_GAS;              // backward compat
      case 'PROT_BODY_GLOVES': return l.supplyItem_PPE_HAND_CUT;           // backward compat
      case 'PROT_BODY_HELMET': return l.supplyItem_PPE_HEAD_HELMET;        // backward compat
      case 'PROT_BODY_BOOTS': return l.supplyItem_PPE_BODY_BOOTS;          // backward compat
      case 'PROT_BODY_GOGGLES': return l.supplyItem_PPE_HEAD_GOGGLES;      // backward compat
      case 'PROT_BODY_VEST': return l.supplyItem_PPE_BODY_VEST;            // backward compat
      case 'PROT_LIGHT_FLASHLIGHT': return l.supplyItem_TOOL_LIGHT_FLASH;  // backward compat
      case 'PROT_LIGHT_LANTERN': return l.supplyItem_TOOL_LIGHT_LANTERN;   // backward compat
      case 'PROT_LIGHT_BATTERY': return l.supplyItem_TOOL_BAT_AA;          // backward compat
      case 'PROT_LIGHT_CANDLE': return l.supplyItem_TOOL_LIGHT_GLOWSTICK;  // backward compat
      // ── Shelter ──
      case 'SHELTER_TENT_2P': return l.supplyItem_SHELTER_TENT_2P;
      case 'SHELTER_TENT_4P': return l.supplyItem_SHELTER_TENT_4P;
      case 'SHELTER_TENT_TARP': return l.supplyItem_SHELTER_TENT_TARP;
      case 'SHELTER_TENT_PLASTIC': return l.supplyItem_SHELTER_TENT_PLASTIC;
      case 'SHELTER_SLEEP_BAG': return l.supplyItem_SHELTER_SLEEP_BAG;
      case 'SHELTER_SLEEP_BLANKET': return l.supplyItem_SHELTER_SLEEP_BLANKET;
      case 'SHELTER_SLEEP_MAT': return l.supplyItem_SHELTER_SLEEP_MAT;
      case 'SHELTER_SLEEP_AIR': return l.supplyItem_SHELTER_SLEEP_AIR;
      case 'SHELTER_THERM_SPACE': return l.supplyItem_SHELTER_THERM_SPACE;
      case 'SHELTER_THERM_HANDWARMER': return l.supplyItem_SHELTER_THERM_HANDWARMER;
      case 'SHELTER_THERM_COAT': return l.supplyItem_SHELTER_THERM_COAT;
      case 'SHELTER_SPACE_ROOM': return l.supplyItem_SHELTER_SPACE_ROOM;
      case 'SHELTER_SPACE_GARAGE': return l.supplyItem_SHELTER_SPACE_GARAGE;
      case 'SHELTER_SPACE_LAND': return l.supplyItem_SHELTER_SPACE_LAND;
      case 'SHELTER_SUPPLY_TABLE': return l.supplyItem_SHELTER_SUPPLY_TABLE;
      case 'SHELTER_SUPPLY_PARTITION': return l.supplyItem_SHELTER_SUPPLY_PARTITION;
      case 'SHELTER_SUPPLY_FAN': return l.supplyItem_SHELTER_SUPPLY_FAN;
      case 'SHELTER_TEMP_TENT': return l.supplyItem_SHELTER_TENT_TARP;     // backward compat
      case 'SHELTER_TEMP_TARP': return l.supplyItem_SHELTER_TENT_TARP;     // backward compat
      case 'SHELTER_TEMP_ROPE': return l.supplyItem_TOOL_RESCUE_ROPE;      // backward compat
      case 'SHELTER_BED_BAG': return l.supplyItem_SHELTER_SLEEP_BAG;       // backward compat
      case 'SHELTER_BED_MAT': return l.supplyItem_SHELTER_SLEEP_MAT;       // backward compat
      case 'SHELTER_BED_BLANKET': return l.supplyItem_SHELTER_SLEEP_BLANKET; // backward compat
      case 'SHELTER_CLOTH_RAIN': return l.supplyItem_PPE_WEATHER_PONCHO;   // backward compat
      case 'SHELTER_CLOTH_WARM': return l.supplyItem_PPE_WEATHER_WARM;     // backward compat
      case 'SHELTER_CLOTH_CHANGE': return l.supplyItem_SHELTER_THERM_COAT; // backward compat
      // ── Tools ──
      case 'TOOL_LIGHT_FLASH': return l.supplyItem_TOOL_LIGHT_FLASH;
      case 'TOOL_LIGHT_LANTERN': return l.supplyItem_TOOL_LIGHT_LANTERN;
      case 'TOOL_LIGHT_HEADLAMP': return l.supplyItem_TOOL_LIGHT_HEADLAMP;
      case 'TOOL_LIGHT_GLOWSTICK': return l.supplyItem_TOOL_LIGHT_GLOWSTICK;
      case 'TOOL_POWER_BANK': return l.supplyItem_TOOL_POWER_BANK;
      case 'TOOL_POWER_SOLAR': return l.supplyItem_TOOL_POWER_SOLAR;
      case 'TOOL_POWER_GENERATOR': return l.supplyItem_TOOL_POWER_GENERATOR;
      case 'TOOL_POWER_EXTENSION': return l.supplyItem_TOOL_POWER_EXTENSION;
      case 'TOOL_POWER_INVERTER': return l.supplyItem_TOOL_POWER_EXTENSION;  // backward compat
      case 'TOOL_POWER_EXT': return l.supplyItem_TOOL_POWER_EXTENSION;      // backward compat
      case 'TOOL_BAT_AA': return l.supplyItem_TOOL_BAT_AA;
      case 'TOOL_BAT_AAA': return l.supplyItem_TOOL_BAT_AAA;
      case 'TOOL_BAT_C': return l.supplyItem_TOOL_BAT_C;
      case 'TOOL_BAT_D': return l.supplyItem_TOOL_BAT_D;
      case 'TOOL_BAT_9V': return l.supplyItem_TOOL_BAT_9V;
      case 'TOOL_BAT_18650': return l.supplyItem_TOOL_BAT_18650;
      case 'TOOL_COIN_CR2032': return l.supplyItem_TOOL_COIN_CR2032;
      case 'TOOL_COIN_CR2025': return l.supplyItem_TOOL_COIN_CR2025;
      case 'TOOL_COIN_CR2016': return l.supplyItem_TOOL_COIN_CR2016;
      case 'TOOL_COIN_LR44': return l.supplyItem_TOOL_COIN_LR44;
      case 'TOOL_COIN_SR626': return l.supplyItem_TOOL_COIN_SR626;
      case 'TOOL_COMM_RADIO': return l.supplyItem_TOOL_COMM_RADIO;
      case 'TOOL_COMM_WALKIE': return l.supplyItem_TOOL_COMM_WALKIE;
      case 'TOOL_COMM_SAT': return l.supplyItem_TOOL_COMM_SAT;
      case 'TOOL_COMM_WHISTLE': return l.supplyItem_TOOL_COMM_WHISTLE;
      case 'TOOL_COMM_CHARGER': return l.supplyItem_TOOL_POWER_SOLAR;      // backward compat
      case 'TOOL_COMM_POWERBANK': return l.supplyItem_TOOL_POWER_BANK;     // backward compat
      case 'TOOL_RESCUE_ROPE': return l.supplyItem_TOOL_RESCUE_ROPE;
      case 'TOOL_RESCUE_AXE': return l.supplyItem_TOOL_RESCUE_AXE;
      case 'TOOL_RESCUE_SAW': return l.supplyItem_TOOL_RESCUE_SAW;
      case 'TOOL_RESCUE_PARACORD': return l.supplyItem_TOOL_RESCUE_PARACORD;
      case 'TOOL_RESCUE_SPRAYPAINT': return l.supplyItem_TOOL_RESCUE_SPRAYPAINT;
      case 'TOOL_RESCUE_CROWBAR': return l.supplyItem_TOOL_RESCUE_AXE;     // backward compat
      case 'TOOL_RESCUE_SHOVEL': return l.supplyItem_TOOL_HAND_SHOVEL;     // backward compat
      case 'TOOL_RESCUE_MULTI': return l.supplyItem_TOOL_HAND_MULTITOOL;   // backward compat
      case 'TOOL_HAND_SCREWDRIVER_PH': return l.supplyItem_TOOL_HAND_SCREWDRIVER_PH;
      case 'TOOL_HAND_SCREWDRIVER_FLAT': return l.supplyItem_TOOL_HAND_SCREWDRIVER_FLAT;
      case 'TOOL_HAND_WRENCH': return l.supplyItem_TOOL_HAND_WRENCH;
      case 'TOOL_HAND_HAMMER': return l.supplyItem_TOOL_HAND_HAMMER;
      case 'TOOL_HAND_SHOVEL': return l.supplyItem_TOOL_HAND_SHOVEL;
      case 'TOOL_HAND_MULTITOOL': return l.supplyItem_TOOL_HAND_MULTITOOL;
      case 'TOOL_HAND_PLIER': return l.supplyItem_TOOL_HAND_PLIER;
      case 'TOOL_REPAIR_DUCT': return l.supplyItem_TOOL_REPAIR_DUCT;
      case 'TOOL_REPAIR_ZIPTIE': return l.supplyItem_TOOL_REPAIR_ZIPTIE;
      case 'TOOL_REPAIR_WIRE': return l.supplyItem_TOOL_REPAIR_WIRE;
      case 'TOOL_REPAIR_SEALANT': return l.supplyItem_TOOL_REPAIR_SEALANT;
      case 'TOOL_REPAIR_TARP_TAPE': return l.supplyItem_TOOL_REPAIR_TARP_TAPE;
      case 'TOOL_TRANSPORT_CAR': return l.supplyItem_TOOL_TRANSPORT_CAR;
      case 'TOOL_TRANSPORT_BIKE': return l.supplyItem_TOOL_TRANSPORT_BIKE;
      case 'TOOL_TRANSPORT_CART': return l.supplyItem_TOOL_TRANSPORT_CART;
      case 'TOOL_TRANSPORT_WHEELBARROW': return l.supplyItem_TOOL_TRANSPORT_WHEELBARROW;
      case 'TOOL_TRANS_CART': return l.supplyItem_TOOL_TRANSPORT_CART;     // backward compat
      case 'TOOL_TRANS_STRETCHER': return l.supplyItem_MED_KIT_STRETCHER;  // backward compat
      case 'TOOL_HEAVY_EXCAVATOR_MINI': return l.supplyItem_TOOL_HEAVY_EXCAVATOR_MINI;
      case 'TOOL_HEAVY_EXCAVATOR_STD': return l.supplyItem_TOOL_HEAVY_EXCAVATOR_STD;
      case 'TOOL_HEAVY_BOBCAT_MINI': return l.supplyItem_TOOL_HEAVY_BOBCAT_MINI;
      case 'TOOL_HEAVY_BOBCAT_STD': return l.supplyItem_TOOL_HEAVY_BOBCAT_STD;
      case 'TOOL_HEAVY_CRANE': return l.supplyItem_TOOL_HEAVY_CRANE;
      case 'TOOL_HEAVY_LOADER': return l.supplyItem_TOOL_HEAVY_LOADER;
      case 'TOOL_DEMO_JACKHAMMER': return l.supplyItem_TOOL_DEMO_JACKHAMMER;
      case 'TOOL_DEMO_CONCRETE_SAW': return l.supplyItem_TOOL_DEMO_CONCRETE_SAW;
      case 'TOOL_DEMO_HYDRAULIC': return l.supplyItem_TOOL_DEMO_HYDRAULIC;
      case 'TOOL_DEMO_CHAINSAW': return l.supplyItem_TOOL_DEMO_CHAINSAW;
      case 'TOOL_CLEANING_WASHER': return l.supplyItem_TOOL_CLEANING_WASHER;
      case 'TOOL_CLEANING_PUMP_CLEAN': return l.supplyItem_TOOL_CLEANING_PUMP_CLEAN;
      case 'TOOL_CLEANING_PUMP_SLUDGE': return l.supplyItem_TOOL_CLEANING_PUMP_SLUDGE;
      case 'TOOL_CLEANING_BLOWER': return l.supplyItem_TOOL_CLEANING_BLOWER;
      case 'TOOL_SIGNAL_FLARE': return l.supplyItem_TOOL_SIGNAL_FLARE;
      case 'TOOL_SIGNAL_MIRROR': return l.supplyItem_TOOL_SIGNAL_MIRROR;
      case 'TOOL_SIGNAL_FLAG': return l.supplyItem_TOOL_SIGNAL_FLAG;
      case 'TOOL_SIGNAL_STROBE': return l.supplyItem_TOOL_SIGNAL_STROBE;
      // ── Pets ──
      case 'PET_FOOD_DOG_DRY': return l.supplyItem_PET_FOOD_DOG_DRY;
      case 'PET_FOOD_DOG_CAN': return l.supplyItem_PET_FOOD_DOG_CAN;
      case 'PET_FOOD_CAT_DRY': return l.supplyItem_PET_FOOD_CAT_DRY;
      case 'PET_FOOD_CAT_CAN': return l.supplyItem_PET_FOOD_CAT_CAN;
      case 'PET_FOOD_BOWL': return l.supplyItem_PET_FOOD_BOWL;
      case 'PET_CARE_CRATE': return l.supplyItem_PET_CARE_CRATE;
      case 'PET_CARE_LEASH': return l.supplyItem_PET_CARE_LEASH;
      case 'PET_CARE_PAD': return l.supplyItem_PET_CARE_PAD;
      case 'PET_CARE_MED': return l.supplyItem_PET_CARE_MED;
      case 'PET_CARE_TAG': return l.supplyItem_PET_CARE_TAG;
      // ── Skills ──
      case 'SKILL_MEDICAL_DOCTOR': return l.supplyItem_SKILL_MEDICAL_DOCTOR;
      case 'SKILL_MEDICAL_NURSE': return l.supplyItem_SKILL_MEDICAL_NURSE;
      case 'SKILL_MEDICAL_EMT': return l.supplyItem_SKILL_MEDICAL_EMT;
      case 'SKILL_MEDICAL_FIRSTAID': return l.supplyItem_SKILL_MEDICAL_FIRSTAID;
      case 'SKILL_MEDICAL_PHARMACIST': return l.supplyItem_SKILL_MEDICAL_PHARMACIST;
      case 'SKILL_RESCUE_FIREFIGHTER': return l.supplyItem_SKILL_RESCUE_FIREFIGHTER;
      case 'SKILL_RESCUE_DIVER': return l.supplyItem_SKILL_RESCUE_DIVER;
      case 'SKILL_RESCUE_K9': return l.supplyItem_SKILL_RESCUE_K9;
      case 'SKILL_RESCUE_MOUNTAIN': return l.supplyItem_SKILL_RESCUE_MOUNTAIN;
      case 'SKILL_LANG_EN': return l.supplyItem_SKILL_LANG_EN;
      case 'SKILL_LANG_JP': return l.supplyItem_SKILL_LANG_JP;
      case 'SKILL_LANG_SEA': return l.supplyItem_SKILL_LANG_SEA;
      case 'SKILL_LANG_SIGN': return l.supplyItem_SKILL_LANG_SIGN;
      case 'SKILL_PSYCH_COUNSELOR': return l.supplyItem_SKILL_PSYCH_COUNSELOR;
      case 'SKILL_PSYCH_SOCIAL': return l.supplyItem_SKILL_PSYCH_SOCIAL;
      case 'SKILL_CARE_BABY': return l.supplyItem_SKILL_CARE_BABY;
      case 'SKILL_CARE_ELDER': return l.supplyItem_SKILL_CARE_ELDER;
      case 'SKILL_CARE_DISABLED': return l.supplyItem_SKILL_CARE_DISABLED;
      case 'SKILL_CARE_SPECIAL': return l.supplyItem_SKILL_CARE_SPECIAL;
      case 'SKILL_TECH_ELECTRIC': return l.supplyItem_SKILL_TECH_ELECTRIC;
      case 'SKILL_TECH_PLUMB': return l.supplyItem_SKILL_TECH_PLUMB;
      case 'SKILL_TECH_STRUCT': return l.supplyItem_SKILL_TECH_STRUCT;
      case 'SKILL_TECH_COMM': return l.supplyItem_SKILL_TECH_COMM;
      case 'SKILL_TECH_LABOR': return l.supplyItem_SKILL_TECH_LABOR;
      case 'SKILL_LOG_TRUCK': return l.supplyItem_SKILL_LOG_TRUCK;
      case 'SKILL_LOG_4WD': return l.supplyItem_SKILL_LOG_4WD;
      case 'SKILL_LOG_MOTO': return l.supplyItem_SKILL_LOG_MOTO;
      case 'SKILL_LOG_FORKLIFT': return l.supplyItem_SKILL_LOG_FORKLIFT;
      case 'SKILL_LOG_HEAVYOP': return l.supplyItem_SKILL_LOG_HEAVYOP;
      case 'SKILL_LOG_MANAGE': return l.supplyItem_SKILL_LOG_MANAGE;
      default: return code;
    }
  }
}
