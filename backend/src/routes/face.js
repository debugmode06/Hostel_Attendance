import express from "express";
import { authenticate, requireWarden } from "../middleware/auth.js";
import { registerFace, verifyFace } from "../controllers/faceController.js";
import { checkFaceApiHealth } from "../services/faceApi.js";

const router = express.Router();

// Health check (public, no auth required)
router.get("/health", async (req, res) => {
  try {
    const isHealthy = await checkFaceApiHealth();
    if (isHealthy) {
      return res
        .status(200)
        .json({ status: "ok", message: "Face API is healthy" });
    } else {
      return res.status(503).json({
        status: "unavailable",
        message: "Face service is waking up. Please try again in 30 seconds.",
      });
    }
  } catch (err) {
    return res
      .status(503)
      .json({ status: "error", message: "Face service check failed" });
  }
});

router.post("/register", authenticate, requireWarden, registerFace);
router.post("/verify", authenticate, verifyFace);

export default router;
