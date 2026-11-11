import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/absensi_model.dart';
import '../providers/absensi_provider.dart';

class KaryawanHomeScreen extends ConsumerStatefulWidget {
  const KaryawanHomeScreen({super.key});

  @override
  ConsumerState<KaryawanHomeScreen> createState() => _KaryawanHomeScreenState();
}

class _KaryawanHomeScreenState extends ConsumerState<KaryawanHomeScreen> {
  late Timer _clockTimer;
  DateTime _currentWibTime = toWib(DateTime.now());

  @override
  void initState() {
    super.initState();
    // Jam digital berjalan (WIB)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentWibTime = toWib(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _currentWibTime.hour;
    if (hour >= 4 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authNotifierProvider).profile;
    final nama = profile?.nama ?? 'Karyawan';
    final todayAbsensiAsync = ref.watch(todayAbsensiProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Absensi Karyawan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Riwayat Absensi',
            icon: const Icon(Icons.history_rounded, size: 26),
            onPressed: () => context.push('/karyawan/riwayat'),
          ),
          IconButton(
            tooltip: 'Profil Saya',
            icon: const Icon(Icons.account_circle_outlined, size: 26),
            onPressed: () => context.push('/profil'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(todayAbsensiProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Salam & Profil
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 28,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()},',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF737686),
                              ),
                            ),
                            Text(
                              nama,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF131B2E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile?.jabatan ?? 'Karyawan',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Banner Jam Digital Berjalan & Tanggal WIB
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF004AC6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004AC6).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatTanggalLengkap(DateTime.now()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'WIB',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          DateFormat('HH:mm:ss').format(_currentWibTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Waktu Server Resmi Presensi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Kartu Status Absensi Hari Ini
                  todayAbsensiAsync.when(
                    data: (absensi) => _buildTodayStatusCard(context, absensi),
                    loading: () => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E7FF)),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.red.shade400, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat status absensi: $err',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref.invalidate(todayAbsensiProvider),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Menu Pintas Tambahan
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          context: context,
                          icon: Icons.calendar_month_rounded,
                          title: 'Riwayat Absensi',
                          subtitle: 'Rekap kehadiran bulan ini',
                          color: const Color(0xFF2563EB),
                          onTap: () => context.push('/karyawan/riwayat'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildQuickActionCard(
                          context: context,
                          icon: Icons.manage_accounts_rounded,
                          title: 'Profil & Sandi',
                          subtitle: 'Pengaturan akun Anda',
                          color: const Color(0xFF006C49),
                          onTap: () => context.push('/profil'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatusCard(BuildContext context, AbsensiModel? absensi) {
    // Kondisi:
    // 1. Belum Masuk: absensi == null || !absensi.sudahMasuk
    // 2. Sudah Masuk: absensi.sudahMasuk && !absensi.sudahPulang
    // 3. Sudah Pulang: absensi.sudahMasuk && absensi.sudahPulang

    final bool sudahMasuk = absensi?.sudahMasuk ?? false;
    final bool sudahPulang = absensi?.sudahPulang ?? false;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E7FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Presensi Hari Ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131B2E),
                ),
              ),
              if (absensi != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: absensi.statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    absensi.statusDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: absensi.statusColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Baris Statistik Jam Masuk & Jam Pulang (Waktu Server WIB)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 16,
                            color: sudahMasuk ? Colors.green.shade700 : const Color(0xFF737686),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Jam Masuk',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF737686),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sudahMasuk ? (absensi?.jamMasukFormatted ?? '-') : '-- : --',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: sudahMasuk ? const Color(0xFF131B2E) : const Color(0xFF737686),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sudahMasuk ? 'Tercatat di server' : 'Belum absen masuk',
                        style: TextStyle(
                          fontSize: 11,
                          color: sudahMasuk ? Colors.green.shade700 : const Color(0xFF737686),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: sudahPulang ? Colors.orange.shade700 : const Color(0xFF737686),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Jam Pulang',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF737686),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sudahPulang ? (absensi?.jamPulangFormatted ?? '-') : '-- : --',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: sudahPulang ? const Color(0xFF131B2E) : const Color(0xFF737686),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sudahPulang ? 'Tercatat di server' : 'Belum absen pulang',
                        style: TextStyle(
                          fontSize: 11,
                          color: sudahPulang ? Colors.orange.shade700 : const Color(0xFF737686),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tombol Tindakan Presensi Sesuai Kondisi
          if (!sudahMasuk) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final result = await context.push<bool>('/karyawan/absen?tipe=masuk');
                if (result == true) {
                  ref.invalidate(todayAbsensiProvider);
                }
              },
              icon: const Icon(Icons.fingerprint_rounded, size: 22),
              label: const Text('Absen Masuk Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ] else if (!sudahPulang) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final result = await context.push<bool>('/karyawan/absen?tipe=pulang');
                if (result == true) {
                  ref.invalidate(todayAbsensiProvider);
                }
              },
              icon: const Icon(Icons.exit_to_app_rounded, size: 22),
              label: const Text('Absen Pulang Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C), // Orange vibrant
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Text(
                    'Presensi Hari Ini Selesai',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF737686),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
