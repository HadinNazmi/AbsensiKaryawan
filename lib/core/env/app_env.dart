import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi environment yang dimuat dari file .env
class AppEnv {
  static String get supabaseUrl {
    final val = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    if (val.isEmpty) {
      throw StateError('SUPABASE_URL belum dikonfigurasi di file .env');
    }
    return val;
  }

  static String get supabaseAnonKey {
    final val = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (val.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY belum dikonfigurasi di file .env');
    }
    return val;
  }

  static String get emailDomain {
    final val = dotenv.env['EMAIL_DOMAIN']?.trim() ?? 'absen.local';
    return val.isEmpty ? 'absen.local' : val;
  }
}

