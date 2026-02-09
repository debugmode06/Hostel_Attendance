import { fileURLToPath } from "url";
import { dirname, join } from "path";
import "./loadEnv.js";
import express from "express";
import cors from "cors";
import mongoose from "mongoose";
import authRoutes from "./routes/auth.js";
import studentRoutes from "./routes/students.js";
import attendanceRoutes from "./routes/attendance.js";
import reportRoutes from "./routes/reports.js";
import faceRoutes from "./routes/face.js";
import { warmUpFaceApi } from "./services/faceApi.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const app = express();
const PORT = process.env.PORT || 5000;
const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://localhost:27017/hostel_attendance";

app.use(
  cors({
    origin: true,
    credentials: true,
    allowedHeaders: ["Content-Type", "Authorization", "Accept"],
    exposedHeaders: ["Authorization"],
  }),
);
app.use(express.json({ limit: "10mb" }));

// simple request logger for debug
app.use((req, _res, next) => {
  console.log(
    `${req.method} ${req.path} - Authorization: ${req.headers.authorization}`,
  );
  next();
});

app.use("/api/auth", authRoutes);
app.use("/api/students", studentRoutes);
app.use("/api/attendance", attendanceRoutes);
app.use("/api/reports", reportRoutes);
app.use("/api/face", faceRoutes);

app.get("/api/health", (_, res) => res.json({ status: "ok" }));

app.use((_req, res) => {
  res.status(404).json({ message: "Not found" });
});

app.use((err, _req, res, _next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ message: "Server error" });
});

if (!process.env.MONGODB_URI) {
  console.warn(
    "MONGODB_URI not set in .env — using localhost. Create backend/.env from .env.example and set MONGODB_URI to your MongoDB Atlas connection string.",
  );
}

mongoose
  .connect(MONGODB_URI)
  .then(() => console.log("MongoDB connected"))
  .catch((err) => {
    console.error("MongoDB connection error:", err.message);
    if (MONGODB_URI.includes("localhost")) {
      console.error(
        "Tip: Install MongoDB locally or set MONGODB_URI in backend/.env to your MongoDB Atlas URI.",
      );
    }
  });

process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  warmUpFaceApi();
});
