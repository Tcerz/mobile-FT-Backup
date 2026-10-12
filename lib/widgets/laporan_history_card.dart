import 'package:flutter/material.dart';
import '../models/foto_laporan_model.dart';
import '../models/laporan_model.dart';

class LaporanHistoryCard extends StatelessWidget {
  final Laporan laporan;
  final VoidCallback onTap;
  final VoidCallback onCetakPdf;
  final VoidCallback onCopyText;
  final VoidCallback onDuplikat;
  final VoidCallback onDelete;
  final VoidCallback onKirimWa;
  final VoidCallback onCobaLagiUpload;

  const LaporanHistoryCard({
    super.key,
    required this.laporan,
    required this.onTap,
    required this.onCetakPdf,
    required this.onCopyText,
    required this.onDuplikat,
    required this.onDelete,
    required this.onKirimWa,
    required this.onCobaLagiUpload,
  });

  /// Upload berjalan otomatis saat simpan, jadi di sini cuma menampilkan
  /// status. Tombol hanya muncul kalau upload belum berhasil (gagal/tertunda).
  Widget _statusUpload() {
    switch (laporan.uploadStatus) {
      case 'UPLOADED':
        return const Chip(
          avatar: Icon(Icons.cloud_done, size: 16, color: Colors.green),
          label: Text('Terupload', style: TextStyle(fontSize: 12)),
        );
      case 'UPLOADING':
        return const Chip(
          avatar: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          label: Text('Mengunggah...', style: TextStyle(fontSize: 12)),
        );
      default: // LOCAL / FAILED
        return OutlinedButton.icon(
          onPressed: onCobaLagiUpload,
          icon: Icon(
            laporan.uploadStatus == 'FAILED' ? Icons.cloud_off : Icons.cloud_upload,
            size: 18,
            color: laporan.uploadStatus == 'FAILED' ? Colors.red : null,
          ),
          label: Text(laporan.uploadStatus == 'FAILED' ? 'Coba Lagi' : 'Upload Ulang'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jumlahFoto = laporan.fotos.length;
    final totalKategori = KategoriFoto.semua.length;
    final lengkap = jumlahFoto >= totalKategori;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder,
                    color: lengkap ? Colors.amber : Colors.orange.shade300,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patroli ${laporan.tanggal} - ${laporan.jamPatroli} WIB',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('PIC: ${laporan.picPatroli}', style: const TextStyle(fontSize: 12)),
                        Text(
                          'Dibuat oleh: ${laporan.namaPembuat}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: lengkap ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: lengkap ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      lengkap ? Icons.check_circle : Icons.pending_actions,
                      size: 14,
                      color: lengkap ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lengkap
                          ? 'Foto lengkap ($jumlahFoto/$totalKategori)'
                          : 'Foto belum lengkap ($jumlahFoto/$totalKategori) - ketuk untuk lanjutkan',
                      style: TextStyle(
                        fontSize: 11,
                        color: lengkap ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onCetakPdf,
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Cetak PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyText,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Text'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDuplikat,
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Duplikat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onKirimWa,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Kirim WA'),
                  ),
                  _statusUpload(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
