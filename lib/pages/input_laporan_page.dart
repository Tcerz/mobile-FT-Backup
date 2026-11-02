import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/foto_laporan_model.dart';
import '../models/kegiatan_model.dart';
import '../models/laporan_model.dart';
import '../models/zona_waktu.dart';
import '../providers/laporan_provider.dart';
import '../providers/profil_provider.dart';
import '../providers/zona_waktu_provider.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import '../services/time_service.dart';
import '../services/weather_service.dart';
import '../widgets/foto_slot_card.dart';
import '../widgets/jam_dunia_baris.dart';
import '../widgets/loading_discharge_form.dart';
import '../widgets/penyaluran_form.dart';
import '../widgets/storage_form.dart';

class InputLaporanPage extends StatefulWidget {
  /// Kalau null -> mode BUAT laporan baru.
  /// Kalau diisi -> mode EDIT laporan yang sudah ada (id ini dimuat dulu).
  final int? laporanId;

  /// Kalau diisi (dan [laporanId] null) -> mode DUPLIKAT: membuat laporan
  /// BARU dengan PIC & seluruh data 4 kegiatan disalin dari laporan ini,
  /// tapi Jam Patroli & foto dikosongkan (wajib diisi/diambil ulang).
  final int? duplikatDariId;

  const InputLaporanPage({super.key, this.laporanId, this.duplikatDariId});

  bool get modeEdit => laporanId != null;
  bool get modeDuplikat => laporanId == null && duplikatDariId != null;

  @override
  State<InputLaporanPage> createState() => _InputLaporanPageState();
}

const _judulLangkah = [
  'Info & Foto',
  '1. Loading',
  '2. Discharge',
  '3. Penyaluran',
  '4. Storage (Penimbunan)',
];

/// PIC Patroli terdiri dari 2 peran (Loading Master & HSSE), tapi tetap
/// disimpan sebagai 1 kolom teks (picPatroli) supaya tidak perlu ubah skema
/// database/Supabase/PDF yang sudah berjalan. Fungsi ini yang menggabung &
/// memisahkannya lagi saat ditampilkan.
String _gabungPic(String lm, String hsse) =>
    'LM: ${lm.trim()} | HSSE: ${hsse.trim()}';

/// Untuk DRAFT: kalau kedua PIC masih kosong, simpan string kosong (bukan "LM:  | HSSE: ").
String _gabungPicDraft(String lm, String hsse) =>
    (lm.trim().isEmpty && hsse.trim().isEmpty) ? '' : _gabungPic(lm, hsse);

final _polaPic = RegExp(r'^LM:\s*(.*?)\s*\|\s*HSSE:\s*(.*)$');
(String, String) _pisahPic(String gabungan) {
  final match = _polaPic.firstMatch(gabungan);
  if (match != null) return (match.group(1) ?? '', match.group(2) ?? '');
  return (gabungan, ''); // data lama (sebelum fitur ini) -> taruh di LM saja
}

