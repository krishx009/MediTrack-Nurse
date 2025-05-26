const mongoose = require("mongoose");

const visitSchema = new mongoose.Schema({
  patientId: { type: String, required: true },
  date: { type: Date, required: true },
  weight: { type: Number, required: true },
  height: { type: Number, required: true },
  bp: { type: String, required: true },
  heartRate: { type: Number, required: true },
  temperature: { type: Number, required: true },
});

module.exports = mongoose.model("Visit", visitSchema);
