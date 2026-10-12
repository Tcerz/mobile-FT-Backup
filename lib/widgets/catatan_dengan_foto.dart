import 'dart:io';
import 'package:flutter/material.dart';

import '../models/kegiatan_model.dart';
import '../services/image_service.dart';

/// Textfield "Note" dengan kotak tambah foto (opsional, maks 3) di atasnya.
/// Foto diambil lewat kamera (konsisten dengan foto lain di aplikasi ini,
/// supaya tetap berupa bukti langsung, bukan foto lama dari galeri).
class CatatanDenganFoto extends StatefulWidget {
  final String note;
  final List<String> fotoPaths;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<List<String>> onFotoChanged;

  const CatatanDenganFoto({
    super.key,
    required this.note,
    required this.fotoPaths,
    required this.onNoteChanged,
    required this.onFotoChanged,
  });

  @override
  State<CatatanDenganFoto> createState() => _CatatanDenganFotoState();
}

class _CatatanDenganFotoState extends State<CatatanDenganFoto> {
  bool _menambah = false;

  Future<void> _tambahFoto() async {
    if (widget.fotoPaths.length >= maksimalFotoNote) return;
    setState(() => _menambah = true);
    try {
      final file = await ImageService.ambilFotoDenganKamera();
      if (file != null) {
        final baru = List<String>.from(widget.fotoPaths)..add(file.path);
        widget.onFotoChanged(baru);
      }
    } finally {
      if (mounted) setState(() => _menambah = false);
    }
  }

  void _hapusFoto(int index) {
    final baru = List<String>.from(widget.fotoPaths)..removeAt(index);
    widget.onFotoChanged(baru);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto pendukung note (opsional, maks $maksimalFotoNote)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < widget.fotoPaths.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(widget.fotoPaths[i]),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _hapusFoto(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (widget.fotoPaths.length < maksimalFotoNote)
              GestureDetector(
                onTap: _menambah ? null : _tambahFoto,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                    color: Colors.grey.shade100,
                  ),
                  child: _menambah
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(Icons.add, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.note,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
          onChanged: widget.onNoteChanged,
        ),
      ],
    );
  }
}
