import Student from "../models/Student.js";
import { registerFace as registerFaceWithHF } from "../services/faceApi.js";

const CATEGORIES = [
  "7.5% Quota",
  "Counselling",
  "Sports Quota",
  "Management",
  "College",
];
const COLLEGES = ["HIT", "HICET", "ARC"];

export async function listStudents(req, res) {
  try {
    const { faceRegistered, dept, roomNo, college, search } = req.query;
    const filter = {};
    if (faceRegistered !== undefined) {
      // ensure boolean filter (accept true/false strings)
      if (
        faceRegistered === "true" ||
        faceRegistered === "1" ||
        faceRegistered === true
      )
        filter.faceRegistered = true;
      else if (
        faceRegistered === "false" ||
        faceRegistered === "0" ||
        faceRegistered === false
      )
        filter.faceRegistered = false;
    }
    if (dept) filter.dept = dept;
    if (roomNo) filter.roomNo = roomNo;
    if (college) filter.college = college;
    if (search) {
      filter.$or = [
        { regNo: { $regex: search, $options: "i" } },
        { name: { $regex: search, $options: "i" } },
      ];
    }
    const students = await Student.find(filter).sort({ name: 1 });
    return res.status(200).json(students);
  } catch (err) {
    console.error("List students error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function getStudent(req, res) {
  try {
    const { id } = req.params;
    const student = await Student.findOne({ regNo: id });
    if (!student) return res.status(404).json({ message: "Student not found" });
    return res.status(200).json(student);
  } catch (err) {
    console.error("Get student error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function createStudent(req, res) {
  try {
    const { regNo, name, roomNo, dept, category, college } = req.body;
    if (!regNo || !name || !roomNo || !dept || !category || !college) {
      return res.status(400).json({
        message:
          "Missing required fields: regNo, name, roomNo, dept, category, college",
      });
    }
    const exists = await Student.findOne({ regNo });
    if (exists)
      return res
        .status(409)
        .json({ message: "Register number already exists" });
    if (!CATEGORIES.includes(category)) {
      return res.status(400).json({ message: "Invalid category" });
    }
    if (!COLLEGES.includes(college)) {
      return res.status(400).json({ message: "Invalid college" });
    }
    const student = await Student.create({
      regNo,
      name,
      roomNo,
      dept,
      category,
      college,
      faceRegistered: false,
    });
    return res.status(201).json(student);
  } catch (err) {
    console.error("Create student error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function updateStudent(req, res) {
  try {
    const { id } = req.params;
    const { name, roomNo, dept, category, college } = req.body;
    const student = await Student.findOne({ regNo: id });
    if (!student) return res.status(404).json({ message: "Student not found" });
    if (name !== undefined) student.name = name;
    if (roomNo !== undefined) student.roomNo = roomNo;
    if (dept !== undefined) student.dept = dept;
    if (category !== undefined) {
      if (!CATEGORIES.includes(category))
        return res.status(400).json({ message: "Invalid category" });
      student.category = category;
    }
    if (college !== undefined) {
      if (!COLLEGES.includes(college))
        return res.status(400).json({ message: "Invalid college" });
      student.college = college;
    }
    await student.save();
    return res.status(200).json(student);
  } catch (err) {
    console.error("Update student error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function deleteStudent(req, res) {
  try {
    const { id } = req.params;
    const student = await Student.findOneAndDelete({ regNo: id });
    if (!student) return res.status(404).json({ message: "Student not found" });
    return res.status(200).json({ message: "Student deleted" });
  } catch (err) {
    console.error("Delete student error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function updateLeaveStatus(req, res) {
  try {
    const { id } = req.params;
    const { leaveStatus, leaveUntil } = req.body;
    const validStatuses = ["none", "on_leave", "medical"];
    if (!validStatuses.includes(leaveStatus)) {
      return res.status(400).json({ message: "Invalid leave status" });
    }
    const student = await Student.findOneAndUpdate(
      { regNo: id },
      { leaveStatus, leaveUntil: leaveStatus === "none" ? null : leaveUntil },
      { new: true },
    );
    if (!student) return res.status(404).json({ message: "Student not found" });
    return res.status(200).json(student);
  } catch (err) {
    console.error("Update leave error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * POST /students/:studentId/register-face
 * Register student face via Hugging Face /register; set faceRegistered = true.
 */
export async function registerFace(req, res) {
  try {
    const studentReg =
      req.params.studentId ??
      req.params.id ??
      req.body.regNo ??
      req.body.studentId;
    const imageBase64 = req.body.imageBase64 ?? req.body.image;
    if (!imageBase64)
      return res
        .status(400)
        .json({ message: "imageBase64 or image is required" });

    const student = await Student.findOne({ regNo: studentReg });
    if (!student) return res.status(404).json({ message: "Student not found" });
    if (student.faceRegistered)
      return res
        .status(400)
        .json({ message: "Face already registered for this student" });
    const result = await registerFaceWithHF(student.regNo, imageBase64);
    if (!result || result.embedding == null) {
      // controlled error if face API did not return embedding
      return res
        .status(400)
        .json({ message: "Face embedding could not be extracted from image" });
    }
    // ensure embedding is an array of numbers
    const embedding = Array.isArray(result.embedding)
      ? result.embedding.map(Number)
      : [];
    student.faceRegistered = true;
    student.faceEmbedding = embedding;
    await student.save();

    return res.status(200).json({
      success: true,
      _id: student._id,
      regNo: student.regNo,
      name: student.name,
      faceRegistered: student.faceRegistered,
      confidence: 0.95,
    });
  } catch (err) {
    console.error("Register face error:", err);
    if (err.message?.toLowerCase().includes("timeout"))
      return res.status(408).json({ message: "Face API timeout" });
    return res
      .status(503)
      .json({ message: err.message || "Face service unavailable" });
  }
}

export async function countStudents(req, res) {
  try {
    const total = await Student.countDocuments();
    const faceRegistered = await Student.countDocuments({
      faceRegistered: true,
    });
    const facePending = await Student.countDocuments({ faceRegistered: false });
    return res.status(200).json({ total, faceRegistered, facePending });
  } catch (err) {
    console.error("Count students error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function bulkCreateStudents(req, res) {
  try {
    const rows = Array.isArray(req.body) ? req.body : (req.body.students ?? []);
    if (!Array.isArray(rows) || rows.length === 0) {
      return res.status(400).json({ message: "No student rows provided" });
    }
    const created = [];
    const failed = [];
    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const regNo = r.regNo ?? r.studentId ?? r.regno ?? r["RegisterNumber"];
      const name = r.name ?? r.studentName ?? r["Name"];
      const roomNo = r.roomNo ?? r.room ?? r["Room"];
      const dept = r.dept ?? r.department ?? r["Dept"];
      const category = r.category ?? r["Category"];
      const college = r.college ?? r["College"];
      if (!regNo || !name || !roomNo || !dept || !category || !college) {
        failed.push({ row: r, reason: "Missing required fields" });
        continue;
      }
      try {
        const exists = await Student.findOne({ regNo });
        if (exists) {
          failed.push({ row: r, reason: "Duplicate regNo" });
          continue;
        }
        const st = await Student.create({
          regNo,
          name,
          roomNo,
          dept,
          category,
          college,
        });
        created.push(st);
      } catch (err) {
        failed.push({ row: r, reason: err.message || "Create failed" });
      }
    }
    return res.status(200).json({ createdCount: created.length, failed });
  } catch (err) {
    console.error("Bulk create error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export function getCategories(_, res) {
  return res.status(200).json(CATEGORIES);
}

export function getColleges(_, res) {
  return res.status(200).json(COLLEGES);
}
