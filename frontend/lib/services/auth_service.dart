import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kUserId = 'auth_user_id';
  static const _kRole = 'auth_role';

  User? _user;

  User? get currentUser => _user;
  bool get isLoggedIn => _user != null;

  AuthService._();

  /// Attempt login via API, store token + user info securely on success
  Future<bool> login(String username, String password) async {
    try {
      final res = await ApiService().login(username, password);
      final token = res['token'] as String?;
      final userJson = res['user'] as Map<String, dynamic>?;
      if (token == null || userJson == null) return false;

      _user = User.fromJson(userJson);
      // persist securely
      await _secure.write(key: _kToken, value: token);
      await _secure.write(key: _kUser, value: jsonEncode(userJson));
      await _secure.write(key: _kUserId, value: userJson['id']?.toString());
      await _secure.write(key: _kRole, value: userJson['role']?.toString());
      // also set token in ApiService memory for immediate use
      ApiService().setToken(token);
      print('AuthService.login - stored token: $token');
      return true;
    } catch (e) {
      print('AuthService.login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    ApiService().clearToken();
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kUser);
    await _secure.delete(key: _kUserId);
    await _secure.delete(key: _kRole);
  }

  /// Restore session from secure storage; returns true if session restored
  Future<bool> restoreSession() async {
    try {
      final token = await _secure.read(key: _kToken);
      final userStr = await _secure.read(key: _kUser);
      if (token == null || userStr == null) return false;
      final userJson = Map<String, dynamic>.from(jsonDecode(userStr));
      _user = User.fromJson(userJson);
      ApiService().setToken(token);
      return true;
    } catch (e) {
      print('AuthService.restoreSession error: $e');
      return false;
    }
  }

  Future<String?> getToken() => _secure.read(key: _kToken);
  Future<String?> getRole() => _secure.read(key: _kRole);
  Future<String?> getUserId() => _secure.read(key: _kUserId);
}
