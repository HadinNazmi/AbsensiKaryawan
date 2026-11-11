import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/admin/presentation/karyawan_management_screen.dart';
import '../../features/admin/presentation/pengaturan_kantor_screen.dart';
import '../../features/admin/presentation/rekap_absensi_screen.dart';
import '../../features/auth/presentation/ganti_password_awal_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/karyawan/presentation/absen_screen.dart';
import '../../features/karyawan/presentation/karyawan_home_screen.dart';
import '../../features/karyawan/presentation/riwayat_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../theme/app_theme.dart';

/// Notifier perantara untuk GoRouter refreshListenable
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (_, _) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authNotifierProvider);

    // 1. Memeriksa sesi awal (misal saat buka aplikasi / refresh browser)
    if (authState.isInitial) {
      return state.matchedLocation == '/splash' ? null : '/splash';
    }

    final isLoggingIn = state.matchedLocation == '/login';
    final isSplash = state.matchedLocation == '/splash';

    // 2. Belum login
    if (!authState.isAuthenticated) {
      return isLoggingIn ? null : '/login';
    }

    final profile = authState.profile!;

    // 3. Wajib ganti password awal: hanya boleh buka /ganti-password-awal
    if (profile.wajibGantiPassword) {
      return state.matchedLocation == '/ganti-password-awal'
          ? null
          : '/ganti-password-awal';
    }

    // Jika sudah tidak wajib tapi masih di /ganti-password-awal
    if (state.matchedLocation == '/ganti-password-awal') {
      return profile.isAdmin ? '/admin' : '/karyawan';
    }

    // 4. Jika sedang di /login atau /splash tapi sudah login, arahkan ke beranda role
    if (isLoggingIn || isSplash) {
      return profile.isAdmin ? '/admin' : '/karyawan';
    }

    // 5. Proteksi: Karyawan tidak boleh membuka rute /admin
    if (!profile.isAdmin && state.matchedLocation.startsWith('/admin')) {
      return '/karyawan';
    }

    // Rute diizinkan
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/ganti-password-awal',
        builder: (context, state) => const GantiPasswordAwalScreen(),
      ),
      GoRoute(
        path: '/karyawan',
        builder: (context, state) => const KaryawanHomeScreen(),
        routes: [
          GoRoute(
            path: 'absen',
            builder: (context, state) {
              final tipe = state.uri.queryParameters['tipe'] ?? 'masuk';
              return AbsenScreen(tipe: tipe);
            },
          ),
          GoRoute(
            path: 'riwayat',
            builder: (context, state) => const RiwayatScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'karyawan',
            builder: (context, state) => const KaryawanManagementScreen(),
          ),
          GoRoute(
            path: 'pengaturan',
            builder: (context, state) => const PengaturanKantorScreen(),
          ),
          GoRoute(
            path: 'rekap',
            builder: (context, state) => const RekapAbsensiScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profil',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Memuat Absensi Karyawan...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF737686),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

