import 'package:hive_flutter/hive_flutter.dart';

class LocalDbService {
  static const String boxAttendance = 'attendance';
  static const String boxStudents = 'students';
  static const String boxPending = 'pending_sync';
  static const String boxAuth = 'auth';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(boxAttendance);
    await Hive.openBox<Map>(boxStudents);
    await Hive.openBox<Map>(boxPending);
    await Hive.openBox(boxAuth);
  }

  static Box<Map> get attendanceBox => Hive.box<Map>(boxAttendance);
  static Box<Map> get studentsBox => Hive.box<Map>(boxStudents);
  static Box<Map> get pendingBox => Hive.box<Map>(boxPending);
  static Box get authBox => Hive.box(boxAuth);

  static void saveAttendanceLocally(String date, Map<String, dynamic> record) {
    final key = '${record['studentId']}_$date';
    attendanceBox.put(key, Map<String, dynamic>.from(record));
  }

  static Map<String, dynamic>? getAttendance(String studentId, String date) {
    final key = '${studentId}_$date';
    return attendanceBox.get(key)?.cast<String, dynamic>();
  }

  static bool hasMarkedToday(String studentId, String date) {
    return getAttendance(studentId, date) != null;
  }

  static void addPendingSync(String action, Map<String, dynamic> data) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    pendingBox.put(id, {'action': action, 'data': data, 'created': id});
  }

  static List<Map<String, dynamic>> getPendingSync() {
    return pendingBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void removePendingSync(String id) {
    pendingBox.delete(id);
  }

  // Auth helpers
  static Future<void> saveToken(String token) async {
    await authBox.put('token', token);
  }

  static String? getToken() => authBox.get('token') as String?;

  static Future<void> clearToken() async => authBox.delete('token');
}
