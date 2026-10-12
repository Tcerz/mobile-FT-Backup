import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mengambil suhu udara saat ini berdasarkan koordinat GPS,
/// menggunakan API gratis Open-Meteo (tanpa API key).
class WeatherService {
  static Future<String> getSuhuSaatIni(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon&current=temperature_2m',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suhu = data['current']?['temperature_2m'];
        if (suhu != null) return '$suhu°C';
      }
    } catch (_) {
      // fallback di bawah
    }
    return '-';
  }
}
