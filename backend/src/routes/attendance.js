import express from 'express';
import { authenticate, requireWarden } from '../middleware/auth.js';
import {
  scanAttendance,
  markAttendance,
  getPendingStudents,
  finalizeAttendance,
  getAttendanceStatus,
  getStudentAttendanceHistory,
  getAttendanceToday,
  getAttendanceByDate,
  getAttendanceByMonth,
} from '../controllers/attendanceController.js';

const router = express.Router();

router.use(authenticate);

router.get('/status', getAttendanceStatus);
router.get('/today', getAttendanceToday);
router.get('/date/:date', getAttendanceByDate);
router.get('/month/:yyyymm', getAttendanceByMonth);
router.get('/history/:studentId', getStudentAttendanceHistory);

router.use(requireWarden);

router.post('/scan', scanAttendance);
router.post('/mark', markAttendance);
router.get('/pending', getPendingStudents);
router.post('/finalize', finalizeAttendance);

export default router;
