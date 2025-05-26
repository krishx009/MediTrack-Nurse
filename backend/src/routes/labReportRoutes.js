// // Lab Report routes for nurse backend
// // NOTE: Nurses can only view lab reports and generate PDFs, but CANNOT create or update lab reports
// // Lab report creation is exclusively handled by the doctor backend
// const express = require('express');
// const router = express.Router();
// const { 
//   getPatientLabReports, 
//   getLabReportById, 
//   getAllLabReports,
//   generatePDF
// } = require('../controllers/labReportController');
// const { verifyToken } = require('../middleware/authMiddleware');

// // Protect all routes
// router.use(verifyToken);

// // Get all lab reports with optional filters
// router.get('/', getAllLabReports);

// // Get all lab reports for a patient
// router.get('/patient/:patientId', getPatientLabReports);

// // Get lab report by ID
// router.get('/:id', getLabReportById);

// // Generate PDF for a lab report
// router.get('/:id/pdf', generatePDF);

// module.exports = router;


// Lab Report routes for nurse backend
// NOTE: Nurses can only view lab reports and generate PDFs, but CANNOT create or update lab reports
// Lab report creation is exclusively handled by the doctor backend
const express = require('express');
const router = express.Router();
const { 
  getPatientLabReports, 
  getLabReportById, 
  getAllLabReports,
  generatePDF,
  getPDF
} = require('../controllers/labReportController');
const { verifyToken } = require('../middleware/authMiddleware');

// Protect all routes
router.use(verifyToken);

// Get all lab reports with optional filters
router.get('/', getAllLabReports);

// Get all lab reports for a patient
router.get('/patient/:patientId', getPatientLabReports);

// Get lab report by ID
router.get('/:id', getLabReportById);

// Generate PDF for a lab report
router.get('/:id/pdf', generatePDF);

// Get and download PDF for a lab report
router.get('/:id/get-pdf', getPDF);

module.exports = router;
