import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../api_keys.dart';

/// Face Verification Service using Face++ API (Megvii)
/// Get free API key from: https://www.faceplusplus.com/
/// Free tier: 1000 calls/month
class FaceVerificationService {
  // 🔹 Get your FREE API credentials from: https://www.faceplusplus.com/
 static final String _apiKey = ApiKeys.apiKey;
  static final String _apiSecret = ApiKeys.apiSecret;

  static const String _baseUrl = 'https://api-us.faceplusplus.com/facepp/v3';

  /// Verifies if two face images match using Face++ API
  static Future<Map<String, dynamic>> verifyFace({
    required File capturedImage,
    required String profileImagePath,
  }) async {
    try {
      print('Starting face verification with Face++ API...');

      // Convert images to base64
      final capturedBytes = await capturedImage.readAsBytes();
      final capturedBase64 = base64Encode(capturedBytes);
      print('Captured image: ${capturedBytes.length} bytes');

      final profileBytes = await _readAssetImage(profileImagePath);
      final profileBase64 = base64Encode(profileBytes);
      print('Profile image: ${profileBytes.length} bytes');

      // Call Face++ Compare API
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/compare'),
      );

      // Add API credentials
      request.fields['api_key'] = _apiKey;
      request.fields['api_secret'] = _apiSecret;

      // Add images as base64
      request.fields['image_base64_1'] = capturedBase64;
      request.fields['image_base64_2'] = profileBase64;

      print('Sending request to Face++ API...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check for errors in response
        if (data.containsKey('error_message')) {
          return {
            'isVerified': false,
            'similarity': 0.0,
            'confidence': '0',
            'message': 'Error: ${data['error_message']}',
          };
        }

        // Face++ returns confidence score (0-100)
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
        final similarity = confidence / 100; // Convert to 0-1 range

        // Face++ also provides thresholds for different accuracy levels
        final threshold1e3 = (data['thresholds']?['1e-3'] as num?)?.toDouble() ?? 62.0;
        final threshold1e4 = (data['thresholds']?['1e-4'] as num?)?.toDouble() ?? 69.0;
        final threshold1e5 = (data['thresholds']?['1e-5'] as num?)?.toDouble() ?? 74.0;

        // Use 1e-4 threshold (good balance between false positive and false negative)
        final isVerified = confidence > threshold1e4;

        print('Confidence: $confidence');
        print('Threshold: $threshold1e4');
        print('Verification result: $isVerified');

        return {
          'isVerified': isVerified,
          'similarity': similarity,
          'confidence': confidence.toStringAsFixed(1),
          'message': isVerified
              ? '✅ Face verified successfully! (${confidence.toStringAsFixed(0)}% confidence)'
              : '❌ Faces do not match. Please try again.',
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return {
          'isVerified': false,
          'similarity': 0.0,
          'confidence': '0',
          'message': '❌ Invalid API credentials. Please check your Face++ API key.',
        };
      } else {
        return {
          'isVerified': false,
          'similarity': 0.0,
          'confidence': '0',
          'message': 'API Error: ${response.statusCode}',
        };
      }

    } catch (e, stackTrace) {
      print('Face verification error: $e');
      print('Stack trace: $stackTrace');

      return {
        'isVerified': false,
        'similarity': 0.0,
        'confidence': '0',
        'message': 'Error during verification: $e',
      };
    }
  }

  /// Read asset image and return bytes
  static Future<List<int>> _readAssetImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      print('Error loading asset $assetPath: $e');

      try {
        final file = File(assetPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (fileError) {
        print('Error loading file: $fileError');
      }

      return [];
    }
  }

  /// Test API connection
  static Future<bool> testApiConnection() async {
    try {
      // Test with a simple detect endpoint
      final response = await http.post(
        Uri.parse('$_baseUrl/detect'),
        body: {
          'api_key': _apiKey,
          'api_secret': _apiSecret,
          'image_url': 'https://via.placeholder.com/150',
        },
      ).timeout(const Duration(seconds: 10));

      print('API Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('API connection test failed: $e');
      return false;
    }
  }
}