import 'package:intl/intl.dart';

import '../models/laporan_model.dart';

class TextExportService {
  /// Membentuk teks ringkas laporan (format mirip laporan manual di WA)
  /// agar tinggal di-copy-paste ke aplikasi chat.
  static String buatTeksLaporan(Laporan laporan) {
    String hari = '';
    try {
      final tgl = DateFormat('dd-MM-yyyy').parse(laporan.tanggal);
      hari = DateFormat('EEEE', 'id_ID').format(tgl);
    } catch (_) {
      hari = '';
    }

    final buffer = StringBuffer();
    buffer.writeln('Laporan Safety Patrol Guard');
    buffer.writeln(
      '${hari.isNotEmpty ? '$hari, ' : ''}${laporan.tanggal} Jam ${laporan.jamPatroli} WIB',
    );
    buffer.writeln('PT. PERTAMINA PATRA NIAGA FT. SEI SIAK');
    buffer.writeln();
    buffer.writeln('Kegiatan :');

    buffer.writeln('1. Loading :');
    buffer.writeln('- Personel : ${_v(laporan.loading.personel)}');
    buffer.writeln('- Jetty 1 : ${_v(laporan.loading.jetty1)}');
    buffer.writeln('- Jetty 2 : ${_v(laporan.loading.jetty2)}');
    buffer.writeln('- Produk : ${_v(laporan.loading.produk)}');
    buffer.writeln('- Kondisi : ${laporan.loading.kondisi}');
    buffer.writeln('- Note : ${_v(laporan.loading.note)}');
    buffer.writeln();

    buffer.writeln('2. Discharge :');
    buffer.writeln('- Personel : ${_v(laporan.discharge.personel)}');
    buffer.writeln('- Jetty 1 : ${_v(laporan.discharge.jetty1)}');
    buffer.writeln('- Jetty 2 : ${_v(laporan.discharge.jetty2)}');
    buffer.writeln('- Produk : ${_v(laporan.discharge.produk)}');
    buffer.writeln('- Kondisi : ${laporan.discharge.kondisi}');
    buffer.writeln('- Note : ${_v(laporan.discharge.note)}');
    buffer.writeln();

    buffer.writeln('3. Penyaluran :');
    buffer.writeln('- Personel : ${_v(laporan.penyaluran.personel)}');
    buffer.writeln('- Start Penyaluran : ${_v(laporan.penyaluran.startJam)}');
    buffer.writeln('- Selesai Penyaluran : ${_v(laporan.penyaluran.selesaiJam)}');
    buffer.writeln('- Kondisi : ${laporan.penyaluran.kondisi}');
    buffer.writeln('- Note : ${_v(laporan.penyaluran.note)}');
    buffer.writeln();

    buffer.writeln('4. Storage (Penimbunan) :');
    buffer.writeln('- Personel : ${_v(laporan.storage.personel)}');
    buffer.writeln('- Tangki Loading : ${_fmt(laporan.storage.tangkiLoading)}');
    buffer.writeln('- Tangki Discharge : ${_fmt(laporan.storage.tangkiDischarge)}');
    buffer.writeln('- Tangki Penyaluran : ${_fmt(laporan.storage.tangkiPenyaluran)}');
    buffer.writeln('- Tangki Aktif/Idle : ${_fmtAktif(laporan.storage.tangkiAktifIdle, laporan.storage.jenisProdukAktif)}');
    buffer.writeln('- Tangki Off : ${_fmt(laporan.storage.tangkiOff)}');
    buffer.writeln('- Kondisi : ${laporan.storage.kondisi}');
    buffer.writeln('- Note : ${_v(laporan.storage.note)}');
    buffer.writeln();

    buffer.writeln('PIC Patroli : ${laporan.picPatroli}');
    buffer.writeln('Dibuat oleh : ${laporan.namaPembuat}');
    buffer.writeln('Waktu Laporan : ${laporan.waktuDibuat}');

    return buffer.toString();
  }

  static String _v(String s) => s.trim().isEmpty ? 'NIHIL' : s;
  static String _fmt(List<String> list) => list.isEmpty ? 'NIHIL' : list.join(', ');

  static String _fmtAktif(List<String> list, Map<String, String> produk) {
    if (list.isEmpty) return 'NIHIL';
    return list.map((k) => produk[k] != null ? '$k ${produk[k]}' : k).join(', ');
  }
}
