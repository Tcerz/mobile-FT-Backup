import 'package:flutter/material.dart';
import '../models/kegiatan_model.dart';

class TangkiMultiSelect extends StatelessWidget {
  final String label;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Tangki yang sudah dipilih di kategori LAIN (mis. sudah dipilih di
  /// "Tangki Aktif/Idle") sehingga tidak boleh dipilih lagi di kategori
  /// ini -> ditampilkan abu-abu & tidak bisa diketuk.
  final Set<String> disabledTanks;

  const TangkiMultiSelect({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.disabledTanks = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: daftarTangki.map((t) {
            final isSelected = selected.contains(t);
            // Kalau dipakai di kategori lain (dan bukan yang sedang dipilih
            // di kategori ini), jadikan non-interaktif & abu-abu.
            final isDikunci = disabledTanks.contains(t) && !isSelected;

            return FilterChip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: isDikunci
                  ? null
                  : (value) {
                      final newList = List<String>.from(selected);
                      if (value) {
                        newList.add(t);
                      } else {
                        newList.remove(t);
                      }
                      onChanged(newList);
                    },
              backgroundColor: isDikunci ? Colors.grey.shade200 : null,
              disabledColor: Colors.grey.shade200,
              labelStyle: TextStyle(
                fontSize: 12,
                color: isDikunci ? Colors.grey.shade500 : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
