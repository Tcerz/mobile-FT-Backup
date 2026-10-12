import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profil_provider.dart';
import '../services/auth_service.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ProfilProvider>();
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
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => AuthService.signOut(),
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
