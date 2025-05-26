const Visit = require("../models/Visit");

const addVisit = async (req, res) => {
  try {
    const { patientId, date, weight, height, bp, heartRate, temperature } = req.body;

    const newVisit = new Visit({
      patientId,
      date,
      weight,
      height,
      bp,
      heartRate,
      temperature,
    });

    await newVisit.save();
    res.status(201).json({ message: "Visit recorded successfully", visit: newVisit });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = { addVisit };
