import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/foto_laporan_model.dart';
import '../models/laporan_model.dart';
import 'image_stamp_service.dart';

/// Menggabung keempat foto patroli (yang sudah berstempel jam/lokasi/suhu,
/// sama seperti hasil "Cetak JPG") menjadi satu gambar kolase 2x2:
///
///   Jetty         | Filling Shed
///   Rumah Pompa   | Area Tangki
///
/// Foto dimasukkan dengan skala "muat" (tidak dipotong) supaya teks stempel
/// di sudut foto tidak terpotong. Foto yang belum diambil diganti kotak abu
/// bertuliskan nama kategorinya.
class KolaseService {
  static const double _lebarSel = 720;
  static const double _tinggiSel = 960;
  static const double _jarak = 6;

  static Future<Uint8List> buatKolase(Laporan laporan) async {
    final totalW = _lebarSel * 2 + _jarak;
    final totalH = _tinggiSel * 2 + _jarak;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalW, totalH));
    canvas.drawRect(Rect.fromLTWH(0, 0, totalW, totalH), Paint()..color = Colors.black);

    final gambarDibuka = <ui.Image>[];
    try {
      for (int i = 0; i < KategoriFoto.semua.length; i++) {
        final kategori = KategoriFoto.semua[i];
        final x = (i % 2) * (_lebarSel + _jarak);
        final y = (i ~/ 2) * (_tinggiSel + _jarak);
        final sel = Rect.fromLTWH(x, y, _lebarSel, _tinggiSel);

        final foto = laporan.fotos.where((f) => f.kategori == kategori).firstOrNull;
        if (foto == null) {
          _gambarKosong(canvas, sel, kategori);
          continue;
        }

        final bytes = await ImageStampService.stampImageBytes(
          imagePath: foto.imagePath,
          foto: foto,
          namaPembuat: laporan.namaPembuat,
        );
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: _lebarSel.toInt());
        final frame = await codec.getNextFrame();
        final img = frame.image;
        gambarDibuka.add(img);

        final iw = img.width.toDouble();
        final ih = img.height.toDouble();
        final skala = (_lebarSel / iw) < (_tinggiSel / ih) ? _lebarSel / iw : _tinggiSel / ih;
        final dw = iw * skala;
        final dh = ih * skala;
        final tujuan = Rect.fromLTWH(x + (_lebarSel - dw) / 2, y + (_tinggiSel - dh) / 2, dw, dh);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, iw, ih),
          tujuan,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }

      final picture = recorder.endRecording();
      final hasil = await picture.toImage(totalW.toInt(), totalH.toInt());
      final byteData = await hasil.toByteData(format: ui.ImageByteFormat.png);
      hasil.dispose();
      return byteData!.buffer.asUint8List();
    } finally {
      for (final g in gambarDibuka) {
        g.dispose();
      }
    }
  }

  static void _gambarKosong(Canvas canvas, Rect sel, String kategori) {
    canvas.drawRect(sel, Paint()..color = const Color(0xFF2A2A2A));
    final tp = TextPainter(
      text: TextSpan(
        text: '$kategori\nbelum diambil',
        style: const TextStyle(color: Colors.white54, fontSize: 36, fontWeight: FontWeight.w600),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: sel.width * 0.9);
    tp.paint(canvas, Offset(sel.left + (sel.width - tp.width) / 2, sel.top + (sel.height - tp.height) / 2));
  }
}
