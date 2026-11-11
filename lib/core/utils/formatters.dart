import 'package:intl/intl.dart';
import '../env/app_env.dart';

/// Normalisasi nomor HP sesuai aturan kontrak backend
/// Buang spasi, "-", "(", ")", "."; buang "+" di depan;
/// Awalan "0" diganti "62"; awalan "8" ditambah "62" di depan.
/// Valid jika cocok regex ^628\d{8,12}$.
String? normalisasiHp(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
  if (cleaned.startsWith('+')) {
    cleaned = cleaned.substring(1);
  }
  if (cleaned.startsWith('0')) {
    cleaned = '62${cleaned.substring(1)}';
  } else if (cleaned.startsWith('8')) {
    cleaned = '62$cleaned';
  }

  final regex = RegExp(r'^628\d{8,12}$');
  if (!regex.hasMatch(cleaned)) {
    return null;
  }
  return cleaned;
}

/// Menghasilkan format email internal dari nomor HP
String emailDariHp(String hp) {
  final norm = normalisasiHp(hp) ?? hp;
  return '$norm@${AppEnv.emailDomain}';
}

/// Konversi DateTime UTC atau lokal ke waktu WIB (UTC+7)
DateTime toWib(DateTime dt) {
  return dt.toUtc().add(const Duration(hours: 7));
}

/// Format tanggal lengkap WIB: "Senin, 11 November 2026"
String formatTanggalLengkap(DateTime dt) {
  final wib = toWib(dt);
  return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(wib);
}

/// Format tanggal pendek WIB: "11 Nov 2026"
String formatTanggalPendek(DateTime dt) {
  final wib = toWib(dt);
  return DateFormat('d MMM yyyy', 'id_ID').format(wib);
}

/// Format tanggal database WIB: "2026-11-11"
String formatTanggalDb(DateTime dt) {
  final wib = toWib(dt);
  return DateFormat('yyyy-MM-dd').format(wib);
}

/// Format jam WIB: "08:15 WIB"
String formatJamWib(DateTime dt) {
  final wib = toWib(dt);
  return '${DateFormat('HH:mm', 'id_ID').format(wib)} WIB';
}

/// Format jam tanpa suffix: "08:15"
String formatJam(DateTime dt) {
  final wib = toWib(dt);
  return DateFormat('HH:mm', 'id_ID').format(wib);
}

