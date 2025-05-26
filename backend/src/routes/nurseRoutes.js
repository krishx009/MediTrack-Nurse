// const express = require("express");
// const router = express.Router();
// // const bcrypt = require("bcrypt");
// const bcrypt = require("bcryptjs");
// const jwt = require("jsonwebtoken");
// const Nurse = require("../models/Nurse");
// const { verifyToken } = require("../middleware/authMiddleware");





// // Nurse Signup
// router.post("/signup", async (req, res) => {
//   try {
//     const { name, email, password, role, departments } = req.body;

//     // Validate required fields
//     if (!name || !email || !password || !role || !departments) {
//       return res.status(400).json({ message: "All fields are required" });
//     }

//     // Check if nurse already exists
//     const existingNurse = await Nurse.findOne({ email });
//     if (existingNurse) {
//       return res.status(400).json({ message: "Nurse already registered" });
//     }

//     // Hash password before saving to DB
//     const hashedPassword = await bcrypt.hash(password, 10);

//     // Create new nurse
//     const newNurse = new Nurse({
//       name,
//       email,
//       password: hashedPassword,
//       role: role || 'Staff Nurse',
//       department: department || 'General Medicine',
//       // role,
//       // departments,
//     });

//     await newNurse.save();

//     res.status(201).json({
//       message: "Nurse registered successfully!",
//       nurse: {
//         id: newNurse._id,
//         nurseId: newNurse.nurseId, // Include the generated nurseId
//         name: newNurse.name,
//         email: newNurse.email,
//         role: newNurse.role,
//         departments: newNurse.departments,
//         status: newNurse.status,
//       },
//     });
//   } catch (error) {
//     console.error("Signup Error:", error);
//     res.status(500).json({ message: "Server error", error: error.message });
//   }
// });



// router.post("/login", async (req, res) => {
//   try {
//     const { email, password } = req.body;

//     // Validate input
//     if (!email || !password) {
//       return res.status(400).json({ message: "Email and password are required" });
//     }

//     // Find nurse by email
//     const nurse = await Nurse.findOne({ email });
//     if (!nurse) {
//       return res.status(400).json({ message: "Invalid credentials" });
//     }

//     // Compare passwords
//     const isMatch = await bcrypt.compare(password, nurse.password);
//     if (!isMatch) {
//       return res.status(400).json({ message: "Invalid credentials" });
//     }

//     // Check nurse status
//     if (nurse.status === "inactive") {
//       return res.status(403).json({
//         message: "Your account is inactive. Please contact the administrator.",
//         nurse: {
//           id: nurse._id,
//           nurseId: nurse.nurseId,
//           name: nurse.name,
//           email: nurse.email,
//           role: nurse.role,
//           departments: nurse.departments,
//           status: nurse.status,
//         },
//       });
//     }

//     const token = jwt.sign(
//       { id: nurse._id, role: nurse.role },
//       process.env.JWT_SECRET,
//       { expiresIn: "1h" }
//     );

//     res.status(200).json({
//       message: "Login successful!",
//       nurse: {
//         id: nurse._id,
//         nurseId: nurse.nurseId,
//         name: nurse.name,
//         email: nurse.email,
//         role: nurse.role,
//         departments: nurse.departments,
//         status: nurse.status,
//       },
//       token,
//     });
//   } catch (error) {
//     console.error("Login Error:", error);
//     res.status(500).json({ message: "Server error", error: error.message });
//   }
// });



// // Update Nurse Status (Admin Only)
// router.patch("/status/:id", verifyToken, async (req, res) => {
//   try {
//     const { id } = req.params;
//     const { status } = req.body;

//     // Validate status
//     if (!["active", "inactive"].includes(status)) {
//       return res.status(400).json({ message: "Invalid status. Allowed values are 'active' or 'inactive'." });
//     }

//     // Find and update the nurse's status
//     const nurse = await Nurse.findByIdAndUpdate(
//       id,
//       { status },
//       { new: true } // Return the updated document
//     );

