import 'package:flutter/material.dart';

import '../models/laporan_model.dart';
import '../models/zona_waktu.dart';
import '../services/notifikasi_patrol_service.dart';

/// Pengaturan alarm & notifikasi Safety Patrol: nyalakan/matikan, pilih nada
/// alarm (dengan tombol coba), pilih jam patroli yang diingatkan, dan cek
/// status izin.
class PengaturanNotifikasiPage extends StatefulWidget {
  const PengaturanNotifikasiPage({super.key});

  @override
  State<PengaturanNotifikasiPage> createState() => _PengaturanNotifikasiPageState();
}

class _PengaturanNotifikasiPageState extends State<PengaturanNotifikasiPage> with WidgetsBindingObserver {
  bool _memuat = true;
  bool _aktif = true;
  NadaDering _nada = NotifikasiPatrolService.daftarNada.first;
  Set<String> _slot = daftarJamPatroli.toSet();
  bool _izinNotif = false;
  bool _izinAlarm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari halaman pengaturan sistem -> cek ulang status izin.
    if (state == AppLifecycleState.resumed) _muat();
  }

  Future<void> _muat() async {
    final aktif = await NotifikasiPatrolService.aktif;
    final nada = await NotifikasiPatrolService.nadaTerpilih();
    final slot = await NotifikasiPatrolService.slotDiingatkan();
    final izinNotif = await NotifikasiPatrolService.notifikasiDiizinkan();
    final izinAlarm = await NotifikasiPatrolService.alarmTepatWaktuDiizinkan();
    if (!mounted) return;
    setState(() {
      _aktif = aktif;
      _nada = nada;
      _slot = slot;
      _izinNotif = izinNotif;
      _izinAlarm = izinAlarm;
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return Scaffold(appBar: AppBar(title: const Text('Alarm & Notifikasi')), body: const Center(child: CircularProgressIndicator()));
    }
    final zona = ZonaWaktu.aktif;
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm & Notifikasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktifkan pengingat Safety Patrol'),
            subtitle: const Text('Alarm 5 menit sebelum jam patroli, notifikasi 1 jam sesudahnya jika laporan belum beres.'),
            value: _aktif,
            onChanged: (v) async {
              setState(() => _aktif = v);
              await NotifikasiPatrolService.setAktif(v);
            },
          ),
          if (!_izinNotif || !_izinAlarm) _kartuIzin(),
          const Divider(height: 32),
          const Text('Nada alarm (5 menit sebelum patroli)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Alarm berbunyi berulang, bisa dimatikan lewat tombol "Matikan Alarm", dan berhenti sendiri setelah ${NotifikasiPatrolService.durasiAlarmMenit} menit.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          RadioGroup<String>(
            groupValue: _nada.kunci,
            onChanged: (k) async {
              final n = NotifikasiPatrolService.daftarNada.firstWhere((e) => e.kunci == k);
              setState(() => _nada = n);
              await NotifikasiPatrolService.setNada(n);
            },
            child: Column(
              children: [
                for (final n in NotifikasiPatrolService.daftarNada)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: n.kunci,
                    title: Text(n.nama),
                    secondary: IconButton(
                      tooltip: 'Coba bunyikan',
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () => NotifikasiPatrolService.ujiAlarm(n),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          const Text('Jam patroli yang diingatkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Jam dalam ${zona.label} (zona waktu Anda saat ini).', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final jam in daftarJamPatroli)
                FilterChip(
                  label: Text(jam),
                  selected: _slot.contains(jam),
                  onSelected: (v) async {
                    final baru = {..._slot};
                    v ? baru.add(jam) : baru.remove(jam);
                    setState(() => _slot = baru);
                    await NotifikasiPatrolService.setSlotDiingatkan(baru);
                  },
                ),
            ],
          ),
          const Divider(height: 32),
          const Text('Uji notifikasi 1 jam sesudah patroli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Dua kondisi memakai suara yang berbeda.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => NotifikasiPatrolService.ujiSusulan(JenisNotif.missed),
                icon: const Icon(Icons.error_outline, size: 18),
                label: const Text('Belum buat laporan'),
              ),
              OutlinedButton.icon(
                onPressed: () => NotifikasiPatrolService.ujiSusulan(JenisNotif.belumUpload),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Belum upload'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tips: bila alarm tidak berbunyi saat aplikasi tertutup, buka Pengaturan HP > Aplikasi > aplikasi ini > Baterai, '
            'lalu pilih "Tidak dibatasi" (beberapa merek HP menghentikan alarm aplikasi di latar belakang).',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _kartuIzin() {
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Expanded(child: Text('Izin belum lengkap, alarm bisa tidak berbunyi tepat waktu.', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 4),
            Text('Notifikasi: ${_izinNotif ? "diizinkan" : "BELUM"}  •  Alarm tepat waktu: ${_izinAlarm ? "diizinkan" : "BELUM"}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                await NotifikasiPatrolService.mintaIzin();
                await _muat();
                await NotifikasiPatrolService.sinkronkanJadwal();
              },
              child: const Text('Berikan izin'),
            ),
          ],
        ),
      ),
    );
  }
}
