// Lab Report model - adapted for compatibility with both nurse and doctor backends
const mongoose = require('mongoose');

const labReportSchema = new mongoose.Schema({
  reportId: {
    type: String,
    unique: true,
    sparse: true
  },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Patient',
    required: true
  },
  // Make doctorId optional for compatibility
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Doctor'
  },
  // Add orderedBy field from doctor backend
  orderedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Doctor'
  },
  date: {
    type: Date,
    default: Date.now
  },
  // Make testType optional and add name field from doctor backend
  testType: {
    type: String
  },
  name: {
    type: String
  },
  // Make testResults optional
  testResults: {
    type: String
  },
  normalRange: {
    type: String
  },
  interpretation: {
    type: String
  },
  recommendations: {
    type: String
  },
  // Add findings field from doctor backend
  findings: String,
  // Add instructions field from doctor backend
  instructions: String,
  // Add filePath field from doctor backend
  filePath: String,
  pdfUrl: String,
  // Update status enum to include all possible values from both backends
  status: {
    type: String,
    enum: ['pending', 'completed', 'ordered', 'in-progress'],
    default: 'pending'
  },
  // Add uploadedBy and uploadedAt fields from doctor backend
  uploadedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Nurse'
  },
  uploadedAt: Date
}, {
  timestamps: true
});

module.exports = mongoose.model('LabReport', labReportSchema);
