import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service ini mengambil waktu resmi lewat internet, BUKAN dari jam yang
/// diatur di HP. Ini mencegah petugas mengubah-ubah jam/tanggal HP untuk
/// memanipulasi waktu laporan.
///
/// SEMUA fungsi di sini mengembalikan UTC (DateTime.isUtc == true). Konversi
/// ke WIB/WITA/WIT dilakukan terpisah lewat [ZonaWaktu] berdasarkan lokasi
/// user -- jadi tidak ada lagi "jam Jakarta" yang tersembunyi di sini.
///
/// Sumber UTAMA: header "Date" yang disertakan di SETIAP respons server
/// HTTPS (bagian standar protokol HTTP), jauh lebih tahan lama daripada
/// "API jam" pihak ketiga yang sering tutup (contoh: worldtimeapi.org).
class TimeService {
  static Future<DateTime> getCurrentUtc() async {
    // 1. Header "Date" dari Google (disinkronkan NTP). HttpDate.parse
    //    sudah menghasilkan UTC.
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 6));
      final dateHeader = _cariHeaderDate(response.headers);
      if (dateHeader != null) {
        return HttpDate.parse(dateHeader).toUtc();
      }
    } catch (_) {
      // lanjut ke fallback
    }

    // 2. Fallback: timeapi.io, diminta langsung dalam zona UTC. Responsnya
    //    tanpa penanda zona ("2026-10-28T03:04:05.123"), jadi ditambah "Z"
    //    secara eksplisit supaya TIDAK dianggap jam lokal perangkat.
    try {
      final response = await http
          .get(Uri.parse('https://timeapi.io/api/Time/current/zone?timeZone=UTC'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tanggal = data['dateTime'] as String;
        return DateTime.parse(tanggal.endsWith('Z') ? tanggal : '${tanggal}Z');
      }
    } catch (_) {
      // lanjut
    }

    // 3. Tidak ada internet -> error. TIDAK diam-diam memakai jam HP supaya
    //    waktu laporan tetap terpercaya.
    throw Exception('Tidak dapat mengambil jam dunia. Periksa koneksi internet.');
  }

  static String? _cariHeaderDate(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'date') return entry.value;
    }
    return null;
  }
}
