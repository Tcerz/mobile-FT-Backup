import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/foto_laporan_model.dart';
import '../models/laporan_model.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'laporan_patroli.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE laporan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama_pembuat TEXT NOT NULL,
            tanggal TEXT NOT NULL,
            jam_patroli TEXT NOT NULL,
            pic_patroli TEXT NOT NULL,
            waktu_dibuat TEXT NOT NULL,
            loading_data TEXT NOT NULL,
            discharge_data TEXT NOT NULL,
            penyaluran_data TEXT NOT NULL,
            storage_data TEXT NOT NULL,
            upload_status TEXT NOT NULL DEFAULT 'LOCAL',
            user_id TEXT NOT NULL DEFAULT '',
            remote_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE foto_laporan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            laporan_id INTEGER NOT NULL,
            kategori TEXT NOT NULL,
            image_path TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            alamat TEXT NOT NULL,
            jam TEXT NOT NULL,
            suhu TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE laporan ADD COLUMN upload_status TEXT NOT NULL DEFAULT 'LOCAL'");
        }
        if (oldVersion < 3) {
          // Sebelum versi ini, SEMUA laporan lokal tercampur satu device
          // tanpa pemilik. Kolom ini ditambah dengan default kosong ('')
          // dulu -- baris lama akan "diadopsi" oleh user yang login
          // pertama kali setelah update (lihat adopsiLaporanLama).
          await db.execute("ALTER TABLE laporan ADD COLUMN user_id TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE laporan ADD COLUMN remote_id TEXT");
        }
      },
    );
  }

  /// Menyimpan 1 laporan header + 4 foto sekaligus dalam satu transaksi.
  Future<int> insertLaporan(Laporan laporan, List<FotoLaporan> fotos) async {
    final db = await database;
    late int laporanId;
    await db.transaction((txn) async {
      laporanId = await txn.insert('laporan', laporan.toMap());
      for (final foto in fotos) {
        final map = foto.copyWith(laporanId: laporanId).toMap();
        map.remove('id');
        await txn.insert('foto_laporan', map);
      }
    });
    return laporanId;
  }

  /// Mengambil daftar laporan MILIK USER INI SAJA untuk history home. Foto
  /// ikut dimuat (query terpisah, digabung di Dart) supaya bisa menampilkan
  /// status kelengkapan (mis. "2/4 foto") tanpa perlu N query per laporan.
  Future<List<Laporan>> getAllLaporanHeader(String userId) async {
    final db = await database;
    final laporanRows = await db.query('laporan', where: 'user_id = ?', whereArgs: [userId], orderBy: 'id DESC');
    final ids = laporanRows.map((e) => e['id'] as int).toList();
    if (ids.isEmpty) return [];

    final placeholder = List.filled(ids.length, '?').join(',');
    final fotoRows = await db.query('foto_laporan', where: 'laporan_id IN ($placeholder)', whereArgs: ids, orderBy: 'id ASC');

    final Map<int, List<FotoLaporan>> fotoPerLaporan = {};
    for (final row in fotoRows) {
      final foto = FotoLaporan.fromMap(row);
      fotoPerLaporan.putIfAbsent(foto.laporanId!, () => []).add(foto);
    }

    return laporanRows.map((e) {
      final id = e['id'] as int;
      return Laporan.fromMap(e, fotos: fotoPerLaporan[id] ?? []);
    }).toList();
  }

  /// Mengambil satu laporan lengkap dengan 4 fotonya (untuk halaman folder).
  /// Ikut memfilter user_id supaya satu akun tidak bisa membuka detail
  /// laporan milik akun lain di device yang sama.
  Future<Laporan?> getLaporanDetail(int id, String userId) async {
    final db = await database;
    final rows = await db.query('laporan', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
    if (rows.isEmpty) return null;

    final fotoRows = await db.query(
      'foto_laporan',
      where: 'laporan_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    final fotos = fotoRows.map((e) => FotoLaporan.fromMap(e)).toList();

    return Laporan.fromMap(rows.first, fotos: fotos);
  }

  /// Memperbarui status upload satu laporan: LOCAL / UPLOADING / UPLOADED / FAILED.
  Future<void> updateStatusUpload(int id, String status) async {
    final db = await database;
    await db.update('laporan', {'upload_status': status}, where: 'id = ?', whereArgs: [id]);
  }

  /// Dipanggil setelah upload sukses -- menyimpan UUID dari server supaya
  /// nanti tidak diunduh dobel saat sinkronisasi dari device lain.
  Future<void> updateRemoteId(int id, String remoteId) async {
    final db = await database;
    await db.update('laporan', {'remote_id': remoteId}, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> remoteIdSudahAda(String remoteId) async {
    final db = await database;
    final rows = await db.query('laporan', where: 'remote_id = ?', whereArgs: [remoteId], limit: 1);
    return rows.isNotEmpty;
  }

  /// SEKALI PAKAI per device: laporan lokal lama (dari sebelum sistem akun
  /// multi-user ada) tidak punya pemilik (user_id kosong). Baris tanpa
  /// pemilik ini "diadopsi" oleh akun pertama yang login setelah update,
  /// supaya datanya tidak hilang/tersembunyi. Aman dipanggil berkali-kali --
  /// setelah baris pertama diadopsi, tidak akan ada lagi user_id kosong.
  Future<void> adopsiLaporanLama(String userId) async {
    final db = await database;
    await db.update('laporan', {'user_id': userId}, where: "user_id = ''");
  }

  Future<void> deleteLaporan(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('foto_laporan', where: 'laporan_id = ?', whereArgs: [id]);
      await txn.delete('laporan', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Memperbarui laporan yang sudah ada: update kolom header, lalu ganti
  /// seluruh baris foto_laporan dengan set foto yang baru (dipakai saat
  /// user mengedit laporan, mis. mengisi data tangki yang lokasinya
  /// baru sempat dikunjungi belakangan).
  Future<void> updateLaporan(Laporan laporan, List<FotoLaporan> fotos) async {
    final db = await database;
    await db.transaction((txn) async {
      final map = laporan.toMap();
      // user_id & remote_id sengaja TIDAK ikut diupdate lewat edit biasa --
      // kepemilikan dan status sinkron cuma boleh berubah lewat proses
      // upload/sync, bukan tertimpa objek Laporan baru yang field ini
      // defaultnya kosong.
      map.remove('id');
      map.remove('user_id');
      map.remove('remote_id');
      await txn.update('laporan', map, where: 'id = ?', whereArgs: [laporan.id]);

      await txn.delete('foto_laporan', where: 'laporan_id = ?', whereArgs: [laporan.id]);
      for (final foto in fotos) {
        final fotoMap = foto.copyWith(laporanId: laporan.id).toMap();
        fotoMap.remove('id');
        await txn.insert('foto_laporan', fotoMap);
      }
    });
  }
}
