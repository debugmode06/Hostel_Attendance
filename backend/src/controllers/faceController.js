import Student from "../models/Student.js";
import {
  registerFace as registerFaceWithHF,
  matchFace,
  checkFaceApiHealth,
} from "../services/faceApi.js";
import Jimp from "jimp";

/**
 * POST /api/face/register
 * Register a student's face with preprocessing and health check
 */
export async function registerFace(req, res) {
  try {
    // Validate inputs
    const { regNo, imageBase64, image } = req.body;
    const imageData = imageBase64 || image;

    if (!regNo) {
      return res.status(400).json({ success: false, message: "regNo is required" });
    }
    if (!imageData) {
      return res.status(400).json({ success: false, message: "imageBase64 or image is required" });
    }

    // Normalize regNo
    const normalizedRegNo = String(regNo).trim().toUpperCase();

    // Verify student exists by regNo (unique key)
    const student = await Student.findOne({ regNo: normalizedRegNo });
    if (!student) {
      console.error("[FACE] Student not found:", normalizedRegNo);
      return res.status(404).json({
        success: false,
        message: `Student with register number ${normalizedRegNo} not found. Please verify and try again.`,
      });
    }

    // Check if face already registered
    if (student.faceRegistered) {
      return res.status(400).json({
        success: false,
        message: "Face already registered for this student",
      });
    }

    console.log(`[FACE] Registering face for student: ${normalizedRegNo}`);

    // Image preprocessing: resize to 224x224 and check quality
    let finalImageBase64 = imageData;
    try {
      const imgBuffer = Buffer.from(String(imageData), "base64");
      const jimg = await Jimp.read(imgBuffer);
      jimg.resize(224, 224).quality(80);

      // Simple variance check for blur detection
      const gray = jimg.clone().grayscale();
      const { data, width, height } = gray.bitmap;
      let sum = 0,
        sumSq = 0;
      for (let i = 0; i < data.length; i += 4) {
        const v = data[i];
        sum += v;
        sumSq += v * v;
      }
      const mean = sum / (width * height);
      const variance = sumSq / (width * height) - mean * mean;

      console.log("[FACE] Image variance:", variance.toFixed(2));

      if (variance < 500) {
        return res.status(200).json({
          success: false,
          message: "Image quality too low. Improve lighting and try again.",
        });
      }

      // Re-encode processed image
      const processedBuffer = await jimg.getBufferAsync(Jimp.MIME_JPEG);
      finalImageBase64 = processedBuffer.toString("base64");
    } catch (imgErr) {
      console.warn("[FACE] Image preprocessing failed, continuing with original:", imgErr.message);
    }

    // Call Face API with retry on service errors
    let embedding;
    let lastError;

    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        const result = await registerFaceWithHF(normalizedRegNo, finalImageBase64);
        embedding = result.embedding;
        console.log(`[FACE] Face registration successful on attempt ${attempt}`);
        break;
      } catch (err) {
        lastError = err;
        console.error(`[FACE] Registration attempt ${attempt} failed:`, err.message);

        // Check if error is retryable
        const isRetryable =
          err.message?.includes("503") ||
          err.message?.includes("408") ||
          err.message?.includes("timeout");

        if (!isRetryable || attempt >= 2) {
          throw err;
        }

        // Wait before retry
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    }

    if (lastError && !embedding) {
      throw lastError;
    }

    // Update student record with face embedding
    student.faceEmbedding = embedding || [];
    student.faceRegistered = true;
    student.faceRegisteredAt = new Date();
    await student.save();

    console.log("[FACE] Student face registration complete:", normalizedRegNo);

    return res.status(200).json({
      success: true,
      message: "Face registered successfully",
      student: {
        regNo: student.regNo,
        name: student.name,
        roomNo: student.roomNo,
        faceRegistered: true,
      },
    });
  } catch (err) {
    console.error("[FACE] Register error:", err.message);

    // Handle specific errors with correct HTTP codes
    if (err.message?.includes("503")) {
      return res.status(503).json({
        success: false,
        message: "Face service unavailable. Please try again in 30 seconds.",
      });
    }

    if (err.message?.includes("408")) {
      return res.status(408).json({
        success: false,
        message: "Face API timeout. Please try again.",
      });
    }

    if (err.message?.includes("404")) {
      return res.status(404).json({
        success: false,
        message: "Student not found",
      });
    }

    return res.status(500).json({
      success: false,
      message: err.message || "Face registration failed",
    });
  }
}

    if (!result.embedding || result.embedding.length === 0) {
      return res.status(400).json({
        message: "Face not detected. Please try with a clear face image.",
      });
    }

    // Save to database
    student.faceRegistered = true;
    student.faceEmbedding = result.embedding;
    await student.save();

    console.log(`[FACE] Face registered successfully for: ${regNo}`);
    return res.status(200).json({
      success: true,
      _id: student._id,
      regNo: student.regNo,
      name: student.name,
      faceRegistered: true,
      confidence: 0.95,
    });
  } catch (err) {
    console.error("[FACE] Register error:", err.message);

    // Handle specific error types
    if (err.message.includes("503")) {
      return res.status(503).json({
        message: "Face service waking up. Please try again in 20 seconds.",
      });
    }
    if (err.message.includes("408")) {
      return res.status(408).json({
        message: "Face service timeout. Please try again.",
      });
    }

    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * POST /api/face/verify
 * Verify a face for attendance
 */
export async function verifyFace(req, res) {
  try {
    const { imageBase64, image } = req.body;
    const imageData = imageBase64 || image;

    if (!imageData) {
      return res
        .status(400)
        .json({ message: "imageBase64 or image is required" });
    }

    // Check Face API health
    const isHealthy = await checkFaceApiHealth();
    if (!isHealthy) {
      return res.status(503).json({
        message: "Face service waking up. Please try again in 20 seconds.",
      });
    }

    // Call Face API to match
    console.log("[FACE] Matching face");
    const result = await matchFace(imageData);

    if (!result.regNo || result.confidence < 0.85) {
      return res
        .status(200)
        .json({ matched: false, confidence: result.confidence || 0 });
    }

    // Find student by regNo
    const student = await Student.findOne({ regNo: result.regNo });
    if (!student) {
      return res.status(200).json({ matched: false });
    }

    if (!student.faceRegistered) {
      return res.status(200).json({ matched: false });
    }

    console.log(`[FACE] Face matched for student: ${student.regNo}`);
    return res.status(200).json({
      matched: true,
      studentId: student.regNo,
      studentName: student.name,
      confidence: result.confidence,
      dept: student.dept,
      roomNo: student.roomNo,
    });
  } catch (err) {
    console.error("[FACE] Verify error:", err.message);

    if (err.message.includes("503")) {
      return res.status(503).json({
        message: "Face service waking up. Please try again in 20 seconds.",
      });
    }
    if (err.message.includes("408")) {
      return res.status(408).json({
        message: "Face service timeout. Please try again.",
      });
    }

    return res.status(500).json({ message: "Server error" });
  }
}
