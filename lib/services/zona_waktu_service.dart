import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/zona_waktu.dart';

/// Menentukan zona waktu (WIB/WITA/WIT) user dari LOKASI GPS-nya.
///
/// Urutan penentuan:
///  1. Nama provinsi hasil reverse geocoding (paling akurat, karena batas
///     zona di Indonesia mengikuti batas provinsi, mis. Kalimantan Tengah
///     WIB tapi Kalimantan Selatan WITA padahal bujurnya berdekatan).
///  2. Kalau geocoding gagal (offline) -> perkiraan dari bujur.
///  3. Kalau lokasi di luar Indonesia / belum ada izin -> zona terakhir yang
///     tersimpan, atau offset zona perangkat (hanya kalau 7/8/9), atau WIB.
class ZonaWaktuService {
  static const _kKey = 'zona_waktu_terakhir';

  static Future<ZonaWaktu> muatTersimpan() async {
    final prefs = await SharedPreferences.getInstance();
    return ZonaWaktu.dariLabel(prefs.getString(_kKey)) ?? dariOffsetPerangkat();
  }

  static Future<void> simpan(ZonaWaktu zona) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, zona.label);
  }

  static ZonaWaktu dariOffsetPerangkat() {
    switch (DateTime.now().timeZoneOffset.inHours) {
      case 8:
        return ZonaWaktu.wita;
      case 9:
        return ZonaWaktu.wit;
      default:
        return ZonaWaktu.wib;
    }
  }

  /// Perkiraan kasar dari bujur -- HANYA fallback saat nama provinsi tidak
  /// tersedia. Tidak akurat di perbatasan (mis. Kalimantan Tengah bagian timur).
  static ZonaWaktu dariBujur(double lng) {
    if (lng >= 127.0) return ZonaWaktu.wit;
    if (lng >= 114.6) return ZonaWaktu.wita;
    return ZonaWaktu.wib;
  }

  /// Nama provinsi (bisa Indonesia atau Inggris, tergantung bahasa HP) ->
  /// zona. Null kalau tidak dikenali.
  static ZonaWaktu? dariProvinsi(String? provinsi) {
    if (provinsi == null || provinsi.trim().isEmpty) return null;
    final p = provinsi.toLowerCase();
    bool ada(List<String> kata) => kata.any(p.contains);

    // Cek WIB eksplisit dulu untuk 2 provinsi Kalimantan yang bujurnya
    // "terlihat" WITA.
    if (ada(['kalimantan barat', 'west kalimantan', 'kalimantan tengah', 'central kalimantan'])) {
      return ZonaWaktu.wib;
    }
    if (ada(['papua', 'maluku', 'moluccas'])) return ZonaWaktu.wit;
    if (ada([
      'bali',
      'nusa tenggara',
      'kalimantan selatan',
      'south kalimantan',
      'kalimantan timur',
      'east kalimantan',
      'kalimantan utara',
      'north kalimantan',
      'sulawesi',
      'gorontalo',
    ])) {
      return ZonaWaktu.wita;
    }
    return null;
  }

  /// null = lokasi di luar Indonesia (zona tidak diubah).
  static Future<ZonaWaktu?> deteksiDariKoordinat(double lat, double lng) async {
    if (lat < -12 || lat > 7 || lng < 94 || lng > 142) return null;
    try {
      final pm = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 5));
      if (pm.isNotEmpty) {
        final z = dariProvinsi(pm.first.administrativeArea);
        if (z != null) return z;
      }
    } catch (_) {
      // offline / geocoder tidak tersedia -> pakai perkiraan bujur
    }
    return dariBujur(lng);
  }

  /// Membaca posisi TANPA memunculkan dialog izin (izin diminta terpisah di
  /// StartupService). Return null kalau izin/GPS tidak tersedia.
  static Future<Position?> posisiTanpaMeminta() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        return null;
      }
      final terakhir = await Geolocator.getLastKnownPosition();
      if (terakhir != null) return terakhir;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
