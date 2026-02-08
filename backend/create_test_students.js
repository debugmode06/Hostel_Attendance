import "dotenv/config";
import mongoose from "mongoose";
import Student from "./src/models/Student.js";

async function createTestStudents() {
  try {
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/hostel_attendance",
    );
    console.log("Connected to MongoDB");

    // Clear existing students (optional - remove if you want to keep them)
    await Student.deleteMany({});
    await Student.collection.dropIndexes();
    console.log("Cleared existing students and dropped indexes");

    const testStudents = [
      {
        regNo: "CSE2024001",
        name: "Raj Kumar",
        roomNo: "A101",
        dept: "CSE",
        category: "Day Scholar",
        college: "HIT",
        faceRegistered: false,
      },
      {
        regNo: "CSE2024002",
        name: "Priya Singh",
        roomNo: "A102",
        dept: "CSE",
        category: "Day Scholar",
        college: "HIT",
        faceRegistered: false,
      },
      {
        regNo: "ECE2024001",
        name: "Amit Patel",
        roomNo: "B201",
        dept: "ECE",
        category: "Hosteller",
        college: "HICET",
        faceRegistered: false,
      },
      {
        regNo: "ECE2024002",
        name: "Neha Sharma",
        roomNo: "B202",
        dept: "ECE",
        category: "Hosteller",
        college: "HICET",
        faceRegistered: false,
      },
    ];

    // Check if students already exist
    const existing = await Student.find({
      regNo: { $in: testStudents.map((s) => s.regNo) },
    });
    const existingRegNos = new Set(existing.map((s) => s.regNo));

    const toCreate = testStudents.filter((s) => !existingRegNos.has(s.regNo));

    if (toCreate.length > 0) {
      const created = await Student.insertMany(toCreate);
      console.log(`✓ Created ${created.length} new students`);
      created.forEach((s) => console.log(`  - ${s.regNo}: ${s.name}`));
    }

    const total = await Student.countDocuments();
    console.log(`\nTotal students in database: ${total}`);

    const students = await Student.find(
      {},
      "regNo name dept roomNo faceRegistered",
    );
    console.log("\nAll students:");
    students.forEach((s) => {
      console.log(
        `  ${s.regNo} | ${s.name} | ${s.dept} | Room ${s.roomNo} | Face: ${s.faceRegistered}`,
      );
    });

    process.exit(0);
  } catch (err) {
    console.error("Error:", err.message);
    process.exit(1);
  }
}

createTestStudents();
