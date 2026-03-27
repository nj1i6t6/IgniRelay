import 'package:flutter/material.dart';

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

final List<SupplyCategory> supplyCategories = const [
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
