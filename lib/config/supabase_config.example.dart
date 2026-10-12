/// TEMPLATE -- salin file ini jadi `supabase_config.dart` (hapus ".example"),
/// lalu isi url & anonKey dengan milik Anda sendiri.
///
/// File hasil salinan (`supabase_config.dart`) SUDAH masuk .gitignore,
/// jadi aman dan tidak akan pernah ikut ter-upload ke GitHub.
class SupabaseConfig {
  static const String url = 'ISI_SUPABASE_PROJECT_URL_DI_SINI';
  static const String anonKey = 'ISI_SUPABASE_ANON_KEY_DI_SINI';

  static bool get sudahDikonfigurasi =>
      !url.contains('ISI_') && !anonKey.contains('ISI_');
}
