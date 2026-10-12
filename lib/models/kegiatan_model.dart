import 'dart:convert';

const List<String> daftarTangki = [
  'T.01', 'T.02', 'T.03', 'T.04', 'T.05', 'T.06', 'T.07', 'T.08',
  'T.09', 'T.10', 'T.11', 'T.12', 'T.13', 'T.14', 'T.15', 'T.16',
];

const String kondisiAman = 'Aman';
const String kondisiTidakAman = 'Tidak Aman';

/// Pilihan jenis produk untuk tangki yang berstatus Aktif.
const List<String> daftarProdukTangki = [
  'Pertamax Turbo', 'Pertamax 92', 'Pertalite', 'Solar', 'Fame',
];

/// Batas maksimal foto pendukung yang boleh dilampirkan di satu textfield Note.
const int maksimalFotoNote = 3;

List<String> _daftarString(dynamic v) =>
    v == null ? <String>[] : List<String>.from(v as List);

Map<String, String> _petaString(dynamic v) =>
    v == null ? <String, String>{} : Map<String, String>.from(v as Map);

/// Bentuk data untuk kegiatan "Loading" & "Discharge" (strukturnya sama).
class LoadingDischargeData {
  final String personel;
  final String jetty1;
  final String jetty2;
  final String produk;
  final String kondisi;
  final String note;
  final List<String> noteFotos;

  LoadingDischargeData({
    this.personel = '',
    this.jetty1 = '',
    this.jetty2 = '',
    this.produk = '',
    this.kondisi = kondisiAman,
    this.note = '',
    this.noteFotos = const [],
  });

  LoadingDischargeData copyWith({
    String? personel,
    String? jetty1,
    String? jetty2,
    String? produk,
    String? kondisi,
    String? note,
    List<String>? noteFotos,
  }) {
    return LoadingDischargeData(
      personel: personel ?? this.personel,
      jetty1: jetty1 ?? this.jetty1,
      jetty2: jetty2 ?? this.jetty2,
      produk: produk ?? this.produk,
      kondisi: kondisi ?? this.kondisi,
      note: note ?? this.note,
      noteFotos: noteFotos ?? this.noteFotos,
    );
  }

  Map<String, dynamic> toMap() => {
        'personel': personel,
        'jetty1': jetty1,
        'jetty2': jetty2,
        'produk': produk,
        'kondisi': kondisi,
        'note': note,
        'noteFotos': noteFotos,
      };

