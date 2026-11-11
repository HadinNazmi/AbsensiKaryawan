import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env/app_env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Muat environment dari file .env
  await dotenv.load(fileName: '.env');

  // 2. Inisialisasi format tanggal bahasa Indonesia (intl)
  await initializeDateFormatting('id_ID', null);

  // 3. Inisialisasi Supabase Client
  // ignore: deprecated_member_use
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppEnv.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: AbsensiApp(),
    ),
  );
}

class AbsensiApp extends ConsumerWidget {
  const AbsensiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Absensi Karyawan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
