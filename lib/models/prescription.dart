import 'dart:convert';
import 'medication.dart';

class Prescription {
  final String id;
  final String prescriptionId;
  final String patientId;
  final String doctorId;
  final DateTime date;
  final String diagnosis;
  final String? clinicalNotes;
  final List<Medication> medications;
  final String? specialInstructions;
  final String? followUp;
  final String status;
  final String? pdfUrl;
  final String? nurseId;
  final String? nurseNotes;
  final String administrationStatus;
  final List<AdministeredMedication>? administeredMedications;

  Prescription({
    required this.id,
    required this.prescriptionId,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.diagnosis,
    this.clinicalNotes,
    required this.medications,
    this.specialInstructions,
    this.followUp,
    required this.status,
    this.pdfUrl,
    this.nurseId,
    this.nurseNotes,
    required this.administrationStatus,
    this.administeredMedications,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['_id'] ?? '',
      prescriptionId: json['prescriptionId'] ?? '',
      patientId: json['patientId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      diagnosis: json['diagnosis'] ?? '',
      clinicalNotes: json['clinicalNotes'],
      medications: json['medications'] != null
          ? List<Medication>.from(
              json['medications'].map((m) => Medication.fromJson(m)))
          : [],
      specialInstructions: json['specialInstructions'],
      followUp: json['followUp'],
      status: json['status'] ?? 'draft',
      pdfUrl: json['pdfUrl'],
      nurseId: json['nurseId'],
      nurseNotes: json['nurseNotes'],
      administrationStatus: json['administrationStatus'] ?? 'pending',
      administeredMedications: json['administeredMedications'] != null
          ? List<AdministeredMedication>.from(
              json['administeredMedications']
                  .map((m) => AdministeredMedication.fromJson(m)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'prescriptionId': prescriptionId,
      'patientId': patientId,
      'doctorId': doctorId,
      'date': date.toIso8601String(),
      'diagnosis': diagnosis,
      'clinicalNotes': clinicalNotes,
      'medications': medications.map((m) => m.toJson()).toList(),
      'specialInstructions': specialInstructions,
      'followUp': followUp,
      'status': status,
      'pdfUrl': pdfUrl,
      'nurseId': nurseId,
      'nurseNotes': nurseNotes,
      'administrationStatus': administrationStatus,
      'administeredMedications': administeredMedications != null
          ? administeredMedications!.map((m) => m.toJson()).toList()
          : null,
    };
  }
}

class AdministeredMedication {
  final String? medicationId;
  final String? administeredBy;
  final DateTime? administeredAt;
  final String? notes;

  AdministeredMedication({
    this.medicationId,
    this.administeredBy,
    this.administeredAt,
    this.notes,
  });

  factory AdministeredMedication.fromJson(Map<String, dynamic> json) {
    return AdministeredMedication(
      medicationId: json['medicationId'],
      administeredBy: json['administeredBy'],
      administeredAt: json['administeredAt'] != null
          ? DateTime.parse(json['administeredAt'])
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicationId': medicationId,
      'administeredBy': administeredBy,
      'administeredAt': administeredAt?.toIso8601String(),
      'notes': notes,
    };
  }
}
