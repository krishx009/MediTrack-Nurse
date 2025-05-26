const express = require("express");
const router = express.Router();
const { registerPatient, addVisit } = require("../controllers/patientController")
const Patient = require("../models/Patient");
const upload = require("../middleware/uploadMiddleware");
const mongoose = require('mongoose'); // mongoose is required for ObjectId validation
const { verifyToken } = require("../middleware/authMiddleware")
const { streamToGridFS, streamFileFromGridFS, deleteFileFromGridFS } = require('../utils/gridfsUtils');

// Register a new patient
router.post("/register", registerPatient);


// router.post("/register", async (req, res) => {
//   try {
//     const newPatient = new Patient(req.body);
//     await newPatient.save();
//     res.status(201).json({ message: "Patient registered successfully!", patient: newPatient });
//   } catch (error) {
//     res.status(500).json({ message: "Server error", error: error.message });
//   }
// });

// Upload documents for a patient
router.post("/upload/:patientId/documents", upload.any(), async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }

    let uploadedBy = null;
    if (req.body.uploadedBy && mongoose.Types.ObjectId.isValid(req.body.uploadedBy)) {
      uploadedBy = req.body.uploadedBy;
    } else if (req.user && req.user._id) {
      uploadedBy = req.user._id;
    }

    const uploadPromises = req.files.map(async (file) => {
      const gridfsFile = await streamToGridFS(file.buffer, {
        filename: file.originalname,
        contentType: file.mimetype,
        metadata: {
          patientId: patient._id,
          uploadedBy: uploadedBy
        }
      });

      return {
        name: file.originalname,
        contentType: file.mimetype,
        fileId: gridfsFile._id,
        uploadedBy: uploadedBy,
        uploadedAt: new Date()
      };
    });

    const uploadedFiles = await Promise.all(uploadPromises);
    patient.documents.push(...uploadedFiles);
    await patient.save();

    res.status(200).json({
      message: "Files uploaded successfully",
      files: uploadedFiles.map(f => ({ name: f.name, uploadDate: f.uploadedAt }))
    });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get all documents for a patient
router.get("/:patientId/documents", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }
    
    const documents = patient.documents.map(doc => ({
      id: doc._id,
      name: doc.name,
      contentType: doc.contentType,
      uploadDate: doc.uploadedAt
    }));
    
    res.status(200).json(documents);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Download a specific document
router.get("/:patientId/documents/:documentId", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }

    const document = patient.documents.id(req.params.documentId);
    if (!document) {
      return res.status(404).json({ message: "Document not found" });
    }

    // Set appropriate headers for file download
    res.set({
      'Content-Type': document.contentType,
      'Content-Disposition': `inline; filename="${document.name}"`,
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache'
    });

    // Stream the file from GridFS
    streamFileFromGridFS(document.fileId, res);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Delete a document
