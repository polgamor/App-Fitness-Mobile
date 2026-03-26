import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('API key no configurada. Verifica tu archivo .env');
    }
    return key;
  }

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  static const String _systemInstruction =
      'Eres un asistente especializado exclusivamente en fitness, nutrición deportiva, '
      'entrenamiento físico y salud física. Únicamente responde preguntas relacionadas con '
      'estos temas. Si el usuario pregunta sobre algo fuera de este ámbito, indícale '
      'amablemente que solo puedes ayudarle con fitness y nutrición deportiva. '
      'No proporciones consejos médicos, diagnósticos ni recomendaciones sobre enfermedades. '
      'No hagas mención de esteroides ni sustancias prohibidas.';

  static const List<String> _blockedTopics = [
    'medicina',
    'tratamiento médico',
    'enfermedades',
    'consejo médico',
    'diagnóstico',
    'esteroides',
    'consejo medico real',
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
      throw Exception('La solicitud tardó demasiado. Inténtalo de nuevo.');
    } catch (e) {
      throw Exception('Error al conectar con Gemini: $e');
    }
  }

  String? _validatePrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    for (final topic in _blockedTopics) {
      if (lowerPrompt.contains(topic.toLowerCase())) {
        return 'Soy un asistente especializado en fitness. No puedo responder sobre $topic.';
      }
    }
    return null;
  }
}
