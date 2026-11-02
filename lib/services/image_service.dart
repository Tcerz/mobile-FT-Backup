import 'dart:io';
import 'package:flutter/material.dart';

import '../pages/kamera_page.dart';

class ImageService {
  /// Membuka kamera dalam aplikasi (rasio dipaksa 4:3, lihat KameraPage) dan
  /// mengembalikan file foto yang sudah tersimpan di folder dokumen aplikasi.
  /// Mengembalikan null jika user membatalkan pengambilan foto.
  static Future<File?> ambilFotoDenganKamera(BuildContext context) async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const KameraPage()),
    );
    return path == null ? null : File(path);
  }
}
