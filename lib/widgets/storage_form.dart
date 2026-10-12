import 'package:flutter/material.dart';
import '../models/kegiatan_model.dart';
import 'catatan_dengan_foto.dart';
import 'tangki_multi_select.dart';

class StorageForm extends StatelessWidget {
  final StorageData data;
  final ValueChanged<StorageData> onChanged;

  const StorageForm({super.key, required this.data, required this.onChanged});

  /// Tangki yang sudah dipakai di kategori LAIN -- tapi HANYA dalam grup
  /// yang sama (Loading/Discharge/Penyaluran saling mengunci satu sama
  /// lain; Aktif-Idle/Off saling mengunci satu sama lain -- kedua grup ini
  /// independen, tidak saling mempengaruhi).
  Set<String> _tangkiDipakaiDiGrup(List<List<String>> grup, int indexSaatIni) {
    final hasil = <String>{};
    for (int i = 0; i < grup.length; i++) {
      if (i == indexSaatIni) continue;
      hasil.addAll(grup[i]);
    }
    return hasil;
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
            const Text('4. Storage (Penimbunan)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Satu tangki hanya bisa dipilih di satu kategori dalam grup yang sama '
              '(Loading/Discharge/Penyaluran saling mengunci; Aktif-Idle/Off saling mengunci).',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: data.personel,
              decoration: const InputDecoration(labelText: 'Personel', border: OutlineInputBorder()),
              onChanged: (v) => onChanged(data.copyWith(personel: v)),
            ),
            const SizedBox(height: 12),
            TangkiMultiSelect(
              label: 'Tangki Loading',
              selected: data.tangkiLoading,
              disabledTanks: _tangkiDipakaiDiGrup([data.tangkiLoading, data.tangkiDischarge, data.tangkiPenyaluran], 0),
              onChanged: (v) => onChanged(data.copyWith(tangkiLoading: v)),
            ),
            const SizedBox(height: 12),
            TangkiMultiSelect(
              label: 'Tangki Discharge',
              selected: data.tangkiDischarge,
              disabledTanks: _tangkiDipakaiDiGrup([data.tangkiLoading, data.tangkiDischarge, data.tangkiPenyaluran], 1),
              onChanged: (v) => onChanged(data.copyWith(tangkiDischarge: v)),
            ),
            const SizedBox(height: 12),
            TangkiMultiSelect(
              label: 'Tangki Penyaluran',
              selected: data.tangkiPenyaluran,
              disabledTanks: _tangkiDipakaiDiGrup([data.tangkiLoading, data.tangkiDischarge, data.tangkiPenyaluran], 2),
              onChanged: (v) => onChanged(data.copyWith(tangkiPenyaluran: v)),
            ),
            const SizedBox(height: 12),
            TangkiMultiSelect(
              label: 'Tangki Aktif/Idle',
              selected: data.tangkiAktifIdle,
              disabledTanks: _tangkiDipakaiDiGrup([data.tangkiAktifIdle, data.tangkiOff], 0),
              onChanged: (v) {
                // Kalau ada tangki yang dihapus dari daftar aktif, ikut bersihkan
                // jenis produknya supaya tidak ada data "nyangkut".
                final produkBaru = Map<String, String>.from(data.jenisProdukAktif)
                  ..removeWhere((kode, _) => !v.contains(kode));
                onChanged(data.copyWith(tangkiAktifIdle: v, jenisProdukAktif: produkBaru));
              },
            ),
            if (data.tangkiAktifIdle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Jenis Produk per Tangki Aktif', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              ...data.tangkiAktifIdle.map((kode) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 48, child: Text(kode, style: const TextStyle(fontWeight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: data.jenisProdukAktif[kode],
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Jenis Produk',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: daftarProdukTangki
                                .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final produkBaru = Map<String, String>.from(data.jenisProdukAktif)..[kode] = v;
                              onChanged(data.copyWith(jenisProdukAktif: produkBaru));
                            },
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 12),
            TangkiMultiSelect(
              label: 'Tangki Off',
              selected: data.tangkiOff,
              disabledTanks: _tangkiDipakaiDiGrup([data.tangkiAktifIdle, data.tangkiOff], 1),
              onChanged: (v) => onChanged(data.copyWith(tangkiOff: v)),
            ),
            const SizedBox(height: 12),
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
