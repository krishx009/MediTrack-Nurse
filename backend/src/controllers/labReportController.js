// // Lab Report operations for nurse backend
// // Nurses can only view lab reports and generate PDFs
// const LabReport = require('../models/LabReport');
// const Patient = require('../models/Patient');
// const PDFDocument = require('pdfkit');
// const fs = require('fs');
// const path = require('path');
// const mongoose = require('mongoose');

// // @desc    Get all lab reports with filters
// // @route   GET /api/lab-reports
// // @access  Private
// const getAllLabReports = async (req, res) => {
//   try {
//     const { status, testType } = req.query;
    
//     const filter = {};
    
//     if (status) {
//       filter.status = status;
//     }
    
//     if (testType) {
//       filter.testType = testType;
//     }
    
//     // Simply fetch lab reports without populating references to avoid model dependency issues
//     const labReports = await LabReport.find(filter)
//       .sort({ date: -1 });
      
//     res.json(labReports);
//   } catch (error) {
//     console.error(error);
//     res.status(500).json({ message: 'Server error', error: error.message });
//   }
// };

// // @desc    Get all lab reports for a patient
// // @route   GET /api/lab-reports/patient/:patientId
// // @access  Private
// const getPatientLabReports = async (req, res) => {
//   try {
//     // Simply fetch lab reports without populating references to avoid model dependency issues
//     const labReports = await LabReport.find({ patientId: req.params.patientId })
//       .sort({ date: -1 });

//     res.json(labReports);
//   } catch (error) {
//     console.error(error);
//     res.status(500).json({ message: 'Server error', error: error.message });
//   }
// };

// // @desc    Get lab report by ID
// // @route   GET /api/lab-reports/:id
// // @access  Private
// const getLabReportById = async (req, res) => {
//   try {
//     // Simply fetch lab report without populating references to avoid model dependency issues
//     const labReport = await LabReport.findById(req.params.id);

//     if (labReport) {
//       res.json(labReport);
//     } else {
//       res.status(404).json({ message: 'Lab report not found' });
//     }
//   } catch (error) {
//     console.error(error);
//     res.status(500).json({ message: 'Server error', error: error.message });
//   }
// };

// // Helper function to generate PDF
// const generateLabReportPDF = async (labReport, patient, doctor) => {
//   return new Promise(async (resolve, reject) => {
//     try {
//       // Get all lab reports for this patient to determine sequence number, excluding the current one
//       const existingLabReports = await LabReport.find({ 
//         patientId: patient._id,
//         _id: { $ne: labReport._id } // Exclude the current lab report
//       });
      
//       // Always start from 1 for the first lab report
//       const sequenceNumber = (existingLabReports.length + 1).toString().padStart(3, '0');
      
//       // Add an 'L' prefix to the sequence number as requested
//       const formattedSequence = `L${sequenceNumber}`;
      
//       // Create new filename format: LABREP-patientId-L[sequenceNumber]
//       const fileName = `LABREP-${patient.patientId}-${formattedSequence}.pdf`;
      
//       // Create directory if it doesn't exist
//       const dir = path.join('uploads', 'lab-reports');
//       if (!fs.existsSync(dir)) {
//         fs.mkdirSync(dir, { recursive: true });
//       }
      
//       // Add current date and timestamp to ensure absolute uniqueness
//       const currentDate = new Date();
//       const formattedDate = `${currentDate.getFullYear()}${(currentDate.getMonth() + 1).toString().padStart(2, '0')}${currentDate.getDate().toString().padStart(2, '0')}`;
//       const timestamp = Date.now();
//       // Include both date and timestamp to guarantee no overwriting
//       const uniqueFileName = `LABREP-${patient.patientId}-${formattedSequence}-${formattedDate}-${timestamp}.pdf`;
//       const filePath = path.join('uploads', 'lab-reports', uniqueFileName);
      
//       // Create PDF document
//       const doc = new PDFDocument({ margin: 50 });
//       const stream = fs.createWriteStream(filePath);
      
//       doc.pipe(stream);
      
//       // Add header
//       doc.fontSize(20).text('Laboratory Test Report', { align: 'center' });
//       doc.moveDown();
      
