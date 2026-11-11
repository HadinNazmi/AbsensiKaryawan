import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_center.dart';
import '../providers/admin_rekap_provider.dart';

class RekapAbsensiScreen extends ConsumerStatefulWidget {
  const RekapAbsensiScreen({super.key});

  @override
  ConsumerState<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends ConsumerState<RekapAbsensiScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _dari;
  late DateTime _sampai;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dari = DateTime(now.year, now.month, 1);
    _sampai = now;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pilihRentangTanggal() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _dari, end: _sampai),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryBlue,
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dari = picked.start;
        _sampai = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterRange = RekapFilterRange(dari: _dari, sampai: _sampai);
    final rekapAsync = ref.watch(adminRekapDataProvider(filterRange));

    final strFormat = DateFormat('d MMM yyyy', 'id_ID');

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Rekapitulasi Kehadiran',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminRekapDataProvider(filterRange)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: const Color(0xFF737686),
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Ringkasan Karyawan'),
            Tab(icon: Icon(Icons.view_list_rounded), text: 'Detail Harian'),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter Rentang Tanggal & Tombol Ekspor
              Container(
                padding: const EdgeInsets.all(16),
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
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pilihRentangTanggal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.date_range_rounded,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${strFormat.format(_dari)} - ${strFormat.format(_sampai)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF131B2E),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: rekapAsync.value != null
                          ? () {
                              final data = rekapAsync.value!;
                              ref.read(adminRekapServiceProvider).exportCsv(
                                    dari: _dari,
                                    sampai: _sampai,
                                    ringkasan: data.ringkasan,
                                    details: data.details,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('File rekap berhasil diunduh.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Ekspor (CSV/Excel)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Konten Tab View
              Expanded(
                child: rekapAsync.when(
                  data: (data) {
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Ringkasan Karyawan
                        _buildRingkasanTab(data),

                        // Tab 2: Detail Harian
                        _buildDetailTab(data),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Gagal memuat rekap: $err'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(adminRekapDataProvider(filterRange)),
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

  Widget _buildRingkasanTab(RekapDataState data) {
    if (data.ringkasan.isEmpty) {
      return const Center(child: Text('Tidak ada data pada periode ini.'));
    }

    return ListView.builder(
      itemCount: data.ringkasan.length,
      itemBuilder: (ctx, index) {
        final r = data.ringkasan[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E7FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.nama,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ),
                  Text(
                    r.noHp,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737686),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatPill('Hadir', r.hadir.toString(), Colors.green),
                  _buildStatPill('Terlambat', r.terlambat.toString(), Colors.amber.shade800),
                  _buildStatPill('Izin', r.izin.toString(), Colors.blue),
                  _buildStatPill('Sakit', r.sakit.toString(), Colors.blue.shade700),
                  _buildStatPill('Alpha', r.alpha.toString(), Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTab(RekapDataState data) {
    if (data.details.isEmpty) {
      return const Center(child: Text('Tidak ada detail absensi pada periode ini.'));
    }

    return ListView.builder(
      itemCount: data.details.length,
      itemBuilder: (ctx, index) {
        final d = data.details[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E7FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    d.namaKaryawan,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: d.absensi.statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      d.absensi.statusDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: d.absensi.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${d.absensi.tanggal} • ${d.noHpKaryawan} (${d.jabatanKaryawan})',
                style: const TextStyle(fontSize: 11, color: Color(0xFF737686)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Masuk: ${d.absensi.jamMasukFormatted ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF434655)),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Pulang: ${d.absensi.jamPulangFormatted ?? 'Belum Pulang'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF434655)),
                  ),
                ],
              ),
              if (d.absensi.catatan != null && d.absensi.catatan!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Catatan: ${d.absensi.catatan}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF737686)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
