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

  static String get _baseUrl => 
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  static const List<String> _allowedTopics = [
    'suplementación',
    'dietas',
    'nutrición deportiva',
    'rutinas de ejercicio',
    'fitness',
    'entrenamiento',
    'recomendaciones deportivas',
    'salud física',
    'ejercicio',
    'deportes'
    
  ];

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
    try {
      final validation = _validatePrompt(prompt);
      if (validation != null) return validation;

      const systemInstruction = "";

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "systemInstruction": {
            "parts": [{"text": systemInstruction}]
          },
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]['text'];
        
        if (!_isResponseValid(responseText)) {
          return "Mi especialidad es el fitness y la nutrición deportivas ¿En que puedo ayudarte hoy?";
        }
        
        return responseText;
      } else {
        throw Exception('Error en la API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al conectar con Gemini: ${e.toString()}');
    }
  }

  String? _validatePrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    for (final topic in _blockedTopics) {
      if (lowerPrompt.contains(topic.toLowerCase())) {
        return "Soy un asistente especializado en fitness. No puedo responder sobre $topic.";
      }
    }
        
    return null;
  }

  bool _isResponseValid(String response) {
    final lowerResponse = response.toLowerCase();
    
    if (lowerResponse.contains("Mi especialidad es el fitness y la nutrición deportivas ¿En que puedo ayudarte hoy?")) {
      return true;
    }
    
    return _allowedTopics.any(
      (topic) => lowerResponse.contains(topic.toLowerCase())
    );
  }
}