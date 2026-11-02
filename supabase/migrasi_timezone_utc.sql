-- Jalankan di Supabase Dashboard > SQL Editor SEKALI, SEBELUM memakai versi
-- aplikasi yang menyimpan waktu dalam UTC (dukungan WIB/WITA/WIT).
--
-- Kolom teks lama (tanggal, jam_patroli, waktu_dibuat, jam) TIDAK dihapus
-- supaya dashboard/laporan lama tetap jalan. Kolom baru di bawah adalah
-- sumber kebenaran waktu (timestamptz = disimpan UTC oleh Postgres).

alter table reports
  add column if not exists patroli_utc timestamptz,
  add column if not exists dibuat_utc  timestamptz,
  add column if not exists zona        text not null default 'WIB';

alter table report_photos
  add column if not exists diambil_utc timestamptz;

-- Isi data lama: seluruhnya dibuat di WIB (UTC+7), jadi diterjemahkan ke UTC.
-- (::timestamp dulu = ambil jam dinding apa adanya, lalu 'at time zone'
-- menafsirkannya sebagai jam Jakarta -> timestamptz.)
update reports
set patroli_utc = (to_timestamp(tanggal || ' ' || jam_patroli, 'DD-MM-YYYY HH24:MI')::timestamp at time zone 'Asia/Jakarta'),
    dibuat_utc  = (to_timestamp(waktu_dibuat, 'DD-MM-YYYY HH24:MI:SS')::timestamp at time zone 'Asia/Jakarta')
where patroli_utc is null;

update report_photos
set diambil_utc = (to_timestamp(jam, 'DD-MM-YYYY HH24:MI:SS')::timestamp at time zone 'Asia/Jakarta')
where diambil_utc is null;
