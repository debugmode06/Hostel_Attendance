import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'navigation_service.dart';
import 'auth_service.dart';

/// Custom exception that includes HTTP status code from Dio
class _DioExceptionWithStatus implements Exception {
  final String message;
  final int statusCode;
  final DioException originalException;

  _DioExceptionWithStatus({
    required this.message,
    required this.statusCode,
    required this.originalException,
  });

  @override
  String toString() => 'DioException($statusCode): $message';
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  late Dio _dio;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  String? _token; // optional in-memory cache for immediate flow

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 40),
        receiveTimeout: const Duration(seconds: 40),
      ),
    );

    // Attach interceptor which reads token from secure storage before each request
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          try {
            final token = _token ?? await _secure.read(key: 'auth_token');
            if (token != null && token.isNotEmpty) {
              opts.headers['Authorization'] = 'Bearer $token';
            }
            // Debug logging
            print('ApiService - Request: ${opts.method} ${opts.path}');
            print('ApiService - Headers: ${opts.headers}');
          } catch (e) {
            print('ApiService.onRequest error: $e');
          }
          return handler.next(opts);
        },
        onError: (err, handler) async {
          // Log error and headers
          print(
            'ApiService - Error (${err.requestOptions.method} ${err.requestOptions.path}): ${err.response?.statusCode}',
          );
          print('ApiService - Response data: ${err.response?.data}');
          final status = err.response?.statusCode;
          if (status == 401) {
            // Clear stored token and perform global logout + navigation
            try {
              await AuthService().logout();
            } catch (e) {
              print('Error during logout: $e');
            }
            try {
              // navigate to login and show session expired message
              NavigationService.navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil('/login', (r) => false);
              final ctx = NavigationService.navigatorKey.currentContext;
              if (ctx != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Session expired, login again'),
                    backgroundColor: null,
                  ),
                );
              }
            } catch (e) {
              print('Navigation on 401 failed: $e');
            }
          }
          return handler.next(err);
        },
      ),
    );
  }

  void setToken(String token) => _token = token;
  void clearToken() {
    _token = null;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<dynamic>> getStudents({
    bool? faceRegistered,
    String? dept,
    String? roomNo,
    String? college,
    String? search,
  }) async {
    final q = <String, dynamic>{};
    if (faceRegistered != null) q['faceRegistered'] = faceRegistered;
    if (dept != null && dept.isNotEmpty) q['dept'] = dept;
    if (roomNo != null && roomNo.isNotEmpty) q['roomNo'] = roomNo;
    if (college != null && college.isNotEmpty) q['college'] = college;
    if (search != null && search.isNotEmpty) q['search'] = search;
    final res = await _dio.get('/students', queryParameters: q);
    return List<dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    // backend expects regNo (not studentId)
    final res = await _dio.post('/students', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> updateLeaveStatus(
    String studentId,
    String leaveStatus,
    DateTime? leaveUntil,
  ) async {
    final res = await _dio.patch(
      '/students/$studentId/leave',
      data: {
        'leaveStatus': leaveStatus,
        if (leaveUntil != null) 'leaveUntil': leaveUntil.toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> registerFace(
    String studentId,
    String imageBase64,
  ) async {
    // use new face API route
    try {
      print(
        'API: Registering face for regNo=$studentId, imageSize=${imageBase64.length} bytes',
      );
      final res = await _dio.post(
        '/face/register',
        data: {'regNo': studentId, 'image': imageBase64},
      );
      print('API: Face register success: ${res.data}');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      print(
        'API: Face register error - status=${e.response?.statusCode}, message=${e.response?.data?['message']}',
      );
      // Re-throw with error details for caller to handle
      throw _DioExceptionWithStatus(
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        statusCode: e.response?.statusCode ?? 500,
        originalException: e,
      );
    }
  }

  Future<Map<String, dynamic>> scanAttendance(String imageBase64) async {
    try {
      final res = await _dio.post('/face/verify', data: {'image': imageBase64});
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _DioExceptionWithStatus(
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        statusCode: e.response?.statusCode ?? 500,
        originalException: e,
      );
    }
  }

  Future<Map<String, dynamic>> getStudentCounts() async {
    final res = await _dio.get('/students/count');
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<dynamic>> getPendingStudents() async {
    final res = await _dio.get('/attendance/pending');
    return List<dynamic>.from(res.data);
  }

  Future<void> finalizeAttendance() async {
    await _dio.post('/attendance/finalize');
  }

  Future<Map<String, dynamic>> getAttendanceStatus() async {
    final res = await _dio.get('/attendance/status');
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<dynamic>> getStudentAttendanceHistory(
    String studentId, {
    int? month,
    int? year,
  }) async {
    final q = <String, dynamic>{};
    if (month != null) q['month'] = month;
    if (year != null) q['year'] = year;
    final res = await _dio.get(
      '/attendance/history/$studentId',
      queryParameters: q.isNotEmpty ? q : null,
    );
    return List<dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> bulkCreateStudents(
    List<Map<String, dynamic>> rows,
  ) async {
    final res = await _dio.post('/students/bulk', data: rows);
    return Map<String, dynamic>.from(res.data);
  }

  // Reports endpoints matching spec
  Future<Map<String, dynamic>> getReportToday() async {
    final res = await _dio.get('/reports/today');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getReportByDate(String yyyyMmDd) async {
    final res = await _dio.get('/reports/date/$yyyyMmDd');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getReportByMonth(String yyyyMm) async {
    final res = await _dio.get('/reports/month/$yyyyMm');
    return Map<String, dynamic>.from(res.data);
  }

  // Generic report endpoint (delegates to getReportByDate if date param provided)
  Future<Map<String, dynamic>> getReport({
    String? date,
    String? dept,
    String? section,
    String? status,
  }) async {
    if (date != null) {
      return getReportByDate(date);
    }
    final q = <String, dynamic>{};
    if (dept != null) q['dept'] = dept;
    if (section != null) q['section'] = section;
    if (status != null) q['status'] = status;
    final res = await _dio.get(
      '/reports',
      queryParameters: q.isNotEmpty ? q : null,
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<dynamic>> getCategories() async {
    final res = await _dio.get('/students/categories');
    return List<dynamic>.from(res.data);
  }

  Future<List<dynamic>> getColleges() async {
    final res = await _dio.get('/students/colleges');
    return List<dynamic>.from(res.data);
  }

  // Generic HTTP methods for flexible API calls
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final res = await _dio.get(endpoint, queryParameters: queryParams);
      return res.data;
    } on DioException catch (e) {
      throw _DioExceptionWithStatus(
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        statusCode: e.response?.statusCode ?? 500,
        originalException: e,
      );
    }
  }

  Future<dynamic> post(String endpoint, {dynamic data}) async {
    try {
      final res = await _dio.post(endpoint, data: data);
      return res.data;
    } on DioException catch (e) {
      throw _DioExceptionWithStatus(
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        statusCode: e.response?.statusCode ?? 500,
        originalException: e,
      );
    }
  }

  Future<dynamic> patch(String endpoint, {dynamic data}) async {
    try {
      final res = await _dio.patch(endpoint, data: data);
      return res.data;
    } on DioException catch (e) {
      throw _DioExceptionWithStatus(
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        statusCode: e.response?.statusCode ?? 500,
        originalException: e,
      );
    }
  }
}
