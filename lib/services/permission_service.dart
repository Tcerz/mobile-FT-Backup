import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Menampilkan penjelasan kita SENDIRI dulu ("fitur ini perlu akses kamera
/// & lokasi") sebelum memicu dialog izin bawaan Android/iOS. Kalau kedua
/// izin sudah pernah disetujui sebelumnya, langsung lanjut tanpa dialog
/// apa pun (supaya tidak mengganggu user tiap kali ambil foto).
class PermissionService {
  static Future<bool> pastikanIzinKameraLokasi(BuildContext context) async {
    final sudahLengkap = await Permission.camera.isGranted &&
        await Permission.locationWhenInUse.isGranted;
    if (sudahLengkap) return true;
    if (!context.mounted) return false;

    final lanjut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.camera_alt_outlined, size: 32),
        title: const Text('Izin Diperlukan'),
        content: const Text(
          'Fitur ini memerlukan akses ke kamera dan lokasi Anda, untuk '
          'mengambil foto patroli beserta data lokasi dan waktunya.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
        ],
      ),
    );
    if (lanjut != true) return false;

    final kamera = await Permission.camera.request();
    final lokasi = await Permission.locationWhenInUse.request();
    return kamera.isGranted && lokasi.isGranted;
  }
}
