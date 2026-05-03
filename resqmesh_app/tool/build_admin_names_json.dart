// build_admin_names_json.dart
//
// Deterministic build tool: produces assets/geodata/taiwan_admin_names.json
// by cross-referencing:
//   1. village_boundary.db — county/town codes + Chinese names (authoritative)
//   2. tool/data/admin_names_en.csv — English names (from official sources)
//
// Data sources for admin_names_en.csv:
//   - 縣市/鄉鎮市區代碼 + 英文名：內政部戶政司「行政區域代碼」
//     https://www.ris.gov.tw/app/portal/346
//     Data date: 2025-01
//   - 補充英文名：交通部觀光署「臺灣地區地名資料_行政區域類」
//     https://gis.taiwan.net.tw/
//     (用於戶政司資料缺漏時 cross-check)
//
// CSV provenance:
//   admin_names_en.csv is a curated seed dataset. Initial version was derived
//   from the 內政部戶政司 administrative area code tables cross-referenced with
//   village_boundary.db Chinese names. It covers all 22 counties and 368
//   townships/districts as of 2025-01.
//
//   To update from official sources:
//   1. Download latest 行政區域代碼 CSV from https://www.ris.gov.tw/app/portal/346
//   2. Cross-reference with village_boundary.db for code + zh name alignment
//   3. Update tool/data/admin_names_en.csv
//   4. Re-run: dart run tool/build_admin_names_json.dart
//
//   The build tool will fail-fast if county count != 22 or town count < 368,
//   ensuring incomplete data never produces a partial JSON asset.
//
// CSV format:
//   level,county_code,town_code,zh_name,en_name
//   - level: "county" or "town"
//   - For counties: town_code is empty
//   - For towns: county_code and town_code both present
//
// manualOverrides below covers entries missing from CSV (e.g. new districts
// not yet in official data). Keep this map minimal and document each entry.
//
// Usage:
//   dart run tool/build_admin_names_json.dart
//
// Output:
//   assets/geodata/taiwan_admin_names.json (sorted keys, deterministic)

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _dbPath = 'assets/geodata/village_boundary.db';
const _csvPath = 'tool/data/admin_names_en.csv';
const _outputPath = 'assets/geodata/taiwan_admin_names.json';

/// Entries missing from CSV. Each entry must include a reason.
/// Keep this list minimal (< 5% of total entries).
const manualOverrides = <String, Map<String, String>>{
  // Example (remove when CSV is updated from official source):
  // '67000370': {'countyCode': '67000', 'zhHant': '中西區', 'en': 'West Central District'},
};

void main() {
  // ── Load CSV ──
  final csvFile = File(_csvPath);
  if (!csvFile.existsSync()) {
    stderr.writeln('ERROR: CSV not found at $_csvPath');
    stderr.writeln('Run the tool with a valid CSV input.');
    exit(1);
  }

  final csvLines = csvFile.readAsLinesSync();
  if (csvLines.isEmpty || csvLines.first != 'level,county_code,town_code,zh_name,en_name') {
    stderr.writeln('ERROR: CSV header mismatch. Expected: level,county_code,town_code,zh_name,en_name');
    exit(1);
  }

  final csvCountyEn = <String, String>{};
  final csvTownEn = <String, String>{};
  final csvTownCounty = <String, String>{};

  for (var i = 1; i < csvLines.length; i++) {
    final line = csvLines[i].trim();
    if (line.isEmpty) continue;
    final parts = line.split(',');
    if (parts.length < 5) {
      stderr.writeln('WARNING: skipping malformed CSV line $i: $line');
      continue;
    }
    final level = parts[0];
    final countyCode = parts[1];
    final townCode = parts[2];
    final enName = parts[4];

    if (level == 'county') {
      csvCountyEn[countyCode] = enName;
    } else if (level == 'town') {
      csvTownEn[townCode] = enName;
      csvTownCounty[townCode] = countyCode;
    }
  }

  // ── Load DB ──
  final db = sqlite3.open(_dbPath, mode: OpenMode.readOnly);

  try {
    // Counties from DB
    final countyRows = db.select(
      'SELECT DISTINCT countycode, countyname FROM villages ORDER BY countycode',
    );

    final counties = <String, Map<String, String>>{};
    for (final row in countyRows) {
      final code = row['countycode'] as String;
      final zhHant = row['countyname'] as String;
      final en = csvCountyEn[code];
      if (en == null) {
        stderr.writeln('WARNING: no English name in CSV for county $code ($zhHant)');
        continue;
      }
      counties[code] = {'zhHant': zhHant, 'en': en};
    }

    // Towns from DB
    final townRows = db.select(
      'SELECT DISTINCT towncode, countycode, townname FROM villages ORDER BY towncode',
    );

    final towns = <String, Map<String, String>>{};
    for (final row in townRows) {
      final code = row['towncode'] as String;
      final countyCode = row['countycode'] as String;
      final zhHant = row['townname'] as String;

      String? en = csvTownEn[code];

      // Check manual overrides
      if (en == null && manualOverrides.containsKey(code)) {
        en = manualOverrides[code]!['en'];
      }

      if (en == null) {
        stderr.writeln('WARNING: no English name in CSV/overrides for town $code ($zhHant)');
        continue;
      }
      towns[code] = {'countyCode': countyCode, 'zhHant': zhHant, 'en': en};
    }

    // ── Integrity check ──
    if (counties.length != 22) {
      stderr.writeln('FATAL: expected 22 counties, got ${counties.length}');
      exit(2);
    }
    if (towns.length < 368) {
      stderr.writeln('FATAL: expected >= 368 towns, got ${towns.length}');
      exit(2);
    }

    // ── Output ──
    final output = <String, dynamic>{
      'counties': _sortedMap(counties),
      'towns': _sortedMap(towns),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(output);
    File(_outputPath).writeAsStringSync('$jsonStr\n');
    stdout.writeln('Wrote $_outputPath');
    stdout.writeln('  counties: ${counties.length} (CSV: ${csvCountyEn.length})');
    stdout.writeln('  towns: ${towns.length} (CSV: ${csvTownEn.length})');
    if (manualOverrides.isNotEmpty) {
      stdout.writeln('  manual overrides: ${manualOverrides.length}');
    }
  } finally {
    db.dispose();
  }
}

Map<String, dynamic> _sortedMap(Map<String, dynamic> input) {
  return Map.fromEntries(
    input.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
