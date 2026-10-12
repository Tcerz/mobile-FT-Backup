import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/laporan_model.dart';
import 'download_service.dart';
import 'image_stamp_service.dart';

class PdfService {
  static const double _labelColumnWidth = 110;

  /// Membuat PDF lengkap 1 laporan: halaman ringkasan (header + 4 kegiatan,
  /// termasuk foto pendukung tiap Note kalau ada) lalu diikuti 1 halaman
  /// per foto kategori. Foto kategori yang disisipkan adalah foto hasil
  /// STEMPEL (sama persis dengan yang dihasilkan tombol "Cetak JPG").
  /// PDF hasil akhir LANGSUNG disimpan ke folder
  /// "Download/Laporan Patroli/PDF/" di HP. Mengembalikan path file
  /// yang tersimpan.
  static Future<String> printLaporanPdf(Laporan laporan) async {
    final pdf = pw.Document();

    // Foto pendukung note dimuat dulu (async) sebelum membangun halaman,
    // karena builder pw.MultiPage harus sinkron.
    final gambarLoading = await _muatGambarCatatan(laporan.loading.noteFotos);
    final gambarDischarge = await _muatGambarCatatan(laporan.discharge.noteFotos);
    final gambarPenyaluran = await _muatGambarCatatan(laporan.penyaluran.noteFotos);
    final gambarStorage = await _muatGambarCatatan(laporan.storage.noteFotos);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Laporan Safety Patrol Guard',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'PT. PERTAMINA PATRA NIAGA FT. SEI SIAK',
            style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 14),
          _baris('Tanggal', laporan.tanggal),
          _baris('Jam Patroli', '${laporan.jamPatroli} WIB'),
          _baris('PIC Patroli', laporan.picPatroli),
          _baris('Dibuat Oleh', laporan.namaPembuat),
          _baris('Waktu Dibuat', laporan.waktuDibuat),
          pw.SizedBox(height: 16),
          _judulSeksi('1. Loading'),
          _baris('Personel', laporan.loading.personel),
          _baris('Jetty 1', laporan.loading.jetty1),
          _baris('Jetty 2', laporan.loading.jetty2),
          _baris('Produk', laporan.loading.produk),
          _baris('Kondisi', laporan.loading.kondisi),
          _baris('Note', laporan.loading.note),
          ..._blokGambarCatatan(gambarLoading),
          pw.SizedBox(height: 10),
          _judulSeksi('2. Discharge'),
          _baris('Personel', laporan.discharge.personel),
          _baris('Jetty 1', laporan.discharge.jetty1),
          _baris('Jetty 2', laporan.discharge.jetty2),
          _baris('Produk', laporan.discharge.produk),
          _baris('Kondisi', laporan.discharge.kondisi),
          _baris('Note', laporan.discharge.note),
          ..._blokGambarCatatan(gambarDischarge),
          pw.SizedBox(height: 10),
          _judulSeksi('3. Penyaluran'),
          _baris('Personel', laporan.penyaluran.personel),
          _baris('Start Penyaluran', laporan.penyaluran.startJam),
          _baris('Selesai Penyaluran', laporan.penyaluran.selesaiJam),
          _baris('Kondisi', laporan.penyaluran.kondisi),
          _baris('Note', laporan.penyaluran.note),
          ..._blokGambarCatatan(gambarPenyaluran),
          pw.SizedBox(height: 10),
          _judulSeksi('4. Storage (Penimbunan)'),
          _baris('Personel', laporan.storage.personel),
          _baris('Tangki Loading', _fmtTangki(laporan.storage.tangkiLoading)),
          _baris('Tangki Discharge', _fmtTangki(laporan.storage.tangkiDischarge)),
          _baris('Tangki Penyaluran', _fmtTangki(laporan.storage.tangkiPenyaluran)),
          _baris('Tangki Aktif/Idle', _fmtTangkiAktif(laporan.storage.tangkiAktifIdle, laporan.storage.jenisProdukAktif)),
          _baris('Tangki Off', _fmtTangki(laporan.storage.tangkiOff)),
          _baris('Kondisi', laporan.storage.kondisi),
          _baris('Note', laporan.storage.note),
          ..._blokGambarCatatan(gambarStorage),
        ],
      ),
    );

    // Satu halaman per foto kategori, memakai gambar hasil stempel (sama
    // seperti hasil tombol "Cetak JPG"). Dihitung dari bytes di memori
    // langsung, tanpa menulis/membaca file sementara ke disk.
    for (final foto in laporan.fotos) {
      final imageBytes = await ImageStampService.stampImageBytes(
        imagePath: foto.imagePath,
        foto: foto,
        namaPembuat: laporan.namaPembuat,
      );
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(child: pw.Image(image)),
        ),
      );
    }

    final pdfBytes = await pdf.save();

    final namaFile = DownloadService.namaFile(laporan.tanggal, laporan.jamPatroli);
    return DownloadService.simpanPdf(namaFile, pdfBytes);
  }

  static String _fmtTangki(List<String> list) =>
      list.isEmpty ? 'NIHIL' : list.join(', ');

  static String _fmtTangkiAktif(List<String> list, Map<String, String> produk) {
    if (list.isEmpty) return 'NIHIL';
    return list.map((k) => produk[k] != null ? '$k ${produk[k]}' : k).join('\n');
  }

  static pw.Widget _judulSeksi(String judul) {
    return pw.Text(
      judul,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _baris(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: _labelColumnWidth, child: pw.Text(label)),
          pw.Text(':'),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  /// Membaca semua file foto pendukung note (kalau ada) menjadi widget
  /// gambar siap-pakai untuk PDF. File yang sudah tidak ada di disk
  /// (misal terhapus) dilewati saja, tidak menggagalkan seluruh PDF.
  static Future<List<pw.Widget>> _muatGambarCatatan(List<String> paths) async {
    final List<pw.Widget> hasil = [];
    for (final path in paths) {
      try {
        final bytes = await File(path).readAsBytes();
        hasil.add(
          pw.Container(
            width: 110,
            height: 110,
            margin: const pw.EdgeInsets.only(right: 6, top: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        );
      } catch (_) {
        // file sudah tidak ada / gagal dibaca -> lewati, jangan gagalkan PDF
      }
    }
    return hasil;
  }

  /// Membungkus daftar gambar catatan (kalau ada) jadi baris foto di
  /// bawah field Note terkait. Kosong kalau tidak ada foto pendukung.
  static List<pw.Widget> _blokGambarCatatan(List<pw.Widget> gambar) {
    if (gambar.isEmpty) return [];
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: _labelColumnWidth + 8, bottom: 4),
        child: pw.Wrap(children: gambar),
      ),
    ];
  }
}
