import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/web_download.dart';
import '../models/absensi_admin_item.dart';
import '../models/rekap_model.dart';

class RekapDataState {
  final List<RekapRingkasanModel> ringkasan;
  final List<AbsensiAdminItem> details;

  const RekapDataState({required this.ringkasan, required this.details});
}

class RekapFilterRange {
  final DateTime dari;
  final DateTime sampai;

  const RekapFilterRange({required this.dari, required this.sampai});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RekapFilterRange &&
          runtimeType == other.runtimeType &&
          dari == other.dari &&
          sampai == other.sampai;

  @override
  int get hashCode => dari.hashCode ^ sampai.hashCode;
}

final adminRekapDataProvider =
    FutureProvider.family<RekapDataState, RekapFilterRange>(
  (ref, range) async {
    final supabase = ref.watch(supabaseClientProvider);
    final strDari = formatTanggalDb(range.dari);
    final strSampai = formatTanggalDb(range.sampai);

    try {
      // 1. Panggil RPC rekap_ringkasan
      final rpcRes = await supabase.rpc(
        'rekap_ringkasan',
        params: {
          'p_dari': strDari,
          'p_sampai': strSampai,
        },
      );

      final ringkasanList = (rpcRes as List<dynamic>)
          .map((e) => RekapRingkasanModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // 2. Ambil detail baris absensi
      final detailRes = await supabase
          .from('absensi')
          .select('*, profiles:user_id(nama, no_hp, jabatan)')
          .gte('tanggal', strDari)
          .lte('tanggal', strSampai)
          .order('tanggal', ascending: false);

      final detailList = (detailRes as List<dynamic>)
          .map((e) => AbsensiAdminItem.fromJson(e as Map<String, dynamic>))
          .toList();

      return RekapDataState(ringkasan: ringkasanList, details: detailList);
    } catch (e) {
      throw Exception('Gagal memuat data rekap absensi: $e');
    }
  },
);

class AdminRekapService {
  void exportCsv({
    required DateTime dari,
    required DateTime sampai,
    required List<RekapRingkasanModel> ringkasan,
    required List<AbsensiAdminItem> details,
  }) {
    final strDari = formatTanggalDb(dari);
    final strSampai = formatTanggalDb(sampai);
    final filename = 'rekap-absensi_${strDari}_$strSampai.csv';

    final StringBuffer buffer = StringBuffer();

    // Bagian 1: Ringkasan per Karyawan
    buffer.writeln('=== RINGKASAN PRESENSI KARYAWAN ($strDari s/d $strSampai) ===');
    buffer.writeln('No,Nama Karyawan,Nomor HP,Hadir,Terlambat,Total Hadir,Izin,Sakit,Alpha,Total Tidak Hadir');

    for (int i = 0; i < ringkasan.length; i++) {
      final r = ringkasan[i];
      buffer.writeln('${i + 1},"${r.nama}","${r.noHp}",${r.hadir},${r.terlambat},${r.totalHadir},${r.izin},${r.sakit},${r.alpha},${r.totalTidakHadir}');
    }

    buffer.writeln();
    buffer.writeln();

    // Bagian 2: Detail Absensi Harian
    buffer.writeln('=== DETAIL CATATAN ABSENSI HARIAN ===');
    buffer.writeln('No,Tanggal,Nama Karyawan,Nomor HP,Jabatan,Jam Masuk,Jam Pulang,Status,Jarak Masuk (m),Catatan');

    for (int i = 0; i < details.length; i++) {
      final d = details[i];
      final jamMasuk = d.absensi.jamMasukFormatted ?? '-';
      final jamPulang = d.absensi.jamPulangFormatted ?? 'Belum Pulang';
      final jarak = d.absensi.jarakMasukM != null
          ? d.absensi.jarakMasukM!.toStringAsFixed(0)
          : '-';
      final catatan = d.absensi.catatan?.replaceAll('"', '""') ?? '';

      buffer.writeln(
          '${i + 1},${d.absensi.tanggal},"${d.namaKaryawan}","${d.noHpKaryawan}","${d.jabatanKaryawan}",$jamMasuk,$jamPulang,${d.absensi.statusDisplay},$jarak,"$catatan"');
    }

    downloadFileWeb(content: buffer.toString(), filename: filename);
  }
}

final adminRekapServiceProvider = Provider<AdminRekapService>((ref) {
  return AdminRekapService();
});

