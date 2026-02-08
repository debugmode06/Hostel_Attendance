class Student {
  final String studentId;
  final String name;
  final String roomNo;
  final String dept;
  final String category;
  final String college;
  final bool faceRegistered;
  final String leaveStatus;
  final DateTime? leaveUntil;

  Student({
    required this.studentId,
    required this.name,
    required this.roomNo,
    required this.dept,
    required this.category,
    required this.college,
    this.faceRegistered = false,
    this.leaveStatus = 'none',
    this.leaveUntil,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      // backend may return `regNo` or `studentId` depending on server version
      studentId: json['regNo'] ?? json['studentId'] ?? '',
      name: json['name'] ?? '',
      roomNo: json['roomNo'] ?? '',
      dept: json['dept'] ?? '',
      category: json['category'] ?? '',
      college: json['college'] ?? '',
      faceRegistered: json['faceRegistered'] ?? false,
      leaveStatus: json['leaveStatus'] ?? 'none',
      leaveUntil: json['leaveUntil'] != null
          ? DateTime.tryParse(json['leaveUntil'].toString())
          : null,
    );
  }

  bool get isOnLeave => leaveStatus == 'on_leave' || leaveStatus == 'medical';
}
