/**
 * Seed script - creates admin and warden users
 * Run: node src/seed.js
 */
import 'dotenv/config';
import mongoose from 'mongoose';
import User from './models/User.js';

async function seed() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/hostel_attendance');
  const admin = await User.findOne({ username: 'admin' });
  if (!admin) {
    await User.create({ username: 'admin', password: 'admin123', role: 'admin' });
    console.log('Created admin user (admin/admin123)');
  }
  const warden = await User.findOne({ username: 'warden' });
  if (!warden) {
    await User.create({ username: 'warden', password: 'warden123', role: 'warden' });
    console.log('Created warden user (warden/warden123)');
  }
  process.exit(0);
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
