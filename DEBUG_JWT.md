# JWT Auth Debug Guide

## Overview

This guide helps verify that JWT authentication is working correctly in the Hostel Face Attendance system.

---

## PART 1: BACKEND LOGS

### Start Backend with Debug Logging

```bash
cd backend
npm start
```

**Expected logs on startup:**

```
Server running on port 5000
MongoDB connected
```

### Login Flow

**Request:**

```
POST http://localhost:5000/api/auth/login
Body: { "username": "warden", "password": "pass123" }
```

**Expected backend logs:**

```
POST /api/auth/login - Authorization: undefined
Login error (if db seed doesn't exist):
  Error: User not found

OR on success:
POST /api/auth/login - Authorization: undefined
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "<userId>",
    "username": "warden",
    "role": "warden"
  }
}
```

### Protected Route Flow

**Request:**

```
GET http://localhost:5000/api/attendance/status
Authorization: Bearer <JWT_TOKEN>
```

**Expected backend logs:**

```
GET /api/attendance/status - Authorization: Bearer eyJ...
Authorization header: Bearer eyJ...
Decoded JWT: { userId: '<id>', role: 'warden', iat: ..., exp: ... }
(then endpoint response)
```

### 401 Response

If token is missing/invalid:

```
GET /api/attendance/status - Authorization: undefined

or

GET /api/attendance/status - Authorization: Bearer invalid_token

Console:
  Authorization header: undefined
  → Status 401: "Token missing or malformed"

OR

  JWT verify failed: jwt malformed
  → Status 401: "Token invalid or expired"
```

---

## PART 2: FLUTTER LOGS

### Configure Flutter to show API logs

The app prints auth/API info to console. Run:

```bash
cd frontend
flutter run -v  # verbose mode shows all logs
```

### Login Flow in Flutter

**Screen:** LoginScreen
**Terminal shows:**

```
AuthService.login - stored token: eyJhbGciOi...
ApiService - Request: POST /auth/login
ApiService - Headers: {Content-Type: application/json, ...}
```

**App behavior:**

- If login succeeds → stores token in flutter_secure_storage → navigates to /warden or /admin
- If login fails → shows "Invalid credentials" or "Connection failed"

### Protected API Call

**After login, when Warden Home loads:**

```
ApiService - Request: GET /students
ApiService - Headers: {
  Authorization: Bearer eyJhbGciOi...,
  Content-Type: application/json,
  ...
}
```

**If token is present and valid:**

- Request succeeds → models load
- No 401 errors

**If token is missing or invalid:**

```
ApiService - Error (GET /students): 401
ApiService - Response data: {message: "Token missing or malformed"}
→ Auto logout triggered
→ Navigate to /login with snackbar: "Session expired, login again"
```

---

## PART 3: TESTING CHECKLIST

### ✅ Backend Tests

1. **Auth endpoint working**

   ```bash
   # Make sure backend is seeded with test user
   npm run seed  # if available

   # or manually create user in MongoDB
   ```

2. **Check JWT_SECRET is set**

   ```bash
   cat backend/.env | grep JWT_SECRET
   # Should output: JWT_SECRET=your_secret_key
   # If not set, backend uses 'fallback-secret'
   ```

3. **Test login endpoint**

   ```bash
   curl -X POST http://localhost:5000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"warden","password":"pass123"}'

   # Should return: {"token":"jwt...","user":{...}}
   ```

4. **Test protected route with token**

   ```bash
   TOKEN="your_jwt_from_login"
   curl -X GET http://localhost:5000/api/attendance/status \
     -H "Authorization: Bearer $TOKEN"

   # Should return: {finalized:false, status:"Open", ...}
   ```

5. **Test protected route without token (401)**

   ```bash
   curl -X GET http://localhost:5000/api/attendance/status

   # Should return: {"message":"Token missing or malformed"} [401]
   ```

### ✅ Flutter Tests

