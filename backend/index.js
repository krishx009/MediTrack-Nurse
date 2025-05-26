const express = require("express");
const connectDB = require("./src/config/db");
const cors = require("cors");
const dotenv = require("dotenv");
const path = require("path");
const fs = require("fs");

dotenv.config();
connectDB();

const app = express();
app.use(express.json());
app.use(cors());

// Create uploads directory and prescriptions subdirectory if they don't exist
const uploadsDir = path.join(__dirname, 'uploads');
const prescriptionsDir = path.join(uploadsDir, 'prescriptions');

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
}

if (!fs.existsSync(prescriptionsDir)) {
  fs.mkdirSync(prescriptionsDir);
}

// Serve static files from uploads directory
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use("/api/nurse", require("./src/routes/nurseRoutes"));
app.use("/api/patient", require("./src/routes/patientRoutes"));
app.use("/api/visit", require("./src/routes/visitRoutes"));
app.use("/api/prescriptions", require("./src/routes/prescriptionRoutes"));
app.use("/api/lab-reports", require("./src/routes/labReportRoutes"));

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}`));
