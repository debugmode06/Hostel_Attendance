import Student from "../models/Student.js";
import {
  registerFace as registerFaceWithHF,
  matchFace,
  checkFaceApiHealth,
} from "../services/faceApi.js";

/**
 * POST /api/face/register
 * Register a student's face
 */
export async function registerFace(req, res) {
  try {
    const { regNo, imageBase64, image } = req.body;
    const imageData = imageBase64 || image;

    // Validate inputs
    if (!regNo) {
      return res.status(400).json({ message: "regNo is required" });
    }
    if (!imageData) {
      return res
        .status(400)
        .json({ message: "imageBase64 or image is required" });
    }

    // Verify student exists
    const student = await Student.findOne({ regNo: regNo.trim() });
    if (!student) {
      return res.status(404).json({ message: "Student not found" });
    }

    // Check if face already registered
    if (student.faceRegistered) {
      return res
        .status(400)
        .json({ message: "Face already registered for this student" });
    }

    // Check Face API health
    const isHealthy = await checkFaceApiHealth();
    if (!isHealthy) {
      return res.status(503).json({
        message: "Face service waking up. Please try again in 20 seconds.",
      });
    }

    // Call Face API to register
    console.log(`[FACE] Registering face for student: ${regNo}`);
    const result = await registerFaceWithHF(regNo, imageData);

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
