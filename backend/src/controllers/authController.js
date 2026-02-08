import jwt from "jsonwebtoken";
import User from "../models/User.js";

const JWT_EXPIRES = "7d";

// Helper to get JWT_SECRET at runtime (after dotenv.config())
function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret === "your-super-secret-jwt-key-change-in-production") {
    throw new Error(
      "JWT_SECRET not set in .env or still using default placeholder",
    );
  }
  return secret;
}

export async function login(req, res) {
  try {
    const { username, password } = req.body;
    const user = await User.findOne({ username });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const secret = getJwtSecret();
    const token = jwt.sign(
      { userId: user._id.toString(), role: user.role },
      secret,
      { expiresIn: JWT_EXPIRES },
    );

    console.log("[AUTH] Login successful for:", username);
    console.log("[AUTH] JWT_SECRET used:", secret.substring(0, 20) + "...");

    return res.status(200).json({
      token,
      user: { id: user._id, username: user.username, role: user.role },
    });
  } catch (err) {
    console.error("[AUTH] Login error:", err.message || err);
    return res.status(500).json({ message: "Server error" });
  }
}
