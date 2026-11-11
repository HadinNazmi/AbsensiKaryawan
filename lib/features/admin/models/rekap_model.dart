/// Model baris ringkasan absensi per karyawan dari RPC 'rekap_ringkasan'
class RekapRingkasanModel {
  final String userId;
  final String nama;
  final String noHp;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int alpha;

  const RekapRingkasanModel({
    required this.userId,
    required this.nama,
    required this.noHp,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.alpha,
  });

  int get totalHadir => hadir + terlambat;
  int get totalTidakHadir => alpha + izin + sakit;

  factory RekapRingkasanModel.fromJson(Map<String, dynamic> json) {
    return RekapRingkasanModel(
      userId: json['user_id'] as String? ?? '',
      nama: json['nama'] as String? ?? '-',
      noHp: json['no_hp'] as String? ?? '-',
      hadir: json['hadir'] is int ? json['hadir'] as int : int.tryParse(json['hadir']?.toString() ?? '0') ?? 0,
      terlambat: json['terlambat'] is int ? json['terlambat'] as int : int.tryParse(json['terlambat']?.toString() ?? '0') ?? 0,
      izin: json['izin'] is int ? json['izin'] as int : int.tryParse(json['izin']?.toString() ?? '0') ?? 0,
      sakit: json['sakit'] is int ? json['sakit'] as int : int.tryParse(json['sakit']?.toString() ?? '0') ?? 0,
      alpha: json['alpha'] is int ? json['alpha'] as int : int.tryParse(json['alpha']?.toString() ?? '0') ?? 0,
    );
  }
}

