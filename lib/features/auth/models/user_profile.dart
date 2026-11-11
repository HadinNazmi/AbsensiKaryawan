/// Model data profil pengguna dari tabel 'profiles'
class UserProfile {
  final String id;
  final String noHp;
  final String nama;
  final String jabatan;
  final String role; // 'karyawan' | 'admin'
  final bool aktif;
  final bool wajibGantiPassword;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.noHp,
    required this.nama,
    required this.jabatan,
    required this.role,
    required this.aktif,
    required this.wajibGantiPassword,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isKaryawan => role == 'karyawan';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      noHp: json['no_hp'] as String? ?? '',
      nama: json['nama'] as String? ?? '',
      jabatan: json['jabatan'] as String? ?? '',
      role: json['role'] as String? ?? 'karyawan',
      aktif: json['aktif'] as bool? ?? false,
      wajibGantiPassword: json['wajib_ganti_password'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'no_hp': noHp,
      'nama': nama,
      'jabatan': jabatan,
      'role': role,
      'aktif': aktif,
      'wajib_ganti_password': wajibGantiPassword,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? noHp,
    String? nama,
    String? jabatan,
    String? role,
    bool? aktif,
    bool? wajibGantiPassword,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      noHp: noHp ?? this.noHp,
      nama: nama ?? this.nama,
      jabatan: jabatan ?? this.jabatan,
      role: role ?? this.role,
      aktif: aktif ?? this.aktif,
      wajibGantiPassword: wajibGantiPassword ?? this.wajibGantiPassword,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

