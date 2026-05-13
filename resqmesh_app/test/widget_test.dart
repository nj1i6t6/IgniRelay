// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/main.dart';
import 'package:ignirelay_app/app/mesh/native_ble_transport_adapter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
  });

  testWidgets('IgniRelay app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(IgniRelayApp(transport: NativeBleTransport()));
    expect(find.byType(IgniRelayApp), findsOneWidget);
  });
}
