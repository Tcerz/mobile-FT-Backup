import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profil_provider.dart';
import '../models/zona_waktu.dart';
import '../providers/zona_waktu_provider.dart';
import '../services/auth_service.dart';
import '../services/notifikasi_patrol_service.dart';
import 'pengaturan_notifikasi_page.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ProfilProvider>();
    final zona = context.watch<ZonaWaktuProvider>().zona;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _baris('Nama', profil.nama),
            _baris('Peran', profil.isAdmin ? 'Admin' : 'Petugas'),
            _baris('Status', profil.aktif ? 'Aktif' : 'Nonaktif'),
            _baris('Zona waktu', '${zona.label} (UTC+${zona.jamOffset}) - ${zona.nama}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await context.read<ZonaWaktuProvider>().perbaruiDariLokasi();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Zona waktu: ${ZonaWaktu.aktif.label}')),
                  );
                }
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Perbarui zona waktu dari lokasi'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PengaturanNotifikasiPage()),
              ),
              icon: const Icon(Icons.alarm),
              label: const Text('Alarm & Notifikasi'),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await NotifikasiPatrolService.batalkanSemua(); // jangan bunyikan alarm akun lain
                await AuthService.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baris(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
