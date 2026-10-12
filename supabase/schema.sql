-- Jalankan file ini di Supabase Dashboard > SQL Editor.
-- Urutan sudah aman dijalankan sekali dari awal (project baru).

-- 1. Tabel profil (role & status dikelola admin, bukan oleh user)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  email text,
  role text not null default 'user' check (role in ('user','admin')),
  status text not null default 'aktif' check (status in ('aktif','nonaktif')),
  created_at timestamptz not null default now()
);

-- 2. Tabel laporan (versi server dari laporan yang diupload dari mobile)
create table reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  nama_pembuat text not null,
  tanggal text not null,
  jam_patroli text not null,
  pic_patroli text not null,
  waktu_dibuat text not null,
  loading_data text not null,
  discharge_data text not null,
  penyaluran_data text not null,
  storage_data text not null,
  created_at timestamptz not null default now()
);

-- 3. Tabel foto per laporan
create table report_photos (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references reports(id) on delete cascade,
  kategori text not null,
  photo_url text not null,
  latitude double precision not null,
  longitude double precision not null,
  alamat text not null,
  jam text not null,
  suhu text not null
);

-- 4. Aktifkan Row Level Security
alter table profiles enable row level security;
alter table reports enable row level security;
alter table report_photos enable row level security;

-- Helper: cek apakah user yang login adalah admin
create or replace function is_admin() returns boolean as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$ language sql security definer;

-- Policy profiles: user lihat/ubah profil sendiri, admin lihat/kelola semua
create policy "user lihat profil sendiri" on profiles for select using (auth.uid() = id or is_admin());
create policy "admin kelola semua profil" on profiles for insert with check (is_admin());
create policy "admin update semua profil" on profiles for update using (is_admin());

-- Policy reports: user kelola laporan miliknya sendiri, admin lihat semua
create policy "user insert laporan sendiri" on reports for insert with check (auth.uid() = user_id);
create policy "user lihat laporan sendiri atau admin lihat semua" on reports for select using (auth.uid() = user_id or is_admin());

-- Policy report_photos: mengikuti kepemilikan laporan induknya
create policy "user insert foto laporan sendiri" on report_photos for insert with check (
  exists (select 1 from reports r where r.id = report_id and r.user_id = auth.uid())
);
create policy "user lihat foto laporan sendiri atau admin" on report_photos for select using (
  exists (select 1 from reports r where r.id = report_id and (r.user_id = auth.uid() or is_admin()))
);

-- 5. Trigger: setiap kali admin buat user baru lewat Supabase Auth,
-- baris profiles dibuat otomatis (nama diambil dari user metadata "nama").
create or replace function handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, nama, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'nama', new.email), new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- 6. Storage bucket untuk foto laporan (privat, hanya lewat signed/public URL sesuai policy di bawah)
insert into storage.buckets (id, name, public) values ('laporan-foto', 'laporan-foto', true);

create policy "user upload foto ke folder sendiri" on storage.objects for insert
  with check (bucket_id = 'laporan-foto' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "siapa saja bisa baca foto (bucket public)" on storage.objects for select
  using (bucket_id = 'laporan-foto');
