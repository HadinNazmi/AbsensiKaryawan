import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../models/absensi_admin_item.dart';

/// Provider absensi hari ini yang dipantau oleh Admin
final adminTodayAbsensiProvider =
    FutureProvider<List<AbsensiAdminItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final todayWib = formatTanggalDb(DateTime.now());

  try {
    final res = await supabase
        .from('absensi')
        .select('*, profiles:user_id(nama, no_hp, jabatan)')
        .eq('tanggal', todayWib)
        .order('jam_masuk', ascending: false);

    final list = res as List<dynamic>;
    return list
        .map((e) => AbsensiAdminItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Gagal memuat monitoring absensi: $e');
  }
});

/// Provider total karyawan aktif (peserta absensi)
final totalKaryawanAktifProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'karyawan')
        .eq('aktif', true);

    return (res as List).length;
  } catch (e) {
    return 0;
  }
});

/// Service aksi pemantauan dan koreksi oleh Admin
class AdminMonitoringService {
  final Ref _ref;

  AdminMonitoringService(this._ref);

  /// Koreksi status absensi (mis. ubah ke Izin, Sakit, Hadir, Terlambat, Alpha dengan catatan)
  Future<void> koreksiStatus({
    required dynamic absensiId,
    required String newStatus,
    required String catatan,
  }) async {
    final supabase = _ref.read(supabaseClientProvider);
    final adminUser = supabase.auth.currentUser;

    try {
      await supabase.from('absensi').update({
        'status': newStatus.toLowerCase(),
        'catatan': catatan.trim(),
        'dikoreksi_oleh': adminUser?.id,
        'dikoreksi_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', absensiId);

      _ref.invalidate(adminTodayAbsensiProvider);
    } catch (e) {
      throw Exception('Gagal mengoreksi status absensi: $e');
    }
  }

  /// Tambah status izin/sakit/hadir manual untuk karyawan yang belum memiliki baris absensi
  Future<void> inputStatusManual({
    required String userId,
    required String tanggal, // yyyy-MM-dd
    required String status,
    required String catatan,
  }) async {
    final supabase = _ref.read(supabaseClientProvider);
    final adminUser = supabase.auth.currentUser;

    try {
      await supabase.from('absensi').upsert({
        'user_id': userId,
        'tanggal': tanggal,
        'status': status.toLowerCase(),
        'catatan': catatan.trim(),
        'dikoreksi_oleh': adminUser?.id,
        'dikoreksi_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,tanggal');

      _ref.invalidate(adminTodayAbsensiProvider);
    } catch (e) {
      throw Exception('Gagal menyimpan status manual: $e');
    }
  }
}

final adminMonitoringServiceProvider = Provider<AdminMonitoringService>((ref) {
  return AdminMonitoringService(ref);
});

