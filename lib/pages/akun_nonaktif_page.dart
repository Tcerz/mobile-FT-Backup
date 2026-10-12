import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AkunNonaktifPage extends StatelessWidget {
  const AkunNonaktifPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Akun Anda dinonaktifkan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hubungi admin untuk mengaktifkan kembali akun Anda.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => AuthService.signOut(),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
