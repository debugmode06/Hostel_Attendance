import mongoose from 'mongoose';

const attendanceDaySchema = new mongoose.Schema(
  {
    date: { type: String, required: true, unique: true },
    finalized: { type: Boolean, default: false },
    finalizedAt: { type: Date },
    finalizedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

// Index on date is already created by unique: true above; no duplicate needed

export default mongoose.model('AttendanceDay', attendanceDaySchema);
