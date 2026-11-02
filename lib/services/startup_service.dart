import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/zona_waktu_provider.dart';
import 'notifikasi_patrol_service.dart';

/// Permintaan izin yang dilakukan SEKALI saat aplikasi pertama kali dibuka:
///  1. Lokasi  -> menentukan zona waktu (WIB/WITA/WIT).
///  2. Notifikasi & alarm -> pengingat jam Safety Patrol.
/// Tiap izin didahului penjelasan singkat supaya user paham alasannya.
/// (Izin kamera tetap diminta saat pertama kali mengambil foto.)
class StartupService {
  static const _kSelesai = 'startup_izin_v1_selesai';

  static Future<void> jalankanPertamaKali(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSelesai) ?? false) return;
    if (!context.mounted) return;

    // --- 1. Lokasi ---
    final lanjutLokasi = await _dialog(
      context,
      icon: Icons.my_location,
      judul: 'Izin Lokasi',
      isi: 'Aplikasi memakai lokasi Anda untuk menentukan zona waktu '
          '(WIB / WITA / WIT) sehingga jam patroli dan waktu laporan tampil sesuai tempat Anda bertugas. '
          'Lokasi juga dicatat pada foto patroli.',
    );
    if (lanjutLokasi == true) {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted && context.mounted) {
        await context.read<ZonaWaktuProvider>().perbaruiDariLokasi();
      }
    }

    // --- 2. Notifikasi & alarm ---
    if (!context.mounted) return;
    final lanjutNotif = await _dialog(
      context,
      icon: Icons.alarm,
      judul: 'Izin Notifikasi & Alarm',
      isi: 'Aplikasi akan membunyikan alarm 5 menit sebelum jam Safety Patrol dan '
          'mengingatkan 1 jam setelahnya jika laporan belum dibuat atau belum diupload.\n\n'
          'Pada langkah berikutnya, izinkan notifikasi dan "Alarm & pengingat" agar alarm bisa berbunyi tepat waktu.',
    );
    if (lanjutNotif == true) {
      await NotifikasiPatrolService.mintaIzin();
      await NotifikasiPatrolService.sinkronkanJadwal();
    }

    await prefs.setBool(_kSelesai, true);
  }

  static Future<bool?> _dialog(
    BuildContext context, {
    required IconData icon,
    required String judul,
    required String isi,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, size: 32),
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
        ],
      ),
    );
  }
}
