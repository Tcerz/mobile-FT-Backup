# Perubahan: timezone UTC, auto-save draft, notifikasi/alarm, kamera 4:3

## Langkah wajib setelah menarik perubahan
1. `flutter pub get` (dependency baru: `flutter_local_notifications`, `timezone`, `camera`, `image`).
2. Jalankan `supabase/migrasi_timezone_utc.sql` di Supabase SQL Editor **sebelum** memakai build baru
   (kolom `patroli_utc`, `dibuat_utc`, `zona`, `diambil_utc`). Tanpa ini upload akan gagal.
3. Uji di HP fisik (alarm/notifikasi tidak bisa diuji di emulator dengan benar).

## 1. Timezone
- `lib/models/zona_waktu.dart`: enum WIB/WITA/WIT. Semua waktu disimpan UTC; tampilan dikonversi ke `ZonaWaktu.aktif`.
- Zona ditentukan dari GPS (`zona_waktu_service.dart`): nama provinsi dari geocoding, fallback bujur, fallback zona terakhir.
- SQLite v4: kolom `patroli_utc`, `dibuat_utc`, `zona`, `diambil_utc`. Data lama otomatis dikonversi (dianggap WIB).
- Kolom teks lama (`tanggal`, `jam_patroli`, `waktu_dibuat`, `jam`) tetap diisi agar dashboard lama tidak rusak.
- `TimeService.getCurrentUtc()` selalu UTC (fallback timeapi.io sebelumnya salah menafsirkan jam Jakarta sebagai jam HP).
- Izin lokasi diminta saat pertama kali app dibuka (`startup_service.dart`).

## 2. Auto-save
- Perubahan di form disimpan sebagai `DRAFT` (debounce 1,5 dtk, dan langsung saat app ke background/ditutup/back).
- Draft TIDAK pernah diupload (dijaga di `LaporanProvider` dan `UploadService`). Upload hanya lewat "Simpan & Upload".
- Draft tampil di Home dengan tombol "Draft - Lanjutkan".

## 3. Notifikasi & alarm (`notifikasi_patrol_service.dart`)
- 5 menit sebelum jam patroli: alarm (suara berulang, tombol "Matikan Alarm", berhenti sendiri setelah 5 menit).
- 1 jam sesudah: Kondisi A "Missed Safety Patrol jam HH:mm" (belum ada laporan) / Kondisi B "Kamu belum upload laporanmu"
  (ada tapi belum UPLOADED, termasuk draft). Dua suara berbeda: `notif_missed.wav` dan `notif_belum_upload.wav`.
- Jadwal dihitung ulang tiap data berubah (simpan/edit/hapus/upload), ganti pengaturan, ganti zona, dan saat app dibuka. Horizon 3 hari.
- Pengaturan: Profil > Alarm & Notifikasi (nada alarm, jam yang diingatkan, tes notifikasi, status izin).
- Suara ada di `android/app/src/main/res/raw/`. Ganti file dengan nama yang sama untuk memakai suara sendiri.

## 4. Kamera 4:3
- `kamera_page.dart`: kamera dalam aplikasi, preview 3:4 portrait, hasil foto di-crop tengah ke 4:3 persis (maks 1600 px).
- `image_picker` tidak dipakai lagi (boleh dihapus dari pubspec).
