import Attendance from "../models/Attendance.js";
import AttendanceDay from "../models/AttendanceDay.js";
import Student from "../models/Student.js";
import { matchFace } from "../services/faceApi.js";
import Jimp from "jimp";

const CONFIDENCE_THRESHOLD = 0.55;

function getToday() {
  return new Date().toISOString().slice(0, 10);
}

/**
 * POST /attendance/scan
 * Receive imageBase64 -> HF /match -> validate -> save Present (confidence >= 0.85, once per day, not finalized).
 */
export async function scanAttendance(req, res) {
  try {
    let imageBase64 = req.body.imageBase64 ?? req.body.image;
    if (!imageBase64)
      return res
        .status(400)
        .json({ message: "imageBase64 or image is required" });

    const today = getToday();
    const wardenId = req.user._id;

    const dayRecord = await AttendanceDay.findOne({ date: today });
    if (dayRecord?.finalized) {
      return res.status(400).json({
        message: "Attendance finalized for today. No further scans allowed.",
      });
    }

    // Preprocess image: resize to 224x224 and check blur/quality
    try {
      const imgBuffer = Buffer.from(String(imageBase64), "base64");
      const jimg = await Jimp.read(imgBuffer);
      jimg.resize(224, 224).quality(80);
      // Convert to grayscale and compute variance as a simple blur detector
      const gray = jimg.clone().grayscale();
      const { data, width, height } = gray.bitmap;
      let sum = 0;
      let sumSq = 0;
      let count = 0;
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const idx = (y * width + x) * 4; // rgba
          const v = data[idx];
          sum += v;
          sumSq += v * v;
          count++;
        }
      }
      const mean = sum / count;
      const variance = sumSq / count - mean * mean;
      console.log("[ATTENDANCE] Image variance:", variance.toFixed(2));
      // If variance low, image likely blurred or low-contrast; reject early
      if (variance < 500) {
        return res
          .status(200)
          .json({
            matched: false,
            confidence: 0,
            message: "Image too blurred or low contrast",
            compared: 0,
          });
      }
      // Re-encode resized RGB image to base64 for sending
      const processedBuffer = await jimg.getBufferAsync(Jimp.MIME_JPEG);
      // Use processed base64 for matching
      imageBase64 = processedBuffer.toString("base64");
    } catch (imgErr) {
      console.warn("[ATTENDANCE] Image preprocessing failed:", imgErr.message);
      // continue with original image if preprocessing fails
    }

    // Fetch all students with registered faces
    const students = await Student.find({ faceRegistered: true }).lean();
    const embeddingsList = [];
    for (const s of students) {
      if (s.faceEmbedding && Array.isArray(s.faceEmbedding) && s.regNo) {
        embeddingsList.push({ regNo: s.regNo, embedding: s.faceEmbedding });
      }
    }

    console.log(
      "[ATTENDANCE] Comparing against",
      embeddingsList.length,
      "embeddings. Threshold:",
      CONFIDENCE_THRESHOLD,
    );

    const result = await matchFace(imageBase64, embeddingsList);
    const regNo = result.regNo;
    const confidence = result.confidence ?? 0;

    console.log("[ATTENDANCE] Match confidence:", confidence);

    if (!regNo || confidence < CONFIDENCE_THRESHOLD) {
      return res
        .status(200)
        .json({ matched: false, confidence, compared: embeddingsList.length });
    }

    const student = await Student.findOne({ regNo });
    if (!student) return res.status(200).json({ matched: false, confidence });
    if (!student.faceRegistered)
      return res.status(200).json({ matched: false, confidence });

    const existing = await Attendance.findOne({
      studentId: regNo,
      date: today,
    });
    if (existing) {
      return res.status(409).json({
        message: "Attendance already marked today",
        markedAt: existing.time,
      });
    }

    const markedAt = new Date();
    const attendance = await Attendance.create({
      studentId: regNo,
      date: today,
      time: markedAt,
      status: "Present",
      markedBy: wardenId,
    });

    return res.status(200).json({
      success: true,
      message: "Attendance marked present",
      timestamp: markedAt,
      student: {
        studentId: student.regNo,
        name: student.name,
        roomNo: student.roomNo,
        dept: student.dept,
      },
      attendance: {
        date: attendance.date,
        time: attendance.time,
        status: attendance.status,
      },
    });
  } catch (err) {
    console.error("[ATTENDANCE] Scan attendance error:", err.message);
    if (err.message?.toLowerCase().includes("timeout")) {
      return res.status(408).json({ message: "Face API timeout" });
    }
    return res.status(503).json({ message: "Service unavailable" });
  }
}

