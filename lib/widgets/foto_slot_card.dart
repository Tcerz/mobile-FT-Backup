import 'dart:io';
import 'package:flutter/material.dart';

import '../models/foto_laporan_model.dart';

class FotoSlotCard extends StatelessWidget {
  final String kategori;
  final FotoLaporan? data;
  final bool loading;
  final VoidCallback onAmbilFoto;

  const FotoSlotCard({
    super.key,
    required this.kategori,
    required this.data,
    required this.loading,
    required this.onAmbilFoto,
  });

  @override
  Widget build(BuildContext context) {
    final sudahAda = data != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: loading ? null : onAmbilFoto,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : sudahAda
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(data!.imagePath), fit: BoxFit.cover),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kategori,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Icon(
                        sudahAda ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: sudahAda ? Colors.green : Colors.grey,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (loading)
                    const Text('Mengambil foto & data lokasi...', style: TextStyle(fontSize: 12))
                  else if (sudahAda) ...[
                    Text('Suhu: ${data!.suhu}', style: const TextStyle(fontSize: 12)),
                    Text('Jam: ${data!.jam}', style: const TextStyle(fontSize: 12)),
                    Text(
                      'Koordinat: ${data!.latitude}, ${data!.longitude}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Lokasi: ${data!.alamat}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAmbilFoto,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('Ambil ulang'),
                      ),
                    ),
                  ] else
                    const Text(
                      'Ketuk untuk ambil foto (lokasi, jam, suhu otomatis terisi)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
