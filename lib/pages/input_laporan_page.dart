import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/foto_laporan_model.dart';
import '../models/kegiatan_model.dart';
import '../models/laporan_model.dart';
import '../providers/laporan_provider.dart';
import '../providers/profil_provider.dart';
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
  /// tapi Jam Patroli & foto dikosongkan (wajib diisi ulang).
  /// Sumbernya laporan MILIK SENDIRI di device ini (dicari lewat id lokal).
  final int? duplikatDariId;

  /// Alternatif dari [duplikatDariId]: dipakai saat duplikat berasal dari
  /// laporan MILIK ORANG LAIN (tab Posted) -- datanya sudah diambil
  /// langsung dari server, tanpa foto (foto wajib diambil ulang sendiri).
  final Laporan? duplikatData;

  const InputLaporanPage({
    super.key,
    this.laporanId,
    this.duplikatDariId,
    this.duplikatData,
  });

  bool get modeEdit => laporanId != null;
  bool get modeDuplikat =>
      laporanId == null && (duplikatDariId != null || duplikatData != null);

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

final _polaPic = RegExp(r'^LM:\s*(.*?)\s*\|\s*HSSE:\s*(.*)$');
(String, String) _pisahPic(String gabungan) {
  final match = _polaPic.firstMatch(gabungan);
  if (match != null) return (match.group(1) ?? '', match.group(2) ?? '');
  return (gabungan, ''); // data lama (sebelum fitur ini) -> taruh di LM saja
}

class _InputLaporanPageState extends State<InputLaporanPage> {
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
  String? _waktuDibuatAsli;