1. **App starts and shows login**
   - Run `flutter run`
   - Should show LoginScreen with username/password fields

2. **Login with valid credentials**
   - Enter username: `warden`
   - Enter password: `pass123`
   - Click Login
   - Should navigate to Warden home (bottom nav bar)
   - Check console for `AuthService.login - stored token: ...`

3. **Check token is stored**
   - Open `flutter_secure_storage` (use Xcode/Android Studio)
   - Should contain key `auth_token` with JWT value

4. **Try to access protected screen**
   - From Home, tap "Get Students" or similar
   - Check console for `ApiService - Request: GET /students` with Authorization header
   - Should load student list without 401

5. **Simulate 401 (optional)**
   - Open backend auth middleware
   - Temporarily break JWT verification
   - Restart backend
   - Reload app
   - App should auto-logout and show "Session expired"

---

## PART 4: TROUBLESHOOTING

### Backend says "User not found"

- Check MongoDB is running and seeded
- Ensure test user exists: `db.users.findOne({username:"warden"})`
- Run `npm run seed` if available

### Flutter shows "Connection failed"

- Ensure backend is running: `npm start`
- Check `lib/config/app_config.dart` baseUrl points to correct backend
- Default: `http://localhost:5000/api`
- For device testing: use machine IP, not localhost

### API returns 401 even with valid token

- Check backend logs for `JWT verify failed`
- Ensure JWT_SECRET matches in backend .env
- Check token format: must be `Bearer <jwt>` not just `<jwt>`
- Check token hasn't expired (JWT_EXPIRES = '7d')

### Flutter secure storage not persisting

- iOS: Check entitlements
- Android: Check uses-permission for `android.permission.USE_CREDENTIALS`
- Clear app cache and try login again

### CORS errors

- Backend main.js already enables CORS with Authorization header
- If still failing, check browser dev tools for exact error

---

## PART 5: PRODUCTION CHECKLIST

Before deploying:

1. **Backend**
   - [ ] Set `JWT_SECRET` in .env (use strong random string)
   - [ ] Set `MONGODB_URI` to production MongoDB
   - [ ] Remove debug console.log statements or use logger
   - [ ] Test all role-based endpoints (warden vs admin)
   - [ ] Set CORS origin to specific frontend domain

2. **Flutter**
   - [ ] Update `AppConfig.baseUrl` to production API
   - [ ] Remove verbose logging (or use logger that respects build mode)
   - [ ] Build release APK/IPA
   - [ ] Test on real device
   - [ ] Verify session persistence after app restart

3. **Security**
   - [ ] Use HTTPS in production
   - [ ] Keep JWT_SECRET safe (never commit to git)
   - [ ] Rotate JWT_SECRET periodically
   - [ ] Implement token refresh logic if JWT_EXPIRES is short

---

## QUICK REFERENCE

| Issue            | Backend Log                  | Flutter Log          | Fix                        |
| ---------------- | ---------------------------- | -------------------- | -------------------------- |
| Missing token    | No Authorization header      | No Bearer in request | Login again                |
| Invalid token    | JWT verify failed            | 401 error            | Token expired, login again |
| Wrong JWT_SECRET | JWT verify failed always     | 401 always           | Sync JWT_SECRET in .env    |
| Missing user     | User not found               | Login returns null   | Seed database              |
| Wrong role       | Forbidden: insufficient role | 403 error            | Use correct account        |

---

## KEY CODE LOCATIONS

**Backend:**

- Auth middleware: `backend/src/middleware/auth.js`
- Login controller: `backend/src/controllers/authController.js`
- Protected routes: `backend/src/routes/*.js`

**Flutter:**

- Auth service: `frontend/lib/services/auth_service.dart`
- API service: `frontend/lib/services/api_service.dart`
- Navigation service: `frontend/lib/services/navigation_service.dart`
- Login screen: `frontend/lib/screens/login_screen.dart`