//       // Add doctor info
//       doc.fontSize(12).text(`Dr. ${doctor.name}`, { align: 'right' });
//       doc.fontSize(10).text(`${doctor.specialization}`, { align: 'right' });
//       doc.moveDown();
      
//       // Add line
//       doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
//       doc.moveDown();
      
//       // Add patient info
//       doc.fontSize(12).text(`Patient: ${patient.name}`);
//       doc.fontSize(10).text(`ID: ${patient.patientId}`);
//       doc.fontSize(10).text(`Age/Gender: ${patient.age} years / ${patient.gender}`);
//       doc.moveDown();
      
//       // Add report details
//       doc.fontSize(12).text('Test Type:');
//       doc.fontSize(10).text(labReport.testType);
//       doc.moveDown();
      
//       doc.fontSize(12).text('Test Results:');
//       doc.fontSize(10).text(labReport.testResults);
//       doc.moveDown();
      
//       if (labReport.normalRange) {
//         doc.fontSize(12).text('Normal Range:');
//         doc.fontSize(10).text(labReport.normalRange);
//         doc.moveDown();
//       }
      
//       if (labReport.interpretation) {
//         doc.fontSize(12).text('Interpretation:');
//         doc.fontSize(10).text(labReport.interpretation);
//         doc.moveDown();
//       }
      
//       if (labReport.recommendations) {
//         doc.fontSize(12).text('Recommendations:');
//         doc.fontSize(10).text(labReport.recommendations);
//         doc.moveDown();
//       }
      
//       // Add footer
//       doc.moveDown(2);
//       doc.fontSize(10).text(`Date: ${new Date(labReport.date).toLocaleDateString()}`, { align: 'right' });
//       doc.moveDown();
//       doc.fontSize(10).text("Doctor's Signature:", { align: 'right' });
      
//       // Finalize PDF
//       doc.end();
      
//       stream.on('finish', () => {
//         resolve(`/uploads/lab-reports/${uniqueFileName}`);
//       });
      
//       stream.on('error', (error) => {
//         reject(error);
//       });
//     } catch (error) {
//       reject(error);
//     }
//   });
// };

// // @desc    Generate PDF for a lab report
// // @route   GET /api/lab-reports/:id/pdf
// // @access  Private
// const generatePDF = async (req, res) => {
//   try {
//     const labReport = await LabReport.findById(req.params.id);
    
//     if (!labReport) {
//       return res.status(404).json({ message: 'Lab report not found' });
//     }
    
//     const patient = await Patient.findById(labReport.patientId);
//     if (!patient) {
//       return res.status(404).json({ message: 'Patient not found' });
//     }
    
//     // Create a placeholder for doctor information since we don't have access to the Doctor model
//     const doctor = {
//       name: 'Doctor',
//       specialization: 'Medical Professional'
//     };
    
//     // Always generate a fresh PDF with the correct sequence number
//     // This ensures each lab report has its own unique PDF
//     const pdfPath = await generateLabReportPDF(labReport, patient, doctor);
    
//     // Update the lab report with the PDF URL if it's different
//     if (labReport.pdfUrl !== pdfPath) {
//       labReport.pdfUrl = pdfPath;
//       await labReport.save();
//     }
    
//     // Return the PDF URL for download
//     res.json({ 
//       message: 'PDF generated successfully', 
//       pdfUrl: pdfPath,
//       fileName: pdfPath.split('/').pop() // Extract filename for frontend use
//     });
//   } catch (error) {
//     console.error(error);
//     res.status(500).json({ message: 'Server error', error: error.message });
//   }
// };

// module.exports = {
//   getAllLabReports,
//   getPatientLabReports,
//   getLabReportById,
//   generatePDF
// };





// Lab Report operations for nurse backend
// Nurses can only view lab reports and generate PDFs
const LabReport = require('../models/LabReport');
const Patient = require('../models/Patient');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

