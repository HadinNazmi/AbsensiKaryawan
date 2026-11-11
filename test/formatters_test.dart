import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:absenkaryawan/core/utils/formatters.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: 'EMAIL_DOMAIN=absen.local');
  });

  group('normalisasiHp', () {
    test('normalisasi format 08...', () {
      expect(normalisasiHp('081234567890'), '6281234567890');
    });

    test('normalisasi format +628...', () {
      expect(normalisasiHp('+6281234567890'), '6281234567890');
    });

    test('normalisasi format 8...', () {
      expect(normalisasiHp('81234567890'), '6281234567890');
    });

    test('normalisasi dengan spasi dan tanda baca', () {
      expect(normalisasiHp('0812-3456-7890'), '6281234567890');
      expect(normalisasiHp('(0812) 3456.7890'), '6281234567890');
    });

    test('nomor tidak valid jika terlalu pendek atau format salah', () {
      expect(normalisasiHp('12345'), isNull);
      expect(normalisasiHp('0812'), isNull);
      expect(normalisasiHp('02112345678'), isNull); // bukan 08
    });
  });

  group('emailDariHp', () {
    test('menghasilkan email internal yang tepat', () {
      expect(emailDariHp('081234567890'), '6281234567890@absen.local');
    });
  });
}
