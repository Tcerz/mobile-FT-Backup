import 'foto_laporan_model.dart';
import 'kegiatan_model.dart';

/// Daftar jam patroli tetap setiap 2 jam.
const List<String> daftarJamPatroli = [
  '00:00', '02:00', '04:00', '06:00', '08:00', '10:00',
  '12:00', '14:00', '16:00', '18:00', '20:00', '22:00',
];

/// Laporan = "folder" yang berisi header (tanggal, jam, PIC) + 4 kegiatan
/// (Loading, Discharge, Penyaluran, Storage) + daftar 4 foto (dimuat terpisah).
class Laporan {
  final int? id;
  final String namaPembuat;
  final String tanggal; // dd-MM-yyyy
  final String jamPatroli; // salah satu dari daftarJamPatroli
  final String picPatroli;
  final String waktuDibuat; // timestamp lengkap saat disimpan (jam dunia)
  final LoadingDischargeData loading;
  final LoadingDischargeData discharge;
  final PenyaluranData penyaluran;
  final StorageData storage;
  final List<FotoLaporan> fotos;
  final String uploadStatus; // LOCAL / UPLOADING / UPLOADED / FAILED
  final String userId;       // UID akun Supabase pemilik laporan ini
  final String? remoteId;    // UUID di server, terisi setelah upload/sync

  Laporan({
    this.id,
    required this.namaPembuat,
    required this.tanggal,
    required this.jamPatroli,
    required this.picPatroli,
    required this.waktuDibuat,
    required this.loading,
    required this.discharge,
    required this.penyaluran,
    required this.storage,
    this.fotos = const [],
    this.uploadStatus = 'LOCAL',
    this.userId = '',
    this.remoteId,
  });

  Laporan copyWith({String? userId, String? remoteId, String? uploadStatus, List<FotoLaporan>? fotos, String? tanggal}) {
    return Laporan(
      id: id,
      namaPembuat: namaPembuat,
      tanggal: tanggal ?? this.tanggal,
      jamPatroli: jamPatroli,
      picPatroli: picPatroli,
      waktuDibuat: waktuDibuat,
      loading: loading,
      discharge: discharge,
      penyaluran: penyaluran,
      storage: storage,
      fotos: fotos ?? this.fotos,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      userId: userId ?? this.userId,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_pembuat': namaPembuat,
      'tanggal': tanggal,
      'jam_patroli': jamPatroli,
      'pic_patroli': picPatroli,
      'waktu_dibuat': waktuDibuat,
      'loading_data': loading.toJson(),
      'discharge_data': discharge.toJson(),
      'penyaluran_data': penyaluran.toJson(),
      'storage_data': storage.toJson(),
      'upload_status': uploadStatus,
      'user_id': userId,
      'remote_id': remoteId,
    };
  }

  factory Laporan.fromMap(Map<String, dynamic> map, {List<FotoLaporan> fotos = const []}) {
    return Laporan(
      id: map['id'] as int?,
      namaPembuat: map['nama_pembuat'] as String,
      tanggal: map['tanggal'] as String,
      jamPatroli: map['jam_patroli'] as String,
      picPatroli: map['pic_patroli'] as String,
      waktuDibuat: map['waktu_dibuat'] as String,
      loading: LoadingDischargeData.fromJson(map['loading_data'] as String? ?? ''),
      discharge: LoadingDischargeData.fromJson(map['discharge_data'] as String? ?? ''),
      penyaluran: PenyaluranData.fromJson(map['penyaluran_data'] as String? ?? ''),
      storage: StorageData.fromJson(map['storage_data'] as String? ?? ''),
      fotos: fotos,
      uploadStatus: map['upload_status'] as String? ?? 'LOCAL',
      userId: map['user_id'] as String? ?? '',
      remoteId: map['remote_id'] as String?,
    );
  }
}
