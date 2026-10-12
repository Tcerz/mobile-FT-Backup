import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/foto_laporan_model.dart';
import '../models/laporan_model.dart';
import '../providers/laporan_provider.dart';
import '../services/download_service.dart';
import '../services/image_stamp_service.dart';
import 'input_laporan_page.dart';

/// Halaman "folder" laporan: menampilkan ringkasan header + 4 foto,
/// masing-masing foto punya tombol "Cetak JPG" sendiri.
class LaporanDetailPage extends StatefulWidget {
  final int laporanId;

  const LaporanDetailPage({super.key, required this.laporanId});

  @override
  State<LaporanDetailPage> createState() => _LaporanDetailPageState();
}

class _LaporanDetailPageState extends State<LaporanDetailPage> {
  Laporan? _laporan;
  bool _loading = true;
  int? _sedangCetak;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final detail = await context.read<LaporanProvider>().fetchDetail(widget.laporanId);
    if (!mounted) return;
    setState(() {
      _laporan = detail;
      _loading = false;
    });
  }

  void _tampilkanPesan(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  /// Membuat foto hasil stempel lalu LANGSUNG menyimpannya ke folder
  /// "Download/Laporan Patroli/JPG/" di HP. Nama file mengikuti pola
  /// "Patroli_<tanggal>_<jam>", ditambah kategori supaya 4 foto dalam
  /// satu laporan tidak saling menimpa satu sama lain.
  Future<void> _cetakJpg(FotoLaporan foto) async {
    setState(() => _sedangCetak = foto.id);
    try {
      final bytes = await ImageStampService.stampImageBytes(
        imagePath: foto.imagePath,
        foto: foto,
        namaPembuat: _laporan?.namaPembuat ?? '',
      );
      final namaDasar = DownloadService.namaFile(
        _laporan?.tanggal ?? '',
        _laporan?.jamPatroli ?? '',
      );
      final namaFile = '${namaDasar}_${foto.kategori.replaceAll(' ', '')}';

      final path = await DownloadService.simpanJpg(namaFile, bytes);
      _tampilkanPesan('Foto ${foto.kategori} tersimpan: $path');
    } catch (e) {
      _tampilkanPesan('Gagal mencetak JPG: $e');
    } finally {
      if (mounted) setState(() => _sedangCetak = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final laporan = _laporan;
    if (laporan == null) {
      return const Scaffold(body: Center(child: Text('Laporan tidak ditemukan')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Patroli ${laporan.tanggal}'),
        actions: [
          IconButton(
            tooltip: 'Duplikat jadi Laporan Baru',
            icon: const Icon(Icons.content_copy),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InputLaporanPage(duplikatDariId: widget.laporanId),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Edit Laporan',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InputLaporanPage(laporanId: widget.laporanId),
                ),
              );
              _muat();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jam Patroli: ${laporan.jamPatroli} WIB'),
                  Text('PIC Patroli: ${laporan.picPatroli}'),
                  Text('Dibuat oleh: ${laporan.namaPembuat}'),
                  Text('Waktu Dibuat: ${laporan.waktuDibuat}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final kategoriAda = laporan.fotos.map((f) => f.kategori).toSet();
            final kategoriKurang = KategoriFoto.semua.where((k) => !kategoriAda.contains(k)).toList();
            if (kategoriKurang.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Belum ada foto: ${kategoriKurang.join(', ')}. '
                      'Ketuk ikon pensil di atas untuk melengkapi.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Text('Foto Patroli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...laporan.fotos.map((foto) {
            final sedangProses = _sedangCetak == foto.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(foto.imagePath),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(foto.kategori, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Suhu: ${foto.suhu}', style: const TextStyle(fontSize: 12)),
                          Text('Jam: ${foto.jam}', style: const TextStyle(fontSize: 12)),
                          Text(
                            'Koordinat: ${foto.latitude}, ${foto.longitude}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Lokasi: ${foto.alamat}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: sedangProses ? null : () => _cetakJpg(foto),
                            icon: sedangProses
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.image, size: 16),
                            label: const Text('Cetak JPG'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
