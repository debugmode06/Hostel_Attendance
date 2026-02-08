import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables from backend/.env before other imports run
const loaded = dotenv.config({ path: join(__dirname, "..", ".env") });
console.log("[loadEnv] .env loaded:", !!loaded.parsed);
console.log("[loadEnv] FACE_API_TEST_MODE:", process.env.FACE_API_TEST_MODE);

export default null;
