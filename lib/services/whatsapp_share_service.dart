import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/laporan_model.dart';
import 'download_service.dart';
import 'kolase_service.dart';

/// Menyiapkan kolase 4 foto lalu membagikannya bersama teks laporan lewat
/// menu share bawaan HP (pilih WhatsApp + grup tujuan di menu itu). Di
/// WhatsApp, teks yang ikut dibagikan bersama 1 gambar menjadi caption.
class WhatsappShareService {
  /// Membuat kolase dan menyimpannya sebagai file sementara (folder cache,
  /// bukan Download -- ini bukan hasil "cetak", cuma bahan untuk dikirim).
  static Future<File> siapkanKolase(Laporan laporan) async {
    final bytes = await KolaseService.buatKolase(laporan);
    final dir = await getTemporaryDirectory();
    final nama = DownloadService.namaFile(laporan.tanggal, laporan.jamPatroli);
    final file = File('${dir.path}/${nama}_kolase.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> bagikan(File gambar, String teks) async {
    await Share.shareXFiles(
      [XFile(gambar.path, mimeType: 'image/png')],
      text: teks,
    );
  }
}
