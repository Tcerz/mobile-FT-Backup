import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config/supabase_config.dart';
import '../database/database_helper.dart';
import '../models/laporan_model.dart';
import '../models/zona_waktu.dart';
import 'auth_service.dart';

/// Pilihan nada alarm pengingat. [rawName] = nama file di
/// android/app/src/main/res/raw (tanpa ekstensi); null = nada alarm bawaan HP.
class NadaDering {
  final String kunci;
  final String nama;
  final String? rawName;
  const NadaDering(this.kunci, this.nama, this.rawName);
}

enum JenisNotif { pengingat, missed, belumUpload }

/// Dipanggil Android saat tombol "Matikan" ditekan. Notifikasi sudah
/// dibatalkan sistem (cancelNotification: true) sehingga suara alarm yang
/// berulang ikut berhenti; fungsi ini sengaja kosong tapi WAJIB ada.
@pragma('vm:entry-point')
void notifikasiBackgroundHandler(NotificationResponse response) {}

/// Notifikasi lokal Safety Patrol.
///
///  * 5 menit SEBELUM jam patroli  -> ALARM (nada bisa dipilih, berbunyi
///    berulang, bisa dimatikan manual, berhenti sendiri setelah 5 menit).
///  * 1 jam SETELAH jam patroli:
///      - Kondisi A, belum ada laporan sama sekali -> "Missed Safety Patrol"
///      - Kondisi B, laporan ada tapi belum terupload (termasuk draft/gagal
///        upload) -> "Kamu belum upload laporanmu"
///    Kedua kondisi punya SUARA yang berbeda.
///
/// Karena notifikasi terjadwal tidak bisa menjalankan kode Dart saat
/// berbunyi, jadwalnya dihitung ulang ([sinkronkanJadwal]) setiap kali ada
/// perubahan yang memengaruhi kondisi: simpan/edit/hapus/upload laporan,
/// ganti pengaturan, ganti zona waktu, dan saat app dibuka/dilanjutkan.
class NotifikasiPatrolService {
  NotifikasiPatrolService._();

  // ---------------- Pengaturan (SharedPreferences) ----------------
  static const _kAktif = 'notif_aktif';
  static const _kNada = 'notif_nada_alarm';
  static const _kSlot = 'notif_slot_diingatkan';

  static const List<NadaDering> daftarNada = [
    NadaDering('klasik', 'Alarm Klasik', 'alarm_klasik'),
    NadaDering('digital', 'Alarm Digital', 'alarm_digital'),
    NadaDering('lonceng', 'Lonceng', 'alarm_lonceng'),
    NadaDering('sistem', 'Nada alarm bawaan HP', null),
  ];

  static const int menitSebelum = 5; // alarm pengingat
  static const int jamSesudah = 1; // notif susulan
  static const int durasiAlarmMenit = 5; // auto-stop
  static const int _hariKeDepan = 3; // hari ini + 2 hari (≈ 72 notif maks)

  // Suara notif susulan -- diatur di KODE (bukan oleh user), seperti notif
  // Grab/bank: Missed = nada turun mendesak, Belum upload = dentingan naik.
  static const _rawMissed = 'notif_missed';
  static const _rawBelumUpload = 'notif_belum_upload';

  static const _chMissed = 'patrol_missed_v1';
  static const _chBelumUpload = 'patrol_belum_upload_v1';
  static String _chAlarm(NadaDering n) => 'patrol_alarm_v1_${n.kunci}';

  static const int _idTes = 1; // id notif uji coba; id jadwal selalu > 1000

  // ---------------- State ----------------
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _siap = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> get aktif async => (await SharedPreferences.getInstance()).getBool(_kAktif) ?? true;

  static Future<NadaDering> nadaTerpilih() async {
    final k = (await SharedPreferences.getInstance()).getString(_kNada);
    return daftarNada.firstWhere((n) => n.kunci == k, orElse: () => daftarNada.first);
  }

  static Future<Set<String>> slotDiingatkan() async {
    final l = (await SharedPreferences.getInstance()).getStringList(_kSlot);
    return (l ?? daftarJamPatroli).toSet();
  }

