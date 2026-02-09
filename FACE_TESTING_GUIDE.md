# 🧪 Face Recognition Testing Guide

## Quick Smoke Test (5 minutes)

### Prerequisites
- Backend server running (`cd backend && npm run dev`)
- Mobile app connected to backend
- At least one student registered (without face)

### Test Steps

#### 1. Register a Face
1. Open the app
2. Go to **Face Registration** screen
3. Select a student
4. Take a photo
5. **IMPORTANT:** Save this photo or remember the student

**Expected Log Output:**
```
[FACE API] ✅ Embedding normalized (L2 norm: 12.xxxx → 1.0000)
[FACE API] Register success: { regNo: 'STUDENTXXX', hasEmbedding: true }
[FACE] Student face registration complete: STUDENTXXX
```

#### 2. Verify Same Student (Critical Test)
1. Go to **Mark Attendance** screen
2. Use the **SAME student** you just registered
3. Take a **new photo** (or ideally same lighting)
4. Press scan

**Expected Log Output:**
```
[FACE] 🎯 Starting face verification...
[FACE] Fetching all registered students from database...
[FACE] Found X registered students
[FACE] Calling matchFace with stored embeddings...
[FACE API] Extracting embedding from incoming image...
[FACE API] ✅ Embedding normalized (L2 norm: 11.xxxx → 1.0000)
[FACE API] Incoming embedding extracted (384 dimensions)

[FACE API] 🔍 Comparing against X stored faces...

[FACE API]   STUDENTXXX: SIMILARITY = 0.7234  ← Should be HIGH
[FACE API]   STUDENTYYY: SIMILARITY = 0.2145
[FACE API]   STUDENTZZZ: SIMILARITY = 0.1823
...

[FACE API] ============================================
[FACE API] 🎯 Best Match: STUDENTXXX
[FACE API] 📊 Confidence: 0.7234
[FACE API] 🎚️  Threshold:  0.55
[FACE API] ✅ Match: YES
[FACE API] ============================================

[FACE] Match result: regNo=STUDENTXXX, confidence=0.7234
[FACE] ✅ Face matched for student: STUDENTXXX (Student Name) with confidence 0.7234
```

**Expected App Behavior:**
- ✅ Shows "Success" message
- ✅ Displays student name
- ✅ Marks attendance

### ❌ If It Fails

#### Check 1: Similarity Scores
Look at the logs for `SIMILARITY =` values.

**If all scores are low (< 0.4):**
- Issue: Embeddings might not be normalized correctly
- Action: Check if `normalizeEmbedding()` is being called

**If scores are random:**
- Issue: Different preprocessing pipeline
- Action: Verify both use `/register` endpoint

**If best match is correct student but < 0.55:**
- Mobile conditions might need lower threshold
- Try threshold of **0.50** or **0.48**

#### Check 2: Database Embeddings
Connect to MongoDB and verify:
```javascript
db.students.findOne({ faceRegistered: true })
```

Should show:
- `faceEmbedding`: Array of 384 numbers
- Values should NOT all be zeros
- Values should be in range [-1, 1]

#### Check 3: Backend Logs
Ensure logging shows:
- ✅ `Embedding normalized`
- ✅ `Comparing against X stored faces`
- ✅ Individual similarity scores

## 📊 Interpreting Results

### Similarity Score Meanings

| Score Range | Meaning | Action |
|------------|---------|--------|
| **0.70 - 0.90** | Excellent match | ✅ Working perfectly |
| **0.60 - 0.70** | Good match | ✅ Working well |
| **0.55 - 0.60** | Acceptable match | ✅ Threshold is good |
| **0.45 - 0.55** | Almost match | ⚠️  Lower threshold to 0.50 |
| **0.30 - 0.45** | Different person | ❌ Check normalization |
| **0.00 - 0.30** | Very different | ❌ Check preprocessing |

### Common Issues

#### Issue: "No registered faces in database"
**Cause:** No students have `faceRegistered: true`  
**Fix:** Register at least one face first

#### Issue: All similarities are ~0.50
**Cause:** Embeddings might not be normalized  
**Fix:** Check normalizeEmbedding() is called with valid data

#### Issue: Similarities are negative or > 1.0
**Cause:** Cosine similarity calculation error  
**Fix:** Verify cosineSimilarity() function

#### Issue: "Face service unavailable (503)"
**Cause:** Hugging Face Space is sleeping/loading  
**Fix:** 
- Wait 30 seconds and try again
- Or set `FACE_API_TEST_MODE=true` in `.env` for testing

## 🎯 Success Criteria

✅ **System is working if:**
1. Same person gets similarity **≥ 0.55**
2. Different people get similarity **< 0.45**
3. Registered faces are verified successfully
4. Logs show normalization happening
5. Threshold of 0.55 allows valid matches

❌ **System needs adjustment if:**
1. Same person gets **< 0.50** consistently
2. Different people get **> 0.60**
3. Random results (no consistency)

## 🔧 Threshold Tuning

If needed, adjust threshold in `backend/src/services/faceApi.js`:

```javascript
// Line ~296
const MATCH_THRESHOLD = 0.55;  // Change this value

// Conservative (fewer false positives): 0.60 - 0.65
// Balanced (recommended): 0.55
// Forgiving (more matches): 0.50 - 0.52
// Too lenient (security risk): < 0.48
```

## 📱 Mobile Testing Tips

1. **Consistent Lighting:** Test in similar lighting conditions
2. **Face Position:** Center face in the frame
3. **Distance:** Keep similar distance from camera
4. **Angle:** Face camera straight on
5. **Multiple Tests:** Try 3-5 times to verify consistency

## ✨ Expected Timeline

- **Before fixes:** 100% failure rate
- **After fixes:** 80-95% success rate (with good lighting)
- **Optimal conditions:** 95%+ success rate

