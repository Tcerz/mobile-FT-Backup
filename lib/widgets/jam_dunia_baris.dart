import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Menampilkan jam dunia yang berjalan tiap detik. Dipisah jadi widget
/// sendiri supaya yang ikut ter-render ulang tiap detik cuma baris kecil
/// ini, BUKAN seluruh halaman input laporan (lebih ringan).
class JamDuniaBaris extends StatefulWidget {
  final Duration? offset;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  const JamDuniaBaris({
    super.key,
    required this.offset,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  State<JamDuniaBaris> createState() => _JamDuniaBarisState();
}

class _JamDuniaBarisState extends State<JamDuniaBaris> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waktu = DateTime.now().add(widget.offset ?? Duration.zero);
    return Row(
      children: [
        Icon(
          widget.error != null ? Icons.warning_amber : Icons.public,
          size: 18,
          color: widget.error != null ? Colors.orange : Colors.blueGrey,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: widget.loading
              ? const Text('Mengambil jam dunia...', style: TextStyle(fontSize: 12))
              : widget.error != null
                  ? Text(widget.error!, style: const TextStyle(fontSize: 12, color: Colors.orange))
                  : Text(
                      'Jam dunia: ${DateFormat('dd-MM-yyyy HH:mm:ss').format(waktu)}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
        ),
        IconButton(
          tooltip: 'Sinkronkan ulang jam dunia',
          onPressed: widget.loading ? null : widget.onRefresh,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }
}