/** Alias for backward compatibility */
export async function markAttendance(req, res) {
  return scanAttendance(req, res);
}

export async function getPendingStudents(req, res) {
  try {
    const today = getToday();
    const marked = await Attendance.find({
      date: today,
      status: "Present",
    }).distinct("studentId");
    const students = await Student.find({
      faceRegistered: true,
      regNo: { $nin: marked },
      $or: [{ leaveStatus: "none" }, { leaveStatus: { $exists: false } }],
    }).sort({ roomNo: 1, name: 1 });
    return res.status(200).json(students);
  } catch (err) {
    console.error("Pending students error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * POST /attendance/finalize
 * Mark all unmarked students as Absent, lock day, prevent further scans.
 */
export async function finalizeAttendance(req, res) {
  try {
    const today = getToday();
    let dayRecord = await AttendanceDay.findOne({ date: today });
    if (!dayRecord) dayRecord = await AttendanceDay.create({ date: today });
    if (dayRecord.finalized) {
      return res.status(400).json({ message: "Attendance already finalized" });
    }

    // Get all students marked present today
    const marked = await Attendance.find({
      date: today,
      status: "Present",
    }).distinct("studentId");

    // Get students on leave
    const studentsOnLeave = await Student.find({
      leaveStatus: { $in: ["on_leave", "medical"] },
      $or: [{ leaveUntil: null }, { leaveUntil: { $gte: new Date() } }],
    }).distinct("regNo");

    // Get all registered students who haven't been marked and aren't on leave
    const toMarkAbsent = await Student.find({
      faceRegistered: true,
      regNo: { $nin: [...marked, ...studentsOnLeave] },
    }).distinct("regNo");

    const finalizedAt = new Date();
    // Mark remaining as Absent
    for (const regNo of toMarkAbsent) {
      await Attendance.findOneAndUpdate(
        { studentId: regNo, date: today },
        { status: "Absent", markedBy: req.user._id },
        { upsert: true },
      );
    }

    dayRecord.finalized = true;
    dayRecord.finalizedAt = finalizedAt;
    dayRecord.finalizedBy = req.user._id;
    await dayRecord.save();

    console.log(
      `[ATTENDANCE] Attendance finalized for ${today}. Marked ${toMarkAbsent.length} as absent.`,
    );
    return res.status(200).json({
      message: "Attendance finalized",
      date: today,
      absentCount: toMarkAbsent.length,
    });
  } catch (err) {
    console.error("[ATTENDANCE] Finalize error:", err.message);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function getAttendanceStatus(req, res) {
  try {
    const today = getToday();
    const dayRecord = await AttendanceDay.findOne({ date: today });
    const presentCount = await Attendance.countDocuments({
      date: today,
      status: "Present",
    });
    const totalStudents = await Student.countDocuments({
      faceRegistered: true,
    });
    return res.status(200).json({
      date: today,
      finalized: dayRecord?.finalized ?? false,
      status: dayRecord?.finalized ? "Finalized" : "Open",
      finalizedAt: dayRecord?.finalizedAt ?? null,
      finalizedBy: dayRecord?.finalizedBy ?? null,
      presentCount,
      totalStudents,
    });
  } catch (err) {
    console.error("Status error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function getStudentAttendanceHistory(req, res) {
  try {
    const { studentId } = req.params;
    const { month, year } = req.query;
    const filter = { studentId };
    if (month && year) {
      const start = `${year}-${String(month).padStart(2, "0")}-01`;
      const end = `${year}-${String(month).padStart(2, "0")}-31`;
      filter.date = { $gte: start, $lte: end };
    }
    const records = await Attendance.find(filter).sort({ date: -1 });
    return res.status(200).json(records);
  } catch (err) {
    console.error("History error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /attendance/today
 * Present list, absent list, timestamp, student details for today.
 */
export async function getAttendanceToday(req, res) {
  try {
    const today = getToday();
    const dayRecord = await AttendanceDay.findOne({ date: today });
    const records = await Attendance.find({ date: today }).sort({ time: 1 });
    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ regNo: { $in: studentIds } });
    const studentMap = Object.fromEntries(students.map((s) => [s.regNo, s]));

    const present = records
      .filter((r) => r.status === "Present")
      .map((r) => ({
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name ?? "Unknown",
        roomNo: studentMap[r.studentId]?.roomNo,
        dept: studentMap[r.studentId]?.dept,
        time: r.time,
        status: r.status,
      }));
    const absent = records
      .filter((r) => r.status === "Absent")
      .map((r) => ({
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name ?? "Unknown",
        roomNo: studentMap[r.studentId]?.roomNo,
        dept: studentMap[r.studentId]?.dept,
        status: r.status,
      }));

    return res.status(200).json({
      date: today,
      finalized: dayRecord?.finalized ?? false,
      finalizedAt: dayRecord?.finalizedAt ?? null,
      present,
      absent,
      generatedAt: new Date(),
    });
  } catch (err) {
    console.error("Attendance today error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /attendance/date/:date
 * Report for a specific date (YYYY-MM-DD).
 */
export async function getAttendanceByDate(req, res) {
  try {
    const { date } = req.params;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return res
        .status(400)
        .json({ message: "Invalid date format. Use YYYY-MM-DD" });
    }
    const dayRecord = await AttendanceDay.findOne({ date });
    const records = await Attendance.find({ date }).sort({ time: 1 });
    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ studentId: { $in: studentIds } });
    const studentMap = Object.fromEntries(
      students.map((s) => [s.studentId, s]),
    );

    const present = records
      .filter((r) => r.status === "Present")
      .map((r) => ({
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name ?? "Unknown",
        roomNo: studentMap[r.studentId]?.roomNo,
        dept: studentMap[r.studentId]?.dept,
        time: r.time,
        status: r.status,
      }));
    const absent = records
      .filter((r) => r.status === "Absent")
      .map((r) => ({
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name ?? "Unknown",
        roomNo: studentMap[r.studentId]?.roomNo,
        dept: studentMap[r.studentId]?.dept,
        status: r.status,
      }));

    return res.status(200).json({
      date,
      finalized: dayRecord?.finalized ?? false,
      finalizedAt: dayRecord?.finalizedAt ?? null,
      present,
      absent,
      generatedAt: new Date(),
    });
  } catch (err) {
    console.error("Attendance by date error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /attendance/month/:yyyy-mm
 * Report for a month (e.g. 2025-02).
 */
export async function getAttendanceByMonth(req, res) {
  try {
    const { "yyyy-mm": yyyyMm } = req.params;
    if (!/^\d{4}-\d{2}$/.test(yyyyMm)) {
      return res
        .status(400)
        .json({ message: "Invalid month format. Use YYYY-MM" });
    }
    const [year, month] = yyyyMm.split("-");
    const start = `${year}-${month}-01`;
    const end = `${year}-${month}-31`;

    const records = await Attendance.find({
      date: { $gte: start, $lte: end },
    }).sort({ date: 1, time: 1 });

    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ studentId: { $in: studentIds } });
    const studentMap = Object.fromEntries(
      students.map((s) => [s.studentId, s]),
    );

    const byDate = {};
    for (const r of records) {
      if (!byDate[r.date]) byDate[r.date] = { present: [], absent: [] };
      const detail = {
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name ?? "Unknown",
        roomNo: studentMap[r.studentId]?.roomNo,
        dept: studentMap[r.studentId]?.dept,
        time: r.time,
        status: r.status,
      };
      if (r.status === "Present") byDate[r.date].present.push(detail);
      else byDate[r.date].absent.push(detail);
    }

    return res.status(200).json({
      month: yyyyMm,
      byDate,
      generatedAt: new Date(),
    });
  } catch (err) {
    console.error("Attendance by month error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}
