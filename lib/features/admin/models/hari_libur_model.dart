/// Model data hari libur dari tabel 'hari_libur'
class HariLiburModel {
  final dynamic id;
  final String tanggal; // yyyy-MM-dd
  final String keterangan;

  const HariLiburModel({
    required this.id,
    required this.tanggal,
    required this.keterangan,
  });

  factory HariLiburModel.fromJson(Map<String, dynamic> json) {
    return HariLiburModel(
      id: json['id'],
      tanggal: json['tanggal'] as String,
      keterangan: json['keterangan'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tanggal': tanggal,
      'keterangan': keterangan,
    };
  }
}

