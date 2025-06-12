import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_tool.dart';

class TranslatorTool implements AITool {
  @override
  String get name => 'translator';

  @override
  String get description => 'Translate short text using MyMemory API';

  @override
  bool canHandle(String query) {
    final lower = query.toLowerCase();
    return lower.startsWith('translate') || lower.startsWith('traduire');
  }

  @override
  Future<String> handle(String query) async {
    try {
      final parts = query.split(' ');
      if (parts.length < 3) {
        return 'Usage: translate <from>-<to> <text>';
      }
      final langPart = parts[1];
      final text = parts.sublist(2).join(' ');
      final url = Uri.parse('https://api.mymemory.translated.net/get?q=' +
          Uri.encodeComponent(text) + '&langpair=' + langPart);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['responseData']['translatedText'];
      }
      return 'Translation API error';
    } catch (e) {
      return 'Translation failed: $e';
    }
  }
}
