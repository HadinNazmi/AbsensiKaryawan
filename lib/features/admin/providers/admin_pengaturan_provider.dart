import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../karyawan/models/kantor_setting.dart';
import '../../karyawan/providers/absensi_provider.dart';
import '../models/hari_libur_model.dart';

/// Provider memuat pengaturan kantor untuk admin
final adminKantorSettingProvider =
    FutureProvider<KantorSetting?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase.from('kantor_setting').select().maybeSingle();
    if (res == null) return null;
    return KantorSetting.fromJson(res);
  } catch (e) {
    throw Exception('Gagal memuat pengaturan kantor: $e');
  }
});

/// Provider memuat daftar hari libur
final adminHariLiburListProvider =
    FutureProvider<List<HariLiburModel>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase
        .from('hari_libur')
        .select()
        .order('tanggal', ascending: true);

    final list = res as List<dynamic>;
    return list.map((e) => HariLiburModel.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Gagal memuat hari libur: $e');
  }
});

/// Service operasional pengaturan kantor dan hari libur oleh Admin
class AdminPengaturanService {
  final Ref _ref;

  AdminPengaturanService(this._ref);

  /// Perbarui pengaturan kantor (titik GPS, radius, jam kerja, toleransi)
  Future<void> updateKantorSetting({
    required dynamic id,
    required String nama,
    required double latitude,
    required double longitude,
    required double radiusMeter,
    required String jamMasuk,
    required String jamPulang,
    required int toleransiMenit,
    required List<int> hariKerja,
  }) async {
    final supabase = _ref.read(supabaseClientProvider);

    try {
      final updateData = {
        'nama': nama.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'radius_meter': radiusMeter.toInt(),
        'jam_masuk': jamMasuk,
        'jam_pulang': jamPulang,
        'toleransi_menit': toleransiMenit,
        'hari_kerja': hariKerja,
      };

      if (id != null) {
        await supabase.from('kantor_setting').update(updateData).eq('id', id);
      } else {
        await supabase.from('kantor_setting').update(updateData).neq('nama', '');
      }

      _ref.invalidate(adminKantorSettingProvider);
      _ref.invalidate(kantorSettingProvider);
    } catch (e) {
      throw Exception('Gagal memperbarui pengaturan kantor: $e');
    }
  }

  /// Tambah hari libur baru
  Future<void> addHariLibur({
    required String tanggal, // yyyy-MM-dd
    required String keterangan,
  }) async {
    final supabase = _ref.read(supabaseClientProvider);

    try {
      await supabase.from('hari_libur').insert({
        'tanggal': tanggal,
        'keterangan': keterangan.trim(),
      });

      _ref.invalidate(adminHariLiburListProvider);
    } catch (e) {
      throw Exception('Gagal menambahkan hari libur: $e');
    }
  }

  /// Hapus hari libur
  Future<void> deleteHariLibur(dynamic id) async {
    final supabase = _ref.read(supabaseClientProvider);

    try {
      await supabase.from('hari_libur').delete().eq('id', id);
      _ref.invalidate(adminHariLiburListProvider);
    } catch (e) {
      throw Exception('Gagal menghapus hari libur: $e');
    }
  }
}

final adminPengaturanServiceProvider = Provider<AdminPengaturanService>((ref) {
  return AdminPengaturanService(ref);
});

