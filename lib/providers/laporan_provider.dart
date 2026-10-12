import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/foto_laporan_model.dart';
import '../models/laporan_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/upload_service.dart';

class LaporanProvider extends ChangeNotifier {
  List<Laporan> _daftarLaporan = [];
  List<Laporan> get daftarLaporan => _daftarLaporan;

  bool _sinkronBerjalan = false;
  bool get sinkronBerjalan => _sinkronBerjalan;

  String get _uid => AuthService.currentUser?.id ?? '';

  /// id lokal laporan yang sedang diupload di sesi ini -- mencegah upload
  /// ganda untuk laporan yang sama (mis. tombol Coba Lagi ditekan berulang).
  final Set<int> _sedangUpload = {};

  /// Dipanggil sekali tiap kali user berhasil login (lihat main.dart).
  /// 1) Mengadopsi laporan lokal lama yang belum punya pemilik (migrasi).
  /// 2) Menarik laporan milik user ini dari server (device lain / install ulang).
  Future<void> bootstrapUntukUser() async {
    if (_uid.isEmpty) return;
    await DatabaseHelper.instance.adopsiLaporanLama(_uid);
    await fetchAll();
    await uploadTertunda();
    await sinkronDariServer();
  }

  void reset() {
    _daftarLaporan = [];
    notifyListeners();
  }

  Future<void> fetchAll() async {
    if (_uid.isEmpty) {
      _daftarLaporan = [];
    } else {
      _daftarLaporan = await DatabaseHelper.instance.getAllLaporanHeader(_uid);
    }
    notifyListeners();
  }

  Future<Laporan?> fetchDetail(int id) async {
    return await DatabaseHelper.instance.getLaporanDetail(id, _uid);
  }

  Future<int> simpanLaporan(Laporan laporan, List<FotoLaporan> fotos) async {
    final id = await DatabaseHelper.instance.insertLaporan(laporan.copyWith(userId: _uid), fotos);
    await fetchAll();
    return id;
  }

  Future<void> hapusLaporan(int id) async {
    await DatabaseHelper.instance.deleteLaporan(id);
    await fetchAll();
  }

  Future<void> updateLaporan(Laporan laporan, List<FotoLaporan> fotos) async {
    await DatabaseHelper.instance.updateLaporan(laporan, fotos);
    await fetchAll();
  }

  /// Mengunggah laporan [id] (hasil simpan/edit, atau retry). Mengembalikan
  /// null kalau sukses, atau pesan error kalau gagal -- laporan tetap
  /// tersimpan lokal dengan status FAILED dan bisa dicoba lagi dari card.
  Future<String?> uploadLaporanById(int id) async {
    if (!_sedangUpload.add(id)) return null;
    try {
      final detail = await fetchDetail(id);
      if (detail == null) return 'Laporan tidak ditemukan';
      await UploadService.uploadLaporan(detail);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _sedangUpload.remove(id);
      await fetchAll();
    }
  }

  /// Mengunggah semua laporan yang belum UPLOADED (LOCAL / FAILED / sisa
  /// UPLOADING karena app tertutup di tengah upload). Dipanggil saat login.
  /// Return jumlah laporan yang berhasil diupload.
  Future<int> uploadTertunda() async {
    final ids = _daftarLaporan
        .where((l) => l.id != null && l.uploadStatus != 'UPLOADED')
        .map((l) => l.id!)
        .toList();
    int berhasil = 0;
    for (final id in ids) {
      if (await uploadLaporanById(id) == null) berhasil++;
    }
    return berhasil;
  }

  /// Menarik ulang laporan milik user ini dari server -- supaya laporan
  /// yang diupload dari device lain juga muncul di device sekarang.
  /// Return jumlah laporan baru yang berhasil ditarik.
  Future<int> sinkronDariServer() async {
    if (_uid.isEmpty || _sinkronBerjalan) return 0;
    _sinkronBerjalan = true;
    notifyListeners();
    int jumlahBaru = 0;
    try {
      jumlahBaru = await SyncService.tarikLaporanSaya();
      if (jumlahBaru > 0) await fetchAll();
    } finally {
      _sinkronBerjalan = false;
      notifyListeners();
    }
    return jumlahBaru;
  }
}
