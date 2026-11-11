import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGantiPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      _showSnackbar('Password baru minimal 6 karakter', isError: true);
      return;
    }

    if (newPass == '123456') {
      _showSnackbar('Password baru tidak boleh "123456"', isError: true);
      return;
    }

    if (newPass == oldPass) {
      _showSnackbar(
        'Password baru tidak boleh sama dengan password lama',
        isError: true,
      );
      return;
    }

    if (newPass != confirmPass) {
      _showSnackbar('Konfirmasi password baru tidak cocok', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      await authNotifier.gantiPasswordProfil(
        passwordLama: oldPass,
        passwordBaru: newPass,
        konfirmasiPassword: confirmPass,
      );

      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnackbar('Password berhasil diperbarui', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authNotifierProvider).profile;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // Jika dibuka langsung via URL, arahkan sesuai role
              if (profile?.isAdmin ?? false) {
                context.go('/admin');
              } else {
                context.go('/karyawan');
              }
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Informasi Profil Pengguna
                Container(
                  padding: const EdgeInsets.all(20),
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
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.nama ?? '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF131B2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: profile?.isAdmin == true
                              ? Colors.purple.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile?.isAdmin == true
                              ? 'Administrator'
                              : (profile?.jabatan ?? 'Karyawan'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: profile?.isAdmin == true
                                ? Colors.purple.shade700
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFF2F3FF), thickness: 1.5),
                      const SizedBox(height: 8),

                      // Info baris nomor HP & Jabatan
                      _buildInfoRow(
                        icon: Icons.smartphone_rounded,
                        label: 'Nomor WhatsApp / HP',
                        value: profile?.noHp ?? '-',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Jabatan',
                        value: profile?.jabatan ?? '-',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.shield_outlined,
                        label: 'Peran Akun',
                        value: profile?.role.toUpperCase() ?? '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Card Form Ganti Password
                Container(
                  padding: const EdgeInsets.all(24),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_reset_rounded,
                              color: AppTheme.primaryBlue,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ganti Kata Sandi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Perbarui kata sandi secara berkala untuk menjaga keamanan akun Anda.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF737686),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password Lama
                        const Text(
                          'Password Lama',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _oldPasswordController,
                          obscureText: _obscureOld,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: 'Masukkan password lama',
                            prefixIcon: const Icon(
                              Icons.key_rounded,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureOld
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF737686),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureOld = !_obscureOld;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password lama wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Baru
                        const Text(
                          'Password Baru',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: 'Minimal 6 karakter, bukan 123456',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF737686),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNew = !_obscureNew;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password baru wajib diisi';
                            }
                            if (value.length < 6) {
                              return 'Minimal 6 karakter';
                            }
                            if (value == '123456') {
                              return 'Tidak boleh "123456"';
                            }
                            if (value == _oldPasswordController.text) {
                              return 'Tidak boleh sama dengan password lama';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Konfirmasi Password Baru
                        const Text(
                          'Konfirmasi Password Baru',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: 'Ulangi password baru',
                            prefixIcon: const Icon(
                              Icons.lock_reset_rounded,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF737686),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirm = !_obscureConfirm;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Konfirmasi password baru wajib diisi';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Konfirmasi password baru tidak cocok';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Tombol Simpan Password Baru
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleGantiPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Perbarui Password'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Keluar di Bawah
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Keluar dari Akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF737686)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF737686),
          ),
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

