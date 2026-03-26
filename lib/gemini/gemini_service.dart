import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('API key not configured. Check your .env file');
    }
    return key;
  }

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  static const String _systemInstruction =
      'You are an assistant specialized exclusively in fitness, sports nutrition, '
      'physical training, and physical health. Only respond to questions related to '
      'these topics. If the user asks about anything outside this scope, kindly let '
      'them know that your specialty is fitness and sports nutrition. '
      'Do not provide medical advice, diagnoses, or recommendations about diseases. '
      'Do not mention steroids or any prohibited substances.';

  static const List<String> _blockedTopics = [
    'medical advice',
    'medical treatment',
    'disease',
    'diagnosis',
    'steroids',
    'prescription drugs',
    'medication',
  ];

  Future<String> generateContent(String prompt) async {
    final validation = _validatePrompt(prompt);
    if (validation != null) return validation;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [{'text': _systemInstruction}]
              },
              'contents': [
                {
                  'parts': [{'text': prompt}]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('La API no devolvió ninguna respuesta.');
        }
        final text = candidates[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text == null || text.isEmpty) {
          throw Exception('Respuesta vacía de la API.');
        }
        return text;
      } else {
        throw Exception('Error en la API: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      throw Exception('Error connecting to Gemini: $e');
    }
  }

  String? _validatePrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    for (final topic in _blockedTopics) {
      if (lowerPrompt.contains(topic.toLowerCase())) {
        return 'I am a fitness specialist assistant. I cannot respond about $topic.';
      }
    }
    return null;
  }
}
