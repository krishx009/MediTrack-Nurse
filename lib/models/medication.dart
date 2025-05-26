// This file defines the Medication class for managing patient medications
import 'dart:convert';

class Medication {
  final String medicine;
  final String dosage;
  final String duration;
  final String? notes;

  Medication({
    required this.medicine,
    required this.dosage,
    required this.duration,
    this.notes,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      medicine: json['medicine'] ?? '',
      dosage: json['dosage'] ?? '',
      duration: json['duration'] ?? '',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine': medicine,
      'dosage': dosage,
      'duration': duration,
      'notes': notes,
    };
  }
}
