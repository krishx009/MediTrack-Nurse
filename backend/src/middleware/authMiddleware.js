// const admin = require("../config/firebase");
// const jwt = require("jsonwebtoken");

// const verifyToken = async (req, res, next) => {
//   const token = req.headers.authorization?.split(" ")[1];
//   if (!token) return res.status(401).json({ error: "Unauthorized" });

//   try {
//     const decodedToken = await admin.auth().verifyIdToken(token);
//     req.user = decodedToken;
//     next();
//   } catch (error) {
//     res.status(401).json({ error: "Invalid token" });
//   }
// };

// module.exports = { verifyToken };


const admin = require("../config/firebase");
const jwt = require("jsonwebtoken");
const Nurse = require("../models/Nurse"); // Import the Nurse model

const verifyToken = async (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "Unauthorized" });

  try {
    // Verify the token
    const decodedToken = jwt.verify(token, process.env.JWT_SECRET);

    // Find the nurse in the database
    const nurse = await Nurse.findById(decodedToken.id);
    if (!nurse) {
      return res.status(404).json({ error: "Nurse not found" });
    }

    // Check the nurse's status
    if (nurse.status === "inactive") {
      return res.status(403).json({ error: "Your account is inactive. Please contact the administrator." });
    }

    // Attach the nurse to the request object
    req.user = nurse;
    next();
  } catch (error) {
    console.error("Token verification error:", error);
    res.status(401).json({ error: "Invalid token" });
  }
};

module.exports = { verifyToken };