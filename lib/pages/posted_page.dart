import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/foto_laporan_model.dart';
import '../models/kegiatan_model.dart';
import '../models/laporan_model.dart';
import '../providers/profil_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'input_laporan_page.dart';
import 'posted_detail_page.dart';

/// Menampilkan laporan yang sudah diupload oleh SEMUA petugas di depot yang
/// sama (read-only). Petugas lain hanya boleh melihat & menduplikasi --
/// tidak bisa mengedit laporan milik orang lain.
class PostedPage extends StatefulWidget {
  final VoidCallback onPindahKeAktivitas;
  const PostedPage({super.key, required this.onPindahKeAktivitas});

  @override
  State<PostedPage> createState() => _PostedPageState();
}

class _PostedPageState extends State<PostedPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String? _sedangDiduplikatId; // id laporan yg fotonya lagi didownload

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final depotId = context.read<ProfilProvider>().depotId;
      if (depotId == null) {
        setState(() {
          _rows = [];
          _loading = false;
        });
        return;
      }
      final data = await AuthService.client
          .from('reports')
          .select('*, report_photos(*)')
          .eq('depot_id', depotId)
          .order('created_at', ascending: false);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat: $e';
        _loading = false;
      });
    }
  }

  /// Laporan untuk ditampilkan (read-only) -- foto masih berupa URL
  /// jaringan, cukup dipakai Image.network, tidak perlu diunduh.
  Laporan _keLaporanTampilan(Map<String, dynamic> row) {
    final fotos = (row['report_photos'] as List)
        .map((f) => FotoLaporan(
              kategori: f['kategori'] as String,
              imagePath: f['photo_url'] as String,
              latitude: (f['latitude'] as num).toDouble(),
              longitude: (f['longitude'] as num).toDouble(),
              alamat: f['alamat'] as String,
              jam: f['jam'] as String,
              suhu: f['suhu'] as String,
            ))
        .toList();
    return _bangunLaporan(row, fotos);
  }

  Laporan _bangunLaporan(Map<String, dynamic> row, List<FotoLaporan> fotos) {
    return Laporan(
      namaPembuat: row['nama_pembuat'] as String,
      tanggal: row['tanggal'] as String, // ikut tanggal laporan ASLI, bukan hari ini
      jamPatroli: row['jam_patroli'] as String,
      picPatroli: row['pic_patroli'] as String,
      waktuDibuat: row['waktu_dibuat'] as String,
      loading: LoadingDischargeData.fromJson(row['loading_data'] as String? ?? ''),
      discharge: LoadingDischargeData.fromJson(row['discharge_data'] as String? ?? ''),
      penyaluran: PenyaluranData.fromJson(row['penyaluran_data'] as String? ?? ''),
      storage: StorageData.fromJson(row['storage_data'] as String? ?? ''),
      fotos: fotos,
    );
  }

  String _tanggalHariIni() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}-${n.month.toString().padLeft(2, '0')}-${n.year}';
  }

  /// Untuk duplikat: foto TETAP dibawa (bukan dikosongkan), tapi harus
  /// diunduh dulu jadi file lokal (bukan URL) supaya bisa dipakai/diedit
  /// seperti foto biasa. Jam & suhu pada foto akan otomatis diperbarui
  /// mengikuti waktu saat DISIMPAN nanti (logika ini sudah ada di
  /// input_laporan_page.dart untuk semua mode duplikat, tidak perlu diulang
  /// di sini). Tanggal laporan default ke HARI INI (saat penduplikat
  /// menyimpan), bukan ikut tanggal laporan asli -- beda dengan duplikat
  /// laporan sendiri yang memang biasanya untuk hari yang sama.
  Future<Laporan> _siapkanDataDuplikat(Map<String, dynamic> row) async {
    final fotos = <FotoLaporan>[];
    for (final f in (row['report_photos'] as List)) {
      final path = await SyncService.unduhFoto(f['photo_url'] as String, 'dup_${row['id']}_${f['kategori']}');
      if (path == null) continue; // gagal unduh 1 foto -> lewati, jangan gagalkan semua
      fotos.add(FotoLaporan(
        kategori: f['kategori'] as String,
        imagePath: path,
        latitude: (f['latitude'] as num).toDouble(),
        longitude: (f['longitude'] as num).toDouble(),
        alamat: f['alamat'] as String,
        jam: f['jam'] as String,
        suhu: f['suhu'] as String,
      ));
    }
    return _bangunLaporan(row, fotos).copyWith(tanggal: _tanggalHariIni());
  }

  Future<bool> _duplikat(Map<String, dynamic> row) async {
    setState(() => _sedangDiduplikatId = row['id'] as String);
    Laporan laporan;
    try {
      laporan = await _siapkanDataDuplikat(row);
    } finally {
      if (mounted) setState(() => _sedangDiduplikatId = null);
    }
    if (!mounted) return false;
    final berhasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InputLaporanPage(duplikatData: laporan)),
    );
    if (berhasil == true) widget.onPindahKeAktivitas();
    return berhasil == true;
  }

  void _lihatDetail(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostedDetailPage(
          laporan: _keLaporanTampilan(row),
          onDuplikat: () => _duplikat(row),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posted \u2014 Laporan Se-Depot'),
        actions: [IconButton(onPressed: _muat, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : _rows.isEmpty
                  ? const Center(child: Text('Belum ada laporan yang diupload di depot ini'))
                  : RefreshIndicator(
                      onRefresh: _muat,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rows.length,
                        itemBuilder: (context, i) {
                          final row = _rows[i];
                          final sedangDiduplikat = _sedangDiduplikatId == row['id'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _lihatDetail(row),
                              title: Text('${row['tanggal']} \u00b7 ${row['jam_patroli']}'),
                              subtitle: Text('Oleh: ${row['nama_pembuat']}\nPIC: ${row['pic_patroli']}'),
                              isThreeLine: true,
                              trailing: OutlinedButton.icon(
                                onPressed: sedangDiduplikat ? null : () => _duplikat(row),
                                icon: sedangDiduplikat
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.content_copy, size: 16),
                                label: Text(sedangDiduplikat ? 'Mengunduh...' : 'Duplikat'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
