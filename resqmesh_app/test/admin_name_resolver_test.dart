import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/geo/admin_name_resolver.dart';

void main() {
  group('AdminNameResolver', () {
    late AdminNameResolver resolver;

    setUp(() {
      resolver = AdminNameResolver();
      resolver.debugSetData(
        counties: {
          '65000': (zhHant: '新北市', en: 'New Taipei City'),
          '64000': (zhHant: '高雄市', en: 'Kaohsiung City'),
        },
        towns: {
          '65000050': (zhHant: '新莊區', en: 'Xinzhuang District'),
          '64000060': (zhHant: '新興區', en: 'Xinxing District'),
        },
      );
    });

    test('county returns zhHant and en for known code', () {
      final result = resolver.county('65000');
      expect(result, isNotNull);
      expect(result!.zhHant, '新北市');
      expect(result.en, 'New Taipei City');
    });

    test('county returns null for unknown code', () {
      expect(resolver.county('99999'), isNull);
    });

    test('town returns zhHant and en for known code', () {
      final result = resolver.town('65000050');
      expect(result, isNotNull);
      expect(result!.zhHant, '新莊區');
      expect(result.en, 'Xinzhuang District');
    });

    test('town returns null for unknown code', () {
      expect(resolver.town('00000000'), isNull);
    });

    test('debugSetData replaces previous data', () {
      resolver.debugSetData(
        counties: {'10002': (zhHant: '宜蘭縣', en: 'Yilan County')},
        towns: {},
      );
      expect(resolver.county('65000'), isNull);
      expect(resolver.county('10002'), isNotNull);
    });
  });
}
