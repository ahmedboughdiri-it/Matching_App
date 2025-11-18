import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Secure password hashing service using PBKDF2
/// Add to pubspec.yaml: crypto: ^3.0.3
class PasswordHashService {
  static const int _iterations = 10000;
  static const int _saltLength = 32;
  static const int _hashLength = 64;

  /// Hash a password securely
  static String hashPassword(String password) {
    // Generate random salt
    final salt = _generateSalt();

    // Hash password with salt
    final hash = _pbkdf2(password, salt);

    // Combine salt and hash for storage
    // Format: salt:hash (both in base64)
    return '${base64.encode(salt)}:${base64.encode(hash)}';
  }

  /// Verify a password against stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      // Split stored hash into salt and hash
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final salt = base64.decode(parts[0]);
      final originalHash = base64.decode(parts[1]);

      // Hash the input password with the same salt
      final newHash = _pbkdf2(password, salt);

      // Compare hashes in constant time (prevent timing attacks)
      return _constantTimeCompare(originalHash, newHash);
    } catch (e) {
      print('Password verification error: $e');
      return false;
    }
  }

  /// Generate random salt
  static List<int> _generateSalt() {
    final random = Random.secure();
    return List.generate(_saltLength, (_) => random.nextInt(256));
  }

  /// PBKDF2 implementation using SHA-256
  static List<int> _pbkdf2(String password, List<int> salt) {
    var hmac = Hmac(sha256, utf8.encode(password));
    var result = <int>[];

    // Simple PBKDF2 implementation
    for (var i = 0; i < _hashLength / 32; i++) {
      var block = List<int>.from(salt)..addAll([0, 0, 0, i + 1]);
      var u = hmac.convert(block).bytes;
      var output = List<int>.from(u);

      for (var j = 1; j < _iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < output.length; k++) {
          output[k] ^= u[k];
        }
      }

      result.addAll(output);
    }

    return result.sublist(0, _hashLength);
  }

  /// Constant-time comparison to prevent timing attacks
  static bool _constantTimeCompare(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }

  /// Validate password strength
  static Map<String, dynamic> validatePasswordStrength(String password) {
    final errors = <String>[];

    if (password.length < 8) {
      errors.add('Password must be at least 8 characters long');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one number');
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain at least one special character');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'strength': _calculateStrength(password),
    };
  }

  /// Calculate password strength score (0-100)
  static int _calculateStrength(String password) {
    var score = 0;

    // Length score (max 40 points)
    score += (password.length * 4).clamp(0, 40);

    // Variety score (max 60 points)
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 15;

    // Mixed case bonus
    if (password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[a-z]'))) {
      score += 15;
    }

    return score.clamp(0, 100);
  }
}