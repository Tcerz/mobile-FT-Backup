import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/laporan_model.dart';
import '../providers/laporan_provider.dart';
import '../services/pdf_service.dart';
import '../services/text_export_service.dart';
import '../services/whatsapp_share_service.dart';
import '../widgets/laporan_history_card.dart';
import 'input_laporan_page.dart';
import 'laporan_detail_page.dart';
import 'profil_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LaporanProvider>().fetchAll();
    });
  }

  Future<void> _sinkronManual(BuildContext context) async {
    final jumlah = await context.read<LaporanProvider>().sinkronDariServer();
    if (!mounted) return;
    _tampilkanPesan(jumlah > 0 ? '$jumlah laporan baru ditarik dari server' : 'Tidak ada laporan baru');
  }

  void _tampilkanPesan(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _bukaFolder(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LaporanDetailPage(laporanId: id)),
    );
  }

  Future<void> _cetakPdf(int id) async {
    final detail = await context.read<LaporanProvider>().fetchDetail(id);
    if (detail == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Membuat PDF...')),
          ],
        ),
      ),
    );

    try {
      final path = await PdfService.printLaporanPdf(detail);
      if (mounted) Navigator.pop(context); // tutup dialog loading
      _tampilkanPesan('PDF tersimpan: $path');
    } catch (e) {
      if (mounted) Navigator.pop(context); // tutup dialog loading
      _tampilkanPesan('Gagal membuat PDF: $e');
    }
  }

  Future<void> _copyText(int id) async {
    final detail = await context.read<LaporanProvider>().fetchDetail(id);
    if (detail == null) return;
    final teks = TextExportService.buatTeksLaporan(detail);
    await Clipboard.setData(ClipboardData(text: teks));
    _tampilkanPesan('Teks laporan disalin, silakan paste ke WhatsApp/chat lain');
  }

  /// Upload sudah otomatis saat simpan; ini hanya untuk mengulang upload
  /// yang gagal/tertunda (mis. saat itu tidak ada sinyal).
  Future<void> _cobaLagiUpload(int id) async {
    final error = await context.read<LaporanProvider>().uploadLaporanById(id);
    _tampilkanPesan(error == null ? 'Laporan berhasil diupload' : 'Gagal upload: $error');
  }

  /// Menggabung keempat foto jadi 1 gambar (kolase 2x2) lalu membuka menu
  /// share bersama teks laporan (format sama dengan Copy Text) -- pilih
  /// WhatsApp dan grup tujuannya di menu itu.
  Future<void> _kirimWa(int id) async {
    final detail = await context.read<LaporanProvider>().fetchDetail(id);
    if (detail == null) return;
    if (detail.fotos.isEmpty) {
      _tampilkanPesan('Belum ada foto di laporan ini');
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Menyiapkan gambar...')),
          ],
        ),
      ),
    );

    try {
      final gambar = await WhatsappShareService.siapkanKolase(detail);
      if (mounted) Navigator.pop(context); // tutup dialog sebelum menu share
      await WhatsappShareService.bagikan(gambar, TextExportService.buatTeksLaporan(detail));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _tampilkanPesan('Gagal menyiapkan gambar: $e');
    }
  }

  Future<void> _hapus(Laporan laporan) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Laporan'),
        content: Text('Hapus laporan ${laporan.tanggal} - ${laporan.jamPatroli}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (konfirmasi == true && laporan.id != null) {
      await context.read<LaporanProvider>().hapusLaporan(laporan.id!);
    }
  }

  /// Membuka form Buat Laporan dalam mode DUPLIKAT: PIC & data kegiatan
  /// disalin dari laporan ini, Jam Patroli & foto wajib diisi ulang.
  /// Dipakai supaya laporan jam 10 bisa jadi dasar laporan jam 12, dst.
  Future<void> _duplikat(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InputLaporanPage(duplikatDariId: id)),
    );
    if (mounted) context.read<LaporanProvider>().fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LaporanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Safety Patrol'),
        actions: [
          IconButton(
            tooltip: 'Tarik laporan dari server (device lain)',
            onPressed: provider.sinkronBerjalan ? null : () => _sinkronManual(context),
            icon: provider.sinkronBerjalan
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilPage()),
            ),
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InputLaporanPage()),
                  );
                  if (mounted) context.read<LaporanProvider>().fetchAll();
                },
                icon: const Icon(Icons.add),
                label: const Text('Buat Laporan Baru'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('History Laporan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.daftarLaporan.isEmpty
                ? const Center(child: Text('Belum ada laporan'))
                : ListView.builder(
                    itemCount: provider.daftarLaporan.length,
                    itemBuilder: (context, index) {
                      final laporan = provider.daftarLaporan[index];
                      return LaporanHistoryCard(
                        laporan: laporan,
                        onTap: () => _bukaFolder(laporan.id!),
                        onCetakPdf: () => _cetakPdf(laporan.id!),
                        onCopyText: () => _copyText(laporan.id!),
                        onDuplikat: () => _duplikat(laporan.id!),
                        onDelete: () => _hapus(laporan),
                        onKirimWa: () => _kirimWa(laporan.id!),
                        onCobaLagiUpload: () => _cobaLagiUpload(laporan.id!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
