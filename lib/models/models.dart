// This file exports all model classes to make imports cleaner in other files

// Export only the Patient class from patient.dart
export 'patient.dart' show Patient;

// Export the dedicated model classes from their respective files
export 'patient_document.dart';
export 'diagnosis.dart';
export 'vitals.dart';
export 'medication.dart';
export 'lab_report.dart';
export 'prescription.dart';
