import '../../karyawan/models/absensi_model.dart';

/// Model item data absensi lengkap dengan relasi nama karyawan untuk Admin
class AbsensiAdminItem {
  final AbsensiModel absensi;
  final String namaKaryawan;
  final String noHpKaryawan;
  final String jabatanKaryawan;

  const AbsensiAdminItem({
    required this.absensi,
    required this.namaKaryawan,
    required this.noHpKaryawan,
    required this.jabatanKaryawan,
  });

  factory AbsensiAdminItem.fromJson(Map<String, dynamic> json) {
    final absensi = AbsensiModel.fromJson(json);

    String nama = 'Karyawan';
    String noHp = '-';
    String jabatan = '-';

    if (json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      nama = p['nama'] as String? ?? 'Karyawan';
      noHp = p['no_hp'] as String? ?? '-';
      jabatan = p['jabatan'] as String? ?? '-';
    }

    return AbsensiAdminItem(
      absensi: absensi,
      namaKaryawan: nama,
      noHpKaryawan: noHp,
      jabatanKaryawan: jabatan,
    );
  }
}