class _InputLaporanPageState extends State<InputLaporanPage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _halaman = 0;

  DateTime? _tanggal;
  String? _jamPatroli;
  final TextEditingController _picLmController = TextEditingController();
  final TextEditingController _picHsseController = TextEditingController();

  Duration? _offsetJamDunia;
  bool _loadingJamDunia = true;
  String? _errorJamDunia;

  final Map<String, FotoLaporan?> _fotoMap = {
    for (final k in KategoriFoto.semua) k: null,
  };
  final Map<String, bool> _loadingFotoMap = {
    for (final k in KategoriFoto.semua) k: false,
  };

  LoadingDischargeData _loading = LoadingDischargeData();
  LoadingDischargeData _discharge = LoadingDischargeData();
  PenyaluranData _penyaluran = PenyaluranData();
  StorageData _storage = StorageData();

  bool _menyimpan = false;
  bool _loadingAwal = false;

  // Waktu dibuat laporan (UTC) -- ditetapkan sekali (saat pertama kali ada
  // jam dunia) dan TIDAK berubah walau laporan diedit.
  DateTime? _dibuatUtcAsli;
  String? _waktuDibuatTeksAsli; // teks legacy (jam dinding zona asal)
  String _zonaAsal = ZonaWaktu.aktif.label;

  // --- Auto-save (draft) ---
  // id baris laporan di SQLite. Terisi saat mode edit, atau setelah draft
  // pertama tersimpan -- selanjutnya semua simpan memakai id ini (UPDATE).
  int? _idLokal;
  bool _draftAwal = false; // laporan yang dibuka memang sudah berstatus draft
  bool _siapAutosave = false; // false selama data awal masih dimuat
  bool _adaPerubahan = false;
  bool _sedangSimpanDraft = false;
  bool _draftUlang = false;
  bool _sudahFinal = false; // setelah "Simpan & Upload" -> auto-save berhenti
  Timer? _autosaveTimer;
  // Diambil sekali di initState supaya auto-save tetap bisa jalan saat
  // halaman sedang ditutup (context sudah tidak aman dipakai saat itu).
  late final LaporanProvider _laporanProvider;
  late final String _namaPembuat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laporanProvider = context.read<LaporanProvider>();
    _namaPembuat = context.read<ProfilProvider>().nama;
    _idLokal = widget.laporanId;
    _ambilJamDunia();

    if (widget.modeEdit) {
      _muatLaporanUntukEdit();
    } else if (widget.modeDuplikat) {
      _muatLaporanUntukDuplikat();
    } else {
      _tanggal = _hariIniDiZona();
      _siapAutosave = true;
    }
  }

  /// Tanggal "hari ini" menurut zona user (bukan zona perangkat).
  DateTime _hariIniDiZona() {
    final l = ZonaWaktu.aktif.keLokal(DateTime.now().toUtc());
    return DateTime(l.year, l.month, l.day);
  }

  Future<void> _muatLaporanUntukEdit() async {
    setState(() => _loadingAwal = true);
    final detail = await context.read<LaporanProvider>().fetchDetail(
      widget.laporanId!,
    );
    if (detail == null) {
      if (mounted) setState(() => _loadingAwal = false);
      return;
    }
    setState(() {
      // Jadwal patroli tersimpan sebagai UTC -> ditampilkan di zona user sekarang.
      final patroli = detail.patroliUtcEfektif;
      if (patroli != null) {
        final l = ZonaWaktu.aktif.keLokal(patroli);
        _tanggal = DateTime(l.year, l.month, l.day);
        _jamPatroli = ZonaWaktu.aktif.formatJam(patroli);
      } else {
        // Draft yang belum memilih jam patroli.
        _tanggal = _parseTanggalLegacy(detail.tanggal) ?? _hariIniDiZona();
        _jamPatroli = null;
      }
      final (lm, hsse) = _pisahPic(detail.picPatroli);
      _picLmController.text = lm;
      _picHsseController.text = hsse;
      _dibuatUtcAsli = detail.dibuatUtcEfektif;
      _waktuDibuatTeksAsli = detail.waktuDibuat.isEmpty ? null : detail.waktuDibuat;
      _zonaAsal = detail.zona;
      _draftAwal = detail.isDraft;
      _loading = detail.loading;
      _discharge = detail.discharge;
      _penyaluran = detail.penyaluran;
      _storage = detail.storage;
      for (final foto in detail.fotos) {
        _fotoMap[foto.kategori] = foto;
      }
      _loadingAwal = false;
      _siapAutosave = true;
    });
  }

  DateTime? _parseTanggalLegacy(String t) {
    try {
      return DateFormat('dd-MM-yyyy').parse(t);
    } catch (_) {
      return null;
    }
  }

  Future<void> _muatLaporanUntukDuplikat() async {
    setState(() => _loadingAwal = true);
    final sumber = await context.read<LaporanProvider>().fetchDetail(
      widget.duplikatDariId!,
    );
    if (sumber == null) {
      if (mounted) setState(() => _loadingAwal = false);
      return;
    }
    setState(() {
      final patroli = sumber.patroliUtcEfektif;
      if (patroli != null) {
        final l = ZonaWaktu.aktif.keLokal(patroli);
        _tanggal = DateTime(l.year, l.month, l.day);
      } else {
        _tanggal = _hariIniDiZona();
      }
      _jamPatroli = null;
      final (lm, hsse) = _pisahPic(sumber.picPatroli);
      _picLmController.text = lm;
      _picHsseController.text = hsse;
      _loading = sumber.loading;
      _discharge = sumber.discharge;
      _penyaluran = sumber.penyaluran;
      _storage = sumber.storage;
      // Foto SENGAJA tidak disalin: petugas wajib mengambil ulang keempat
      // foto (lokasi, jam, suhu harus sesuai patroli yang baru).
      _loadingAwal = false;
      _siapAutosave = true;
    });
  }

  /// App ke background / ditutup (termasuk tidak sengaja) -> simpan draft SEKARANG.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _autosaveTimer?.cancel();
      _simpanDraft();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _simpanDraft(); // halaman ditutup (mis. tombol back) -> flush perubahan terakhir
    _picLmController.dispose();
    _picHsseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _ambilJamDunia() async {
    setState(() {
      _loadingJamDunia = true;
      _errorJamDunia = null;
    });
    try {
      final utcDunia = await TimeService.getCurrentUtc();
      setState(() => _offsetJamDunia = utcDunia.difference(DateTime.now().toUtc()));
    } catch (e) {
      setState(
        () => _errorJamDunia =
            'Gagal mengambil jam dunia. Periksa koneksi internet.',
      );
    } finally {
      if (mounted) setState(() => _loadingJamDunia = false);
    }
  }

  /// Waktu SEKARANG dalam UTC menurut jam dunia (bukan jam HP).
  DateTime _sekarangUtc() => DateTime.now().toUtc().add(_offsetJamDunia ?? Duration.zero);

  void _tampilkanPesan(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _ambilFotoUntukKategori(String kategori) async {
    final boleh = await PermissionService.pastikanIzinKameraLokasi(context);
    if (!boleh) {
      _tampilkanPesan('Izin kamera & lokasi diperlukan untuk mengambil foto');
      return;
    }
    setState(() => _loadingFotoMap[kategori] = true);
    try {
      final file = await ImageService.ambilFotoDenganKamera(context);
      if (file == null) return;

      final pos = await LocationService.getCurrentLocation();
      // GPS saat ini paling baru -> sekalian segarkan zona waktu (mis. petugas
      // sudah pindah dari WIB ke WITA) SEBELUM jam foto diformat.
      if (mounted) {
        await context.read<ZonaWaktuProvider>().perbaruiDariKoordinat(pos.latitude, pos.longitude);
      }
      final alamat = await LocationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final suhu = await WeatherService.getSuhuSaatIni(
        pos.latitude,
        pos.longitude,
      );
      final sekarangUtc = _sekarangUtc();
      final jamStr = ZonaWaktu.aktif.formatLengkap(sekarangUtc);

      final foto = FotoLaporan(
        kategori: kategori,
        imagePath: file.path,
        latitude: pos.latitude,
        longitude: pos.longitude,
        alamat: alamat,
        jam: jamStr,
        diambilUtc: sekarangUtc,
        suhu: suhu,
      );
      setState(() => _fotoMap[kategori] = foto);
      _tandaiBerubah();
    } catch (e) {
      _tampilkanPesan('Gagal mengambil foto $kategori: $e');
    } finally {
      if (mounted) setState(() => _loadingFotoMap[kategori] = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? _hariIniDiZona(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (result != null) {
      setState(() => _tanggal = result);
      _tandaiBerubah();
    }
  }

  void _kePage(int target) {
    setState(() => _halaman = target);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _simpanLaporan() async {
    final namaPembuat = _namaPembuat;
    _autosaveTimer?.cancel();

    if (namaPembuat.trim().isEmpty) {
      _tampilkanPesan('Gagal memuat data akun, silakan login ulang');
      return;
    }
    if (_tanggal == null ||
        _jamPatroli == null ||
        (_picLmController.text.trim().isEmpty &&
            _picHsseController.text.trim().isEmpty)) {
      _kePage(0);
      _tampilkanPesan(
        'Lengkapi dulu Tanggal, Jam Patroli, dan minimal salah satu PIC (LM/HSSE) di langkah "Info & Foto"',
      );
      return;
    }
    if (_dibuatUtcAsli == null && _offsetJamDunia == null) {
      _kePage(0);
      _tampilkanPesan(
        'Jam dunia belum berhasil diambil. Tekan ikon refresh jam dahulu.',
      );
      return;
    }
    final belumLengkap = _fotoMap.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();
    if (belumLengkap.isNotEmpty) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Foto Belum Lengkap'),
          content: Text(
            'Foto berikut belum diambil: ${belumLengkap.join(', ')}.\n\n'
            'Laporan tetap bisa disimpan sekarang, lalu Anda bisa membuka '
            'lagi laporan ini lewat tombol Edit setelah berpindah ke lokasi '
            'lainnya untuk melengkapi sisa foto.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan Sekarang'),
            ),
          ],
        ),
      );
      if (lanjut != true) return;
    }

    setState(() => _menyimpan = true);
    // Tunggu auto-save yang sedang berjalan selesai supaya tidak saling menimpa.
    while (_sedangSimpanDraft) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _sudahFinal = true; // mulai sekarang auto-save dimatikan

    final laporan = _bangunLaporan(draft: false);
    final fotos = _daftarFoto();

    // Simpan lokal dulu (selalu berhasil), baru upload otomatis. Kalau
    // upload gagal (mis. tidak ada sinyal), laporan tetap aman di HP dan
    // di-upload ulang otomatis saat login berikutnya / lewat tombol di card.
    // Kalau sebelumnya sudah ada draft (auto-save), baris yang sama di-UPDATE.
    final provider = _laporanProvider;
    final int id;
    if (_idLokal != null) {
      await provider.updateLaporan(laporan, fotos);
      id = _idLokal!;
    } else {
      id = await provider.simpanLaporan(laporan, fotos);
      _idLokal = id;
    }
    final errorUpload = await provider.uploadLaporanById(id);

    if (!mounted) return;
    // Ambil messenger sebelum pop supaya snackbar tetap muncul di Home.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _menyimpan = false);
    Navigator.pop(context, true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          errorUpload == null
              ? 'Laporan tersimpan & terupload'
              : 'Laporan tersimpan di HP, tapi upload gagal. Tekan "Coba Lagi" di laporan tersebut.',
        ),
      ),
    );
  }

  List<FotoLaporan> _daftarFoto() => [
        for (final k in KategoriFoto.semua)
          if (_fotoMap[k] != null) _fotoMap[k]!,
      ];

  /// Menyusun objek Laporan dari isi form. [draft] = true -> boleh belum
  /// lengkap (tanpa jam patroli / PIC / jam dunia) dan statusnya DRAFT.
  Laporan _bangunLaporan({required bool draft}) {
    final zona = ZonaWaktu.aktif;

    // Jadwal patroli: tanggal + jam yang dipilih = jam DINDING di zona user
    // -> diterjemahkan ke instan UTC.
    DateTime? patroliUtc;
    String tanggalStr;
    String jamStr = '';
    if (_tanggal != null && _jamPatroli != null) {
      final jm = _jamPatroli!.split(':');
      patroliUtc = zona.dariLokal(_tanggal!.year, _tanggal!.month, _tanggal!.day, int.parse(jm[0]), int.parse(jm[1]));
      tanggalStr = zona.formatTanggal(patroliUtc);
      jamStr = _jamPatroli!;
    } else {
      tanggalStr = DateFormat('dd-MM-yyyy').format(_tanggal ?? _hariIniDiZona());
    }

    // Waktu dibuat: ditetapkan sekali, tidak berubah saat diedit.
    DateTime? dibuatUtc = _dibuatUtcAsli;
    String teksDibuat = _waktuDibuatTeksAsli ?? '';
    String zonaDibuat = _zonaAsal;
    if (dibuatUtc == null && _offsetJamDunia != null) {
      dibuatUtc = _sekarangUtc();
      zonaDibuat = zona.label;
      teksDibuat = zona.formatLengkap(dibuatUtc);
      _dibuatUtcAsli = dibuatUtc;
      _waktuDibuatTeksAsli = teksDibuat;
      _zonaAsal = zonaDibuat;
    }

    return Laporan(
      id: _idLokal,
      namaPembuat: _namaPembuat,
      tanggal: tanggalStr,
      jamPatroli: jamStr,
      picPatroli: draft
          ? _gabungPicDraft(_picLmController.text, _picHsseController.text)
          : _gabungPic(_picLmController.text, _picHsseController.text),
      waktuDibuat: teksDibuat,
      patroliUtc: patroliUtc,
      dibuatUtc: dibuatUtc,
      zona: zonaDibuat,
      loading: _loading,
      discharge: _discharge,
      penyaluran: _penyaluran,
      storage: _storage,
      uploadStatus: draft ? 'DRAFT' : 'LOCAL',
    );
  }

  // ---------------- AUTO-SAVE ----------------

  /// Dipanggil setiap user mengubah sesuatu. Simpan draft ditunda ~1,5 detik
  /// setelah perubahan terakhir (debounce); simpan segera terjadi saat app
  /// ke background / halaman ditutup.
  void _tandaiBerubah() {
    if (!_siapAutosave || _sudahFinal) return;
    _adaPerubahan = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 1500), _simpanDraft);
  }

  /// Menyimpan isi form sebagai DRAFT di HP. TIDAK memicu upload -- upload
  /// baru jalan saat user menekan "Simpan & Upload" (data lengkap). Fungsi
  /// ini sengaja tidak memakai `context`/`setState` supaya aman dipanggil
  /// saat halaman sedang ditutup.
  Future<void> _simpanDraft() async {
    if (!_siapAutosave || !_adaPerubahan || _menyimpan || _sudahFinal) return;
    if (_sedangSimpanDraft) {
      _draftUlang = true;
      return;
    }
    _sedangSimpanDraft = true;
    try {
      do {
        _draftUlang = false;
        _adaPerubahan = false;
        final laporan = _bangunLaporan(draft: true);
        final fotos = _daftarFoto();
        if (_idLokal == null) {
          _idLokal = await _laporanProvider.simpanDraftBaru(laporan, fotos);
        } else {
          await _laporanProvider.updateDraft(laporan, fotos);
        }
      } while (_draftUlang && !_sudahFinal);
    } catch (_) {
      _adaPerubahan = true; // gagal -> coba lagi pada perubahan berikutnya
    } finally {
      _sedangSimpanDraft = false;
    }
  }

  String get _judul {
    if (widget.modeEdit && _draftAwal) return 'Lanjutkan Draft Laporan';
    if (widget.modeEdit) return 'Edit Laporan Patroli';
    if (widget.modeDuplikat) return 'Duplikat Laporan Patroli';
    return 'Buat Laporan Patroli';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAwal) {
      return Scaffold(
        appBar: AppBar(title: Text(_judul)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: true,
      // Tombol back: simpan draft terakhir (berjalan tanpa context, aman setelah pop).
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _autosaveTimer?.cancel();
          _simpanDraft();
        }
      },
      child: Scaffold(
      appBar: AppBar(title: Text(_judul)),
      body: Column(
        children: [
          _indikatorLangkah(),
          const Divider(height: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _halaman = i),
              children: [
                _halamanInfoFoto(),
                _halamanKegiatan(
                  LoadingDischargeForm(
                    judul: '1. Loading',
                    data: _loading,
                    onChanged: (v) => _ubah(() => _loading = v),
                  ),
                ),
                _halamanKegiatan(
                  LoadingDischargeForm(
                    judul: '2. Discharge',
                    data: _discharge,
                    onChanged: (v) => _ubah(() => _discharge = v),
                  ),
                ),
                _halamanKegiatan(
                  PenyaluranForm(
                    data: _penyaluran,
                    onChanged: (v) => _ubah(() => _penyaluran = v),
                  ),
                ),
                _halamanKegiatan(
                  StorageForm(
                    data: _storage,
                    onChanged: (v) => _ubah(() => _storage = v),
                  ),
                ),
              ],
            ),
          ),
          _tombolNavigasi(),
        ],
      ),
    ),
    );
  }

  /// setState + tandai perubahan untuk auto-save.
  void _ubah(VoidCallback f) {
    setState(f);
    _tandaiBerubah();
  }

  Widget _indikatorLangkah() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Text(
            'Langkah ${_halaman + 1}/${_judulLangkah.length}: ${_judulLangkah[_halaman]}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _halamanKegiatan(Widget form) {
    return ListView(padding: const EdgeInsets.all(16), children: [form]);
  }

  Widget _halamanInfoFoto() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.modeDuplikat) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.content_copy, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PIC & data kegiatan disalin dari laporan sebelumnya. '
                    'Pilih Jam Patroli yang baru dan ambil ulang keempat '
                    'foto sebelum menyimpan.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Informasi Patroli',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pilihTanggal,
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(
            _tanggal == null
                ? 'Pilih Tanggal'
                : 'Tanggal: ${DateFormat('dd-MM-yyyy').format(_tanggal!)}',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _jamPatroli,
          decoration: const InputDecoration(
            labelText: 'Jam Patroli',
            border: OutlineInputBorder(),
          ),
          // Jam patroli = jam dinding di zona user (WIB/WITA/WIT, sesuai lokasi).
          // Laporan lama yang dilihat dari zona berbeda bisa punya jam di luar
          // daftar tetap (mis. 07:00 WITA) -> tetap ditampilkan agar tidak error.
          items: [
            ...daftarJamPatroli,
            if (_jamPatroli != null && !daftarJamPatroli.contains(_jamPatroli)) _jamPatroli!,
          ]
              .map((j) => DropdownMenuItem(value: j, child: Text('$j ${ZonaWaktu.aktif.label}')))
              .toList(),
          onChanged: (v) => _ubah(() => _jamPatroli = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _picLmController,
          onChanged: (_) => _tandaiBerubah(),
          decoration: const InputDecoration(
            labelText: 'PIC Patroli - Loading Master (LM)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _picHsseController,
          onChanged: (_) => _tandaiBerubah(),
          decoration: const InputDecoration(
            labelText: 'PIC Patroli - HSSE',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        JamDuniaBaris(
          offset: _offsetJamDunia,
          loading: _loadingJamDunia,
          error: _errorJamDunia,
          onRefresh: _ambilJamDunia,
        ),
        if (widget.modeEdit && _dibuatUtcAsli != null) ...[
          const SizedBox(height: 4),
          Text(
            'Waktu dibuat awal: ${ZonaWaktu.aktif.formatLengkap(_dibuatUtcAsli!)} ${ZonaWaktu.aktif.label} (tidak berubah walau diedit)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Foto Patroli',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final terisi = _fotoMap.values.where((v) => v != null).length;
                final total = KategoriFoto.semua.length;
                final lengkap = terisi >= total;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: lengkap
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: lengkap
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    '$terisi/$total',
                    style: TextStyle(
                      fontSize: 12,
                      color: lengkap
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Boleh diisi bertahap. Kalau lokasi tangki lain belum dikunjungi, '
          'simpan dulu lalu lengkapi lagi lewat tombol Edit nanti.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        ...KategoriFoto.semua.map(
          (kategori) => FotoSlotCard(
            kategori: kategori,
            data: _fotoMap[kategori],
            loading: _loadingFotoMap[kategori] ?? false,
            onAmbilFoto: () => _ambilFotoUntukKategori(kategori),
          ),
        ),
      ],
    );
  }

  Widget _tombolNavigasi() {
    final akhir = _halaman == _judulLangkah.length - 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_halaman > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _kePage(_halaman - 1),
                child: const Text('Sebelumnya'),
              ),
            ),
          if (_halaman > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _menyimpan
                  ? null
                  : (akhir ? _simpanLaporan : () => _kePage(_halaman + 1)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _menyimpan
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      akhir
                          ? (widget.modeEdit
                                ? 'Simpan & Upload Perubahan'
                                : widget.modeDuplikat
                                ? 'Simpan & Upload Laporan Baru'
                                : 'Simpan & Upload Laporan')
                          : 'Selanjutnya',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
