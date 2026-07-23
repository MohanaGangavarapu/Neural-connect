import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../words/domain/dio_error_extension.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage;

  Future<void> register(String username, String email, String password) async {
    try {
      final response = await _dio.post('/api/v1/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });

      if (response.statusCode == 201) {
        final token = response.data['data']['token'];
        await _storage.write(key: 'jwt_token', value: token);
      }
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['data']['token'];
        await _storage.write(key: 'jwt_token', value: token);
      }
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null;
  }

  Future<bool> isOnboardingCompleted() async {
    final val = await _storage.read(key: 'onboarding_completed');
    return val == 'true';
  }

  Future<void> completeOnboarding() async {
    await _storage.write(key: 'onboarding_completed', value: 'true');
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/api/v1/auth/account');
      await logout();
      await _storage.delete(key: 'onboarding_completed');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }
}
