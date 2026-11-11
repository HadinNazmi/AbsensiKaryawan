import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../models/user_profile.dart';

enum AuthStatus {
  initial,         // Memeriksa sesi tersimpan (saat start/refresh)
  unauthenticated, // Belum login atau sudah logout
  authenticated,   // Berhasil login dan profil aktif
}

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final User? user;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.profile,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && profile != null && user != null;

  bool get isInitial => status == AuthStatus.initial;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    User? user,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final SupabaseClient _supabase;

  @override
  AuthState build() {
    _supabase = ref.watch(supabaseClientProvider);

    final sub = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });

    ref.onDispose(() {
      sub.cancel();
    });

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    // Jika ada currentUser dari browser storage (refresh halaman), ambil profilnya
    Future.microtask(() => _loadUserProfile(currentUser));
    return const AuthState(status: AuthStatus.initial, isLoading: true);
  }

  /// Memuat profil dari tabel 'profiles'
  Future<void> _loadUserProfile(User user) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (res == null) {
        await _supabase.auth.signOut();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Data profil tidak ditemukan.',
        );
        return;
      }

      final profile = UserProfile.fromJson(res);

      // Karyawan nonaktif: aplikasi harus langsung logout setelah login
      if (!profile.aktif) {
        await _supabase.auth.signOut();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Akun Anda dinonaktifkan',
        );
        return;
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        profile: profile,
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Gagal mengambil data profil: ${e.toString()}',
      );
    }
  }

  /// Refresh data profil pengguna saat ini
  Future<void> refreshProfile() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      await _loadUserProfile(currentUser);
    }
  }

  /// Proses Login nomor HP + Password
  Future<bool> login({
    required String noHpRaw,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Normalisasi nomor HP
    final normHp = normalisasiHp(noHpRaw);
    if (normHp == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Nomor HP tidak valid',
      );
      return false;
    }

    // 2. Email internal dari nomor HP
    final email = emailDariHp(normHp);

    try {
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Nomor HP atau password salah',
        );
        return false;
      }

      // 3. Ambil data profil
      final profileRes = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (profileRes == null) {
        await _supabase.auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Data profil tidak ditemukan.',
        );
        return false;
      }

      final profile = UserProfile.fromJson(profileRes);

      // 4. Validasi keaktifan akun
      if (!profile.aktif) {
        await _supabase.auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Akun Anda dinonaktifkan',
        );
        return false;
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        profile: profile,
        isLoading: false,
      );
      return true;
    } on AuthException {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Nomor HP atau password salah',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      );
      return false;
    }
  }

  /// Ganti password awal (saat wajib_ganti_password = true)
  Future<void> submitGantiPasswordAwal({
    required String passwordBaru,
    required String konfirmasiPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (passwordBaru.length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password minimal 6 karakter',
      );
      throw Exception('Password minimal 6 karakter');
    }

    if (passwordBaru == '123456') {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password tidak boleh "123456"',
      );
      throw Exception('Password tidak boleh "123456"');
    }

    if (passwordBaru != konfirmasiPassword) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Konfirmasi password tidak cocok',
      );
      throw Exception('Konfirmasi password tidak cocok');
    }

    try {
      // 1. Update password di Supabase Auth
      await _supabase.auth.updateUser(
        UserAttributes(password: passwordBaru),
      );

      // 2. Panggil RPC selesai_ganti_password
      await _supabase.rpc('selesai_ganti_password');

      // 3. Muat ulang profil untuk memperbarui wajib_ganti_password = false
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        await _loadUserProfile(currentUser);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui password: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Ganti password dari halaman Profil (memeriksa password lama)
  Future<void> gantiPasswordProfil({
    required String passwordLama,
    required String passwordBaru,
    required String konfirmasiPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (passwordLama.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password lama wajib diisi',
      );
      throw Exception('Password lama wajib diisi');
    }

    if (passwordBaru.length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password baru minimal 6 karakter',
      );
      throw Exception('Password baru minimal 6 karakter');
    }

    if (passwordBaru == '123456') {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password baru tidak boleh "123456"',
      );
      throw Exception('Password baru tidak boleh "123456"');
    }

    if (passwordBaru == passwordLama) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password baru tidak boleh sama dengan password lama',
      );
      throw Exception('Password baru tidak boleh sama dengan password lama');
    }

    if (passwordBaru != konfirmasiPassword) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Konfirmasi password baru tidak cocok',
      );
      throw Exception('Konfirmasi password baru tidak cocok');
    }

    final currentUser = _supabase.auth.currentUser;
    final currentProfile = state.profile;
    if (currentUser == null || currentProfile == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sesi tidak valid, silakan login ulang',
      );
      throw Exception('Sesi tidak valid, silakan login ulang');
    }

    final internalEmail = currentUser.email ?? emailDariHp(currentProfile.noHp);

    // 1. Verifikasi password lama dengan signInWithPassword
    try {
      await _supabase.auth.signInWithPassword(
        email: internalEmail,
        password: passwordLama,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password lama salah',
      );
      throw Exception('Password lama salah');
    }

    // 2. Jika valid, update password baru
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: passwordBaru),
      );
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui password: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Keluar / Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _supabase.auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