  factory LoadingDischargeData.fromMap(Map<String, dynamic> map) {
    return LoadingDischargeData(
      personel: map['personel'] ?? '',
      jetty1: map['jetty1'] ?? '',
      jetty2: map['jetty2'] ?? '',
      produk: map['produk'] ?? '',
      kondisi: map['kondisi'] ?? kondisiAman,
      note: map['note'] ?? '',
      noteFotos: _daftarString(map['noteFotos']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LoadingDischargeData.fromJson(String json) {
    if (json.isEmpty) return LoadingDischargeData();
    return LoadingDischargeData.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}

/// Bentuk data untuk kegiatan "Penyaluran".
class PenyaluranData {
  final String personel;
  final String startJam;
  final String selesaiJam;
  final String kondisi;
  final String note;
  final List<String> noteFotos;

  PenyaluranData({
    this.personel = '',
    this.startJam = '',
    this.selesaiJam = '',
    this.kondisi = kondisiAman,
    this.note = '',
    this.noteFotos = const [],
  });

  PenyaluranData copyWith({
    String? personel,
    String? startJam,
    String? selesaiJam,
    String? kondisi,
    String? note,
    List<String>? noteFotos,
  }) {
    return PenyaluranData(
      personel: personel ?? this.personel,
      startJam: startJam ?? this.startJam,
      selesaiJam: selesaiJam ?? this.selesaiJam,
      kondisi: kondisi ?? this.kondisi,
      note: note ?? this.note,
      noteFotos: noteFotos ?? this.noteFotos,
    );
  }

  Map<String, dynamic> toMap() => {
        'personel': personel,
        'startJam': startJam,
        'selesaiJam': selesaiJam,
        'kondisi': kondisi,
        'note': note,
        'noteFotos': noteFotos,
      };

  factory PenyaluranData.fromMap(Map<String, dynamic> map) {
    return PenyaluranData(
      personel: map['personel'] ?? '',
      startJam: map['startJam'] ?? '',
      selesaiJam: map['selesaiJam'] ?? '',
      kondisi: map['kondisi'] ?? kondisiAman,
      note: map['note'] ?? '',
      noteFotos: _daftarString(map['noteFotos']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PenyaluranData.fromJson(String json) {
    if (json.isEmpty) return PenyaluranData();
    return PenyaluranData.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}

/// Bentuk data untuk kegiatan "Storage" (Penimbunan), dengan 5 daftar tangki.
class StorageData {
  final String personel;
  final List<String> tangkiLoading;
  final List<String> tangkiDischarge;
  final List<String> tangkiPenyaluran;
  final List<String> tangkiAktifIdle;
  final Map<String, String> jenisProdukAktif; // kode tangki -> jenis produk (khusus tangki Aktif)
  final List<String> tangkiOff;
  final String kondisi;
  final String note;
  final List<String> noteFotos;

  StorageData({
    this.personel = '',
    this.tangkiLoading = const [],
    this.tangkiDischarge = const [],
    this.tangkiPenyaluran = const [],
    this.tangkiAktifIdle = const [],
    this.jenisProdukAktif = const {},
    this.tangkiOff = const [],
    this.kondisi = kondisiAman,
    this.note = '',
    this.noteFotos = const [],
  });

  StorageData copyWith({
    String? personel,
    List<String>? tangkiLoading,
    List<String>? tangkiDischarge,
    List<String>? tangkiPenyaluran,
    List<String>? tangkiAktifIdle,
    Map<String, String>? jenisProdukAktif,
    List<String>? tangkiOff,
    String? kondisi,
    String? note,
    List<String>? noteFotos,
  }) {
    return StorageData(
      personel: personel ?? this.personel,
      tangkiLoading: tangkiLoading ?? this.tangkiLoading,
      tangkiDischarge: tangkiDischarge ?? this.tangkiDischarge,
      tangkiPenyaluran: tangkiPenyaluran ?? this.tangkiPenyaluran,
      tangkiAktifIdle: tangkiAktifIdle ?? this.tangkiAktifIdle,
      jenisProdukAktif: jenisProdukAktif ?? this.jenisProdukAktif,
      tangkiOff: tangkiOff ?? this.tangkiOff,
      kondisi: kondisi ?? this.kondisi,
      note: note ?? this.note,
      noteFotos: noteFotos ?? this.noteFotos,
    );
  }

  Map<String, dynamic> toMap() => {
        'personel': personel,
        'tangkiLoading': tangkiLoading,
        'tangkiDischarge': tangkiDischarge,
        'tangkiPenyaluran': tangkiPenyaluran,
        'tangkiAktifIdle': tangkiAktifIdle,
        'jenisProdukAktif': jenisProdukAktif,
        'tangkiOff': tangkiOff,
        'kondisi': kondisi,
        'note': note,
        'noteFotos': noteFotos,
      };

  factory StorageData.fromMap(Map<String, dynamic> map) {
    return StorageData(
      personel: map['personel'] ?? '',
      tangkiLoading: _daftarString(map['tangkiLoading']),
      tangkiDischarge: _daftarString(map['tangkiDischarge']),
      tangkiPenyaluran: _daftarString(map['tangkiPenyaluran']),
      tangkiAktifIdle: _daftarString(map['tangkiAktifIdle']),
      jenisProdukAktif: _petaString(map['jenisProdukAktif']),
      tangkiOff: _daftarString(map['tangkiOff']),
      kondisi: map['kondisi'] ?? kondisiAman,
      note: map['note'] ?? '',
      noteFotos: _daftarString(map['noteFotos']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory StorageData.fromJson(String json) {
    if (json.isEmpty) return StorageData();
    return StorageData.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
