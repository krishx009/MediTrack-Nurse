// This file defines the Diagnosis class for managing patient diagnoses and visits
import 'dart:convert';
import 'vitals.dart';
import 'medication.dart';
import 'lab_report.dart';

class Diagnosis {
  final String date;
  final String condition;
  final String status;
  final String? details;
  final Vitals? vitals;
  final String? bmi;
  final String? bmiCategory;
  final List<Medication>? medications;
  final List<LabReport>? labReports;

  var notes;

  Diagnosis({
    required this.date,
    required this.condition,
    required this.status,
    this.details,
    this.vitals,
    this.bmi,
    this.bmiCategory,
    this.medications,
    this.labReports,
  });

  // Create Diagnosis from visit data
  factory Diagnosis.fromVisit(Map<String, dynamic> visit) {
    String formattedDate = '';
    if (visit['date'] != null) {
      try {
        formattedDate =
            DateTime.parse(visit['date'].toString()).toString().substring(0, 10);
      } catch (e) {
        formattedDate = visit['date'].toString();
      }
    }
    
    // Safely extract numeric values
    String weight = '';
    if (visit['weight'] != null) {
      weight = visit['weight'].toString();
    }
    
    String height = '';
    if (visit['height'] != null) {
      height = visit['height'].toString();
    }
    
    String bp = '';
    if (visit['BP'] != null) {
      bp = visit['BP'].toString();
    } else if (visit['bp'] != null) {
      bp = visit['bp'].toString();
    }
    
    String heartRate = '';
    if (visit['heartRate'] != null) {
      heartRate = visit['heartRate'].toString();
    }
    
    String temperature = '';
    if (visit['temperature'] != null) {
      temperature = visit['temperature'].toString();
    }
    
    String? bmiValue;
    if (visit['bmi'] != null) {
      bmiValue = visit['bmi'].toString();
    }
    
    String? bmiCategoryValue;
    if (visit['bmiCategory'] != null) {
      bmiCategoryValue = visit['bmiCategory'].toString();
    }

    return Diagnosis(
      date: formattedDate,
      condition: visit['chiefComplaint'] != null ? visit['chiefComplaint'].toString() : 'Regular Checkup',
      status: 'Completed',
      details:
          'Weight: ${weight}kg, Height: ${height}cm, BP: ${bp}',
      vitals: Vitals(
        bloodPressure: bp,
        heartRate: heartRate,
        respiratoryRate: '16', // Default value
        temperature: temperature,
        oxygenSaturation: '98%', // Default value
      ),
      bmi: bmiValue,
      bmiCategory: bmiCategoryValue,
      medications: [],
      labReports: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'condition': condition,
      'status': status,
      'details': details,
      'vitals': vitals?.toJson(),
      'bmi': bmi,
      'bmiCategory': bmiCategory,
      'medications': medications?.map((m) => m.toJson()).toList(),
      'labReports': labReports?.map((l) => l.toJson()).toList(),
    };
  }
}
