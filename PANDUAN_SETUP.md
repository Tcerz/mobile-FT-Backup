# Panduan Setup - Aplikasi Laporan Safety Patrol (versi rombak besar)

## Asumsi yang dipakai (tolong dikoreksi kalau salah)

Karena beberapa hal masih general di permintaan, saya pakai asumsi berikut:

1. **Foto**: wajib tepat 4 foto per laporan, kategori tetap: **Jetty, Filling Shed,
   Rumah Pompa, Area Tangki** (sesuai jawaban Anda).
2. **Login**: tidak ada halaman login. Saat aplikasi pertama kali dibuka, user
   diminta isi nama sekali (halaman onboarding), nama itu dipakai otomatis
   sebagai "Dibuat oleh" di setiap laporan, dan bisa diubah lagi lewat
   halaman **Profil** (ikon orang di kanan atas Home).
3. **Kegiatan**: saya jadikan **4 seksi kegiatan tetap dalam SATU laporan**
   (Loading, Discharge, Penyaluran, Storage — semuanya diisi sekaligus di
   form yang sama), BUKAN kegiatan yang bisa ditambah berkali-kali. Ini saya
   pilih karena mengikuti contoh laporan asli Anda (`isi_inputan.txt`) yang
   selalu punya semua bagian ini dalam satu laporan harian. Kalau ternyata
   maksud Anda kegiatan bisa ditambah dinamis (list, bisa lebih dari sekali
   per jenis), kabari saya, itu perlu perubahan struktur database.
4. **Suhu berdasarkan lokasi**: diambil otomatis dari API cuaca gratis
   (Open-Meteo, tanpa API key) berdasarkan koordinat GPS saat foto diambil.

## Update Terbaru (modifikasi tambahan)

1. **PDF sekarang pakai gambar hasil stempel** — foto yang disisipkan ke
   PDF adalah versi yang sudah ditempel teks (kategori/lokasi/koordinat/
   suhu/waktu), persis sama seperti hasil tombol "Cetak JPG". Tidak ada
   lagi info foto yang ditulis terpisah di PDF karena sudah menyatu di
   gambarnya.
2. **Laporan bisa diedit** — di halaman folder laporan (`laporan_detail_page.dart`)
   sekarang ada ikon pensil di AppBar. Membuka form yang sama dengan "Buat
   Laporan Baru", tapi terisi otomatis dengan data lama. Cocok untuk kasus
   petugas perlu bergerak dulu ke titik lain sebelum bisa mengisi status
   tangki tertentu — simpan dulu apa yang sudah ada, edit lagi nanti.
   **Waktu Dibuat asli tidak berubah** walau laporan diedit.
3. **Koordinat ditambahkan** ke data yang ditampilkan — sebelumnya hanya
   suhu yang muncul di kartu foto & stempel gambar, sekarang koordinat
   (`latitude, longitude`) ikut ditampilkan di form input, halaman folder,
   dan di gambar hasil stempel/PDF.
4. **Tangki saling eksklusif** — di seksi "4. Storage", satu tangki (mis.
   T.05) yang sudah dipilih di satu kategori (mis. "Aktif/Idle") otomatis
   jadi abu-abu & tidak bisa diketuk di 4 kategori tangki lainnya (Loading/
   Discharge/Penyaluran/Off), sampai dihapus dulu dari kategori asalnya.



```
lib/
├── database/
│   └── database_helper.dart      (2 tabel: laporan + foto_laporan)
├── models/
│   ├── laporan_model.dart        (header laporan)
│   ├── foto_laporan_model.dart   (1 foto + kategori + lokasi + suhu + jam)
│   └── kegiatan_model.dart       (Loading/Discharge/Penyaluran/Storage)
├── pages/
│   ├── onboarding_nama_page.dart (isi nama pertama kali buka app)
│   ├── profil_page.dart          (edit nama)
│   ├── home_page.dart            (history laporan = daftar folder)
│   ├── input_laporan_page.dart   (form besar: buat laporan baru)
│   └── laporan_detail_page.dart  (isi folder: 4 foto + tombol Cetak JPG)
├── providers/
│   ├── laporan_provider.dart
│   └── profil_provider.dart      (simpan nama via shared_preferences)
├── services/
│   ├── image_service.dart        (ambil foto kamera)
│   ├── image_stamp_service.dart  (stempel teks di bawah foto, generik)
│   ├── location_service.dart     (GPS + alamat)
│   ├── time_service.dart         (jam dunia, bukan jam HP)
│   ├── weather_service.dart      (BARU: suhu dari lokasi)
│   ├── pdf_service.dart          (PDF lengkap: header+kegiatan+4 foto)
│   └── text_export_service.dart  (BARU: teks untuk di-copy ke WA)
└── widgets/
    ├── foto_slot_card.dart          (1 dari 4 slot foto di form input)
    ├── laporan_history_card.dart    (kartu folder di Home)
    ├── loading_discharge_form.dart  (form Loading & Discharge)
    ├── penyaluran_form.dart
    ├── storage_form.dart
    └── tangki_multi_select.dart     (chip pilih T.01–T.16)
```

