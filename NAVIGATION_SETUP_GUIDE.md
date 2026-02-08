# Navigation Setup Guide

This document provides guidance on integrating the new screens into your main.dart navigation.

## Screen Imports

Add these imports to your `main.dart`:

```dart
import 'lib/screens/face_scan_screen_premium.dart';
import 'lib/screens/face_register_screen_auto.dart';
import 'lib/screens/reports_screen.dart';
import 'lib/screens/bulk_student_upload_screen_complete.dart';
import 'lib/screens/pending_students_screen.dart';  // For pending face registration list
```

## Navigation Structure

### Tab 1: Mark Attendance (Warden)

Use `FaceScanScreenPremium()` to replace current attendance marking screen.

```dart
CupertinoTabView(
  builder: (context) => FaceScanScreenPremium(),
)
```

### Tab 2: Register Faces (Admin/Warden)

Navigation to pending face registration list, then can tap each student to register:

```dart
CupertinoTabView(
  builder: (context) => PendingStudentsScreen(),
)
// User taps student → Opens FaceRegisterScreenAuto(regNo, name, onSuccess)
```

### Tab 3: View Reports (Admin/Warden)

Display attendance reports with filters:

```dart
CupertinoTabView(
  builder: (context) => ReportsScreen(),
)
```

### Tab 4: Bulk Upload (Admin)

Upload multiple students at once:

```dart
CupertinoTabView(
  builder: (context) => BulkStudentUploadScreenComplete(),
)
```

## Full Example Tab Structure

```dart
class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.camera),
            label: 'Mark Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_add),
            label: 'Register Faces',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cloud_upload),
            label: 'Bulk Upload',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(builder: (_) => FaceScanScreenPremium());
          case 1:
            return CupertinoTabView(builder: (_) => PendingStudentsScreen());
          case 2:
            return CupertinoTabView(builder: (_) => ReportsScreen());
          case 3:
            return CupertinoTabView(builder: (_) => BulkStudentUploadScreenComplete());
          default:
            return Container();
        }
      },
    );
  }
}
```

## PendingStudentsScreen Implementation

The `PendingStudentsScreen` fetches students with `faceRegistered: false` and displays them in a list. When auto, it opens `FaceRegisterScreenAuto`:

```dart
onTap: () {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (_) => FaceRegisterScreenAuto(
        regNo: student['regNo'],
        studentName: student['name'],
        onSuccess: () {
          // Refresh pending list
          setState(() => _fetchPendingStudents());
        },
      ),
    ),
  );
}
```

## API Endpoints Used

- `GET /students/pending-registration` - Fetch pending face registrations
- `POST /face/register` - Register face by regNo
- `POST /attendance/scan` - Mark attendance by face match
- `GET /attendance/date/{date}` - Fetch attendance for date
- `POST /students/bulk` - Bulk upload students
- `GET /students/count` - Dashboard stats

All endpoints documented in `IMPLEMENTATION_GUIDE_COMPLETE.md`.
