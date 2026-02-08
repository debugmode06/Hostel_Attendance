import express from "express";
import { authenticate, requireWarden } from "../middleware/auth.js";
import {
  listStudents,
  getStudent,
  createStudent,
  updateStudent,
  deleteStudent,
  updateLeaveStatus,
  registerFace,
  countStudents,
  bulkCreateStudents,
  getCategories,
  getColleges,
} from "../controllers/studentController.js";

const router = express.Router();

router.get("/categories", getCategories);
router.get("/colleges", getColleges);

router.use(authenticate);

router.get("/count", countStudents);
router.post("/bulk", requireWarden, bulkCreateStudents);

router.get("/", listStudents);
router.get("/:id", getStudent);

router.use(requireWarden);

router.post("/", createStudent);
router.put("/:id", updateStudent);
router.delete("/:id", deleteStudent);
router.patch("/:id/leave", updateLeaveStatus);
router.post("/:id/face", registerFace);
router.post("/:studentId/register-face", registerFace);

export default router;