**Timpa/ganti seluruh isi folder `lib/` lama Anda dengan struktur ini.**
File lama yang sudah tidak dipakai (`ambil_laporan_page.dart`, model &
provider laporan versi 1-foto, `history_card.dart` versi lama) sengaja
dihapus dari paket ini — hapus juga versi lama dari project Anda supaya
tidak bentrok nama file.

## Tambahan Dependency di `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter

  provider: ^6.1.2
  sqflite: ^2.3.3
  path: ^1.9.0
  image_picker: ^1.1.2
  path_provider: ^2.1.4
  geolocator: ^13.0.1
  geocoding: ^3.0.0
  pdf: ^3.11.1
  printing: ^5.13.2
  intl: ^0.19.0
  share_plus: ^10.1.2
  http: ^1.2.2
  shared_preferences: ^2.3.2   # BARU: simpan nama petugas
```

Jalankan:
```bash
flutter pub get
```

## Izin Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
`minSdkVersion` minimal **21**.

## Izin iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Aplikasi membutuhkan akses kamera untuk mengambil foto laporan</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Aplikasi membutuhkan akses lokasi untuk mencatat titik laporan</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Aplikasi membutuhkan akses untuk menyimpan foto laporan</string>
```

## Alur Aplikasi Baru

1. **Buka pertama kali** → diminta isi nama → masuk ke Home.
2. **Home**:
   - Tombol besar "Buat Laporan Baru".
   - History di bawahnya sekarang berupa **folder laporan** (bukan per-foto
     lagi). Tiap folder = satu laporan patroli (tanggal + jam patroli).
   - Setiap folder punya 2 tombol: **Cetak PDF** (PDF lengkap: header +
     4 kegiatan + 4 foto) dan **Copy Text** (salin teks ringkas siap paste
     ke WhatsApp).
   - Ketuk folder untuk masuk melihat isinya.
3. **Buat Laporan Baru**:
   - Isi tanggal, jam patroli (dropdown per 2 jam), PIC Patroli.
   - Ambil 4 foto wajib (Jetty, Filling Shed, Rumah Pompa, Area Tangki) —
     setiap foto otomatis mengambil lokasi GPS, alamat, suhu, dan jam dunia.
   - Isi 4 seksi kegiatan: Loading, Discharge, Penyaluran, Storage (tangki
     dipilih lewat chip T.01–T.16).
   - Tombol "Simpan Laporan" di paling bawah.
4. **Isi Folder Laporan** (setelah ketuk folder di Home):
   - Menampilkan ringkasan header + daftar 4 foto.
   - Setiap foto punya tombol **Cetak JPG** sendiri (foto + info kategori/
     lokasi/suhu/jam distempel di bawah foto, lalu dibuka lewat share sheet).

## Catatan

- Data lama dari versi aplikasi sebelumnya (skema database lama) **tidak
  kompatibel** dengan skema baru ini. Karena nama file database diganti
  (`laporan_patroli.db`, sebelumnya `laporan.db`), aplikasi akan otomatis
  membuat database baru yang kosong — tidak akan crash, tapi laporan lama
  (kalau ada di HP testing sebelumnya) tidak akan muncul lagi.
- Kalau nanti ternyata "Kegiatan" perlu bisa ditambah dinamis (bukan 4
  seksi tetap), kabari saya — perlu tabel `kegiatan` terpisah dengan
  relasi ke `laporan`, bukan disimpan sebagai kolom JSON tetap seperti
  sekarang.
