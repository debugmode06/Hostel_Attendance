# Running Hostel Face Attendance App

## Prerequisites

### Backend

- ✅ Node.js running on port 5000
- ✅ MongoDB connected (Atlas)
- ✅ Test users seeded (warden/warden123, admin/admin123)

**Verify backend is running:**

```bash
curl http://localhost:5000/api/health
# Should return: {"status":"ok"}
```

**Seed test users (if needed):**

```bash
cd backend
npm run seed
```

---

## Frontend: Flutter App

### Option 1: Android Emulator (Recommended for Development)

Android emulator has a special IP `10.0.2.2` that refers to the host machine's localhost.

```bash
cd frontend
flutter run
```

The app will automatically use `http://10.0.2.2:5000/api` (configured in `lib/config/app_config.dart`)

**Test login with:**

- Username: `warden`
- Password: `warden123`

---

### Option 2: iOS Simulator

iOS simulator can access host's localhost directly.

```bash
cd frontend
flutter run -d "iPhone Simulator Name"
```

If connection fails, update the API URL:

```bash
flutter run --dart-define=API_URL=http://localhost:5000/api
```

---

### Option 3: Physical Android Device

First, find your machine's IP address:

**Windows (PowerShell):**

```powershell
ipconfig | findstr "IPv4"
# Look for your local network IP (e.g., 192.168.1.100)
```

**Mac/Linux:**

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Then run:

```bash
cd frontend
flutter run --dart-define=API_URL=http://192.168.1.100:5000/api
```

Replace `192.168.1.100` with your actual machine IP.

---

### Option 4: Web (Chrome)

Use localhost directly:

```bash
cd frontend
flutter run -d chrome --dart-define=API_URL=http://localhost:5000/api
```

---

### Option 5: Windows/macOS Desktop

```bash
cd frontend
flutter run -d windows
# or: flutter run -d macos
```

Uses default API URL: `http://localhost:5000/api`

---

## Troubleshooting

### "Connection refused" or "Network error"

**Check backend is running:**

```bash
cd backend
npm start
```

**Check the right API URL is being used:**

- Android emulator: `http://10.0.2.2:5000/api`
- iOS simulator: `http://localhost:5000/api`
- Physical device: `http://192.168.X.X:5000/api` (your machine's IP)

### "Version mismatch" errors in console

Clear Flutter cache:

```bash
flutter clean
cd frontend
flutter pub get
```

### "Cannot read properties of undefined (reading 'write')" on backend

This was a port 5000 conflict. Kill existing process:

```bash
# Windows PowerShell
netstat -ano | findstr :5000
taskkill /PID <PID> /F
```

---

## Quick Start Commands

**Terminal 1 - Start Backend:**

```bash
cd backend
npm start
```

**Terminal 2 - Seed Users:**

```bash
cd backend
npm run seed
```

**Terminal 3 - Run Flutter (Android Emulator):**

```bash
cd frontend
flutter run
```

**Then login with:**

- Username: `warden` or `admin`
- Password: `warden123` or `admin123`

---

## API Endpoints (for reference)

| Endpoint                   | Method | Protected | Role   |
| -------------------------- | ------ | --------- | ------ |
| `/api/auth/login`          | POST   | ❌        | Any    |
| `/api/attendance/status`   | GET    | ✅        | Any    |
| `/api/attendance/scan`     | POST   | ✅        | Warden |
| `/api/attendance/finalize` | POST   | ✅        | Warden |
| `/api/students`            | GET    | ✅        | Any    |
| `/api/students`            | POST   | ✅        | Warden |
| `/api/reports/today`       | GET    | ✅        | Any    |
| `/api/reports/date/:date`  | GET    | ✅        | Any    |

All protected endpoints require `Authorization: Bearer <JWT_TOKEN>` header (auto-attached by Flutter app).

---

## Testing JWT Auth

Use the JWT token from login to test protected endpoints:

```bash
# Login
$json = @{username="warden";password="warden123"} | ConvertTo-Json
$response = Invoke-WebRequest -Uri http://localhost:5000/api/auth/login `
  -Method Post -Body $json -ContentType "application/json" -UseBasicParsing
$token = ($response.Content | ConvertFrom-Json).token

# Use token on protected endpoint
Invoke-WebRequest -Uri http://localhost:5000/api/attendance/status `
  -Headers @{"Authorization" = "Bearer $token"} `
  -UseBasicParsing
```

---

## Default Credentials

| Role   | Username | Password    |
| ------ | -------- | ----------- |
| Warden | `warden` | `warden123` |
| Admin  | `admin`  | `admin123`  |

> ⚠️ **Production**: Change these credentials and use strong passwords!
