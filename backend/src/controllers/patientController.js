const Patient = require("../models/Patient");

// Register a new patient
const registerPatient = async (req, res) => {
  try {
    const { name, age, gender, contact, emergencyContact, address, medicalHistory } = req.body;

    if (!name || !age || !gender || !contact) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    // Generate a unique patient ID with year, month, date, serial number
    const patientId = await generatePatientId();

    // Create a new patient
    const patient = new Patient({
      patientId,
      name,
      age,
      gender,
      contact,
      emergencyContact,
      address,
      medicalHistory,
      visits: [],
    });

    await patient.save();

    res.status(201).json({
      message: "Patient registered successfully",
      patientId: patientId,
      patientId: patient.patientId,
      _id: patient._id,
      name: patient.name,
      age: patient.age,
      gender: patient.gender,
      contact: patient.contact,
      emergencyContact: patient.emergencyContact,
      address: patient.address,
      medicalHistory: patient.medicalHistory,
      visits: patient.visits,
    });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

// Add a visit for a patient
const addVisit = async (req, res) => {
  try {
    const { patientId, visit } = req.body;

    // Find the patient by ID
    const patient = await Patient.findById(patientId);

    if (!patient) {
      return res.status(404).json({ message: "Patient not found" });
    }

    // Create a new visit with the nested visit data
    const newVisit = {
      date: new Date(),
      weight: visit.weight,
      height: visit.height,
      BP: visit.BP,
      heartRate: visit.heartRate,
      temperature: visit.temperature,
      chiefComplaint: visit.chiefComplaint || "Regular checkup"
    };

    // Add the visit to the patient's visits array
    patient.visits.push(newVisit);
    await patient.save();

    res.status(201).json({
      message: "Visit added successfully",
      visit: newVisit,
      patient: patient,
    });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

// Helper function to generate a unique patient ID0
async function generatePatientId() {
  const now = new Date();
  const year = now.getFullYear();
  const month = (now.getMonth() + 1).toString().padStart(2, "0");
  const date = now.getDate().toString().padStart(2, "0");

  // Get the base prefix for today
  const prefix = `${year}${month}${date}`;

  // Find the highest serial number for today
  const latestPatient = await Patient.findOne({ patientId: new RegExp(`^${prefix}`) }, {}, { sort: { patientId: -1 } });

  let serialNumber = 1;

  if (latestPatient) {
    // Extract the serial number from the latest patient ID
    const latestSerial = Number.parseInt(latestPatient.patientId.substring(8));
    serialNumber = latestSerial + 1;
  }

  // Format the serial number with leading zeros (3 digits)
  const formattedSerial = serialNumber.toString().padStart(3, "0");

  return `${prefix}${formattedSerial}`;
}




// async function generatePatientId() {
//   const date = new Date();
//   const year = date.getFullYear();
//   const month = String(date.getMonth() + 1).padStart(2, "0");
//   const day = String(date.getDate()).padStart(2, "0");
//   const serial = Math.floor(Math.random() * 10000).toString().padStart(4, "0");
//   return `${year}${month}${day}${serial}`;
// }


// Export functions
module.exports = { registerPatient, addVisit };
