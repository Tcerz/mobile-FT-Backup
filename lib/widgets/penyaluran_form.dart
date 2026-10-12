import 'package:flutter/material.dart';
import '../models/kegiatan_model.dart';
import 'catatan_dengan_foto.dart';

class PenyaluranForm extends StatelessWidget {
  final PenyaluranData data;
  final ValueChanged<PenyaluranData> onChanged;

  const PenyaluranForm({super.key, required this.data, required this.onChanged});

  Future<void> _pilihJam(BuildContext context, bool isStart) async {
    final now = TimeOfDay.now();
    final result = await showTimePicker(context: context, initialTime: now);
    if (result == null) return;
    final jamStr =
        '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
    onChanged(isStart ? data.copyWith(startJam: jamStr) : data.copyWith(selesaiJam: jamStr));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3. Penyaluran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: data.personel,
              decoration: const InputDecoration(labelText: 'Personel', border: OutlineInputBorder()),
              onChanged: (v) => onChanged(data.copyWith(personel: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pilihJam(context, true),
                    child: Text(
                      data.startJam.isEmpty ? 'Start Penyaluran' : 'Start: ${data.startJam}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pilihJam(context, false),
                    child: Text(
                      data.selesaiJam.isEmpty ? 'Selesai Penyaluran' : 'Selesai: ${data.selesaiJam}',
                    ),
                  ),
                ),
              ],
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
