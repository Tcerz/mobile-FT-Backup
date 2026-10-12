import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database_helper.dart';
import '../models/laporan_model.dart';
import 'auth_service.dart';

/// Mengunggah satu laporan (header + foto) ke Supabase. Dipanggil otomatis
/// setiap laporan disimpan/diedit (lihat LaporanProvider), dan oleh tombol
/// "Coba Lagi" kalau upload sebelumnya gagal (mis. sinyal hilang).
///
/// Aman dipanggil berulang untuk laporan yang sama: kalau laporan sudah
/// punya remoteId, baris di server DIPERBARUI (bukan dibuat dobel) dan
/// seluruh fotonya diganti dengan set foto terbaru.
class UploadService {
  static Future<void> uploadLaporan(Laporan laporan) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null || laporan.id == null) throw Exception('Belum login');

    await DatabaseHelper.instance.updateStatusUpload(laporan.id!, 'UPLOADING');
    try {
      final client = AuthService.client;

      final data = {
        'nama_pembuat': laporan.namaPembuat,
        'tanggal': laporan.tanggal,
        'jam_patroli': laporan.jamPatroli,
        'pic_patroli': laporan.picPatroli,
        'waktu_dibuat': laporan.waktuDibuat,
        'loading_data': laporan.loading.toJson(),
        'discharge_data': laporan.discharge.toJson(),
        'penyaluran_data': laporan.penyaluran.toJson(),
        'storage_data': laporan.storage.toJson(),
      };

      final String reportId;
      if (laporan.remoteId != null) {
        // Laporan sudah pernah terupload (diedit, atau retry) -> update.
        reportId = laporan.remoteId!;
        await client.from('reports').update(data).eq('id', reportId);
        await client.from('report_photos').delete().eq('report_id', reportId);
      } else {
        final report = await client
            .from('reports')
            .insert({'user_id': uid, ...data})
            .select('id')
            .single();
        reportId = report['id'] as String;
        // Simpan segera: kalau upload FOTO gagal di tengah jalan, retry
        // berikutnya akan masuk jalur update di atas, bukan insert dobel.
        await DatabaseHelper.instance.updateRemoteId(laporan.id!, reportId);
      }

      final versi = DateTime.now().millisecondsSinceEpoch;
      for (final foto in laporan.fotos) {
        final file = File(foto.imagePath);
        if (!await file.exists()) continue;
        final path = '$uid/$reportId/${foto.kategori}.jpg';
        await client.storage
            .from('laporan-foto')
            .upload(path, file, fileOptions: const FileOptions(upsert: true));
        // ?v= supaya foto hasil "ambil ulang" tidak tertahan cache CDN.
        final url = '${client.storage.from('laporan-foto').getPublicUrl(path)}?v=$versi';

        await client.from('report_photos').insert({
          'report_id': reportId,
          'kategori': foto.kategori,
          'photo_url': url,
          'latitude': foto.latitude,
          'longitude': foto.longitude,
          'alamat': foto.alamat,
          'jam': foto.jam,
          'suhu': foto.suhu,
        });
      }

      await DatabaseHelper.instance.updateStatusUpload(laporan.id!, 'UPLOADED');
    } catch (e) {
      await DatabaseHelper.instance.updateStatusUpload(laporan.id!, 'FAILED');
      rethrow;
    }
  }
}
