import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Membuka kamera, lalu menyimpan hasil foto ke folder dokumen aplikasi.
  /// Resolusi dibatasi (maxWidth/maxHeight) supaya proses stempel & PDF
  /// tidak lambat -- foto kamera modern bisa 12MP+ yang berat diproses.
  /// Mengembalikan null jika user membatalkan pengambilan foto.
  static Future<File?> ambilFotoDenganKamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (photo == null) return null;
    return await _simpanKeLokal(File(photo.path));
  }

  static Future<File> _simpanKeLokal(File sourceFile) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String fileName = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String newPath = '${dir.path}/$fileName';
    return await sourceFile.copy(newPath);
  }
}
