// This file defines the Patient class for managing patient data in a healthcare application.
import 'dart:convert';
import 'package:flutter/foundation.dart';
// Import model classes from their dedicated files
import 'diagnosis.dart';
import 'patient_document.dart';
import 'vitals.dart';
import 'medication.dart';
import 'lab_report.dart';

class Patient {
  final String id;
  final String patientId;
  final String name;
  final int age;
  final String gender;
  final String phoneNumber;
  final String emergencyContact;
  final String address;
  final String medicalHistory;
  final String? photo;
  final String? photoUploadedBy;
  final String? idProof;
  final String? idProofUploadedBy;
  final String lastVisitDate;
  final List<Diagnosis> diagnoses;
  final List<PatientDocument> documents;
  final bool isActive;

  Patient({
    required this.id,
    required this.patientId,
    required this.name,
    required this.age,
    required this.gender,
    required this.phoneNumber,
    required this.emergencyContact,
    required this.address,
    required this.medicalHistory,
    this.photo,
    this.photoUploadedBy,
    this.idProof,
    this.idProofUploadedBy,
    required this.lastVisitDate,
    required this.diagnoses,
    required this.documents,
    required this.isActive,
  });

  // Convert JSON to Patient object
  factory Patient.fromJson(Map<String, dynamic> json) {
    List<Diagnosis> diagnosesList = [];
    if (json['visits'] != null && json['visits'] is List) {
      diagnosesList = List<Diagnosis>.from(
          json['visits'].map((visit) => Diagnosis.fromVisit(visit)));
    }

    List<PatientDocument> documentsList = [];
    if (json['documents'] != null && json['documents'] is List) {
      documentsList = List<PatientDocument>.from(
          json['documents'].map((doc) => PatientDocument.fromJson(doc)));
    }

    String lastVisitDate = '';
    if (json['visits'] != null &&
        json['visits'] is List &&
        json['visits'].isNotEmpty) {
      var lastVisit = json['visits'].last;
      if (lastVisit['date'] != null) {
        lastVisitDate =
            DateTime.parse(lastVisit['date']).toString().substring(0, 10);
      }
    }
    
    // Safely handle photo and idProof fields which might be complex objects
    String? photoStr;
    if (json['photo'] != null) {
      if (json['photo'] is String) {
        photoStr = json['photo'];
      } else if (json['photo'] is Map) {
        // If photo is a map/object, extract the fileId which we can use for API calls
        if (json['photo']['fileId'] != null) {
          // Construct direct path to photo endpoint
          photoStr = json['_id'] + '/photo';
        } else {
          photoStr = json['photo']['data'] != null ? json['_id'] + '/photo' : null;
        }
      }
    }
    
    String? idProofStr;
    if (json['idProof'] != null) {
      if (json['idProof'] is String) {
        idProofStr = json['idProof'];
      } else if (json['idProof'] is Map) {
        // If idProof is a map/object, extract the fileId which we can use for API calls
        if (json['idProof']['fileId'] != null) {
          // Construct direct path to idproof endpoint
          idProofStr = json['_id'] + '/idproof';
        } else {
          idProofStr = json['idProof']['data'] != null ? json['_id'] + '/idproof' : null;
        }
      }
    }
    
    // Safely handle uploadedBy fields
    String? photoUploadedByStr;
    if (json['photoUploadedBy'] != null) {
      if (json['photoUploadedBy'] is String) {
        photoUploadedByStr = json['photoUploadedBy'];
      } else if (json['photoUploadedBy'] is Map) {
        photoUploadedByStr = json['photoUploadedBy']['name'] ?? 'Unknown';
      }
    }
    
    String? idProofUploadedByStr;
    if (json['idProofUploadedBy'] != null) {
      if (json['idProofUploadedBy'] is String) {
        idProofUploadedByStr = json['idProofUploadedBy'];
      } else if (json['idProofUploadedBy'] is Map) {
        idProofUploadedByStr = json['idProofUploadedBy']['name'] ?? 'Unknown';
      }
    }

    return Patient(
      id: json['_id'] ?? '',
      patientId: json['patientId'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? '',
      phoneNumber: json['contact'] ?? '',
      emergencyContact: json['emergencyContact'] ?? '',
      address: json['address'] ?? '',
      medicalHistory: json['medicalHistory'] ?? '',
      photo: photoStr,
      photoUploadedBy: photoUploadedByStr,
      idProof: idProofStr,
      idProofUploadedBy: idProofUploadedByStr,
      lastVisitDate: lastVisitDate,
      diagnoses: diagnosesList,
      documents: documentsList,
      isActive: json['isActive'] ?? true,
    );
  }

  // Convert Patient object to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'contact': phoneNumber,
      'emergencyContact': emergencyContact,
      'address': address,
      'medicalHistory': medicalHistory,
    };
  }

  // Get number of visits
  int get visitCount => diagnoses.length;
}
