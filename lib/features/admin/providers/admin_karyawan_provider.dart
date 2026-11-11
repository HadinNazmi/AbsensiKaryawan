import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/models/user_profile.dart';

/// Provider memuat daftar seluruh karyawan dari tabel 'profiles'
final karyawanListProvider = FutureProvider<List<UserProfile>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    final list = res as List<dynamic>;
    return list.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Gagal memuat daftar karyawan: $e');
  }
});

/// Service operasional manajemen karyawan oleh Admin via Edge Function & database
class AdminKaryawanService {
  final SupabaseClient _supabase;

  AdminKaryawanService(this._supabase);

  /// 1. Tambah akun karyawan baru
  /// Memanggil Edge Function 'admin-karyawan' dengan action: 'create'
  Future<void> createKaryawan({
    required String nama,
    required String noHpRaw,
    required String jabatan,
    String role = 'karyawan',
  }) async {
    final normHp = normalisasiHp(noHpRaw);
    if (normHp == null) {
      throw Exception('Nomor HP tidak valid. Gunakan format seperti 081234567890');
    }

    try {
      final res = await _supabase.functions.invoke(
        'admin-karyawan',
        body: {
          'action': 'create',
          'nama': nama.trim(),
          'no_hp': normHp,
          'jabatan': jabatan.trim(),
          'role': role,
        },
      );

      _handleEdgeFunctionResponse(res);
    } catch (e) {
      rethrow;
    }
  }

  /// 2. Reset password karyawan ke 123456
  /// Memanggil Edge Function 'admin-karyawan' dengan action: 'reset-password'
  Future<void> resetPassword(String userId) async {
    try {
      final res = await _supabase.functions.invoke(
        'admin-karyawan',
        body: {
          'action': 'reset-password',
          'user_id': userId,
        },
      );

      _handleEdgeFunctionResponse(res);
    } catch (e) {
      rethrow;
    }
  }

  /// 3. Ubah nomor HP karyawan dan sinkronkan ke akun login Supabase Auth
  /// Memanggil Edge Function 'admin-karyawan' dengan action: 'update-phone'
  Future<void> updatePhone({
    required String userId,
    required String newPhoneRaw,
  }) async {
    final normHp = normalisasiHp(newPhoneRaw);
    if (normHp == null) {
      throw Exception('Nomor HP baru tidak valid.');
    }

    try {
      final res = await _supabase.functions.invoke(
        'admin-karyawan',
        body: {
          'action': 'update-phone',
          'user_id': userId,
          'no_hp': normHp,
        },
      );

      _handleEdgeFunctionResponse(res);
    } catch (e) {
      rethrow;
    }
  }

  /// 4. Ubah status aktif/nonaktif karyawan langsung di tabel profiles
  Future<void> toggleAktif({
    required String userId,
    required bool newStatus,
  }) async {
    try {
      await _supabase
          .from('profiles')
          .update({'aktif': newStatus})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Gagal mengubah status aktif karyawan: $e');
    }
  }

  /// Helper untuk validasi respons Edge Function sesuai kontrak BACKEND.md:
  /// Respons sukses {ok:true}; gagal {error:'pesan'} (tampilkan pesannya).
  void _handleEdgeFunctionResponse(FunctionResponse res) {
    dynamic rawData = res.data;
    Map<String, dynamic> data = {};

    if (rawData is Map) {
      data = Map<String, dynamic>.from(rawData);
    } else if (rawData is String && rawData.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(rawData) as Map);
      } catch (_) {}
    }

    if (data['ok'] == true) {
      return; // Berhasil
    }

    final errorMessage = data['error'] ??
        data['message'] ??
        (res.status != 200
            ? 'Gagal memproses permintaan (Status ${res.status})'
            : 'Terjadi kesalahan sistem: Edge function belum mengembalikan status berhasil.');
    throw Exception(errorMessage);
  }
}

final adminKaryawanServiceProvider = Provider<AdminKaryawanService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminKaryawanService(supabase);
});

