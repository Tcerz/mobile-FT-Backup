import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/foto_laporan_model.dart';
import '../models/kegiatan_model.dart';
import '../models/laporan_model.dart';
import 'auth_service.dart';

/// Menarik laporan milik user yang sedang login dari server ke device ini.
/// Dipakai supaya laporan yang diupload dari device A tetap terlihat saat
/// user yang sama login di device B (atau install ulang aplikasi).
class SyncService {
  static Future<int> tarikLaporanSaya() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return 0;

    final rows = await AuthService.client
        .from('reports')
        .select('*, report_photos(*)')
        .eq('user_id', uid)
        .order('created_at');

    int jumlahBaru = 0;
    for (final row in rows) {
      final remoteId = row['id'] as String;
      if (await DatabaseHelper.instance.remoteIdSudahAda(remoteId)) continue;

      final fotos = <FotoLaporan>[];
      for (final f in (row['report_photos'] as List)) {
        final path = await unduhFoto(f['photo_url'] as String, '${remoteId}_${f['kategori']}');
        if (path == null) continue;
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

      final laporan = Laporan(
        namaPembuat: row['nama_pembuat'] as String,
        tanggal: row['tanggal'] as String,
        jamPatroli: row['jam_patroli'] as String,
        picPatroli: row['pic_patroli'] as String,
        waktuDibuat: row['waktu_dibuat'] as String,
        loading: LoadingDischargeData.fromJson(row['loading_data'] as String? ?? ''),
        discharge: LoadingDischargeData.fromJson(row['discharge_data'] as String? ?? ''),
        penyaluran: PenyaluranData.fromJson(row['penyaluran_data'] as String? ?? ''),
        storage: StorageData.fromJson(row['storage_data'] as String? ?? ''),
        fotos: fotos,
        uploadStatus: 'UPLOADED',
        userId: uid,
        remoteId: remoteId,
      );
      await DatabaseHelper.instance.insertLaporan(laporan, fotos);
      jumlahBaru++;
    }
    return jumlahBaru;
  }

  /// Unduh 1 foto dari Supabase Storage ke folder dokumen lokal. Kalau
  /// gagal (mis. tidak ada internet), return null -- foto itu dilewati.
  static Future<String?> unduhFoto(String url, String namaFile) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/sync_$namaFile.jpg');
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
