import 'package:flutter/material.dart';
import '../models/kegiatan_model.dart';
import 'catatan_dengan_foto.dart';

class LoadingDischargeForm extends StatelessWidget {
  final String judul;
  final LoadingDischargeData data;
  final ValueChanged<LoadingDischargeData> onChanged;

  const LoadingDischargeForm({
    super.key,
    required this.judul,
    required this.data,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: data.personel,
              decoration: const InputDecoration(labelText: 'Personel', border: OutlineInputBorder()),
              onChanged: (v) => onChanged(data.copyWith(personel: v)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: data.jetty1,
              decoration: const InputDecoration(labelText: 'Jetty 1', border: OutlineInputBorder()),
              onChanged: (v) => onChanged(data.copyWith(jetty1: v)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: data.jetty2,
              decoration: const InputDecoration(labelText: 'Jetty 2', border: OutlineInputBorder()),
              onChanged: (v) => onChanged(data.copyWith(jetty2: v)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: data.produk,
              decoration: const InputDecoration(labelText: 'Produk', border: OutlineInputBorder()),
              onChanged: (v) => onChanged(data.copyWith(produk: v)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: data.kondisi,
              decoration: const InputDecoration(labelText: 'Kondisi', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: kondisiAman, child: Text(kondisiAman)),
                DropdownMenuItem(value: kondisiTidakAman, child: Text(kondisiTidakAman)),
              ],
              onChanged: (v) => onChanged(data.copyWith(kondisi: v)),
            ),
            const SizedBox(height: 8),
            CatatanDenganFoto(
              note: data.note,
              fotoPaths: data.noteFotos,
              onNoteChanged: (v) => onChanged(data.copyWith(note: v)),
              onFotoChanged: (v) => onChanged(data.copyWith(noteFotos: v)),
            ),
          ],
        ),
      ),
    );
  }
}
