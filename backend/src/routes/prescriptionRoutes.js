// Prescription routes for nurse backend
// NOTE: Nurses can only view prescriptions and generate PDFs, but CANNOT create, update, or administer prescriptions
// Prescription creation and administration is exclusively handled by the doctor backend
const express = require('express');
const router = express.Router();
const { 
  getPatientPrescriptions, 
  getPrescriptionById, 
  getAllPrescriptions,
  generatePDF,
  getPDF
} = require('../controllers/prescriptionController');
const { verifyToken } = require('../middleware/authMiddleware');

// Protect all routes
router.use(verifyToken);

// Get all prescriptions with optional filters
router.get('/', getAllPrescriptions);

// Get all prescriptions for a patient
router.get('/patient/:patientId', getPatientPrescriptions);

// Get prescription by ID
router.get('/:id', getPrescriptionById);

// Administration-related routes have been removed as per requirement

// Generate PDF for a prescription
router.get('/:id/pdf', generatePDF);

// Get and download PDF for a prescription
router.get('/:id/get-pdf', getPDF);

module.exports = router;
