import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'pages/akun_nonaktif_page.dart';
import 'pages/login_page.dart';
import 'pages/main_shell_page.dart';
import 'providers/laporan_provider.dart';
import 'providers/profil_provider.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  if (SupabaseConfig.sudahDikonfigurasi) {
    await AuthService.init();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfilProvider()),
        ChangeNotifierProvider(create: (_) => LaporanProvider()),
      ],
      child: MaterialApp(
        title: 'Laporan Safety Patrol',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2563EB), // biru netral, bukan biru terang "default Flutter"
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0.5, scrolledUnderElevation: 1),
          cardTheme: const CardThemeData(elevation: 0.5, margin: EdgeInsets.zero),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        home: const AppRoot(),
      ),
    );
  }
}

/// Menentukan halaman awal berdasarkan status login Supabase:
/// belum login -> Login, sudah login tapi nonaktif -> AkunNonaktif,
/// sudah login & aktif -> Home.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.sudahDikonfigurasi) {
      return const _BelumDikonfigurasi();
    }

    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final session = AuthService.currentUser;
        if (session == null) {
          return const LoginPage();
        }
        return _ProfilGate(key: ValueKey(session.id));
      },
    );
  }
}

/// Memuat profil (nama, role, status) dari server sebelum masuk ke Home,
/// lalu memblokir akses jika status akun nonaktif.
class _ProfilGate extends StatefulWidget {
  const _ProfilGate({super.key});

  @override
  State<_ProfilGate> createState() => _ProfilGateState();
}

class _ProfilGateState extends State<_ProfilGate> {
  @override
  void initState() {
    super.initState();
    // Reset SINKRON dulu (bukan di dalam postFrameCallback) supaya frame
    // pertama tidak sempat menampilkan profil/laporan milik sesi sebelumnya
    // sebelum data user yang baru selesai dimuat.
    context.read<ProfilProvider>().reset();
    context.read<LaporanProvider>().reset();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ProfilProvider>().loadFromServer();
      if (mounted) context.read<LaporanProvider>().bootstrapUntukUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ProfilProvider>();
    if (!profil.sudahDimuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!profil.aktif) {
      return const AkunNonaktifPage();
    }
    return const MainShellPage();
  }
}

class _BelumDikonfigurasi extends StatelessWidget {
  const _BelumDikonfigurasi();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase belum dikonfigurasi.\nIsi lib/config/supabase_config.dart terlebih dahulu.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
