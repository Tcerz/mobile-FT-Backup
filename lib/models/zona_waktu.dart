import 'package:intl/intl.dart';

/// Tiga zona waktu Indonesia. SEMUA waktu di database & server disimpan
/// sebagai UTC; zona ini hanya dipakai untuk MENAMPILKAN (dan untuk
/// menerjemahkan jam patroli yang dipilih user ke UTC).
///
/// [aktif] diisi oleh ZonaWaktuProvider berdasarkan lokasi user (GPS),
/// jadi seluruh tampilan waktu di aplikasi (kartu, PDF, teks WA, stempel
/// foto) otomatis mengikuti lokasi user saat ini.
enum ZonaWaktu {
  wib(7, 'WIB', 'Waktu Indonesia Barat'),
  wita(8, 'WITA', 'Waktu Indonesia Tengah'),
  wit(9, 'WIT', 'Waktu Indonesia Timur');

  const ZonaWaktu(this.jamOffset, this.label, this.nama);

  final int jamOffset;
  final String label;
  final String nama;

  /// Zona yang sedang berlaku untuk tampilan. Default WIB sampai lokasi
  /// user berhasil dideteksi (atau dibaca dari cache terakhir).
  static ZonaWaktu aktif = ZonaWaktu.wib;

  Duration get offset => Duration(hours: jamOffset);

  static ZonaWaktu? dariLabel(String? label) {
    for (final z in ZonaWaktu.values) {
      if (z.label == label) return z;
    }
    return null;
  }

  /// UTC -> "jam dinding" di zona ini. Hasilnya DateTime berflag UTC yang
  /// field-nya (tahun, jam, dst) sudah berisi waktu lokal zona -- cukup
  /// dipakai untuk diformat, JANGAN dibandingkan dengan DateTime lain.
  DateTime keLokal(DateTime utc) => utc.toUtc().add(offset);

  /// Jam dinding di zona ini -> instan UTC yang sebenarnya.
  DateTime dariLokal(int tahun, int bulan, int hari, [int jam = 0, int menit = 0, int detik = 0]) =>
      DateTime.utc(tahun, bulan, hari, jam, menit, detik).subtract(offset);

  String formatTanggal(DateTime utc) => DateFormat('dd-MM-yyyy').format(keLokal(utc));
  String formatJam(DateTime utc) => DateFormat('HH:mm').format(keLokal(utc));
  String formatLengkap(DateTime utc) => DateFormat('dd-MM-yyyy HH:mm:ss').format(keLokal(utc));

  /// Membaca string waktu format LAMA ("dd-MM-yyyy HH:mm[:ss]", jam dinding
  /// di [zona]) menjadi UTC. Dipakai untuk data lama yang dibuat sebelum
  /// sistem UTC ada (semuanya WIB). Return null kalau gagal dibaca.
  static DateTime? parseLegacy(String teks, [ZonaWaktu zona = ZonaWaktu.wib]) {
    final t = teks.trim();
    if (t.isEmpty) return null;
    for (final pola in const ['dd-MM-yyyy HH:mm:ss', 'dd-MM-yyyy HH:mm']) {
      try {
        final jamDinding = DateFormat(pola).parseUtc(t);
        return jamDinding.subtract(zona.offset);
      } catch (_) {}
    }
    return null;
  }
}
