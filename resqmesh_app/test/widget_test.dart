// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_app/main.dart';
import 'package:resqmesh_app/mesh/native_ble_transport.dart';

void main() {
  testWidgets('IgniRelay app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(ResQMeshApp(transport: NativeBleTransport()));
    expect(find.byType(ResQMeshApp), findsOneWidget);
  });
}