router.delete("/:patientId/documents/:documentId", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }

    const document = patient.documents.id(req.params.documentId);
    if (!document) {
      return res.status(404).json({ message: "Document not found" });
    }

    await deleteFileFromGridFS(document.fileId);
    patient.documents.pull(req.params.documentId);
    await patient.save();

    res.status(200).json({ message: "Document deleted successfully" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get all patients
router.get("/list", async (req, res) => {
  try {
    const patients = await Patient.find().select('-documents.fileId -photo.fileId -idProof.fileId');
    res.status(200).json(patients);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get a specific patient
router.get("/:id", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.id).select('-documents.fileId -photo.fileId -idProof.fileId');
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }
    res.status(200).json(patient);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Add a visit for a patient
router.post("/visit", addVisit);

// Get all visits for a specific patient
router.get("/:id/visits", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.id);
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }
    res.status(200).json(patient.visits || []);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Upload patient photo and ID proof
router.post("/upload/:patientId/profile", upload.fields([
  { name: 'photo', maxCount: 1 },
  { name: 'idProof', maxCount: 1 }
]), async (req, res) => {
  try {
    const { patientId } = req.params;
    const patient = await Patient.findById(patientId);

    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }

    let uploadedBy = null;
    if (req.body.uploadedBy && mongoose.Types.ObjectId.isValid(req.body.uploadedBy)) {
      uploadedBy = req.body.uploadedBy;
    } else if (req.user && req.user._id) {
      uploadedBy = req.user._id;
    }

    if (req.files.photo) {
      const photoFile = req.files.photo[0];
      const gridfsFile = await streamToGridFS(photoFile.buffer, {
        filename: photoFile.originalname,
        contentType: photoFile.mimetype,
        metadata: {
          patientId: patient._id,
          type: 'photo',
          uploadedBy: uploadedBy
        }
      });

      patient.photo = {
        fileId: gridfsFile._id,
        contentType: photoFile.mimetype,
        uploadedAt: new Date()
      };
      patient.photoUploadedBy = uploadedBy;
    }
    
    if (req.files.idProof) {
      const idProofFile = req.files.idProof[0];
      const gridfsFile = await streamToGridFS(idProofFile.buffer, {
        filename: idProofFile.originalname,
        contentType: idProofFile.mimetype,
        metadata: {
          patientId: patient._id,
          type: 'idProof',
          uploadedBy: uploadedBy
        }
      });

      patient.idProof = {
        fileId: gridfsFile._id,
        contentType: idProofFile.mimetype,
        uploadedAt: new Date()
      };
      patient.idProofUploadedBy = uploadedBy;
    }

    await patient.save();
    res.status(200).json({ 
      message: "Files uploaded successfully", 
      patient: {
        _id: patient._id,
        name: patient.name,
        hasPhoto: !!patient.photo.fileId,
        hasIdProof: !!patient.idProof.fileId
      }
    });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get patient photo
router.get("/:patientId/photo", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient || !patient.photo || !patient.photo.fileId) {
      return res.status(404).json({ message: "Photo not found" });
    }

    res.set('Content-Type', patient.photo.contentType);
    streamFileFromGridFS(patient.photo.fileId, res);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get patient ID proof
router.get("/:patientId/idproof", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient || !patient.idProof || !patient.idProof.fileId) {
      return res.status(404).json({ message: "ID proof not found" });
    }

    res.set('Content-Type', patient.idProof.contentType);
    streamFileFromGridFS(patient.idProof.fileId, res);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Rename a document
router.put("/:patientId/documents/:documentId/rename", async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }

    const document = patient.documents.id(req.params.documentId);
    if (!document) {
      return res.status(404).json({ message: "Document not found" });
    }

    const { newName } = req.body;
    if (!newName || typeof newName !== 'string' || newName.trim().length === 0) {
      return res.status(400).json({ message: "Invalid document name" });
    }

    // Update the document name
    document.name = newName.trim();
    await patient.save();

    res.status(200).json({
      message: "Document renamed successfully",
      document: {
        id: document._id,
        name: document.name,
        contentType: document.contentType,
        uploadedAt: document.uploadedAt,
        uploadedBy: document.uploadedBy
      }
    });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Delete patient photo
router.delete('/:patientId/photo', async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: 'Patient not found' });
    }

    // Check if patient has a photo
    if (!patient.photo || !patient.photo.fileId) {
      return res.status(404).json({ message: 'Patient photo not found' });
    }

    // Delete photo from GridFS
    await deleteFileFromGridFS(patient.photo.fileId);

    // Remove photo reference from patient document
    patient.photo = {};
    patient.photoUploadedBy = null;
    await patient.save();

    res.status(200).json({ message: 'Patient photo deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete patient ID proof
router.delete('/:patientId/idproof', async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.patientId);
    if (!patient) {
      return res.status(404).json({ message: 'Patient not found' });
    }

    // Check if patient has an ID proof
    if (!patient.idProof || !patient.idProof.fileId) {
      return res.status(404).json({ message: 'Patient ID proof not found' });
    }

    // Delete ID proof from GridFS
    await deleteFileFromGridFS(patient.idProof.fileId);

    // Remove ID proof reference from patient document
    patient.idProof = {};
    patient.idProofUploadedBy = null;
    await patient.save();

    res.status(200).json({ message: 'Patient ID proof deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
