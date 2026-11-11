import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive_center.dart';
import '../models/absensi_model.dart';
import '../providers/absensi_provider.dart';

class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Future<void> _selectMonthDialog() async {
    final now = DateTime.now();
    final List<DateTime> months = [];
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(now.year, now.month - i));
    }

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Periode Bulan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (ctx, index) {
                    final m = months[index];
                    final isCurrent = m.year == _selectedMonth.year &&
                        m.month == _selectedMonth.month;
                    return ListTile(
                      title: Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(m),
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? AppTheme.primaryBlue : const Color(0xFF131B2E),
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppTheme.primaryBlue)
                          : null,
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedMonth = selected;
      });
    }
  }

  void _showDetailAbsensi(AbsensiModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AbsensiDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riwayatAsync = ref.watch(riwayatAbsensiProvider(_selectedMonth));

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Riwayat Presensi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 500,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Bar Navigasi Pemilih Bulan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E7FF)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _previousMonth,
                    ),
                    InkWell(
                      onTap: _selectMonthDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: Color(0xFF737686),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Daftar Riwayat & Ringkasan
              Expanded(
                child: riwayatAsync.when(
                  data: (items) {
                    // Hitung ringkasan
                    int hadir = 0;
                    int terlambat = 0;
                    int alpha = 0;
                    int izinSakit = 0;

                    for (final a in items) {
                      switch (a.status.toLowerCase()) {
                        case 'hadir':
                          hadir++;
                          break;
                        case 'terlambat':
                          terlambat++;
                          break;
                        case 'alpha':
                          alpha++;
                          break;
                        case 'izin':
                        case 'sakit':
                          izinSakit++;
                          break;
                      }
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(riwayatAbsensiProvider(_selectedMonth));
                      },
                      child: ListView(
                        children: [
                          // Widget Ringkasan Bulan Berjalan
                          _buildSummaryWidget(hadir, terlambat, alpha, izinSakit),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Catatan Kehadiran',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF131B2E),
                                ),
                              ),
                              Text(
                                '${items.length} hari tercatat',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF737686),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (items.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E7FF)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.event_busy_rounded,
                                      size: 48, color: Color(0xFF737686)),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada catatan presensi pada bulan ini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF737686),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...items.map((item) => _buildAbsensiItem(item)),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Gagal memuat riwayat: $err'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(riwayatAbsensiProvider(_selectedMonth)),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryWidget(int hadir, int terlambat, int alpha, int izinSakit) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E7FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Kehadiran',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF737686),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatMetric(
                label: 'Tepat Waktu',
                count: hadir,
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 8),
              _buildStatMetric(
                label: 'Terlambat',
                count: terlambat,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 8),
              _buildStatMetric(
                label: 'Alpha',
                count: alpha,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
              ),
              if (izinSakit > 0) ...[
                const SizedBox(width: 8),
                _buildStatMetric(
                  label: 'Izin/Sakit',
                  count: izinSakit,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsensiItem(AbsensiModel item) {
    // Format tanggal
    DateTime? dt;
    try {
      dt = DateTime.parse(item.tanggal);
    } catch (_) {}

    final tanggalFormatted =
        dt != null ? formatTanggalLengkap(dt) : item.tanggal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E7FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailAbsensi(item),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Baris: Tanggal & Badge Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tanggalFormatted,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.statusBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.statusDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Jam Masuk dan Jam Pulang
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.login_rounded,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Masuk',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF737686))),
                              Text(
                                item.jamMasukFormatted ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF131B2E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pulang',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF737686))),
                              Text(
                                item.jamPulang != null
                                    ? item.jamPulangFormatted!
                                    : 'Belum pulang',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: item.jamPulang != null
                                      ? const Color(0xFF131B2E)
                                      : const Color(0xFF737686),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF737686),
                      size: 20,
                    ),
                  ],
                ),

                if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Catatan: ${item.catatan}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF737686),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom Sheet untuk melihat detail foto selfie dan metrik GPS
class _AbsensiDetailSheet extends ConsumerStatefulWidget {
  final AbsensiModel item;

  const _AbsensiDetailSheet({required this.item});

  @override
  ConsumerState<_AbsensiDetailSheet> createState() => _AbsensiDetailSheetState();
}

class _AbsensiDetailSheetState extends ConsumerState<_AbsensiDetailSheet> {
  String? _fotoMasukUrl;
  String? _fotoPulangUrl;
  bool _isLoadingPhotos = true;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    _loadSignedUrls();
  }

  Future<void> _loadSignedUrls() async {
    final service = ref.read(absensiServiceProvider);

    try {
      if (widget.item.fotoMasuk != null) {
        _fotoMasukUrl =
            await service.getSignedPhotoUrl(widget.item.fotoMasuk!);
      }
      if (widget.item.fotoPulang != null) {
        _fotoPulangUrl =
            await service.getSignedPhotoUrl(widget.item.fotoPulang!);
      }
    } catch (e) {
      _photoError = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoadingPhotos = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Presensi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item.tanggal,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF737686)),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.statusBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.statusDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: item.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Foto Selfie (Masuk & Pulang via Signed URL)
            const Text(
              'Foto Selfie Presensi (Signed URL)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(height: 10),

            if (_isLoadingPhotos)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              )
            else if (_photoError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Gagal memuat foto: $_photoError',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Foto Masuk',
                      url: _fotoMasukUrl,
                      jam: item.jamMasukFormatted,
                      jarak: item.jarakMasukM,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Foto Pulang',
                      url: _fotoPulangUrl,
                      jam: item.jamPulangFormatted,
                      jarak: item.jarakPulangM,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Rincian Lokasi dan Jam
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.login_rounded,
                    label: 'Jam Masuk',
                    value: item.jamMasukFormatted ?? '-',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.place_outlined,
                    label: 'Jarak Masuk',
                    value: item.jarakMasukM != null
                        ? '${item.jarakMasukM!.toStringAsFixed(0)} m'
                        : '-',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    icon: Icons.logout_rounded,
                    label: 'Jam Pulang',
                    value: item.jamPulangFormatted ?? 'Belum pulang',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.place_outlined,
                    label: 'Jarak Pulang',
                    value: item.jarakPulangM != null
                        ? '${item.jarakPulangM!.toStringAsFixed(0)} m'
                        : '-',
                  ),
                  if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                    const Divider(height: 16),
                    _buildDetailRow(
                      icon: Icons.notes_rounded,
                      label: 'Catatan',
                      value: item.catatan!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required String title,
    required String? url,
    required String? jam,
    required double? jarak,
  }) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E7FF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${jam ?? '-'} • ${jarak != null ? '${jarak.toStringAsFixed(0)}m' : '-'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined,
                      color: Colors.grey.shade400, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    '$title\nTidak Ada',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF737686)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF737686)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF131B2E),
          ),
        ),
      ],
    );
  }
}
