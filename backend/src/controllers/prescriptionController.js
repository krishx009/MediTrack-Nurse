// Prescription operations for nurse backend
// Nurses can only view prescriptions and generate PDFs, no administration capabilities
const Prescription = require('../models/Prescription');
const Patient = require('../models/Patient');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const mongoose = require('mongoose');

// @desc    Get all prescriptions for a patient
// @route   GET /api/prescriptions/patient/:patientId
// @access  Private
const getPatientPrescriptions = async (req, res) => {
  try {
    // Simply fetch prescriptions without populating references to avoid model dependency issues
    const prescriptions = await Prescription.find({ patientId: req.params.patientId })
      .sort({ date: -1 });

    res.json(prescriptions);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// @desc    Get prescription by ID
// @route   GET /api/prescriptions/:id
// @access  Private
const getPrescriptionById = async (req, res) => {
  try {
    // Simply fetch prescription without populating references to avoid model dependency issues
    const prescription = await Prescription.findById(req.params.id);

    if (prescription) {
      res.json(prescription);
    } else {
      res.status(404).json({ message: 'Prescription not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Note: Administration-related functions have been removed as per requirement

// @desc    Get all prescriptions with filters
// @route   GET /api/prescriptions
// @access  Private
const getAllPrescriptions = async (req, res) => {
  try {
    const { status, administrationStatus } = req.query;
    
    const filter = {};
    
    if (status) {
      filter.status = status;
    }
    
    if (administrationStatus) {
      filter.administrationStatus = administrationStatus;
    }
    
    // Simply fetch prescriptions without populating references to avoid model dependency issues
    const prescriptions = await Prescription.find(filter)
      .sort({ date: -1 });
      
    res.json(prescriptions);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Helper function to generate PDF
const generatePrescriptionPDF = async (prescription, patient, doctor) => {
  return new Promise(async (resolve, reject) => {
    try {
      // Get all prescriptions for this patient to determine sequence number, excluding the current one
      const existingPrescriptions = await Prescription.find({ 
        patientId: patient._id,
        _id: { $ne: prescription._id } // Exclude the current prescription
      });
      
      // Always start from 1 for the first prescription
      const sequenceNumber = (existingPrescriptions.length + 1).toString().padStart(3, '0');
      
      // Add a 'P' prefix to the sequence number as requested
      const formattedSequence = `P${sequenceNumber}`;
      
      // Create new filename format: PRXN-patientId-P[sequenceNumber]
      const fileName = `PRXN-${patient.patientId}-${formattedSequence}.pdf`;
      
      // Ensure uploads and prescriptions directories exist
      const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
      const prescriptionsDir = path.join(uploadsDir, 'prescriptions');
      
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }
      
      if (!fs.existsSync(prescriptionsDir)) {
        fs.mkdirSync(prescriptionsDir, { recursive: true });
      }
      
      // Add current date and timestamp to ensure absolute uniqueness
      const currentDate = new Date();
      const formattedDate = `${currentDate.getFullYear()}${(currentDate.getMonth() + 1).toString().padStart(2, '0')}${currentDate.getDate().toString().padStart(2, '0')}`;
      const timestamp = Date.now();
      // Include both date and timestamp to guarantee no overwriting
      const uniqueFileName = `PRXN-${patient.patientId}-${formattedSequence}-${formattedDate}-${timestamp}.pdf`;
      const filePath = path.join(prescriptionsDir, uniqueFileName);
      
      // Create PDF document
      const doc = new PDFDocument({ margin: 50 });
      const stream = fs.createWriteStream(filePath);
      
      doc.pipe(stream);
      
      // Add header
      doc.fontSize(20).text('Medical Prescription', { align: 'center' });
      doc.moveDown();
      
      // Add doctor info
      doc.fontSize(12).text(`Dr. ${doctor.name}`, { align: 'right' });
      doc.fontSize(10).text(`${doctor.specialization}`, { align: 'right' });
      doc.moveDown();
      
      // Add line
      doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
      doc.moveDown();
      
      // Add patient info
      doc.fontSize(12).text(`Patient: ${patient.name}`);
      doc.fontSize(10).text(`ID: ${patient.patientId}`);
      doc.fontSize(10).text(`Age/Gender: ${patient.age} years / ${patient.gender}`);
      doc.moveDown();
      
      // Add prescription details
      doc.fontSize(12).text('Diagnosis:');
      doc.fontSize(10).text(prescription.diagnosis);
      doc.moveDown();
      
      if (prescription.clinicalNotes) {
        doc.fontSize(12).text('Clinical Notes:');
        doc.fontSize(10).text(prescription.clinicalNotes);
        doc.moveDown();
      }
      
      // Add medications
      doc.fontSize(12).text('Medications:');
      doc.moveDown();
      
      prescription.medications.forEach((med, index) => {
        doc.fontSize(10).text(`${index + 1}. ${med.medicine}`);
        doc.fontSize(9).text(`   Dosage: ${med.dosage}`);
        doc.fontSize(9).text(`   Duration: ${med.duration}`);
        if (med.notes) {
          doc.fontSize(9).text(`   Instructions: ${med.notes}`);
        }
        doc.moveDown(0.5);
      });
      
      if (prescription.specialInstructions) {
        doc.moveDown();
        doc.fontSize(12).text('Special Instructions:');
        doc.fontSize(10).text(prescription.specialInstructions);
      }
      
      if (prescription.followUp) {
        doc.moveDown();
        doc.fontSize(12).text('Follow-up:');
        doc.fontSize(10).text(`After ${prescription.followUp}`);
      }
      
      // Nurse administration info has been removed as per requirement
      
      // Add footer
      doc.moveDown(2);
      doc.fontSize(10).text(`Date: ${new Date(prescription.date).toLocaleDateString()}`, { align: 'right' });
      doc.moveDown();
      doc.fontSize(10).text("Doctor's Signature:", { align: 'right' });
      
      // Finalize PDF
      doc.end();
      
      stream.on('finish', () => {
        resolve(`/uploads/prescriptions/${uniqueFileName}`);
      });
      
      stream.on('error', (error) => {
        reject(error);
      });
    } catch (error) {
      reject(error);
    }
  });
};

// @desc    Generate PDF for a prescription
// @route   GET /api/prescriptions/:id/pdf
// @access  Private
const generatePDF = async (req, res) => {
  try {
    console.log('Generating PDF for prescription:', req.params.id);
    const prescription = await Prescription.findById(req.params.id);
    
    if (!prescription) {
      return res.status(404).json({ message: 'Prescription not found' });
    }
    
    const patient = await Patient.findById(prescription.patientId);
    if (!patient) {
      return res.status(404).json({ message: 'Patient not found' });
    }
    
    // Create a placeholder for doctor information
    const doctor = {
      name: 'Doctor',
      specialization: 'Medical Professional'
    };
    
    // Generate the PDF
    const pdfPath = await generatePrescriptionPDF(prescription, patient, doctor);
    console.log('Generated PDF at path:', pdfPath);
    
    // Update the prescription with the PDF URL
    prescription.pdfUrl = pdfPath;
    await prescription.save();
    
    // Return the PDF URL for download
    res.json({ 
      success: true,
      message: 'PDF generated successfully', 
      pdfUrl: pdfPath,
      fileName: pdfPath.split('/').pop() // Extract filename for frontend use
    });
  } catch (error) {
    console.error('PDF Generation Error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// @desc    Get PDF for a prescription
// @route   GET /api/prescriptions/:id/get-pdf
// @access  Private
const getPDF = async (req, res) => {
  try {
    console.log('Getting PDF for prescription:', req.params.id);
    console.log('Auth header:', req.headers.authorization);
    
    const prescription = await Prescription.findById(req.params.id);
    
    if (!prescription) {
      return res.status(404).json({ message: 'Prescription not found' });
    }
    
    // Check if PDF exists
    if (!prescription.pdfUrl) {
      console.log('PDF does not exist, generating new one');
      // If PDF doesn't exist, generate it
      const patient = await Patient.findById(prescription.patientId);
      if (!patient) {
        return res.status(404).json({ message: 'Patient not found' });
      }
      
      // Create a placeholder for doctor information
      const doctor = {
        name: 'Doctor',
        specialization: 'Medical Professional'
      };
      
      // Generate the PDF
      const pdfPath = await generatePrescriptionPDF(prescription, patient, doctor);
      console.log('Generated PDF at path:', pdfPath);
      
      // Update the prescription with the PDF URL
      prescription.pdfUrl = pdfPath;
      await prescription.save();
    } else {
      console.log('Using existing PDF:', prescription.pdfUrl);
    }
    
    // Get the absolute file path
    const absoluteFilePath = path.join(__dirname, '..', '..', prescription.pdfUrl.replace(/^\//, ''));
    console.log('Absolute file path:', absoluteFilePath);
    
    // Check if the file exists
    if (!fs.existsSync(absoluteFilePath)) {
      console.log('PDF file not found at path:', absoluteFilePath);
      return res.status(404).json({ message: 'PDF file not found on server' });
    }
    
    try {
      console.log('Reading PDF file...');
      const fileBuffer = fs.readFileSync(absoluteFilePath);
      console.log('PDF file read successfully, size:', fileBuffer.length, 'bytes');
      
      // Set appropriate headers for PDF download
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${prescription.pdfUrl.split('/').pop()}"`); 
      res.setHeader('Content-Length', fileBuffer.length);
      
      // Send the file as binary data
      console.log('Sending PDF file to client');
      return res.send(fileBuffer);
    } catch (fileError) {
      console.error('Error reading PDF file:', fileError);
      return res.status(500).json({ message: 'Error reading PDF file', error: fileError.message });
    }
  } catch (error) {
    console.error('PDF Generation Error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getPatientPrescriptions,
  getPrescriptionById,
  getAllPrescriptions,
  generatePDF,
  getPDF
};
