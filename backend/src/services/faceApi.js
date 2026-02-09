/**
 * Hugging Face Face Recognition API Service
 * Endpoints:
 * - GET  /health
 * - POST /register (multipart/form-data with 'image' and 'regNo' fields)
 * - POST /verify (multipart/form-data with 'image' field)
 */
import FormData from "form-data";
import fetch from "node-fetch";

const FACE_API_URL = (
  process.env.FACE_API_URL || "https://mohans143-face-attendance-api.hf.space"
).replace(/\/$/, "");

// Increased to 60s to handle cold starts
const FACE_API_TIMEOUT_MS = Number(process.env.FACE_API_TIMEOUT_MS) || 60000;
const FACE_API_TEST_MODE = process.env.FACE_API_TEST_MODE === "true";

console.log(
  `[FACE API] Initialized with URL: ${FACE_API_URL}, Test Mode: ${FACE_API_TEST_MODE}`,
);

/**
 * L2 Normalization - CRITICAL for face recognition consistency
 * Normalizes embedding vector to unit length
 */
function normalizeEmbedding(embedding) {
  if (!Array.isArray(embedding) || embedding.length === 0) {
    console.error("[FACE API] Cannot normalize empty embedding");
    return embedding;
  }

  const norm = Math.sqrt(
    embedding.reduce((sum, val) => sum + val * val, 0)
  );

  if (norm === 0) {
    console.error("[FACE API] Cannot normalize zero-norm embedding");
    return embedding;
  }

  const normalized = embedding.map(val => val / norm);
  // console.log(`[FACE API] ✅ Embedding normalized (L2 norm: ${norm.toFixed(4)} → 1.0000)`);
  return normalized;
}

/**
 * Generate a deterministic mock embedding from regNo (for testing)
 */
function generateMockEmbedding(regNo) {
  const hash = regNo.split("").reduce((acc, char) => {
    return (acc << 5) - acc + char.charCodeAt(0);
  }, 0);

  const embedding = [];
  let seed = Math.abs(hash);
  for (let i = 0; i < 384; i++) {
    seed = (seed * 9301 + 49297) % 233280;
    embedding.push((seed / 233280) * 2 - 1);
  }
  // Normalize mock embedding too
  return normalizeEmbedding(embedding);
}

/**
 * Check if Face API is healthy
 */
export async function checkFaceApiHealth() {
  if (FACE_API_TEST_MODE) return true;
  if (!FACE_API_URL) return false;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout for health

    const response = await fetch(`${FACE_API_URL}/health`, {
      method: "GET",
      signal: controller.signal,
    });

    clearTimeout(timeoutId);
    return response.ok;
  } catch (err) {
    console.warn("[FACE API] Health check failed:", err.message);
    return false;
  }
}

/**
 * Warm up the Face API on server start to reduce cold start latency
 */
export async function warmUpFaceApi() {
  if (FACE_API_TEST_MODE) return;
  console.log("[FACE API] 🔥 Warming up Hugging Face Space...");

  // Fire and forget - don't block server start
  checkFaceApiHealth().then((healthy) => {
    if (healthy) console.log("[FACE API] ✅ Service is warm and ready");
    else console.log("[FACE API] ⚠️ Service might be cold or down (will retry on request)");
  }).catch(() => { });
}

/**
 * Health check with retry
 */
async function ensureHealthy(retries = 2) {
  let lastErr;
  for (let i = 0; i <= retries; i++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000);
      const res = await fetch(`${FACE_API_URL}/health`, {
        signal: controller.signal,
      });
      clearTimeout(timeoutId);
      if (res.ok) return true;
    } catch (err) {
      lastErr = err;
      if (i < retries) {
        console.log(`[FACE API] Health check retry ${i + 1}/${retries}...`);
        await new Promise((r) => setTimeout(r, 1500));
      }
    }
  }
  if (lastErr?.name === "AbortError")
    throw new Error("Health check timeout (408)");
  throw new Error("Face service unavailable (503)");
}

/**
 * Register face: Convert base64 image to file and send as multipart/form-data
 * @param {string} regNo - Student registration number
 * @param {string} imageBase64 - Base64 encoded image
 * @returns {Promise<{ success: boolean, embedding?: number[] }>}
 */