//     if (!nurse) {
//       return res.status(404).json({ message: "Nurse not found." });
//     }

//     res.status(200).json({
//       message: `Nurse status updated to '${status}' successfully.`,
//       nurse: {
//         id: nurse._id,
//         nurseId: nurse.nurseId,
//         name: nurse.name,
//         email: nurse.email,
//         role: nurse.role,
//         departments: nurse.departments,
//         status: nurse.status,
//       },
//     });
//   } catch (error) {
//     console.error("Error updating nurse status:", error);
//     res.status(500).json({ message: "Server error", error: error.message });
//   }
// });

// module.exports = router;






// module.exports = router;













const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const Nurse = require("../models/Nurse");
const { verifyToken } = require("../middleware/authMiddleware");

// Nurse Signup
router.post("/signup", async (req, res) => {
  try {
    const { name, email, password, role, department } = req.body;

    // Validate required fields
    if (!name || !email || !password || !role || !department ) {
      return res.status(400).json({ message: "All fields are required" });
    }

    // Check if nurse already exists
    const existingNurse = await Nurse.findOne({ email });
    if (existingNurse) {
      return res.status(400).json({ message: "Nurse already registered" });
    }

    // Create new nurse - password will be hashed in pre-save hook
    const newNurse = new Nurse({
      name,
      email,
      password,
      role: role || 'Staff Nurse',
      department,
    });

    await newNurse.save();

    res.status(201).json({
      message: "Nurse registered successfully!",
      nurse: {
        id: newNurse._id,
        nurseId: newNurse.nurseId,
        name: newNurse.name,
        email: newNurse.email,
        role: newNurse.role,
        department: newNurse.department,
        status: newNurse.status,
      },
    });
  } catch (error) {
    console.error("Signup Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Nurse Login
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    // Find nurse by email
    const nurse = await Nurse.findOne({ email });
    if (!nurse) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    // Compare passwords using the matchPassword method
    const isMatch = await nurse.matchPassword(password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    // Check nurse status - handle both lowercase and uppercase status values
    if (nurse.status === "Inactive" || nurse.status === "inactive") {
      return res.status(403).json({
        message: "Your account is inactive. Please contact the administrator.",
        nurse: {
          id: nurse._id,
          nurseId: nurse.nurseId,
          name: nurse.name,
          email: nurse.email,
          role: nurse.role,
          department: nurse.department,
          status: nurse.status,
        },
      });
    }

    const token = jwt.sign(
      { id: nurse._id, role: nurse.role },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.status(200).json({
      message: "Login successful!",
      nurse: {
        id: nurse._id,
        nurseId: nurse.nurseId,
        name: nurse.name,
        email: nurse.email,
        role: nurse.role,
        department: nurse.department,
        status: nurse.status,
      },
      token,
    });
  } catch (error) {
    console.error("Login Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Update Nurse Status (Admin Only)
router.patch("/status/:id", verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    // Validate status - accept both lowercase and uppercase
    const normalizedStatus = status.charAt(0).toUpperCase() + status.slice(1).toLowerCase();
    
    if (!["Active", "Inactive"].includes(normalizedStatus)) {
      return res.status(400).json({ message: "Invalid status. Allowed values are 'Active' or 'Inactive'." });
    }

    // Find and update the nurse's status
    const nurse = await Nurse.findByIdAndUpdate(
      id,
      { status: normalizedStatus },
      { new: true } // Return the updated document
    );

    if (!nurse) {
      return res.status(404).json({ message: "Nurse not found." });
    }

    res.status(200).json({
      message: `Nurse status updated to '${normalizedStatus}' successfully.`,
      nurse: {
        id: nurse._id,
        nurseId: nurse.nurseId,
        name: nurse.name,
        email: nurse.email,
        role: nurse.role,
        department: nurse.department,
        status: nurse.status,
      },
    });
  } catch (error) {
    console.error("Error updating nurse status:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

module.exports = router;


















