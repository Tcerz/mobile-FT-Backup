import 'package:flutter/material.dart';

import 'home_page.dart';
import 'posted_page.dart';

/// Wadah dengan 2 tab: "Aktivitas" (laporan milik sendiri, lokal+upload)
/// dan "Posted" (laporan se-depot dari semua petugas, read-only+duplikat).
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  void _keAktivitas() => setState(() => _index = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          PostedPage(onPindahKeAktivitas: _keAktivitas),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Aktivitas'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Posted'),
        ],
      ),
    );
  }
}