// @desc    Get all lab reports with filters
// @route   GET /api/lab-reports
// @access  Private
const getAllLabReports = async (req, res) => {
  try {
    const { status, testType } = req.query;
    
    const filter = {};
    
    if (status) {
      filter.status = status;
    }
    
    if (testType) {
      filter.testType = testType;
    }
    
    // Simply fetch lab reports without populating references to avoid model dependency issues
    const labReports = await LabReport.find(filter)
      .sort({ date: -1 });
      
    res.json(labReports);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// @desc    Get all lab reports for a patient
// @route   GET /api/lab-reports/patient/:patientId
// @access  Private
const getPatientLabReports = async (req, res) => {
  try {
    // Simply fetch lab reports without populating references to avoid model dependency issues
    const labReports = await LabReport.find({ patientId: req.params.patientId })
      .sort({ date: -1 });

    res.json(labReports);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// @desc    Get lab report by ID
// @route   GET /api/lab-reports/:id
// @access  Private
const getLabReportById = async (req, res) => {
  try {
    // Simply fetch lab report without populating references to avoid model dependency issues
    const labReport = await LabReport.findById(req.params.id);

    if (labReport) {
      res.json(labReport);
    } else {
      res.status(404).json({ message: 'Lab report not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// Helper function to generate PDF
const generateLabReportPDF = async (labReport, patient, doctor) => {
  return new Promise(async (resolve, reject) => {
    try {
      // Get all lab reports for this patient to determine sequence number, excluding the current one
      const existingLabReports = await LabReport.find({ 
        patientId: patient._id,
        _id: { $ne: labReport._id } // Exclude the current lab report
      });
      
      // Always start from 1 for the first lab report
      const sequenceNumber = (existingLabReports.length + 1).toString().padStart(3, '0');
      
      // Add an 'L' prefix to the sequence number as requested
      const formattedSequence = `L${sequenceNumber}`;
      
      // Create new filename format: LABREP-patientId-L[sequenceNumber]
      const fileName = `LABREP-${patient.patientId}-${formattedSequence}.pdf`;
      
      // Ensure uploads and lab-reports directories exist
      const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
      const labReportsDir = path.join(uploadsDir, 'lab-reports');
      
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }
      
      if (!fs.existsSync(labReportsDir)) {
        fs.mkdirSync(labReportsDir, { recursive: true });
      }
      
      // Add current date and timestamp to ensure absolute uniqueness
      const currentDate = new Date();
      const formattedDate = `${currentDate.getFullYear()}${(currentDate.getMonth() + 1).toString().padStart(2, '0')}${currentDate.getDate().toString().padStart(2, '0')}`;
      const timestamp = Date.now();
      // Include both date and timestamp to guarantee no overwriting
      const uniqueFileName = `LABREP-${patient.patientId}-${formattedSequence}-${formattedDate}-${timestamp}.pdf`;
      const filePath = path.join(labReportsDir, uniqueFileName);
      
      // Create PDF document
      const doc = new PDFDocument({ margin: 50 });
      const stream = fs.createWriteStream(filePath);
      
      doc.pipe(stream);
      
      // Add header
      doc.fontSize(20).text('Laboratory Test Report', { align: 'center' });
      doc.moveDown();
      
      // Add doctor info if available
      if (doctor && doctor.name) {
        doc.fontSize(12).text(`Dr. ${doctor.name}`, { align: 'right' });
        if (doctor.specialization) {
          doc.fontSize(10).text(`${doctor.specialization}`, { align: 'right' });
        }
      } else {
        doc.fontSize(12).text('Medical Professional', { align: 'right' });
      }
      doc.moveDown();
      
      // Add line
      doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
      doc.moveDown();
      
      // Add patient info
      doc.fontSize(12).text(`Patient: ${patient.name}`);
      doc.fontSize(10).text(`ID: ${patient.patientId}`);
      doc.fontSize(10).text(`Age/Gender: ${patient.age} years / ${patient.gender}`);
      doc.moveDown();
      
      // Add report details
      // Use name field if available, otherwise use testType
      const testTitle = labReport.name || labReport.testType || 'Laboratory Test';
      doc.fontSize(14).text(testTitle, { align: 'center' });
      doc.moveDown();
      
      // Add date
      doc.fontSize(12).text(`Date: ${new Date(labReport.date).toLocaleDateString()}`);
      doc.moveDown();
      
      // Add findings/results if available
      if (labReport.findings || labReport.testResults) {
        doc.fontSize(12).text('Findings/Results:');
        doc.fontSize(10).text(labReport.findings || labReport.testResults || 'Not available');
        doc.moveDown();
      }
      
      // If available, add instructions or recommendations
      if (labReport.instructions || labReport.recommendations) {
        doc.fontSize(12).text('Instructions/Recommendations:');
        doc.fontSize(10).text(labReport.instructions || labReport.recommendations || '');
        doc.moveDown();
      }
      
      // Add normal range if available
      if (labReport.normalRange) {
        doc.fontSize(12).text('Normal Range:');
        doc.fontSize(10).text(labReport.normalRange);
        doc.moveDown();
      }
      
      // Add interpretation if available
      if (labReport.interpretation) {
        doc.fontSize(12).text('Interpretation:');
        doc.fontSize(10).text(labReport.interpretation);
        doc.moveDown();
      }
      
      // Add footer
      doc.moveDown(2);
      doc.fontSize(10).text(`Report ID: ${labReport._id}`, { align: 'right' });
      doc.moveDown();
      doc.fontSize(10).text("Doctor's Signature:", { align: 'right' });
      
      // Finalize PDF
      doc.end();
      
      stream.on('finish', () => {
        resolve(`/uploads/lab-reports/${uniqueFileName}`);
      });
      
      stream.on('error', (error) => {
        reject(error);
      });
    } catch (error) {
      reject(error);
    }
  });
};

// @desc    Generate PDF for a lab report
// @route   GET /api/lab-reports/:id/pdf
// @access  Private
const generatePDF = async (req, res) => {
  try {
    console.log('Generating PDF for lab report:', req.params.id);
    const labReport = await LabReport.findById(req.params.id);
    
    if (!labReport) {
      console.log('Lab report not found:', req.params.id);
      return res.status(404).json({ message: 'Lab report not found' });
    }
    
    const patient = await Patient.findById(labReport.patientId);
    if (!patient) {
      console.log('Patient not found for lab report:', labReport._id);
      return res.status(404).json({ message: 'Patient not found' });
    }
    
    // Try to get doctor information from different possible fields
    let doctorInfo = {
      name: 'Doctor',
      specialization: 'Medical Professional'
    };
    
    // Always generate a fresh PDF with the correct sequence number
    // This ensures each lab report has its own unique PDF
    console.log('Generating PDF for lab report with patient:', patient.patientId);
    const pdfPath = await generateLabReportPDF(labReport, patient, doctorInfo);
    console.log('Generated PDF at path:', pdfPath);
    
    // Update the lab report with the PDF URL
    labReport.pdfUrl = pdfPath;
    await labReport.save();
    
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

// @desc    Get PDF for a lab report
// @route   GET /api/lab-reports/:id/get-pdf
// @access  Private
const getPDF = async (req, res) => {
  try {
    console.log('Getting PDF for lab report:', req.params.id);
    console.log('Auth header:', req.headers.authorization);
    
    const labReport = await LabReport.findById(req.params.id);
    
    if (!labReport) {
      return res.status(404).json({ message: 'Lab report not found' });
    }
    
    // Check if PDF exists
    if (!labReport.pdfUrl) {
      console.log('PDF does not exist, generating new one');
      // If PDF doesn't exist, generate it
      const patient = await Patient.findById(labReport.patientId);
      if (!patient) {
        return res.status(404).json({ message: 'Patient not found' });
      }
      
      // Create a placeholder for doctor information
      const doctorInfo = {
        name: 'Doctor',
        specialization: 'Medical Professional'
      };
      
      // Generate the PDF
      const pdfPath = await generateLabReportPDF(labReport, patient, doctorInfo);
      console.log('Generated PDF at path:', pdfPath);
      
      // Update the lab report with the PDF URL
      labReport.pdfUrl = pdfPath;
      await labReport.save();
    } else {
      console.log('Using existing PDF:', labReport.pdfUrl);
    }
    
    // Get the absolute file path
    const absoluteFilePath = path.join(__dirname, '..', '..', labReport.pdfUrl.replace(/^\//, ''));
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
      res.setHeader('Content-Disposition', `attachment; filename="${labReport.pdfUrl.split('/').pop()}"`);
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
  getAllLabReports,
  getPatientLabReports,
  getLabReportById,
  generatePDF,
  getPDF
};
