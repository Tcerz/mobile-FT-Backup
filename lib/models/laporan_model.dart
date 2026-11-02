import 'foto_laporan_model.dart';
import 'kegiatan_model.dart';
import 'zona_waktu.dart';

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
  // --- Field LEGACY berbentuk teks (jam dinding di zona saat laporan dibuat).
  // Tetap diisi supaya dashboard/server lama tidak rusak, tapi untuk
  // TAMPILAN pakai getter *Tampil di bawah (berbasis UTC + zona user).
  final String tanggal; // dd-MM-yyyy ('' tidak mungkin; draft diisi hari ini)
  final String jamPatroli; // HH:mm, '' kalau draft belum memilih jam
  final String picPatroli;
  final String waktuDibuat; // dd-MM-yyyy HH:mm:ss, '' kalau draft belum punya jam dunia

  // --- Sumber kebenaran waktu: UTC.
  final DateTime? patroliUtc; // jadwal patroli yang dipilih (null = draft belum pilih jam)
  final DateTime? dibuatUtc; // waktu laporan dibuat (jam dunia)
  final String zona; // label zona saat dibuat: WIB / WITA / WIT
  final LoadingDischargeData loading;
  final LoadingDischargeData discharge;
  final PenyaluranData penyaluran;
  final StorageData storage;
  final List<FotoLaporan> fotos;
  final String uploadStatus; // DRAFT / LOCAL / UPLOADING / UPLOADED / FAILED
  final String userId;       // UID akun Supabase pemilik laporan ini
  final String? remoteId;    // UUID di server, terisi setelah upload/sync

  Laporan({
    this.id,
    required this.namaPembuat,
    required this.tanggal,
    required this.jamPatroli,
    required this.picPatroli,
    required this.waktuDibuat,
    this.patroliUtc,
    this.dibuatUtc,
    this.zona = 'WIB',
    required this.loading,
    required this.discharge,
    required this.penyaluran,
    required this.storage,
    this.fotos = const [],
    this.uploadStatus = 'LOCAL',
    this.userId = '',
    this.remoteId,
  });

  bool get isDraft => uploadStatus == 'DRAFT';

  /// Instan jadwal patroli (UTC). Untuk data lama yang belum punya kolom UTC,
  /// dihitung dari teks tanggal+jam dengan asumsi WIB (satu-satunya zona
  /// yang didukung versi lama).
  DateTime? get patroliUtcEfektif {
    if (patroliUtc != null) return patroliUtc;
    if (jamPatroli.isEmpty) return null;
    return ZonaWaktu.parseLegacy('$tanggal $jamPatroli', ZonaWaktu.dariLabel(zona) ?? ZonaWaktu.wib);
  }

  DateTime? get dibuatUtcEfektif =>
      dibuatUtc ?? ZonaWaktu.parseLegacy(waktuDibuat, ZonaWaktu.dariLabel(zona) ?? ZonaWaktu.wib);

  // --- Getter TAMPILAN: selalu dikonversi ke zona user saat ini.
  String get tanggalTampil {
    final u = patroliUtcEfektif;
    return u == null ? tanggal : ZonaWaktu.aktif.formatTanggal(u);
  }

  String get jamPatroliTampil {
    final u = patroliUtcEfektif;
    return u == null ? '-' : ZonaWaktu.aktif.formatJam(u);
  }

  /// Contoh: "06:00 WITA" (atau "Belum dipilih" untuk draft tanpa jam).
  String get jamPatroliLabel {
    final u = patroliUtcEfektif;
    return u == null ? 'Belum dipilih' : '${ZonaWaktu.aktif.formatJam(u)} ${ZonaWaktu.aktif.label}';
  }

  String get waktuDibuatTampil {
    final u = dibuatUtcEfektif;
    return u == null ? (waktuDibuat.isEmpty ? '-' : waktuDibuat) : '${ZonaWaktu.aktif.formatLengkap(u)} ${ZonaWaktu.aktif.label}';
  }

  Laporan copyWith({String? userId, String? remoteId, String? uploadStatus, List<FotoLaporan>? fotos, String? tanggal}) {
    return Laporan(
      id: id,
      namaPembuat: namaPembuat,
      tanggal: tanggal ?? this.tanggal,
      jamPatroli: jamPatroli,
      picPatroli: picPatroli,
      waktuDibuat: waktuDibuat,
      patroliUtc: patroliUtc,
      dibuatUtc: dibuatUtc,
      zona: zona,
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
      'patroli_utc': patroliUtc?.toUtc().toIso8601String(),
      'dibuat_utc': dibuatUtc?.toUtc().toIso8601String(),
      'zona': zona,
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
      patroliUtc: _parseUtc(map['patroli_utc']),
      dibuatUtc: _parseUtc(map['dibuat_utc']),
      zona: map['zona'] as String? ?? 'WIB',
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

  static DateTime? _parseUtc(Object? v) => v == null ? null : DateTime.tryParse(v as String)?.toUtc();
}
