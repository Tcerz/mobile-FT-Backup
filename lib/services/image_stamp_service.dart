import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/foto_laporan_model.dart';

const _navy = Color(0xFF142131);
const _putih = Colors.white;
const _abuFooter = Color(0xFFE0E0E0);

/// Satu baris teks polos di blok kiri-bawah (tanpa kotak/ikon), kecuali
/// baris Jam yang ditandai [kotak] = true untuk dapat latar putih.
class _Baris {
  final String teks;
  final bool kotak;
  final double skalaFont;
  final FontWeight weight;
  final Color warna;
  const _Baris(this.teks, {this.kotak = false, this.skalaFont = 0.032, this.weight = FontWeight.w700, this.warna = _putih});
}

/// Menempelkan info sebagai teks polos rata-kiri-bawah langsung di atas
/// foto -- mengikuti gaya aplikasi timestamp-camera pada umumnya: cuma
/// baris Jam yang menonjol dengan kotak putih, sisanya teks tebal biasa
/// tanpa kotak/ikon supaya tidak terlihat penuh sesak.
class ImageStampService {
  static Future<Uint8List> stampImageBytes({
    required String imagePath,
    required FotoLaporan foto,
    required String namaPembuat,
  }) async {
    final Uint8List imageBytes = await File(imagePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final double w = image.width.toDouble();
    final double h = image.height.toDouble();
    double p(double frac) => w * frac;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(image, Offset.zero, Paint());

    // Gradasi gelap tipis di ATAS dan BAWAH foto -- supaya teks putih tetap
    // terbaca di berbagai kondisi pencahayaan foto (siang/malam/latar terang).
    final gradientBawah = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.55),
        Offset(0, h),
        [Colors.black.withOpacity(0), Colors.black.withOpacity(0.45)],
      );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.55, w, h * 0.45), gradientBawah);

    final gradientAtas = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, h * 0.16),
        [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.16), gradientAtas);

    // --- Pojok atas: Nama Petugas (kiri) & Kategori (kanan) ---
    final topY = p(0.03);
    final namaTp = TextPainter(
      text: TextSpan(text: 'Nama Petugas: $namaPembuat', style: TextStyle(color: _putih, fontSize: p(0.028), fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.55);
    namaTp.paint(canvas, Offset(p(0.05), topY));

    final kategoriTp = TextPainter(
      text: TextSpan(text: 'Kategori: ${foto.kategori}', style: TextStyle(color: _putih, fontSize: p(0.028), fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.4);
    kategoriTp.paint(canvas, Offset(w - p(0.05) - kategoriTp.width, topY));

    String fmtKoordinat(double lat, double lng) {
      final ns = lat >= 0 ? 'N' : 'S';
      final ew = lng >= 0 ? 'E' : 'W';
      return '${lat.abs().toStringAsFixed(6)}\u00b0$ns, ${lng.abs().toStringAsFixed(6)}\u00b0$ew';
    }

    final bagianJam = foto.jam.split(' '); // format tersimpan: "dd-MM-yyyy HH:mm:ss"
    final tanggal = bagianJam.isNotEmpty ? bagianJam[0].replaceAll('-', '/') : '-';
    final jam = bagianJam.length > 1 ? bagianJam[1].substring(0, 5) : '-'; // HH:mm saja

    final barisList = <_Baris>[
      _Baris(jam, kotak: true, skalaFont: 0.075, weight: FontWeight.w800, warna: _navy),
      _Baris(tanggal, skalaFont: 0.032, weight: FontWeight.w800),
      _Baris(foto.alamat.isEmpty ? '-' : foto.alamat, skalaFont: 0.03),
      _Baris(fmtKoordinat(foto.latitude, foto.longitude), skalaFont: 0.026, weight: FontWeight.w500),
      _Baris('Suhu: ${foto.suhu}', skalaFont: 0.03),
    ];

    const kiriX = 0.05; // posisi rata kiri, proporsi lebar foto
    final gapAntarBaris = p(0.012);
    final boxPadding = p(0.014);

    // 1) Ukur dulu semua baris (dari atas blok ke bawah) supaya tahu total
    // tinggi blok, baru digambar dari bawah foto ke atas.
    final painters = <TextPainter>[];
    final tinggiBaris = <double>[];
    for (final b in barisList) {
      final tp = TextPainter(
        text: TextSpan(text: b.teks, style: TextStyle(color: b.warna, fontSize: p(b.skalaFont), fontWeight: b.weight)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w * 0.9);
      painters.add(tp);
      tinggiBaris.add(tp.height + (b.kotak ? boxPadding * 2 : 0));
    }

    final footerFontSize = p(0.02);
    final footerIconSize = p(0.022);
    final footerHeight = footerFontSize > footerIconSize ? footerFontSize : footerIconSize;

    final totalTinggi = tinggiBaris.fold<double>(0, (a, b) => a + b) +
        gapAntarBaris * barisList.length + // termasuk jarak ke footer
        footerHeight;

    double dy = h - p(0.04) - totalTinggi;

    // 2) Gambar tiap baris.
    for (int i = 0; i < barisList.length; i++) {
      final b = barisList[i];
      final tp = painters[i];
      if (b.kotak) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(p(kiriX) - boxPadding, dy, tp.width + boxPadding * 2, tp.height + boxPadding * 2),
          Radius.circular(p(0.014)),
        );
        canvas.drawRRect(rrect, Paint()..color = Colors.white);
        tp.paint(canvas, Offset(p(kiriX), dy + boxPadding));
        dy += tp.height + boxPadding * 2 + gapAntarBaris;
      } else {
        tp.paint(canvas, Offset(p(kiriX), dy));
        dy += tp.height + gapAntarBaris;
      }
    }

    // --- Baris verifikasi paling bawah: ikon kecil + teks abu-abu ---
    final ikonTp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.verified.codePoint),
        style: TextStyle(fontSize: footerIconSize, fontFamily: Icons.verified.fontFamily, color: _abuFooter),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final footerTp = TextPainter(
      text: TextSpan(text: 'Terverifikasi: Menjamin keaslian waktu', style: TextStyle(fontSize: footerFontSize, color: _abuFooter, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();

    ikonTp.paint(canvas, Offset(p(kiriX), dy + (footerTp.height - footerIconSize) / 2));
    footerTp.paint(canvas, Offset(p(kiriX) + footerIconSize + p(0.008), dy));

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
