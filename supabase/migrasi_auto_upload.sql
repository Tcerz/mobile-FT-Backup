-- Jalankan di Supabase Dashboard > SQL Editor SEKALI, sebelum memakai versi
-- aplikasi yang meng-upload otomatis. Upload otomatis juga dipakai saat
-- laporan DIEDIT, jadi aplikasi perlu hak UPDATE/DELETE yang sebelumnya
-- tidak ada di schema.sql.

-- Edit laporan: update baris reports milik sendiri
create policy "user update laporan sendiri" on reports for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Edit laporan: foto lama dihapus lalu diinsert ulang
create policy "user hapus foto laporan sendiri" on report_photos for delete using (
  exists (select 1 from reports r where r.id = report_id and r.user_id = auth.uid())
);

-- Ambil-ulang foto: file di Storage ditimpa (upload dengan upsert)
create policy "user timpa foto di folder sendiri" on storage.objects for update
  using (bucket_id = 'laporan-foto' and (storage.foldername(name))[1] = auth.uid()::text);
