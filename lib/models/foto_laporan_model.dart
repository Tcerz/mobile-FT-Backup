import 'zona_waktu.dart';

/// Kategori foto yang WAJIB diisi (4 tetap) dalam satu laporan patroli.
class KategoriFoto {
  static const jetty = 'Jetty';
  static const fillingShed = 'Filling Shed';
  static const rumahPompa = 'Rumah Pompa';
  static const areaTangki = 'Area Tangki';

  static const List<String> semua = [jetty, fillingShed, rumahPompa, areaTangki];
}

class FotoLaporan {
  final int? id;
  final int? laporanId;
  final String kategori;
  final String imagePath;
  final double latitude;
  final double longitude;
  final String alamat;
  final String jam; // LEGACY: dd-MM-yyyy HH:mm:ss (jam dinding zona saat foto diambil)
  final DateTime? diambilUtc; // waktu foto diambil dalam UTC (sumber kebenaran)
  final String suhu; // contoh: "29.4°C"

  FotoLaporan({
    this.id,
    this.laporanId,
    required this.kategori,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.alamat,
    required this.jam,
    this.diambilUtc,
    required this.suhu,
  });

  DateTime? get _utcEfektif => diambilUtc ?? ZonaWaktu.parseLegacy(jam);

  /// Waktu foto untuk TAMPILAN, dikonversi ke zona user saat ini.
  String get jamTampil {
    final utc = _utcEfektif;
    return utc == null ? jam : ZonaWaktu.aktif.formatLengkap(utc);
  }

  String get jamTampilDenganZona => '$jamTampil ${ZonaWaktu.aktif.label}';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'laporan_id': laporanId,
      'kategori': kategori,
      'image_path': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'alamat': alamat,
      'jam': jam,
      'diambil_utc': diambilUtc?.toUtc().toIso8601String(),
      'suhu': suhu,
    };
  }

  factory FotoLaporan.fromMap(Map<String, dynamic> map) {
    return FotoLaporan(
      id: map['id'] as int?,
      laporanId: map['laporan_id'] as int?,
      kategori: map['kategori'] as String,
      imagePath: map['image_path'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      alamat: map['alamat'] as String,
      jam: map['jam'] as String,
      diambilUtc: map['diambil_utc'] == null ? null : DateTime.tryParse(map['diambil_utc'] as String)?.toUtc(),
      suhu: map['suhu'] as String,
    );
  }

  FotoLaporan copyWith({
    int? id,
    int? laporanId,
    String? imagePath,
    double? latitude,
    double? longitude,
    String? alamat,
    String? jam,
    DateTime? diambilUtc,
    String? suhu,
  }) {
    return FotoLaporan(
      id: id ?? this.id,
      laporanId: laporanId ?? this.laporanId,
      kategori: kategori,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      alamat: alamat ?? this.alamat,
      jam: jam ?? this.jam,
      diambilUtc: diambilUtc ?? this.diambilUtc,
      suhu: suhu ?? this.suhu,
    );
  }
}
