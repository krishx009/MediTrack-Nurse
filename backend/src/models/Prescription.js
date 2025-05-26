// Prescription model
const mongoose = require('mongoose');

const medicationSchema = new mongoose.Schema({
  medicine: {
    type: String,
    required: true
  },
  dosage: {
    type: String,
    required: true
  },
  duration: {
    type: String,
    required: true
  },
  notes: String
});

const prescriptionSchema = new mongoose.Schema({
  prescriptionId: {
    type: String,
    unique: true,
    required: true
  },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Patient',
    required: true
  },
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Doctor',
    required: true
  },
  date: {
    type: Date,
    default: Date.now
  },
  diagnosis: {
    type: String,
    required: true
  },
  clinicalNotes: String,
  medications: [medicationSchema],
  specialInstructions: String,
  followUp: String,
  status: {
    type: String,
    enum: ['draft', 'final'],
    default: 'final'
  },
  pdfUrl: String,
  nurseId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Nurse'
  },
  nurseNotes: String,
  administrationStatus: {
    type: String,
    enum: ['pending', 'in-progress', 'completed', 'cancelled'],
    default: 'pending'
  },
  administeredMedications: [{
    medicationId: {
      type: mongoose.Schema.Types.ObjectId
    },
    administeredBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Nurse'
    },
    administeredAt: {
      type: Date
    },
    notes: String
  }]
}, {
  timestamps: true
});

module.exports = mongoose.model('Prescription', prescriptionSchema);
