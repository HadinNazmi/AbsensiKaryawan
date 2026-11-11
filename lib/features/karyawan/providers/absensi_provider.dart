import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/absensi_model.dart';
import '../models/kantor_setting.dart';
import '../utils/image_utils.dart';

/// Provider pengaturan kantor dari tabel 'kantor_setting'
final kantorSettingProvider = FutureProvider<KantorSetting?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase.from('kantor_setting').select().maybeSingle();
    if (res == null) return null;
    return KantorSetting.fromJson(res);
  } catch (e) {
    throw Exception('Gagal memuat pengaturan kantor: $e');
  }
});

/// Provider data absensi hari ini milik user aktif
final todayAbsensiProvider = FutureProvider<AbsensiModel?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return null;

  final todayWib = formatTanggalDb(DateTime.now());

  try {
    final res = await supabase
        .from('absensi')
        .select()
        .eq('user_id', user.id)
        .eq('tanggal', todayWib)
        .maybeSingle();

    if (res == null) return null;
    return AbsensiModel.fromJson(res);
  } catch (e) {
    throw Exception('Gagal memuat status absensi hari ini: $e');
  }
});

/// Provider daftar riwayat absensi berdasarkan bulan yang dipilih
final riwayatAbsensiProvider =
    FutureProvider.family<List<AbsensiModel>, DateTime>((ref, month) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return [];

  // Hitung rentang tanggal bulan
  final year = month.year;
  final m = month.month;
  final startDate = '$year-${m.toString().padLeft(2, '0')}-01';
  // Hari terakhir bulan
  final lastDay = DateTime(year, m + 1, 0).day;
  final endDate = '$year-${m.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

  try {
    final res = await supabase
        .from('absensi')
        .select()
        .eq('user_id', user.id)
        .gte('tanggal', startDate)
        .lte('tanggal', endDate)
        .order('tanggal', ascending: false);

    final list = res as List<dynamic>;
    return list.map((e) => AbsensiModel.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Gagal memuat riwayat absensi: $e');
  }
});

/// Service operasional absensi karyawan
class AbsensiService {
  final SupabaseClient _supabase;

  AbsensiService(this._supabase);

  /// Submit absensi masuk atau pulang:
  /// 1. Kompres foto
  /// 2. Upload ke storage privat 'absensi-foto'
  /// 3. Panggil RPC 'submit_absensi'
  Future<AbsensiModel> submitAbsensi({
    required String uid,
    required String tipe, // 'masuk' atau 'pulang'
    required double latitude,
    required double longitude,
    required double akurasi,
    required Uint8List photoBytes,
  }) async {
    // 1. Kompres foto
    final compressedBytes = processSelfiePhoto(photoBytes);

    // 2. Path upload: {user_id}/{yyyy-MM-dd WIB}/{tipe}-{epochMillis}.jpg
    final todayWib = formatTanggalDb(DateTime.now());
    final epochMillis = DateTime.now().millisecondsSinceEpoch;
    final photoPath = '$uid/$todayWib/$tipe-$epochMillis.jpg';

    // 3. Upload bytes ke Storage bucket 'absensi-foto'
    try {
      await _supabase.storage.from('absensi-foto').uploadBinary(
            photoPath,
            compressedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } catch (e) {
      throw Exception('Gagal mengunggah foto absensi: $e');
    }

    // 4. Panggil RPC 'submit_absensi'
    try {
      final res = await _supabase.rpc(
        'submit_absensi',
        params: {
          'p_tipe': tipe,
          'p_lat': latitude,
          'p_lng': longitude,
          'p_akurasi': akurasi,
          'p_foto_path': photoPath,
        },
      );

      if (res is Map<String, dynamic>) {
        return AbsensiModel.fromJson(res);
      } else if (res is List && res.isNotEmpty) {
        return AbsensiModel.fromJson(res.first as Map<String, dynamic>);
      } else {
        throw Exception('Format respon server tidak valid');
      }
    } on PostgrestException catch (e) {
      // Pesan error dari server sudah dalam bahasa Indonesia
      throw Exception(e.message);
    } catch (e) {
      rethrow;
    }
  }

  /// Membuat signed URL sementara (60 menit) untuk menampilkan foto privat
  Future<String> getSignedPhotoUrl(String photoPath) async {
    try {
      final signedUrl = await _supabase.storage
          .from('absensi-foto')
          .createSignedUrl(photoPath, 3600); // 60 menit
      return signedUrl;
    } catch (e) {
      throw Exception('Gagal mendapatkan foto: $e');
    }
  }
}

final absensiServiceProvider = Provider<AbsensiService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AbsensiService(supabase);
});

