import 'package:dio/dio.dart';
import '../../words/domain/dio_error_extension.dart';

class AppNotification {
  final String id;
  final String type;
  final String message;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      read: json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class NotificationsRepository {
  final Dio _dio;

  NotificationsRepository({required Dio dio}) : _dio = dio;

  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final response = await _dio.get('/api/v1/notifications');
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        return data.map((json) => AppNotification.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.post('/api/v1/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }
}
