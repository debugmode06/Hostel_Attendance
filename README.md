# Hostel Face Attendance System

A full-stack Hostel Face Recognition Attendance System with Flutter (Mobile + Web) and Node.js backend.

## Tech Stack

- **Frontend**: Flutter, Dart, Dio, Hive, Camera, Connectivity Plus
- **Backend**: Node.js, Express.js, MongoDB, Mongoose, JWT
- **Face Recognition**: External hosted API (configure in .env)

## Features

- **Admin**: Dashboard analytics, view/export reports (read-only)
- **Warden**: Mark attendance (face scan), register students, register faces, finalize attendance, manage leave
- **Student Status History**: View attendance timeline, filter by month/year
- **Temporary Leave/Permission**: Mark students as On Leave or Medical (won't auto-mark absent)
- **Face Scan UI**: Circular scanner animation, face bounding box glow, haptic feedback
- **Smart Empty States**: "No pending students", "Attendance finalized for today"
- **Duplicate Scan Protection**: Toast when already marked
- **Smart Scan Feedback**: Green check (Present), Red cross (Not matched), Yellow (Low confidence)
- **Offline-first**: Local storage, pending sync indicator

## Project Structure

```
host/
├── backend/
│   ├── src/
│   │   ├── controllers/
│   │   ├── middleware/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── services/
│   │   └── index.js
│   ├── .env.example
│   └── package.json
├── frontend/
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── theme/
│   │   └── widgets/
│   └── pubspec.yaml
└── README.md
```

## Setup

### Backend

1. `cd backend`
2. Copy `.env.example` to `.env` and configure:
   - `MONGODB_URI` - MongoDB Atlas or local
   - `JWT_SECRET` - Secret for JWT
   - `FACE_API_URL` - External face recognition API URL
   - `FACE_API_KEY` - API key (if required)
3. `npm install`
4. `npm run seed` - Creates admin (admin/admin123) and warden (warden/warden123)
5. `npm run dev` or `npm start`

### Frontend

1. `cd frontend`
2. `flutter pub get`
3. Configure API URL:
   - Default: `http://localhost:5000/api`
   - For Android emulator: use `http://10.0.2.2:5000/api`
   - For web: use your backend URL
   - Build with: `flutter run --dart-define=API_URL=https://your-api.com/api`
4. `flutter run`

### Face Recognition API

Integrate an external hosted Face Recognition API that supports:
- `POST /recognize` - Send base64 image, receive `{ studentId, confidence }`
- `POST /embed` - Send base64 image for registration, receive `{ embedding }`

Configure `FACE_API_URL` and `FACE_API_KEY` in backend `.env`.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/auth/login | Login |
| GET | /api/students | List students |
| POST | /api/students | Create student (warden) |
| PATCH | /api/students/:id/leave | Update leave status |
| POST | /api/students/:id/face | Register face |
| POST | /api/attendance/mark | Mark attendance (face scan) |
| GET | /api/attendance/pending | Pending students |
| POST | /api/attendance/finalize | Finalize attendance |
| GET | /api/attendance/status | Attendance status |
| GET | /api/attendance/history/:studentId | Student attendance history |
| GET | /api/reports | Get report |
| GET | /api/reports/export/pdf | Export PDF |
| GET | /api/reports/export/excel | Export Excel |

## License

MIT
