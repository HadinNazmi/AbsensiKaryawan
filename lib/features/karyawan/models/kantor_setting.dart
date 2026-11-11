/// Model data pengaturan kantor dari tabel 'kantor_setting'
class KantorSetting {
  final dynamic id;
  final String nama;
  final double latitude;
  final double longitude;
  final double radiusMeter;
  final String jamMasuk; // e.g. "08:00:00"
  final String jamPulang; // e.g. "17:00:00"
  final int toleransiMenit;
  final List<int> hariKerja; // 1=Senin..7=Minggu

  const KantorSetting({
    required this.id,
    required this.nama,
    required this.latitude,
    required this.longitude,
    required this.radiusMeter,
    required this.jamMasuk,
    required this.jamPulang,
    required this.toleransiMenit,
    required this.hariKerja,
  });

  factory KantorSetting.fromJson(Map<String, dynamic> json) {
    return KantorSetting(
      id: json['id'],
      nama: json['nama'] as String? ?? 'Kantor',
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
      radiusMeter: json['radius_meter'] is num
          ? (json['radius_meter'] as num).toDouble()
          : double.tryParse(json['radius_meter']?.toString() ?? '') ?? 100.0,
      jamMasuk: json['jam_masuk'] as String? ?? '08:00',
      jamPulang: json['jam_pulang'] as String? ?? '17:00',
      toleransiMenit: json['toleransi_menit'] is int
          ? json['toleransi_menit'] as int
          : int.tryParse(json['toleransi_menit']?.toString() ?? '') ?? 15,
      hariKerja: (json['hari_kerja'] as List<dynamic>?)
              ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 1)
              .toList() ??
          [1, 2, 3, 4, 5],
    );
  }
}

