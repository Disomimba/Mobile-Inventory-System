import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Helper method to hash the password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('username', username)
          .eq('password', hashedPassword)
          .maybeSingle();

      return response;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      print("Get Profile Error: $e");
      return null;
    }
  }
}