  @override
  void initState() {
    super.initState();
    _ambilJamDunia();

    if (widget.modeEdit) {
      _muatLaporanUntukEdit();
    } else if (widget.modeDuplikat) {
      _muatLaporanUntukDuplikat();
    } else {
      _tanggal = DateTime.now();
    }
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
      _tanggal = DateFormat('dd-MM-yyyy').parse(detail.tanggal);
      _jamPatroli = detail.jamPatroli;
      final (lm, hsse) = _pisahPic(detail.picPatroli);
      _picLmController.text = lm;
      _picHsseController.text = hsse;
      _waktuDibuatAsli = detail.waktuDibuat;
      _loading = detail.loading;
      _discharge = detail.discharge;
      _penyaluran = detail.penyaluran;
      _storage = detail.storage;
      for (final foto in detail.fotos) {
        _fotoMap[foto.kategori] = foto;
      }
      _loadingAwal = false;
    });
  }

  Future<void> _muatLaporanUntukDuplikat() async {
    setState(() => _loadingAwal = true);
    final sumber =
        widget.duplikatData ??
        await context.read<LaporanProvider>().fetchDetail(
          widget.duplikatDariId!,
        );
    if (sumber == null) {
      if (mounted) setState(() => _loadingAwal = false);
      return;
    }
    setState(() {
      _tanggal = DateFormat('dd-MM-yyyy').parse(sumber.tanggal);
      _jamPatroli = null;
      final (lm, hsse) = _pisahPic(sumber.picPatroli);
      _picLmController.text = lm;
      _picHsseController.text = hsse;
      _loading = sumber.loading;
      _discharge = sumber.discharge;
      _penyaluran = sumber.penyaluran;
      _storage = sumber.storage;
      for (final foto in sumber.fotos) {
        _fotoMap[foto.kategori] = foto;
      }
      _loadingAwal = false;
    });
  }

  @override
  void dispose() {
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
      final waktuDunia = await TimeService.getCurrentWorldTime();
      setState(() => _offsetJamDunia = waktuDunia.difference(DateTime.now()));
    } catch (e) {
      setState(
        () => _errorJamDunia =
            'Gagal mengambil jam dunia. Periksa koneksi internet.',
      );
    } finally {
      if (mounted) setState(() => _loadingJamDunia = false);
    }
  }

  DateTime _waktuSaatIni() =>
      DateTime.now().add(_offsetJamDunia ?? Duration.zero);

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
      final file = await ImageService.ambilFotoDenganKamera();
      if (file == null) return;

      final pos = await LocationService.getCurrentLocation();
      final alamat = await LocationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final suhu = await WeatherService.getSuhuSaatIni(
        pos.latitude,
        pos.longitude,
      );
      final jamStr = DateFormat('dd-MM-yyyy HH:mm:ss').format(_waktuSaatIni());

      final foto = FotoLaporan(
        kategori: kategori,
        imagePath: file.path,
        latitude: pos.latitude,
        longitude: pos.longitude,
        alamat: alamat,
        jam: jamStr,
        suhu: suhu,
      );
      setState(() => _fotoMap[kategori] = foto);
    } catch (e) {
      _tampilkanPesan('Gagal mengambil foto $kategori: $e');
    } finally {
      if (mounted) setState(() => _loadingFotoMap[kategori] = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (result != null) setState(() => _tanggal = result);
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
    final namaPembuat = context.read<ProfilProvider>().nama;

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
    if (!widget.modeEdit && _offsetJamDunia == null) {
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

    final tanggalStr = DateFormat('dd-MM-yyyy').format(_tanggal!);
    final waktuDibuat = widget.modeEdit && _waktuDibuatAsli != null
        ? _waktuDibuatAsli!
        : DateFormat('dd-MM-yyyy HH:mm:ss').format(_waktuSaatIni());

    final laporan = Laporan(
      id: widget.laporanId,
      namaPembuat: namaPembuat,
      tanggal: tanggalStr,
      jamPatroli: _jamPatroli!,
      picPatroli: _gabungPic(_picLmController.text, _picHsseController.text),
      waktuDibuat: waktuDibuat,
      loading: _loading,
      discharge: _discharge,
      penyaluran: _penyaluran,
      storage: _storage,
    );

    final List<FotoLaporan> fotos = [];
    for (final k in KategoriFoto.semua) {
      final f = _fotoMap[k];
      if (f == null) continue;
      if (widget.modeDuplikat) {
        final suhuBaru = await WeatherService.getSuhuSaatIni(
          f.latitude,
          f.longitude,
        );
        fotos.add(f.copyWith(jam: waktuDibuat, suhu: suhuBaru));
      } else {
        fotos.add(f);
      }
    }

    final provider = context.read<LaporanProvider>();
    if (widget.modeEdit) {
      await provider.updateLaporan(laporan, fotos);
    } else {
      await provider.simpanLaporan(laporan, fotos);
    }

    if (!mounted) return;
    setState(() => _menyimpan = false);
    Navigator.pop(context, true);
  }

  String get _judul {
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

    return Scaffold(
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
                    onChanged: (v) => setState(() => _loading = v),
                  ),
                ),
                _halamanKegiatan(
                  LoadingDischargeForm(
                    judul: '2. Discharge',
                    data: _discharge,
                    onChanged: (v) => setState(() => _discharge = v),
                  ),
                ),
                _halamanKegiatan(
                  PenyaluranForm(
                    data: _penyaluran,
                    onChanged: (v) => setState(() => _penyaluran = v),
                  ),
                ),
                _halamanKegiatan(
                  StorageForm(
                    data: _storage,
                    onChanged: (v) => setState(() => _storage = v),
                  ),
                ),
              ],
            ),
          ),
          _tombolNavigasi(),
        ],
      ),
    );
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
                    'Periksa kembali foto dan pilih Jam Patroli yang baru '
                    'sebelum menyimpan.',
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
          items: daftarJamPatroli
              .map((j) => DropdownMenuItem(value: j, child: Text('$j WIB')))
              .toList(),
          onChanged: (v) => setState(() => _jamPatroli = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _picLmController,
          decoration: const InputDecoration(
            labelText: 'PIC Patroli - Loading Master (LM)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _picHsseController,
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
        if (widget.modeEdit && _waktuDibuatAsli != null) ...[
          const SizedBox(height: 4),
          Text(
            'Waktu dibuat awal: $_waktuDibuatAsli (tidak berubah walau diedit)',
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
                                ? 'Simpan Perubahan'
                                : widget.modeDuplikat
                                ? 'Simpan Laporan Baru'
                                : 'Simpan Laporan')
                          : 'Selanjutnya',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