export async function registerFace(regNo, imageBase64) {
  // Validate input
  const img = String(imageBase64).trim();
  const normalizedRegNo = String(regNo).trim().toUpperCase();

  if (!img || img.length < 100) throw new Error("Invalid image data");
  if (!normalizedRegNo) throw new Error("Invalid registration number");

  if (FACE_API_TEST_MODE) {
    console.log(
      "[FACE API TEST MODE] Generating mock embedding for regNo:",
      normalizedRegNo,
    );
    await new Promise((resolve) => setTimeout(resolve, 300));
    return { success: true, embedding: generateMockEmbedding(normalizedRegNo) };
  }

  if (!FACE_API_URL) throw new Error("FACE_API_URL is not set");

  try {
    // Health check before register
    // await ensureHealthy(1); // Skip explicit health check to save time, rely on main call

    console.log(`[FACE API] Registering face for regNo: ${normalizedRegNo}`);

    const imageBuffer = Buffer.from(img, "base64");
    const form = new FormData();
    form.append("image", imageBuffer, {
      filename: "face.jpg",
      contentType: "image/jpeg",
    });
    form.append("regNo", normalizedRegNo);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FACE_API_TIMEOUT_MS);

    const response = await fetch(`${FACE_API_URL}/register`, {
      method: "POST",
      body: form,
      headers: form.getHeaders(),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      const text = await response.text();
      console.error(
        `[FACE API] Register failed with status ${response.status}:`,
        text,
      );
      if (response.status === 503)
        throw new Error("Face service unavailable (503)");
      if (response.status >= 400 && response.status < 500)
        throw new Error(
          `Face registration failed: ${text || `HTTP ${response.status}`}`,
        );
      throw new Error(`Face API error: ${response.status}`);
    }

    const data = await response.json();
    console.log("[FACE API] Register success:", {
      regNo: normalizedRegNo,
      hasEmbedding: !!data.embedding,
    });

    // 🔥 CRITICAL: Normalize embedding using L2 normalization
    const rawEmbedding = data.embedding || data.data?.embedding || [];
    const normalizedEmbedding = normalizeEmbedding(rawEmbedding);

    return {
      success: true,
      embedding: normalizedEmbedding,
    };
  } catch (err) {
    if (err.name === "AbortError")
      throw new Error("Face registration timeout (408)");
    console.error("[FACE API] Register error:", err.message);
    throw err;
  }
}

/**
 * Verify/match face: send image to HF /register endpoint to get embedding,
 * then compare locally against all stored embeddings
 * @param {string} imageBase64 - Base64 encoded image
 * @param {Array} storedEmbeddings - array of { regNo, embedding } from database
 * @returns {Promise<{ regNo: string|null, confidence: number }>}
 */
