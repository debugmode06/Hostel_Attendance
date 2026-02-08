import mongoose from "mongoose";

const studentSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    regNo: {
      type: String,
      required: true,
      unique: true,
      sparse: true,
      trim: true,
    },
    roomNo: { type: String, required: true, trim: true },
    dept: { type: String, required: true, trim: true },
    category: { type: String, required: true, trim: true },
    college: { type: String, required: true, trim: true },
    faceRegistered: { type: Boolean, default: false },
    faceEmbedding: { type: [Number], default: [] },
    createdAt: { type: Date, default: Date.now },
    leaveStatus: {
      type: String,
      enum: ["none", "on_leave", "medical"],
      default: "none",
    },
    leaveUntil: { type: Date },
  },
  { timestamps: true },
);

// Indexes for common queries
studentSchema.index({ faceRegistered: 1 });
studentSchema.index({ dept: 1 });
studentSchema.index({ roomNo: 1 });
studentSchema.index({ college: 1 });
studentSchema.index({ leaveStatus: 1 });
studentSchema.index({ createdAt: -1 });

export default mongoose.model("Student", studentSchema);
