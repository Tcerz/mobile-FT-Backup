import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async => client.auth.signOut();

  /// Ambil data profil (nama, role, status) milik user yang sedang login.
  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    return await client.from('profiles').select().eq('id', uid).maybeSingle();
  }
}