export async function matchFace(imageBase64, storedEmbeddings = []) {
  const img = String(imageBase64);

  if (FACE_API_TEST_MODE) {
    console.log("[FACE API TEST MODE] Local embedding comparison");
    // Generate embedding from image string deterministically
    const imageHashEmbedding = generateMockEmbedding(String(img).slice(0, 20));

    let best = { regNo: null, confidence: 0 };
    console.log(`[FACE API TEST MODE] Comparing against ${storedEmbeddings.length} stored embeddings...`);

    for (const s of storedEmbeddings) {
      const storedEmb = normalizeEmbedding(s.embedding || []);
      const sim = cosineSimilarity(imageHashEmbedding, storedEmb);
      // console.log(`[FACE API TEST MODE]   ${s.regNo}: similarity = ${sim.toFixed(4)}`);

      if (sim > best.confidence) {
        best = { regNo: s.regNo, confidence: sim };
      }
    }

    // console.log(`[FACE API TEST MODE] Best match: ${best.regNo} with confidence ${best.confidence.toFixed(4)}`);
    return { regNo: best.regNo, confidence: best.confidence };
  }

  if (!FACE_API_URL) throw new Error("FACE_API_URL is not set");

  try {
    console.log("[FACE API] Extracting embedding from incoming image...");

    // Step 1: Get embedding from the incoming image using /register endpoint
    // We use /register because it returns the embedding. /verify on HF side might do comparison, but we do local comparison here.
    // The user's request implies "Facenet model" which usually returns 128/512d vector.

    const imageBuffer = Buffer.from(img, "base64");

    let data;
    let attempts = 0;
    // Retry logic
    while (attempts < 2) {
      attempts++;
      try {
        const form = new FormData();
        form.append("image", imageBuffer, {
          filename: "face.jpg",
          contentType: "image/jpeg",
        });
        form.append("regNo", "TEMP_VERIFY");

        const controller = new AbortController();
        // First attempt 25s, second 45s
        const currentTimeout = attempts === 1 ? 25000 : 45000;
        const timeoutId = setTimeout(() => controller.abort(), currentTimeout);

        console.log(`[FACE API] Requesting embedding (Attempt ${attempts})...`);
        const response = await fetch(`${FACE_API_URL}/register`, {
          method: "POST",
          body: form,
          headers: form.getHeaders(),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (!response.ok) {
          if (response.status >= 500 && attempts < 2) {
            console.log(`[FACE API] Server error ${response.status}, retrying...`);
            await new Promise(r => setTimeout(r, 1500));
            continue;
          }
          const text = await response.text();
          throw new Error(`Face API error: ${response.status} ${text}`);
        }

        data = await response.json();
        break; // success
      } catch (e) {
        console.warn(`[FACE API] Attempt ${attempts} error: ${e.message}`);
        if (attempts >= 2) throw e;
        await new Promise(r => setTimeout(r, 1000));
      }
    }

    if (!data || !data.embedding || data.embedding.length === 0) {
      console.error("[FACE API] No face detected in incoming image");
      return { regNo: null, confidence: 0 };
    }

    // Step 2: Normalize the incoming embedding
    const incomingEmbedding = normalizeEmbedding(data.embedding);
    // console.log(`[FACE API] Incoming embedding extracted (${incomingEmbedding.length} dimensions)`);

    // Step 3: Compare against all stored embeddings locally
    let bestMatch = { regNo: null, confidence: 0 };
    // console.log(`\n[FACE API] 🔍 Comparing against ${storedEmbeddings.length} stored faces...\n`);

    for (const stored of storedEmbeddings) {
      if (!stored.embedding || stored.embedding.length === 0) {
        // console.log(`[FACE API]   ${stored.regNo}: ⚠️  No embedding stored`);
        continue;
      }

      // Normalize stored embedding before comparison
      const normalizedStored = normalizeEmbedding(stored.embedding);
      const similarity = cosineSimilarity(incomingEmbedding, normalizedStored);

      // console.log(`[FACE API]   ${stored.regNo}: SIMILARITY = ${similarity.toFixed(4)}`);

      if (similarity > bestMatch.confidence) {
        bestMatch = { regNo: stored.regNo, confidence: similarity };
      }
    }

    // 🔥 CRITICAL: Use threshold of 0.55 for mobile face recognition
    const MATCH_THRESHOLD = 0.55;
    // console.log(`\n[FACE API] ============================================`);
    console.log(`[FACE API] 🎯 Best Match: ${bestMatch.regNo || "NONE"} (${bestMatch.confidence.toFixed(4)})`);
    // console.log(`[FACE API] 📊 Confidence: ${bestMatch.confidence.toFixed(4)}`);
    // console.log(`[FACE API] 🎚️  Threshold:  ${MATCH_THRESHOLD}`);
    // console.log(`[FACE API] ✅ Match: ${bestMatch.confidence >= MATCH_THRESHOLD ? "YES" : "NO"}`);
    // console.log(`[FACE API] ============================================\n`);

    if (bestMatch.confidence < MATCH_THRESHOLD) {
      return { regNo: null, confidence: bestMatch.confidence };
    }

    return {
      regNo: bestMatch.regNo,
      confidence: bestMatch.confidence,
    };
  } catch (err) {
    if (err.name === "AbortError")
      throw new Error("Face verification timeout (408)");
    console.error("[FACE API] Match error:", err.message);
    throw err;
  }
}

// helper: cosine similarity between two numeric arrays
export function cosineSimilarity(a = [], b = []) {
  if (
    !Array.isArray(a) ||
    !Array.isArray(b) ||
    a.length === 0 ||
    b.length === 0
  )
    return 0;

  // Since we normalize beforehand, simple dot product
  let dot = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
  }
  return dot;
}
