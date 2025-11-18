import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_keys.dart';

class HuggingFaceModerationService {
  static final String _apiKeyy = ApiKeys.apiKeyy ;
  static const String _modelId = 'KoalaAI/Text-Moderation';

  static String get _apiUrl =>
      'https://router.huggingface.co/hf-inference/models/$_modelId';

  static Future<Map<String, dynamic>> moderateMessage(String message) async {
    try {
      for (int attempt = 0; attempt < 3; attempt++) {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $_apiKeyy',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'inputs': message}),
        ).timeout(const Duration(seconds: 20));

        print('HF API Response: ${response.statusCode} / ${response.body}');

        final data = jsonDecode(response.body);

        // Case 1: API returns nested list structure [[{label, score}, ...]]
        if (data is List && data.isNotEmpty) {
          // Handle nested list: data = [[{label, score}, {label, score}, ...]]
          final results = data[0] is List ? data[0] : data;

          if (results is List && results.isNotEmpty) {
            // Find the result with highest score
            var topResult = results[0];
            double highestScore = (topResult['score'] as num?)?.toDouble() ?? 0.0;

            for (var result in results) {
              final score = (result['score'] as num?)?.toDouble() ?? 0.0;
              if (score > highestScore) {
                highestScore = score;
                topResult = result;
              }
            }

            final label = topResult['label']?.toString() ?? 'unknown';
            final score = (topResult['score'] as num?)?.toDouble() ?? 0.0;
            final isInappropriate = label.toLowerCase() != 'ok' &&
                label.toLowerCase() != 'safe';

            return {
              'isInappropriate': isInappropriate,
              'label': label,
              'confidence': score,
              'reason': isInappropriate
                  ? 'Detected $label with ${(score * 100).toStringAsFixed(0)}% confidence'
                  : 'Message is appropriate',
            };
          }
        }

        // Case 2: API returns a map with an error
        else if (data is Map<String, dynamic> && data.containsKey('error')) {
          final errorMsg = data['error']?.toString() ?? 'Unknown error';
          print('HF API returned error: $errorMsg');

          // Check if model is loading
          if (errorMsg.contains('loading') || errorMsg.contains('Loading')) {
            print('Model loading... retrying (${attempt + 1}/3)');
            await Future.delayed(const Duration(seconds: 5));
            continue;
          }

          return {
            'isInappropriate': false,
            'label': null,
            'confidence': 0.0,
            'reason': 'API Error: $errorMsg',
          };
        }

        // Case 3: Model still loading (503 status)
        else if (response.statusCode == 503) {
          print('Model loading... retrying (${attempt + 1}/3)');
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        // Any other unexpected response
        else {
          print('HF API Unexpected response structure: $data');
          return {
            'isInappropriate': false,
            'label': null,
            'confidence': 0.0,
            'reason': 'Unexpected response from HF API',
          };
        }
      }

      // Fallback if all attempts failed
      return {
        'isInappropriate': false,
        'label': null,
        'confidence': 0.0,
        'reason': 'Failed to get valid response from API after 3 attempts',
      };
    } catch (e, stackTrace) {
      print('Moderation error: $e');
      print('Stack trace: $stackTrace');
      return {
        'isInappropriate': false,
        'label': null,
        'confidence': 0.0,
        'reason': 'Error during moderation: $e',
      };
    }
  }

  static String getWarningMessage(String? label) {
    switch (label?.toLowerCase()) {
      case 'harassment':
      case 'harassment/threatening':
        return '⚠️ Your message contains harassment or threats.';
      case 'hate':
      case 'hate/threatening':
        return '⚠️ Your message contains hate speech.';
      case 'sexual':
      case 'sexual/minors':
        return '⚠️ Your message contains explicit sexual content.';
      case 'violence':
      case 'violence/graphic':
        return '⚠️ Your message contains violent content.';
      case 'self-harm':
      case 'self-harm/intent':
      case 'self-harm/instructions':
        return '⚠️ Your message contains self-harm content.';
      default:
        return '⚠️ Your message violates community guidelines.';
    }
  }
}