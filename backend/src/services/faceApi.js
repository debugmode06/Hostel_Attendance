/**
 * Hugging Face Face Recognition API Service
 * Endpoints:
 * - GET  /health
 * - POST /register (multipart/form-data with 'image' and 'regNo' fields)
 * - POST /verify (multipart/form-data with 'image' field)
 */
import FormData from "form-data";

const FACE_API_URL = (
  process.env.FACE_API_URL || "https://mohans143-face-attendance-api.hf.space"
).replace(/\/$/, "");
const FACE_API_TIMEOUT_MS = Number(process.env.FACE_API_TIMEOUT_MS) || 60000;
const FACE_API_TEST_MODE = process.env.FACE_API_TEST_MODE === "true";

console.log(
  `[FACE API] Initialized with URL: ${FACE_API_URL}, Test Mode: ${FACE_API_TEST_MODE}`,
);

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
  return embedding;
}

/**
 * Check if Face API is healthy
 */
export async function checkFaceApiHealth() {
  if (FACE_API_TEST_MODE) return true;
  if (!FACE_API_URL) return false;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FACE_API_TIMEOUT_MS);

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
 * Register face: Convert base64 image to file and send as multipart/form-data
 * @param {string} regNo - Student registration number
 * @param {string} imageBase64 - Base64 encoded image
 * @returns {Promise<{ success: boolean, embedding?: number[] }>}
 */
export async function registerFace(regNo, imageBase64) {
  // Normalize input
  const img = String(imageBase64);

  if (FACE_API_TEST_MODE) {
    console.log(
      "[FACE API TEST MODE] Generating mock embedding for regNo:",
      regNo,
    );
    await new Promise((resolve) => setTimeout(resolve, 300));
    return { success: true, embedding: generateMockEmbedding(regNo) };
  }

  if (!FACE_API_URL) throw new Error("FACE_API_URL is not set");

  try {
    console.log(`[FACE API] Registering face for regNo: ${regNo}`);

    const imageBuffer = Buffer.from(img, "base64");

    const form = new FormData();
    form.append("image", imageBuffer, {
      filename: "face.jpg",
      contentType: "image/jpeg",
    });
    form.append("regNo", regNo);

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
      throw new Error(`Face API error: ${response.status} - ${text}`);
    }

    const data = await response.json();
    console.log("[FACE API] Register success:", {
      regNo,
      hasEmbedding: !!data.embedding,
    });

    return {
      success: true,
      embedding: data.embedding || data.data?.embedding || [],
    };
  } catch (err) {
    if (err.name === "AbortError")
      throw new Error("Face registration timeout (408)");
    console.error("[FACE API] Register error:", err.message);
    throw err;
  }
}

/**
 * Verify/match face: send image to HF /verify endpoint
 * @param {string} imageBase64 - Base64 encoded image
 * @returns {Promise<{ regNo: string|null, confidence: number }>}
 */
export async function matchFace(imageBase64, storedEmbeddings = []) {
  // storedEmbeddings: array of { regNo, embedding }
  const img = String(imageBase64);

  if (FACE_API_TEST_MODE) {
    console.log("[FACE API TEST MODE] Local embedding comparison");
    // Generate embedding from image string deterministically
    const imageHashEmbedding = generateMockEmbedding(String(img).slice(0, 20));

    let best = { regNo: null, confidence: 0 };
    for (const s of storedEmbeddings) {
      const sim = cosineSimilarity(imageHashEmbedding, s.embedding || []);
      if (sim > best.confidence) {
        best = { regNo: s.regNo, confidence: sim };
      }
    }
    console.log(
      "[FACE API TEST MODE] Compared",
      storedEmbeddings.length,
      "embeddings. Best:",
      best,
    );
    return { regNo: best.regNo, confidence: best.confidence };
  }

  if (!FACE_API_URL) throw new Error("FACE_API_URL is not set");

  try {
    console.log("[FACE API] Matching face");
    const imageBuffer = Buffer.from(img, "base64");
    const form = new FormData();
    form.append("image", imageBuffer, {
      filename: "face.jpg",
      contentType: "image/jpeg",
    });

    // If storedEmbeddings provided, send as JSON string field
    if (Array.isArray(storedEmbeddings) && storedEmbeddings.length > 0) {
      const onlyEmb = storedEmbeddings.map((s) => ({
        regNo: s.regNo,
        embedding: s.embedding,
      }));
      form.append("embeddings", JSON.stringify(onlyEmb));
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FACE_API_TIMEOUT_MS);

    const response = await fetch(`${FACE_API_URL}/verify`, {
      method: "POST",
      body: form,
      headers: form.getHeaders(),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      const text = await response.text();
      console.error(
        "[FACE API] Match failed with status",
        response.status,
        text,
      );
      if (response.status === 503)
        throw new Error("Face service unavailable (503)");
      throw new Error(`Face API error: ${response.status}`);
    }

    const data = await response.json();
    const regNo = data.regNo || data.studentId || data.data?.regNo || null;
    const confidence = Number(data.confidence || data.data?.confidence || 0);
    console.log("[FACE API] Match result:", { regNo, confidence });
    return { regNo: regNo ? String(regNo) : null, confidence };
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
  const len = Math.min(a.length, b.length);
  let dot = 0,
    na = 0,
    nb = 0;
  for (let i = 0; i < len; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}
