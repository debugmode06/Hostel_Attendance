import Attendance from '../models/Attendance.js';
import Student from '../models/Student.js';
import AttendanceDay from '../models/AttendanceDay.js';
import PDFDocument from 'pdfkit';
import ExcelJS from 'exceljs';

function getToday() {
  return new Date().toISOString().slice(0, 10);
}

function getYesterday() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return d.toISOString().slice(0, 10);
}

async function buildReportForDate(date) {
  const dayRecord = await AttendanceDay.findOne({ date });
  const records = await Attendance.find({ date }).sort({ time: 1 });
  const studentIds = [...new Set(records.map((r) => r.studentId))];
  const students = await Student.find({ studentId: { $in: studentIds } });
  const studentMap = Object.fromEntries(students.map((s) => [s.studentId, s]));

  const present = records.filter((r) => r.status === 'Present').map((r) => ({
    studentId: r.studentId,
    name: studentMap[r.studentId]?.name ?? 'Unknown',
    roomNo: studentMap[r.studentId]?.roomNo,
    dept: studentMap[r.studentId]?.dept,
    time: r.time,
    status: r.status,
  }));
  const absent = records.filter((r) => r.status === 'Absent').map((r) => ({
    studentId: r.studentId,
    name: studentMap[r.studentId]?.name ?? 'Unknown',
    roomNo: studentMap[r.studentId]?.roomNo,
    dept: studentMap[r.studentId]?.dept,
    status: r.status,
  }));

  return {
    date,
    finalized: dayRecord?.finalized ?? false,
    finalizedAt: dayRecord?.finalizedAt ?? null,
    present,
    absent,
    presentCount: present.length,
    absentCount: absent.length,
    generatedAt: new Date(),
  };
}

/** GET /reports/today - present list, absent list, counts, timestamps, student details */
export async function getReportToday(req, res) {
  try {
    const today = getToday();
    const report = await buildReportForDate(today);
    return res.status(200).json(report);
  } catch (err) {
    console.error('Report today error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

/** GET /reports/date/:yyyy-mm-dd */
export async function getReportByDate(req, res) {
  try {
    const date = req.params['yyyy-mm-dd'];
    if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return res.status(400).json({ message: 'Invalid date format. Use YYYY-MM-DD' });
    }
    const report = await buildReportForDate(date);
    return res.status(200).json(report);
  } catch (err) {
    console.error('Report by date error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

/** GET /reports/month/:yyyy-mm */
export async function getReportByMonth(req, res) {
  try {
    const yyyyMm = req.params['yyyy-mm'];
    if (!/^\d{4}-\d{2}$/.test(yyyyMm)) {
      return res.status(400).json({ message: 'Invalid month format. Use YYYY-MM' });
    }
    const [year, month] = yyyyMm.split('-');
    const start = `${year}-${month}-01`;
    const end = `${year}-${month}-31`;

    const records = await Attendance.find({ date: { $gte: start, $lte: end } }).sort({ date: 1, time: 1 });
    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ studentId: { $in: studentIds } });
    const studentMap = Object.fromEntries(students.map((s) => [s.studentId, s]));

    const byDate = {};
    for (const r of records) {
      if (!byDate[r.date]) byDate[r.date] = { present: [], absent: [], presentCount: 0, absentCount: 0 };
      const detail = {
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name ?? 'Unknown',
        roomNo: studentMap[r.studentId]?.roomNo,
        dept: studentMap[r.studentId]?.dept,
        time: r.time,
        status: r.status,
      };
      if (r.status === 'Present') {
        byDate[r.date].present.push(detail);
        byDate[r.date].presentCount += 1;
      } else {
        byDate[r.date].absent.push(detail);
        byDate[r.date].absentCount += 1;
      }
    }

    return res.status(200).json({
      month: yyyyMm,
      byDate,
      generatedAt: new Date(),
    });
  } catch (err) {
    console.error('Report by month error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

export async function getReport(req, res) {
  try {
    const { date, month, year, dept, section, status } = req.query;
    const targetDate = date || getYesterday();
    const filter = { date: targetDate };
    if (status) filter.status = status;

    let records = await Attendance.find(filter)
      .populate('markedBy', 'username')
      .sort({ time: 1 });

    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ studentId: { $in: studentIds } });
    const studentMap = Object.fromEntries(students.map((s) => [s.studentId, s]));

    if (dept) {
      records = records.filter((r) => studentMap[r.studentId]?.dept === dept);
    }
    if (section) {
      records = records.filter((r) => studentMap[r.studentId]?.roomNo?.startsWith(section));
    }

    const enriched = records.map((r) => ({
      studentId: r.studentId,
      name: studentMap[r.studentId]?.name || 'Unknown',
      roomNo: studentMap[r.studentId]?.roomNo || '-',
      dept: studentMap[r.studentId]?.dept || '-',
      time: r.time,
      status: r.status,
    }));

    return res.status(200).json({ date: targetDate, records: enriched });
  } catch (err) {
    console.error('Report error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

export async function exportPDF(req, res) {
  try {
    const { date } = req.query;
    const targetDate = date || getYesterday();
    const records = await Attendance.find({ date: targetDate }).sort({ time: 1 });
    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ studentId: { $in: studentIds } });
    const studentMap = Object.fromEntries(students.map((s) => [s.studentId, s]));

    const doc = new PDFDocument();
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=attendance-${targetDate}.pdf`);
    doc.pipe(res);

    doc.fontSize(18).text('Attendance Report', { align: 'center' });
    doc.fontSize(12).text(`Date: ${targetDate}`, { align: 'center' });
    doc.moveDown(2);

    records.forEach((r, i) => {
      const name = studentMap[r.studentId]?.name || 'Unknown';
      doc.fontSize(10).text(`${i + 1}. ${r.studentId} - ${name} - ${r.status}`, {
        continued: false,
      });
    });

    doc.end();
  } catch (err) {
    console.error('PDF export error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

export async function exportExcel(req, res) {
  try {
    const { date } = req.query;
    const targetDate = date || getYesterday();
    const records = await Attendance.find({ date: targetDate }).sort({ time: 1 });
    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const students = await Student.find({ studentId: { $in: studentIds } });
    const studentMap = Object.fromEntries(students.map((s) => [s.studentId, s]));

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Attendance');
    sheet.columns = [
      { header: 'Student ID', key: 'studentId', width: 15 },
      { header: 'Name', key: 'name', width: 25 },
      { header: 'Room', key: 'roomNo', width: 10 },
      { header: 'Department', key: 'dept', width: 15 },
      { header: 'Status', key: 'status', width: 10 },
      { header: 'Time', key: 'time', width: 20 },
    ];

    records.forEach((r) => {
      sheet.addRow({
        studentId: r.studentId,
        name: studentMap[r.studentId]?.name || 'Unknown',
        roomNo: studentMap[r.studentId]?.roomNo || '-',
        dept: studentMap[r.studentId]?.dept || '-',
        status: r.status,
        time: r.time ? new Date(r.time).toLocaleString() : '-',
      });
    });

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=attendance-${targetDate}.xlsx`);
    await workbook.xlsx.write(res);
  } catch (err) {
    console.error('Excel export error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
}
