import 'package:flutter/material.dart';

import '../models/foto_laporan_model.dart';
import '../models/laporan_model.dart';

/// Detail READ-ONLY untuk laporan milik petugas lain (dari tab Posted).
/// Tidak ada tombol Edit -- cuma bisa Lihat & Duplikat. Logic duplikat
/// (unduh foto, buka InputLaporanPage, pindah tab) didelegasikan ke
/// [onDuplikat] supaya tidak dobel dengan yang ada di posted_page.dart.
class PostedDetailPage extends StatefulWidget {
  final Laporan laporan;
  final Future<bool> Function() onDuplikat;
  const PostedDetailPage({super.key, required this.laporan, required this.onDuplikat});

  @override
  State<PostedDetailPage> createState() => _PostedDetailPageState();
}

class _PostedDetailPageState extends State<PostedDetailPage> {
  bool _memproses = false;

  Future<void> _tapDuplikat() async {
    setState(() => _memproses = true);
    final berhasil = await widget.onDuplikat();
    if (!mounted) return;
    setState(() => _memproses = false);
    // popUntil ke root (MainShellPage) -- membersihkan halaman detail ini
    // DAN halaman input laporan dari stack navigasi sekaligus, supaya user
    // langsung mendarat di tab Aktivitas, bukan nyangkut di sini.
    if (berhasil) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final laporan = widget.laporan;
    return Scaffold(
      appBar: AppBar(
        title: Text('Patroli ${laporan.tanggal}'),
        actions: [
          IconButton(
            tooltip: 'Duplikat jadi Laporan Baru Saya',
            icon: _memproses
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.content_copy),
            onPressed: _memproses ? null : _tapDuplikat,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.visibility, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(child: Text('Laporan milik petugas lain -- hanya bisa dilihat & diduplikat', style: TextStyle(fontSize: 12, color: Colors.black54))),
              ],
            ),
          ),
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
          const Text('Foto Patroli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...laporan.fotos.map(_kartuFoto),
        ],
      ),
    );
  }

  Widget _kartuFoto(FotoLaporan foto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                foto.imagePath, // URL foto di server, khusus untuk halaman read-only ini
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
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
                  Text('Lokasi: ${foto.alamat}', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
