import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/models/user_profile.dart';
import '../providers/admin_karyawan_provider.dart';

class KaryawanManagementScreen extends ConsumerStatefulWidget {
  const KaryawanManagementScreen({super.key});

  @override
  ConsumerState<KaryawanManagementScreen> createState() =>
      _KaryawanManagementScreenState();
}

class _KaryawanManagementScreenState
    extends ConsumerState<KaryawanManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTambahKaryawanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _TambahKaryawanDialog(),
    );
  }

  Future<void> _handleResetPassword(UserProfile user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Kata Sandi'),
        content: Text(
          'Reset kata sandi ${user.nama} ke "123456"?\nKaryawan akan diwajibkan mengganti kata sandi saat login berikutnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Sandi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(adminKaryawanServiceProvider);
      await service.resetPassword(user.id);

      if (!mounted) return;
      _showSnackbar(
        'Kata sandi ${user.nama} berhasil direset ke 123456.',
        isError: false,
      );
      ref.invalidate(karyawanListProvider);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _handleUpdatePhone(UserProfile user) async {
    final phoneController = TextEditingController(text: user.noHp);
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nomor HP Karyawan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubah nomor HP untuk ${user.nama}. Nomor baru ini akan digunakan untuk login.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF737686)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP Baru',
                  hintText: '081234567890',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nomor HP wajib diisi';
                  }
                  if (normalisasiHp(val) == null) {
                    return 'Nomor HP tidak valid';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(adminKaryawanServiceProvider);
      await service.updatePhone(
        userId: user.id,
        newPhoneRaw: phoneController.text,
      );

      if (!mounted) return;
      _showSnackbar(
        'Nomor HP ${user.nama} berhasil diperbarui.',
        isError: false,
      );
      ref.invalidate(karyawanListProvider);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _handleToggleAktif(UserProfile user) async {
    final actionText = user.aktif ? 'menonaktifkan' : 'mengaktifkan';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.aktif ? 'Nonaktifkan Akun' : 'Aktifkan Akun'),
        content: Text(
          'Apakah Anda yakin ingin $actionText akun ${user.nama}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  user.aktif ? Colors.red.shade600 : Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(user.aktif ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(adminKaryawanServiceProvider);
      await service.toggleAktif(
        userId: user.id,
        newStatus: !user.aktif,
      );

      if (!mounted) return;
      _showSnackbar(
        'Status akun ${user.nama} berhasil diubah.',
        isError: false,
      );
      ref.invalidate(karyawanListProvider);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final karyawanAsync = ref.watch(karyawanListProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Manajemen Karyawan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(karyawanListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTambahKaryawanDialog,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Karyawan'),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 600,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Cari nama, nomor HP, atau jabatan...',
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
              const SizedBox(height: 16),

              Expanded(
                child: karyawanAsync.when(
                  data: (list) {
                    final filtered = list.where((u) {
                      if (_searchQuery.isEmpty) return true;
                      return u.nama.toLowerCase().contains(_searchQuery) ||
                          u.noHp.contains(_searchQuery) ||
                          u.jabatan.toLowerCase().contains(_searchQuery);
                    }).toList();

                    final totalKaryawan = list.where((u) => u.isKaryawan).length;
                    final totalAktif = list.where((u) => u.isKaryawan && u.aktif).length;
                    final totalNonaktif = totalKaryawan - totalAktif;

                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(karyawanListProvider),
                      child: ListView(
                        children: [
                          // Statistik Baris
                          Row(
                            children: [
                              _buildMiniStat('Total Karyawan', totalKaryawan.toString(), Colors.blue.shade700),
                              const SizedBox(width: 8),
                              _buildMiniStat('Aktif', totalAktif.toString(), Colors.green.shade700),
                              const SizedBox(width: 8),
                              _buildMiniStat('Nonaktif', totalNonaktif.toString(), Colors.grey.shade700),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (filtered.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E7FF)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.person_search_rounded,
                                      size: 48, color: Color(0xFF737686)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Tidak ditemukan karyawan yang cocok dengan pencarian.'
                                        : 'Belum ada karyawan terdaftar.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF737686),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _showTambahKaryawanDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Tambah Karyawan Pertama'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            ...filtered.map((user) => _buildEmployeeCard(user)),
                          const SizedBox(height: 80), // Padding untuk FAB
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
                        Text('Gagal memuat karyawan: $err'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.invalidate(karyawanListProvider),
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E7FF)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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

  Widget _buildEmployeeCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: user.aktif ? const Color(0xFFE2E7FF) : Colors.red.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: user.isAdmin
                  ? Colors.purple.shade50
                  : (user.aktif
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : Colors.grey.shade100),
              child: Icon(
                user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                color: user.isAdmin
                    ? Colors.purple.shade700
                    : (user.aktif ? AppTheme.primaryBlue : Colors.grey.shade500),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nama,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: user.aktif
                                ? const Color(0xFF131B2E)
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (user.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ADMIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${user.jabatan} • ${user.noHp}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737686),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user.aktif
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.aktif ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: user.aktif
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      if (user.wajibGantiPassword) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Sandi Bawaan',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Menu Aksi
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF737686)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                switch (val) {
                  case 'reset':
                    _handleResetPassword(user);
                    break;
                  case 'phone':
                    _handleUpdatePhone(user);
                    break;
                  case 'toggle':
                    _handleToggleAktif(user);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFFD97706)),
                      SizedBox(width: 10),
                      Text('Reset Kata Sandi'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'phone',
                  child: Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, size: 20, color: AppTheme.primaryBlue),
                      SizedBox(width: 10),
                      Text('Ubah Nomor HP'),
                    ],
                  ),
                ),
                PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        user.aktif ? Icons.person_off_rounded : Icons.person_add_alt_1_rounded,
                        size: 20,
                        color: user.aktif ? Colors.red : Colors.green,
                      ),
                      SizedBox(width: 10),
                      Text(user.aktif ? 'Nonaktifkan Akun' : 'Aktifkan Akun'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog Form Tambah Karyawan Baru
class _TambahKaryawanDialog extends ConsumerStatefulWidget {
  const _TambahKaryawanDialog();

  @override
  ConsumerState<_TambahKaryawanDialog> createState() =>
      _TambahKaryawanDialogState();
}

class _TambahKaryawanDialogState extends ConsumerState<_TambahKaryawanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _hpController = TextEditingController();
  final _jabatanController = TextEditingController();
  String _selectedRole = 'karyawan';
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _hpController.dispose();
    _jabatanController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final normHp = normalisasiHp(_hpController.text);
    if (normHp == null) {
      _showError('Nomor HP tidak valid. Contoh: 081234567890');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminKaryawanServiceProvider);
      await service.createKaryawan(
        nama: _namaController.text,
        noHpRaw: _hpController.text,
        jabatan: _jabatanController.text,
        role: _selectedRole,
      );

      if (!mounted) return;
      Navigator.pop(context); // Tutup form dialog

      // Refresh list karyawan
      ref.invalidate(karyawanListProvider);

      // Tampilkan popup sukses berisi info login
      _showSuccessPopup(
        nama: _namaController.text.trim(),
        noHp: normHp,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessPopup({required String nama, required String noHp}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Akun Karyawan Berhasil Dibuat!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCopyRow('Nama', nama),
                  const SizedBox(height: 8),
                  _buildCopyRow('Nomor HP (Login)', noHp),
                  const SizedBox(height: 8),
                  _buildCopyRow('Password Bawaan', '123456'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Karyawan dapat langsung login dengan nomor HP dan sandi 123456. Sistem akan otomatis meminta pembuatan sandi baru saat login pertama.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF737686), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontSize: 12, color: Color(0xFF737686)),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label berhasil disalin'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryBlue),
          SizedBox(width: 10),
          Text(
            'Tambah Karyawan Baru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Daftarkan karyawan baru. Akun login akan dibuat otomatis dengan password default "123456".',
                  style: TextStyle(fontSize: 12, color: Color(0xFF737686)),
                ),
                const SizedBox(height: 16),

                // Nama Lengkap
                TextFormField(
                  controller: _namaController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    hintText: 'Mis. Budi Santoso',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Nomor HP
                TextFormField(
                  controller: _hpController,
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp / HP',
                    hintText: 'Mis. 081234567890',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nomor HP wajib diisi';
                    }
                    if (normalisasiHp(val) == null) {
                      return 'Nomor HP tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Jabatan
                TextFormField(
                  controller: _jabatanController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Jabatan / Posisi',
                    hintText: 'Mis. Staff Operasional',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Jabatan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Role
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Peran Akun',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'karyawan',
                      child: Text('Karyawan (Peserta Absen)'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrator (Pengelola)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRole = val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 44),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan & Buat Akun'),
        ),
      ],
    );
  }
}
