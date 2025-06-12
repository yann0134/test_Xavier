import 'package:http/http.dart' as http;
import '../ai_tool.dart';

class WeatherTool implements AITool {
  @override
  String get name => 'weather';

  @override
  String get description => 'Get current weather for a city.';

  @override
  bool canHandle(String query) {
    final lower = query.toLowerCase();
    return lower.startsWith('weather') || lower.startsWith('meteo');
  }

  @override
  Future<String> handle(String query) async {
    final parts = query.split(' ');
    if (parts.length < 2) {
      return 'Usage: weather <city>'; 
    }
    final city = parts.sublist(1).join(' ');
    final url = Uri.parse('https://wttr.in/' + Uri.encodeComponent(city) + '?format=3');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return response.body.trim();
      }
      return 'Weather API error';
    } catch (e) {
      return 'Weather fetch failed: $e';
    }
  }
}
