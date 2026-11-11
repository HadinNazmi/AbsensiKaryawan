import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/providers/auth_provider.dart';
import '../../karyawan/providers/absensi_provider.dart';
import '../models/absensi_admin_item.dart';
import '../providers/admin_karyawan_provider.dart';
import '../providers/admin_monitoring_provider.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  String _selectedFilter = 'semua';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showKoreksiDialog(AbsensiAdminItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _KoreksiStatusDialog(item: item),
    );
  }

  void _showInputManualDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _InputManualStatusDialog(),
    );
  }

  void _showPhotoDialog(String photoPath, String title) async {
    showDialog(
      context: context,
      builder: (ctx) => _ViewPhotoDialog(photoPath: photoPath, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authNotifierProvider).profile;
    final nama = profile?.nama ?? 'Administrator';
    final todayAbsensiAsync = ref.watch(adminTodayAbsensiProvider);
    final totalKaryawanAsync = ref.watch(totalKaryawanAktifProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Panel Administrator',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Profil Saya',
            icon: const Icon(Icons.account_circle_outlined, size: 26),
            onPressed: () => context.push('/profil'),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminTodayAbsensiProvider);
              ref.invalidate(totalKaryawanAktifProvider);
            },
            child: ListView(
              children: [
                // 1. Banner Salam Admin
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, $nama',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Administrator HR & Operasional',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${formatTanggalLengkap(DateTime.now())} (WIB)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Navigasi Cepat Modul Admin
                Row(
                  children: [
                    Expanded(
                      child: _buildNavModuleCard(
                        icon: Icons.people_alt_rounded,
                        title: 'Kelola Karyawan',
                        subtitle: 'Tambah akun & reset',
                        color: const Color(0xFF2563EB),
                        onTap: () => context.push('/admin/karyawan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildNavModuleCard(
                        icon: Icons.tune_rounded,
                        title: 'Pengaturan Kantor',
                        subtitle: 'GPS & hari libur',
                        color: const Color(0xFF006C49),
                        onTap: () => context.push('/admin/pengaturan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildNavModuleCard(
                        icon: Icons.table_chart_rounded,
                        title: 'Rekap & Ekspor',
                        subtitle: 'Laporan kehadiran',
                        color: const Color(0xFFD97706),
                        onTap: () => context.push('/admin/rekap'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Metrik Statistik Absensi Hari Ini
                todayAbsensiAsync.when(
                  data: (items) {
                    final totalAktif = totalKaryawanAsync.value ?? items.length;
                    int hadir = 0;
                    int terlambat = 0;
                    int izinSakit = 0;
                    int alpha = 0;

                    for (final item in items) {
                      switch (item.absensi.status.toLowerCase()) {
                        case 'hadir':
                          hadir++;
                          break;
                        case 'terlambat':
                          terlambat++;
                          break;
                        case 'izin':
                        case 'sakit':
                          izinSakit++;
                          break;
                        case 'alpha':
                          alpha++;
                          break;
                      }
                    }

                    final sudahAbsen = items.where((e) => e.absensi.sudahMasuk).length;
                    final belumAbsen = totalAktif > sudahAbsen ? totalAktif - sudahAbsen : 0;

                    return Column(
                      children: [
                        Row(
                          children: [
                            _buildStatCard('Hadir', hadir.toString(), const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
                            const SizedBox(width: 8),
                            _buildStatCard('Terlambat', terlambat.toString(), const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                            const SizedBox(width: 8),
                            _buildStatCard('Belum Absen', belumAbsen.toString(), const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                            const SizedBox(width: 8),
                            _buildStatCard('Izin/Alpha', (izinSakit + alpha).toString(), const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                    ),
                  ),
                  error: (err, _) => Text('Gagal memuat statistik: $err'),
                ),
                const SizedBox(height: 20),

                // 4. Bar Pencarian, Filter Status & Tombol Tambah Status Manual
                Row(
                  children: [
                    const Text(
                      'Monitoring Hari Ini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _showInputManualDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      label: const Text('Input Status Manual', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau nomor HP karyawan...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('semua', 'Semua Status'),
                      _buildFilterChip('hadir', 'Hadir'),
                      _buildFilterChip('terlambat', 'Terlambat'),
                      _buildFilterChip('izin', 'Izin / Sakit'),
                      _buildFilterChip('alpha', 'Alpha'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Daftar Baris Absensi Hari Ini
                todayAbsensiAsync.when(
                  data: (items) {
                    final filtered = items.where((item) {
                      final matchesSearch = _searchQuery.isEmpty ||
                          item.namaKaryawan.toLowerCase().contains(_searchQuery) ||
                          item.noHpKaryawan.contains(_searchQuery);

                      if (!matchesSearch) return false;

                      if (_selectedFilter == 'semua') return true;
                      if (_selectedFilter == 'izin') {
                        return item.absensi.status.toLowerCase() == 'izin' ||
                            item.absensi.status.toLowerCase() == 'sakit';
                      }
                      return item.absensi.status.toLowerCase() == _selectedFilter;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E7FF)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inbox_rounded, size: 40, color: Color(0xFF737686)),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada data absensi untuk filter ini hari ini.',
                              style: TextStyle(color: Color(0xFF737686), fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: filtered.map((item) => _buildAbsensiMonitoringCard(item)).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text('Gagal memuat daftar absensi: $err'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavModuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E7FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF737686)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, Color bgColor) {
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
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _selectedFilter = key);
        },
        selectedColor: AppTheme.primaryBlue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF434655),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAbsensiMonitoringCard(AbsensiAdminItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Foto Masuk (Klik untuk preview)
              GestureDetector(
                onTap: item.absensi.fotoMasuk != null
                    ? () => _showPhotoDialog(
                          item.absensi.fotoMasuk!,
                          'Swafoto Masuk - ${item.namaKaryawan}',
                        )
                    : null,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.surfaceContainerLow,
                  child: item.absensi.fotoMasuk != null
                      ? const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryBlue, size: 20)
                      : const Icon(Icons.person_rounded, color: Color(0xFF737686)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaKaryawan,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    Text(
                      '${item.jabatanKaryawan} • ${item.noHpKaryawan}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF737686)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: item.absensi.statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.absensi.statusDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.absensi.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Baris Detail Jam & Jarak
          Row(
            children: [
              Expanded(
                child: _buildMiniDetail(
                  label: 'Masuk',
                  value: item.absensi.jamMasukFormatted ?? '-',
                  sub: item.absensi.jarakMasukM != null
                      ? '${item.absensi.jarakMasukM!.toStringAsFixed(0)}m dari kantor'
                      : null,
                ),
              ),
              Expanded(
                child: _buildMiniDetail(
                  label: 'Pulang',
                  value: item.absensi.jamPulangFormatted ?? 'Belum Pulang',
                  sub: item.absensi.jarakPulangM != null
                      ? '${item.absensi.jarakPulangM!.toStringAsFixed(0)}m dari kantor'
                      : null,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showKoreksiDialog(item),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Koreksi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          if (item.absensi.catatan != null && item.absensi.catatan!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan: ${item.absensi.catatan}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF434655)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniDetail({required String label, required String value, String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF737686)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF131B2E),
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: Color(0xFF737686)),
          ),
      ],
    );
  }
}

/// Dialog Koreksi Status Absensi oleh Admin
class _KoreksiStatusDialog extends ConsumerStatefulWidget {
  final AbsensiAdminItem item;

  const _KoreksiStatusDialog({required this.item});

  @override
  ConsumerState<_KoreksiStatusDialog> createState() => _KoreksiStatusDialogState();
}

class _KoreksiStatusDialogState extends ConsumerState<_KoreksiStatusDialog> {
  late String _status;
  final _catatanController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.item.absensi.status.toLowerCase();
    _catatanController.text = widget.item.absensi.catatan ?? '';
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submitKoreksi() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminMonitoringServiceProvider);
      await service.koreksiStatus(
        absensiId: widget.item.absensi.id,
        newStatus: _status,
        catatan: _catatanController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status absensi berhasil dikoreksi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Koreksi Absensi: ${widget.item.namaKaryawan}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ubah status absensi dan berikan catatan alasan koreksi.',
              style: TextStyle(fontSize: 12, color: Color(0xFF737686)),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status Kehadiran'),
              items: const [
                DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                DropdownMenuItem(value: 'terlambat', child: Text('Terlambat')),
                DropdownMenuItem(value: 'izin', child: Text('Izin')),
                DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _catatanController,
              decoration: const InputDecoration(
                labelText: 'Catatan Koreksi',
                hintText: 'Mis. Izin dokter, koreksi jam masuk',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitKoreksi,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan Koreksi'),
        ),
      ],
    );
  }
}

/// Dialog Input Status Manual untuk Karyawan yang Izin/Sakit
class _InputManualStatusDialog extends ConsumerStatefulWidget {
  const _InputManualStatusDialog();

  @override
  ConsumerState<_InputManualStatusDialog> createState() => _InputManualStatusDialogState();
}

class _InputManualStatusDialogState extends ConsumerState<_InputManualStatusDialog> {
  String? _selectedUserId;
  String _selectedStatus = 'izin';
  final _catatanController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih karyawan terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminMonitoringServiceProvider);
      final todayWib = formatTanggalDb(DateTime.now());

      await service.inputStatusManual(
        userId: _selectedUserId!,
        tanggal: todayWib,
        status: _selectedStatus,
        catatan: _catatanController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status manual berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final karyawanListAsync = ref.watch(karyawanListProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Input Status Manual Hari Ini'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gunakan ini jika karyawan izin, sakit, atau berhalangan absen mandiri.',
              style: TextStyle(fontSize: 12, color: Color(0xFF737686)),
            ),
            const SizedBox(height: 16),
            karyawanListAsync.when(
              data: (list) {
                final karyawanOnly = list.where((u) => u.isKaryawan && u.aktif).toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  decoration: const InputDecoration(labelText: 'Pilih Karyawan'),
                  items: karyawanOnly
                      .map((u) => DropdownMenuItem(
                            value: u.id,
                            child: Text('${u.nama} (${u.jabatan})'),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedUserId = val),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal memuat karyawan: $err'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'izin', child: Text('Izin')),
                DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                DropdownMenuItem(value: 'hadir', child: Text('Hadir Manual')),
                DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _catatanController,
              decoration: const InputDecoration(
                labelText: 'Keterangan / Catatan',
                hintText: 'Mis. Surat dokter terlampir, dinas luar',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Dialog Lihat Foto Swafoto via Signed URL
class _ViewPhotoDialog extends ConsumerStatefulWidget {
  final String photoPath;
  final String title;

  const _ViewPhotoDialog({required this.photoPath, required this.title});

  @override
  ConsumerState<_ViewPhotoDialog> createState() => _ViewPhotoDialogState();
}

class _ViewPhotoDialogState extends ConsumerState<_ViewPhotoDialog> {
  String? _signedUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    try {
      final service = ref.read(absensiServiceProvider);
      final url = await service.getSignedPhotoUrl(widget.photoPath);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(widget.title, style: const TextStyle(fontSize: 14)),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_isLoading)
            const SizedBox(
              height: 240,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Gagal memuat foto: $_error', style: const TextStyle(color: Colors.red)),
            )
          else if (_signedUrl != null)
            Image.network(
              _signedUrl!,
              height: 380,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Foto tidak dapat ditampilkan'),
              ),
            ),
        ],
      ),
    );
  }
}