  static Future<void> setAktif(bool v) async {
    await (await SharedPreferences.getInstance()).setBool(_kAktif, v);
    await sinkronkanJadwal();
  }

  static Future<void> setNada(NadaDering n) async {
    await (await SharedPreferences.getInstance()).setString(_kNada, n.kunci);
    await sinkronkanJadwal();
  }

  static Future<void> setSlotDiingatkan(Set<String> slot) async {
    await (await SharedPreferences.getInstance()).setStringList(_kSlot, slot.toList());
    await sinkronkanJadwal();
  }

  // ---------------- Inisialisasi & izin ----------------
  static Future<void> init() async {
    if (_siap) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notifikasiBackgroundHandler,
    );
    _siap = true;

    // App dibuka lewat ketukan pada notifikasi -> pastikan alarm berhenti.
    final detail = await _plugin.getNotificationAppLaunchDetails();
    final id = detail?.notificationResponse?.id;
    if (detail?.didNotificationLaunchApp == true && id != null) {
      await _plugin.cancel(id);
    }
  }

  static void _onResponse(NotificationResponse r) {
    // Ketuk notifikasi atau tombol "Matikan" -> hentikan alarm yang berulang.
    final id = r.id;
    if (id != null) _plugin.cancel(id);
  }

  /// Meminta izin notifikasi (Android 13+) dan alarm tepat waktu (Android 12+).
  /// Return true kalau notifikasi diizinkan.
  static Future<bool> mintaIzin() async {
    await init();
    final a = _android;
    if (a == null) return false;
    final notif = await a.requestNotificationsPermission() ?? false;
    if (await a.canScheduleExactNotifications() != true) {
      await a.requestExactAlarmsPermission(); // membuka halaman pengaturan sistem
    }
    return notif;
  }

  static Future<bool> notifikasiDiizinkan() async {
    await init();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  static Future<bool> alarmTepatWaktuDiizinkan() async {
    await init();
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  // ---------------- Channel & detail notifikasi ----------------
  static AndroidNotificationSound _suara(NadaDering n) => n.rawName != null
      ? RawResourceAndroidNotificationSound(n.rawName!)
      : const UriAndroidNotificationSound('content://settings/system/alarm_alert');

  static AndroidNotificationDetails _detailAlarm(NadaDering n, {int? timeoutMs}) {
    return AndroidNotificationDetails(
      _chAlarm(n),
      'Alarm Safety Patrol (${n.nama})',
      channelDescription: 'Alarm pengingat 5 menit sebelum jam Safety Patrol',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm, // ikut volume ALARM, bukan notifikasi
      sound: _suara(n),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ongoing: false,
      // FLAG_INSISTENT (=4): suara diulang terus sampai notifikasi dibuang.
      additionalFlags: Int32List.fromList(<int>[4]),
      // Auto-stop: notifikasi dibuang sistem setelah 5 menit -> suara berhenti.
      timeoutAfter: timeoutMs ?? durasiAlarmMenit * 60 * 1000,
      actions: const [
        AndroidNotificationAction('matikan', 'Matikan Alarm', cancelNotification: true),
      ],
    );
  }

  static AndroidNotificationDetails _detailSusulan(JenisNotif jenis) {
    final missed = jenis == JenisNotif.missed;
    return AndroidNotificationDetails(
      missed ? _chMissed : _chBelumUpload,
      missed ? 'Missed Safety Patrol' : 'Laporan belum diupload',
      channelDescription: missed
          ? 'Pengingat saat laporan Safety Patrol belum dibuat'
          : 'Pengingat saat laporan Safety Patrol sudah ada tapi belum diupload',
      importance: Importance.max, // wajib tinggi agar muncul heads-up + BERSUARA
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(missed ? _rawMissed : _rawBelumUpload),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(missed ? [0, 500, 200, 500, 200, 500] : [0, 300, 150, 300]),
      visibility: NotificationVisibility.public,
      autoCancel: true,
    );
  }

  /// Channel Android tidak bisa diubah suaranya setelah dibuat, jadi tiap
  /// pilihan nada punya channel sendiri. Dibuat di awal supaya pasti ada.
  static Future<void> _buatChannel() async {
    final a = _android;
    if (a == null) return;
    for (final n in daftarNada) {
      await a.createNotificationChannel(AndroidNotificationChannel(
        _chAlarm(n),
        'Alarm Safety Patrol (${n.nama})',
        description: 'Alarm pengingat 5 menit sebelum jam Safety Patrol',
        importance: Importance.max,
        playSound: true,
        sound: _suara(n),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
    }
    for (final j in [JenisNotif.missed, JenisNotif.belumUpload]) {
      final d = _detailSusulan(j);
      await a.createNotificationChannel(AndroidNotificationChannel(
        d.channelId,
        d.channelName,
        description: d.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: d.sound,
        enableVibration: true,
      ));
    }
  }

  // ---------------- Uji coba (dari halaman Pengaturan) ----------------
  static Future<void> ujiAlarm(NadaDering n) async {
    await init();
    await _buatChannel();
    await _plugin.show(_idTes, 'Tes alarm Safety Patrol', 'Beginilah bunyi alarm "${n.nama}" (berhenti sendiri dalam 8 detik).',
        NotificationDetails(android: _detailAlarm(n, timeoutMs: 8000)));
  }

  static Future<void> ujiSusulan(JenisNotif jenis) async {
    await init();
    await _buatChannel();
    final missed = jenis == JenisNotif.missed;
    await _plugin.show(
      _idTes,
      missed ? 'Missed Safety Patrol jam 06:00' : 'Kamu belum upload laporanmu',
      missed ? 'Contoh notifikasi: laporan belum dibuat.' : 'Contoh notifikasi: laporan ada tapi belum terupload.',
      NotificationDetails(android: _detailSusulan(jenis)),
    );
  }

  // ---------------- Penjadwalan ----------------
  static bool _sedangSinkron = false;
  static bool _adaAntrian = false;
  // id -> (signature, waktu bunyi ms). Dipakai agar tiap sinkron hanya
  // menjadwal ulang yang BERUBAH (autosave draft bisa memicu sinkron sering).
  static final Map<int, (String, int)> _terjadwal = {};
  static bool _sudahBersihkanAwal = false;

  /// Hitung ulang & pasang jadwal. Aman dipanggil berulang/bersamaan.
  static Future<void> sinkronkanJadwal() async {
    if (_sedangSinkron) {
      _adaAntrian = true;
      return;
    }
    _sedangSinkron = true;
    try {
      do {
        _adaAntrian = false;
        try {
          await _sinkronInti();
        } catch (_) {
          // Notifikasi tidak boleh membuat aplikasi crash.
        }
      } while (_adaAntrian);
    } finally {
      _sedangSinkron = false;
    }
  }

  static Future<void> batalkanSemua() async {
    await init();
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id != _idTes) await _plugin.cancel(p.id);
    }
    _terjadwal.clear();
  }

  static Future<void> _sinkronInti() async {
    await init();

    final uid = SupabaseConfig.sudahDikonfigurasi ? AuthService.currentUser?.id : null;
    final prefs = await SharedPreferences.getInstance();
    if (uid == null || !(prefs.getBool(_kAktif) ?? true)) {
      await batalkanSemua();
      return;
    }

    await _buatChannel();

    // Proses baru: jadwal lama dari sesi sebelumnya belum dikenal -> bersihkan
    // semua lalu pasang ulang supaya tidak ada sisa yang kedaluwarsa.
    if (!_sudahBersihkanAwal) {
      await batalkanSemua();
      _sudahBersihkanAwal = true;
    }

    final nada = await nadaTerpilih();
    final slotAktif = await slotDiingatkan();
    final zona = ZonaWaktu.aktif;
    final bolehExact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = bolehExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

    // Status tiap slot: 2 = sudah UPLOADED, 1 = ada tapi belum upload, (kosong) = belum ada.
    final statusSlot = <int, int>{};
    for (final r in await DatabaseHelper.instance.getRingkasanPatroli(uid)) {
      final jam = (r['jam_patroli'] as String?) ?? '';
      if (jam.isEmpty) continue; // draft yang belum memilih jam
      final z = ZonaWaktu.dariLabel(r['zona'] as String?) ?? ZonaWaktu.wib;
      final instan = (r['patroli_utc'] != null ? DateTime.tryParse(r['patroli_utc'] as String)?.toUtc() : null) ??
          ZonaWaktu.parseLegacy('${r['tanggal']} $jam', z);
      if (instan == null) continue;
      final nilai = r['upload_status'] == 'UPLOADED' ? 2 : 1;
      final k = instan.millisecondsSinceEpoch;
      if ((statusSlot[k] ?? 0) < nilai) statusSlot[k] = nilai;
    }

    final nowUtc = DateTime.now().toUtc();
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final hariIni = zona.keLokal(nowUtc);

    // ---- Susun rencana ----
    final rencana = <int, _Rencana>{};
    for (int h = 0; h < _hariKeDepan; h++) {
      for (final jam in slotAktif) {
        final bagian = jam.split(':');
        final slot = zona.dariLokal(hariIni.year, hariIni.month, hariIni.day + h, int.parse(bagian[0]), int.parse(bagian[1]));
        final slotMs = slot.millisecondsSinceEpoch;
        final status = statusSlot[slotMs] ?? 0;
        final menitEpoch = slotMs ~/ 60000;
        final label = '$jam ${zona.label}';

        // 1) Alarm pengingat 5 menit sebelum.
        final msAlarm = slotMs - menitSebelum * 60000;
        if (msAlarm > nowMs + 2000 && status < 2) {
          rencana[menitEpoch * 2] = _Rencana(
            id: menitEpoch * 2,
            ms: msAlarm,
            jenis: JenisNotif.pengingat,
            judul: 'Safety Patrol $label',
            isi: '$menitSebelum menit lagi waktunya Safety Patrol jam $label. Siapkan laporanmu.',
            nada: nada,
          );
        }

        // 2) Notif susulan 1 jam setelah -- jenisnya tergantung kondisi SAAT INI.
        final msSusulan = slotMs + jamSesudah * 3600000;
        if (msSusulan > nowMs + 2000 && status < 2) {
          final missed = status == 0;
          rencana[menitEpoch * 2 + 1] = _Rencana(
            id: menitEpoch * 2 + 1,
            ms: msSusulan,
            jenis: missed ? JenisNotif.missed : JenisNotif.belumUpload,
            judul: missed ? 'Missed Safety Patrol jam $jam' : 'Kamu belum upload laporanmu',
            isi: missed
                ? 'Laporan Safety Patrol jam $label belum dibuat.'
                : 'Laporan Safety Patrol jam $label sudah ada tapi belum terupload. Buka aplikasi untuk mengunggah.',
            nada: nada,
          );
        }
      }
    }

    // ---- Terapkan selisihnya ----
    _terjadwal.removeWhere((_, v) => v.$2 <= nowMs); // yang sudah lewat
    for (final id in _terjadwal.keys.toList()) {
      if (!rencana.containsKey(id)) {
        await _plugin.cancel(id);
        _terjadwal.remove(id);
      }
    }
    for (final r in rencana.values) {
      final sig = '${r.ms}|${r.jenis.name}|${r.nada.kunci}|${r.judul}|${r.isi}|$bolehExact';
      if (_terjadwal[r.id]?.$1 == sig) continue;
      await _plugin.zonedSchedule(
        r.id,
        r.judul,
        r.isi,
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, r.ms),
        NotificationDetails(
          android: r.jenis == JenisNotif.pengingat ? _detailAlarm(r.nada) : _detailSusulan(r.jenis),
        ),
        androidScheduleMode: mode,
        payload: r.jenis.name,
      );
      _terjadwal[r.id] = (sig, r.ms);
    }
  }
}

class _Rencana {
  final int id;
  final int ms;
  final JenisNotif jenis;
  final String judul;
  final String isi;
  final NadaDering nada;
  _Rencana({
    required this.id,
    required this.ms,
    required this.jenis,
    required this.judul,
    required this.isi,
    required this.nada,
  });
}
