const mongoose = require("mongoose")

const visitSchema = new mongoose.Schema({
  date: {
    type: Date,
    default: Date.now,
  },
  weight: {
    type: Number,
    required: true,
  },
  height: {
    type: Number,
    required: true,
  },
  BP: {
    type: String,
    required: true,
  },
  heartRate: {
    type: Number,
    required: true,
  },
  temperature: {
    type: Number,
    required: true,
  },
  chiefComplaint: {
    type: String,
    default: "Regular checkup",
  },
  bmi: {
    type: String,
  },
  bmiCategory: {
    type: String,
  },
  notes: {
    type: String,
  },
})

const documentSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  contentType: {
    type: String,
    required: true,
  },
  fileId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
  },
  uploadedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Nurse",
    default: null
  },
  uploadedAt: {
    type: Date,
    default: Date.now,
  },
})

const patientSchema = new mongoose.Schema(
  {
    patientId: {
      type: String,
      unique: true
    },
    name: {
      type: String,
      required: true,
    },
    age: {
      type: Number,
      required: true,
    },
    gender: {
      type: String,
      required: true,
      enum: ["Male", "Female", "Other"],
    },
    contact: {
      type: String,
      required: true,
    },
    emergencyContact: {
      type: String,
      required: true,
    },
    address: {
      type: String,
      required: true,
    },
    medicalHistory: {
      type: String,
      default: "",
    },
    photo: {
      fileId: mongoose.Schema.Types.ObjectId,
      contentType: String,
      uploadedAt: {
        type: Date,
        default: Date.now,
      }
    },
    photoUploadedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Nurse",
      default: null
    },
    idProof: {
      fileId: mongoose.Schema.Types.ObjectId,
      contentType: String,
      uploadedAt: {
        type: Date,
        default: Date.now,
      }
    },
    idProofUploadedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Nurse",
      default: null
    },
    documents: [documentSchema],
    visits: [visitSchema],
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  },
)

module.exports = mongoose.model("Patient", patientSchema)
