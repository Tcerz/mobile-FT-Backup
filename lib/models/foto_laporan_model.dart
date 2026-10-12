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
  final String jam; // dd-MM-yyyy HH:mm:ss (jam dunia)
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
    required this.suhu,
  });

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
      suhu: suhu ?? this.suhu,
    );
  }
}
