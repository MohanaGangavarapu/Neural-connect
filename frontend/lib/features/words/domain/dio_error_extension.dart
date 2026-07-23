import 'package:dio/dio.dart';

extension DioExceptionExtension on DioException {
  String get errorMessage {
    try {
      if (response != null && response!.data != null) {
        final data = response!.data;
        if (data is Map) {
          final error = data['error'];
          if (error is Map) {
            final message = error['message'];
            if (message != null) {
              return message.toString();
            }
          }
        }
      }
    } catch (_) {
      // Fallback if parsing fails
    }
    
    // Provide descriptive message based on exception type
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout with server';
      case DioExceptionType.sendTimeout:
        return 'Send timeout in connection';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout in connection';
      case DioExceptionType.badCertificate:
        return 'Invalid server certificate';
      case DioExceptionType.badResponse:
        final code = response?.statusCode;
        return 'Received invalid response from server' + (code != null ? ' (Status Code: $code)' : '');
      case DioExceptionType.cancel:
        return 'Request to server was cancelled';
      case DioExceptionType.connectionError:
        return 'No internet connection or server unreachable';
      case DioExceptionType.unknown:
      default:
        return 'An unexpected network error occurred';
    }
  }
}
