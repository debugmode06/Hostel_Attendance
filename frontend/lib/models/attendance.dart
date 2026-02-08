class AttendanceRecord {
  final String studentId;
  final String name;
  final String? roomNo;
  final String? dept;
  final String date;
  final DateTime? time;
  final String status;

  AttendanceRecord({
    required this.studentId,
    required this.name,
    this.roomNo,
    this.dept,
    required this.date,
    this.time,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      studentId: json['studentId'] ?? '',
      name: json['name'] ?? 'Unknown',
      roomNo: json['roomNo'],
      dept: json['dept'],
      date: json['date'] ?? '',
      time: json['time'] != null
          ? DateTime.tryParse(json['time'].toString())
          : null,
      status: json['status'] ?? 'Absent',
    );
  }
}
