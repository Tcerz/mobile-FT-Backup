import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service ini mengambil waktu resmi lewat internet, BUKAN dari jam yang
/// diatur di HP. Ini mencegah petugas mengubah-ubah jam/tanggal HP untuk
/// memanipulasi waktu laporan.
///
/// Sumber UTAMA: header "Date" yang otomatis disertakan di SETIAP respons
/// server HTTPS mana pun (bagian standar protokol HTTP itu sendiri) --
/// jauh lebih tahan lama dibanding memakai "API jam" pihak ketiga yang
/// sering tutup/mati (contoh nyata: worldtimeapi.org yang sebelumnya
/// dipakai di sini sudah resmi mengumumkan SUNSET/tutup permanen dan
/// tidak bisa diandalkan lagi).
class TimeService {
  static Future<DateTime> getCurrentWorldTime({
    String timezone = 'Asia/Jakarta',
  }) async {
    // 1. Sumber utama: header "Date" dari respons server HTTPS besar
    //    (Google) yang jamnya disinkronkan presisi tinggi lewat NTP.
    //    Nilai epoch dari header ini dipakai APA ADANYA (tidak digeser
    //    jam berapa pun) -- karena epoch bersifat absolut/tidak
    //    tergantung zona waktu, jadi perhitungan selisih dengan jam
    //    device tetap akurat berapa pun zona waktu device diatur.
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 6));
      final dateHeader = _cariHeaderDate(response.headers);
      if (dateHeader != null) {
        return HttpDate.parse(dateHeader);
      }
    } catch (_) {
      // lanjut ke fallback
    }

    // 2. Fallback: timeapi.io (kalau header Date entah kenapa tidak ada,
    //    atau tidak ada akses ke google.com tapi masih ada internet).
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://timeapi.io/api/Time/current/zone?timeZone=$timezone',
            ),
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tanggal = data['dateTime'] as String;
        return DateTime.parse(tanggal);
      }
    } catch (_) {
      // lanjut ke fallback terakhir
    }

    // 3. Kalau benar-benar tidak ada internet, lempar error -- aplikasi
    //    akan menampilkan peringatan + tombol coba lagi, TIDAK diam-diam
    //    memakai jam device (supaya waktu laporan tetap terpercaya).
    throw Exception(
      'Tidak dapat mengambil jam dunia. Periksa koneksi internet.',
    );
  }

  /// Header HTTP bersifat case-insensitive, jadi dicari tanpa peduli
  /// besar/kecil huruf ("Date", "date", dst semua dianggap sama).
  static String? _cariHeaderDate(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'date') return entry.value;
    }
    return null;
  }
}
