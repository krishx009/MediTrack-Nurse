const mongoose = require("mongoose");
const bcrypt = require('bcryptjs');

const nurseSchema = new mongoose.Schema({
  nurseId: { type: String, unique: true },
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['Head Nurse', 'Staff Nurse', 'Junior Nurse'], default: 'Staff Nurse', required: true },
  department: { type: String, enum: ['General Medicine', 'Pediatrics', 'Surgery', 'Orthopedics', 'Cardiology', 'Emergency', 'Neurology'], required: true },
 status: { type: String, enum: ['Active', 'Inactive'], default: 'Active' } // Match case with doctor-backend
});

// Pre-save middleware to generate nurseId and hash password
nurseSchema.pre("save", async function (next) {
  // Generate nurseId for new nurses
  if (this.isNew) {
    const count = await mongoose.model("Nurse").countDocuments();
    this.nurseId = `N${String(count + 1).padStart(4, "0")}`; // Generate ID like "N0001"
  }
  
  // Hash password if modified
  if (this.isModified('password')) {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
  
//  // Ensure department and departments are in sync
//   if (this.department && !this.departments) {
//     this.departments = this.department;
//   } else if (this.departments && !this.department) {
//     this.department = this.departments;
//   } 
  
  next();
});

// Add password comparison method
nurseSchema.methods.matchPassword = async function(enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};


module.exports = mongoose.model("Nurse", nurseSchema);