import 'package:flutter/widgets.dart';

import '../models/zona_waktu.dart';
import '../services/notifikasi_patrol_service.dart';
import '../services/zona_waktu_service.dart';

/// Menyimpan zona waktu aktif (hasil deteksi lokasi) dan memperbaruinya
/// setiap aplikasi dibuka kembali. Ketika zona berubah (mis. petugas pindah
/// dari Medan ke Makassar), seluruh tampilan waktu ikut berubah dan jadwal
/// notifikasi dihitung ulang.
class ZonaWaktuProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool _dipasang = false;

  ZonaWaktu get zona => ZonaWaktu.aktif;

  Future<void> mulai() async {
    if (!_dipasang) {
      WidgetsBinding.instance.addObserver(this);
      _dipasang = true;
    }
    await perbaruiDariLokasi();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) perbaruiDariLokasi();
  }

  /// Dipanggil saat app start, saat kembali dari background, dan setelah izin
  /// lokasi baru diberikan.
  Future<void> perbaruiDariLokasi() async {
    final pos = await ZonaWaktuService.posisiTanpaMeminta();
    if (pos != null) await perbaruiDariKoordinat(pos.latitude, pos.longitude);
  }

  /// Dipakai juga saat mengambil foto (GPS saat itu pasti terbaru).
  Future<void> perbaruiDariKoordinat(double lat, double lng) async {
    final baru = await ZonaWaktuService.deteksiDariKoordinat(lat, lng);
    if (baru == null || baru == ZonaWaktu.aktif) return;
    ZonaWaktu.aktif = baru;
    await ZonaWaktuService.simpan(baru);
    notifyListeners();
    NotifikasiPatrolService.sinkronkanJadwal();
  }

  @override
  void dispose() {
    if (_dipasang) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
