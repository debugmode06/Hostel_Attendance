import jwt from "jsonwebtoken";
import User from "../models/User.js";

/**
 * Role-based access:
 * - admin: read-only (reports, analytics, view students/attendance)
 * - warden: full access (manage students, register faces, mark attendance, finalize)
 */

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

export const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    console.log(
      "[AUTH] Authorization header:",
      authHeader ? authHeader.substring(0, 50) + "..." : "undefined",
    );
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Token missing or malformed" });
    }
    const token = authHeader.split(" ")[1];
    let decoded;
    try {
      const secret = getJwtSecret();
      console.log(
        "[AUTH] JWT_SECRET used for verification:",
        secret.substring(0, 20) + "...",
      );
      decoded = jwt.verify(token, secret);
    } catch (e) {
      console.error("[AUTH] JWT verify failed:", e.message || e);
      return res.status(401).json({ message: "Token invalid or expired" });
    }
    console.log("[AUTH] Decoded JWT:", decoded);
    const user = await User.findById(decoded.userId);
    if (!user) {
      return res.status(401).json({ message: "User not found" });
    }
    // attach minimal user info to req.user for downstream role checks
    req.user = {
      _id: user._id,
      id: user._id,
      username: user.username,
      role: user.role,
    };
    next();
  } catch (err) {
    console.error("Authenticate middleware error:", err);
    return res.status(401).json({ message: "Authentication failed" });
  }
};

/** Admin only: can view reports and analytics; cannot mark attendance, register students, or register faces */
export const requireRole =
  (allowedRoles = []) =>
  (req, res, next) => {
    const role = req.user?.role;
    if (!role || (allowedRoles.length > 0 && !allowedRoles.includes(role))) {
      return res.status(403).json({ message: "Forbidden: insufficient role" });
    }
    next();
  };

export const requireAdmin = requireRole(["admin"]);
export const requireWarden = requireRole(["warden"]);
