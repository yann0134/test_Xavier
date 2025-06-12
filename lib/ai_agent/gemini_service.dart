import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final GenerativeModel _model;

  GeminiService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash-latest',
          apiKey: apiKey,
        );

  Future<Map<String, dynamic>> decideTool(
      String query, List<String> availableTools) async {
    final prompt = '''You are an assistant that can use tools: ${availableTools.join(', ')}.
Decide the best tool for the user query or answer directly.
Respond only with JSON in one of these formats:
{ "tool": "<tool name>", "toolQuery": "<query>" }
or
{ "answer": "<text>" }
Query: "$query"''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return _extractJson(response.text);
  }

  Map<String, dynamic> _extractJson(String? text) {
    if (text == null) return {};
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return {};
    final jsonStr = text.substring(start, end + 1);
    try {
      return jsonDecode(jsonStr);
    } catch (_) {
      return {};
    }
  }
}
