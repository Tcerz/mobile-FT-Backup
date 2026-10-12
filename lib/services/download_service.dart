import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Menyimpan file langsung ke folder yang benar-benar terlihat di File
/// Manager HP:
///
///   Download/Laporan Patroli/PDF/...
///   Download/Laporan Patroli/JPG/...
///
/// (Sebelumnya pakai file_saver yang menyimpan ke Android/data/<package>/files
/// -- folder itu memang tersimpan, tapi sejak Android 11 disembunyikan dari
/// File Manager biasa, makanya terlihat seperti "tidak tersimpan".)
class DownloadService {
  static const String _namaFolderUtama = 'Laporan Patroli';

  /// Minta izin akses penyimpanan. Di Android 11+ perlu izin khusus
  /// "Kelola semua file" (dibuka lewat halaman Pengaturan sistem).
  static Future<bool> _mintaIzin() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback untuk Android versi lama (<11) yang belum kenal izin di atas.
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  static Future<Directory> _folderTujuan(String subFolder) async {
    late final Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/$_namaFolderUtama/$subFolder');
    } else {
      // iOS tidak punya folder Downloads publik; simpan di folder dokumen
      // aplikasi dengan struktur folder yang sama (terlihat di app Files
      // kalau LSSupportsOpeningDocumentsInPlace & UIFileSharingEnabled aktif).
      final base = await getApplicationDocumentsDirectory();
      dir = Directory('${base.path}/$_namaFolderUtama/$subFolder');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Format nama file: "Patroli_<tanggal>_<jam>" (tanggal & jam disanitasi
  /// supaya aman dipakai sebagai nama file di semua sistem).
  static String namaFile(String tanggal, String jam) {
    final tanggalAman = tanggal.replaceAll('/', '-');
    final jamAman = jam.replaceAll(':', '-').replaceAll(' ', '_');
    return 'Patroli_${tanggalAman}_$jamAman';
  }

  static Future<String> simpanPdf(String nama, Uint8List bytes) async {
    final diizinkan = await _mintaIzin();
    if (!diizinkan) {
      throw Exception(
        'Izin penyimpanan ditolak. Aktifkan izin "Kelola semua file" untuk '
        'aplikasi ini lewat Pengaturan HP.',
      );
    }
    final dir = await _folderTujuan('PDF');
    final file = File('${dir.path}/$nama.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<String> simpanJpg(String nama, Uint8List bytes) async {
    final diizinkan = await _mintaIzin();
    if (!diizinkan) {
      throw Exception(
        'Izin penyimpanan ditolak. Aktifkan izin "Kelola semua file" untuk '
        'aplikasi ini lewat Pengaturan HP.',
      );
    }
    final dir = await _folderTujuan('JPG');
    final file = File('${dir.path}/$nama.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
