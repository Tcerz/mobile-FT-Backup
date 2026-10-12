import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Menyimpan data profil user yang sedang login, diisi otomatis dari
/// tabel `profiles` di Supabase (bukan diketik bebas oleh user lagi).
class ProfilProvider extends ChangeNotifier {
  String _nama = '';
  String _role = 'user';
  String _status = 'aktif';
  String? _depotId;
  bool _sudahDimuat = false;

  String get nama => _nama;
  String get role => _role;
  String get status => _status;
  String? get depotId => _depotId;
  bool get isAdmin => _role == 'admin';
  bool get aktif => _status == 'aktif';
  bool get sudahDimuat => _sudahDimuat;
  bool get sudahDiatur => _sudahDimuat && _nama.trim().isNotEmpty;

  /// Dipanggil setelah login berhasil untuk memuat profil dari server.
  Future<void> loadFromServer() async {
    final data = await AuthService.fetchMyProfile();
    _nama = (data?['nama'] as String?)?.trim() ?? '';
    _role = data?['role'] as String? ?? 'user';
    _status = data?['status'] as String? ?? 'aktif';
    _depotId = data?['depot_id'] as String?;
    _sudahDimuat = true;
    notifyListeners();
  }

  void reset() {
    _nama = '';
    _role = 'user';
    _status = 'aktif';
    _depotId = null;
    _sudahDimuat = false;
    notifyListeners();
  }
}
