import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  getReportToday,
  getReportByDate,
  getReportByMonth,
  getReport,
  exportPDF,
  exportExcel,
} from '../controllers/reportController.js';

const router = express.Router();

router.use(authenticate);

router.get('/today', getReportToday);
router.get('/date/:yyyymmdd', getReportByDate);
router.get('/month/:yyyymm', getReportByMonth);
router.get('/', getReport);
router.get('/export/pdf', exportPDF);
router.get('/export/excel', exportExcel);

export default router;
