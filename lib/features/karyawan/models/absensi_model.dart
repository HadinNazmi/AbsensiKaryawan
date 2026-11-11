import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';

/// Model data catatan absensi dari tabel 'absensi'
class AbsensiModel {
  final dynamic id;
  final String userId;
  final String tanggal; // yyyy-MM-dd
  final DateTime? jamMasuk; // timestamptz (UTC)
  final String? fotoMasuk;
  final double? latMasuk;
  final double? lngMasuk;
  final double? jarakMasukM;
  final double? akurasiMasukM;
  final DateTime? jamPulang; // timestamptz (UTC)
  final String? fotoPulang;
  final double? latPulang;
  final double? lngPulang;
  final double? jarakPulangM;
  final double? akurasiPulangM;
  final String status; // 'hadir' | 'terlambat' | 'izin' | 'sakit' | 'alpha'
  final String? catatan;
  final String? dikoreksiOleh;
  final DateTime? dikoreksiAt;
  final DateTime? createdAt;

  const AbsensiModel({
    required this.id,
    required this.userId,
    required this.tanggal,
    this.jamMasuk,
    this.fotoMasuk,
    this.latMasuk,
    this.lngMasuk,
    this.jarakMasukM,
    this.akurasiMasukM,
    this.jamPulang,
    this.fotoPulang,
    this.latPulang,
    this.lngPulang,
    this.jarakPulangM,
    this.akurasiPulangM,
    required this.status,
    this.catatan,
    this.dikoreksiOleh,
    this.dikoreksiAt,
    this.createdAt,
  });

  bool get sudahMasuk => jamMasuk != null;
  bool get sudahPulang => jamPulang != null;

  String? get jamMasukFormatted =>
      jamMasuk != null ? formatJamWib(jamMasuk!) : null;

  String? get jamPulangFormatted =>
      jamPulang != null ? formatJamWib(jamPulang!) : null;

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat':
        return 'Terlambat';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpha':
        return 'Alpha';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'hadir':
        return const Color(0xFF16A34A); // Hijau
      case 'terlambat':
        return const Color(0xFFD97706); // Oranye/Amber
      case 'izin':
      case 'sakit':
        return const Color(0xFF2563EB); // Biru
      case 'alpha':
        return const Color(0xFFDC2626); // Merah
      default:
        return Colors.grey;
    }
  }

  Color get statusBgColor {
    switch (status.toLowerCase()) {
      case 'hadir':
        return const Color(0xFFDCFCE7);
      case 'terlambat':
        return const Color(0xFFFEF3C7);
      case 'izin':
      case 'sakit':
        return const Color(0xFFDBEAFE);
      case 'alpha':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  factory AbsensiModel.fromJson(Map<String, dynamic> json) {
    return AbsensiModel(
      id: json['id'],
      userId: json['user_id'] as String,
      tanggal: json['tanggal'] as String,
      jamMasuk: json['jam_masuk'] != null
          ? DateTime.tryParse(json['jam_masuk'] as String)
          : null,
      fotoMasuk: json['foto_masuk'] as String?,
      latMasuk: json['lat_masuk'] != null
          ? (json['lat_masuk'] as num).toDouble()
          : null,
      lngMasuk: json['lng_masuk'] != null
          ? (json['lng_masuk'] as num).toDouble()
          : null,
      jarakMasukM: json['jarak_masuk_m'] != null
          ? (json['jarak_masuk_m'] as num).toDouble()
          : null,
      akurasiMasukM: json['akurasi_masuk_m'] != null
          ? (json['akurasi_masuk_m'] as num).toDouble()
          : null,
      jamPulang: json['jam_pulang'] != null
          ? DateTime.tryParse(json['jam_pulang'] as String)
          : null,
      fotoPulang: json['foto_pulang'] as String?,
      latPulang: json['lat_pulang'] != null
          ? (json['lat_pulang'] as num).toDouble()
          : null,
      lngPulang: json['lng_pulang'] != null
          ? (json['lng_pulang'] as num).toDouble()
          : null,
      jarakPulangM: json['jarak_pulang_m'] != null
          ? (json['jarak_pulang_m'] as num).toDouble()
          : null,
      akurasiPulangM: json['akurasi_pulang_m'] != null
          ? (json['akurasi_pulang_m'] as num).toDouble()
          : null,
      status: json['status'] as String? ?? 'alpha',
      catatan: json['catatan'] as String?,
      dikoreksiOleh: json['dikoreksi_oleh'] as String?,
      dikoreksiAt: json['dikoreksi_at'] != null
          ? DateTime.tryParse(json['dikoreksi_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

