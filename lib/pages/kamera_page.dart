import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Kamera dalam aplikasi dengan rasio TETAP 4:3 (portrait 3:4), tidak peduli
/// setting kamera bawaan HP (fullscreen / 16:9 / dll).
///
/// Dua lapis jaminan:
///  1. Preview ditampilkan di kotak 3:4 (center-crop dari preview sensor),
///     jadi yang terlihat = yang akan tersimpan (WYSIWYG).
///  2. Foto hasil jepretan di-crop tengah ke 4:3 persis (lihat
///     [_potongKe43]), karena sebagian HP menghasilkan foto 16:9 walau
///     preview 4:3. Hasil akhir pasti 4:3 di semua perangkat.
///
/// Mengembalikan path file JPEG hasil (via Navigator.pop), atau null kalau
/// dibatalkan.
class KameraPage extends StatefulWidget {
  const KameraPage({super.key});

  @override
  State<KameraPage> createState() => _KameraPageState();
}

class _KameraPageState extends State<KameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _mengambil = false;
  String? _error;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Halaman kamera dikunci portrait supaya foto selalu 3:4 tegak.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _mulaiKamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _mulaiKamera();
    }
  }

  Future<void> _mulaiKamera() async {
    try {
      final daftar = await availableCameras();
      if (daftar.isEmpty) {
        setState(() => _error = 'Kamera tidak ditemukan di perangkat ini.');
        return;
      }
      final belakang = daftar.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => daftar.first,
      );
      final controller = CameraController(
        belakang,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flash);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = 'Kamera gagal dibuka: ${e.description ?? e.code}');
    } catch (e) {
      if (mounted) setState(() => _error = 'Kamera gagal dibuka: $e');
    }
  }

  Future<void> _gantiFlash() async {
    final c = _controller;
    if (c == null) return;
    final berikut = _flash == FlashMode.off ? FlashMode.auto : (_flash == FlashMode.auto ? FlashMode.always : FlashMode.off);
    await c.setFlashMode(berikut);
    setState(() => _flash = berikut);
  }

  Future<void> _ambilFoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _mengambil) return;
    setState(() => _mengambil = true);
    try {
      final mentah = await c.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final tujuan = '${dir.path}/foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Decode/crop/encode gambar besar dijalankan di isolate terpisah agar UI tidak macet.
      await compute(_potongKe43, <String, String>{'src': mentah.path, 'dst': tujuan});
      try {
        await File(mentah.path).delete();
      } catch (_) {}
      if (mounted) Navigator.pop(context, tujuan);
    } catch (e) {
      if (mounted) {
        setState(() => _mengambil = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _mengambil ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(4)),
                    child: const Text('4:3', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _mengambil ? null : _gantiFlash,
                    icon: Icon(
                      _flash == FlashMode.off ? Icons.flash_off : (_flash == FlashMode.auto ? Icons.flash_auto : Icons.flash_on),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Center(child: _areaPreview())),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: GestureDetector(
                onTap: _ambilFoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  padding: const EdgeInsets.all(5),
                  child: _mengambil
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaPreview() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Kotak 3:4 terbesar yang muat di area yang tersedia.
        double lebar = box.maxWidth;
        double tinggi = lebar * 4 / 3;
        if (tinggi > box.maxHeight) {
          tinggi = box.maxHeight;
          lebar = tinggi * 3 / 4;
        }
        // aspectRatio dari plugin = lebar/tinggi sensor (landscape, mis. 1.78).
        // Dalam portrait, rasio preview = kebalikannya (0.5625).
        final r = c.value.aspectRatio;
        final rasioPortrait = r > 1 ? 1 / r : r;
        return ClipRect(
          child: SizedBox(
            width: lebar,
            height: tinggi,
            child: FittedBox(
              fit: BoxFit.cover, // center-crop preview ke kotak 3:4
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: lebar,
                height: lebar / rasioPortrait,
                child: CameraPreview(c),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Top-level (dibutuhkan compute). Decode -> luruskan orientasi EXIF ->
/// crop tengah ke 4:3 -> perkecil (sisi panjang maks 1600px, seperti
/// pengaturan lama) -> simpan JPEG.
Future<void> _potongKe43(Map<String, String> arg) async {
  final bytes = await File(arg['src']!).readAsBytes();
  var gambar = img.decodeImage(bytes);
  if (gambar == null) throw Exception('Gagal membaca hasil foto');
  gambar = img.bakeOrientation(gambar);

  final w = gambar.width;
  final h = gambar.height;
  final landscape = w >= h;
  final target = landscape ? 4 / 3 : 3 / 4; // lebar / tinggi

  int cw = w;
  int ch = h;
  if (w / h > target) {
    cw = (h * target).round();
  } else {
    ch = (w / target).round();
  }
  var hasil = img.copyCrop(gambar, x: (w - cw) ~/ 2, y: (h - ch) ~/ 2, width: cw, height: ch);

  const sisiMaks = 1600;
  if (landscape && hasil.width > sisiMaks) {
    hasil = img.copyResize(hasil, width: sisiMaks, height: sisiMaks * 3 ~/ 4);
  } else if (!landscape && hasil.height > sisiMaks) {
    hasil = img.copyResize(hasil, width: sisiMaks * 3 ~/ 4, height: sisiMaks);
  }

  await File(arg['dst']!).writeAsBytes(img.encodeJpg(hasil, quality: 80));
}
