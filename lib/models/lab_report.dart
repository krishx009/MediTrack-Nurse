// This file defines the LabReport class for managing patient lab reports
import 'dart:convert';

class LabReport {
  final String id;
  final String reportId;
  final String patientId;
  final String name;
  final String testType;
  final String date;
  final String status;
  final String testResults;
  final String normalRange;
  final String interpretation;
  final String recommendations;
  final String findings;
  final String instructions;
  final String pdfUrl;
  final String requestedBy;
  final String notes;

  LabReport({
    required this.id,
    this.reportId = '',
    required this.patientId,
    required this.name,
    this.testType = '',
    required this.date,
    required this.status,
    this.testResults = '',
    this.normalRange = '',
    this.interpretation = '',
    this.recommendations = '',
    this.findings = '',
    this.instructions = '',
    this.pdfUrl = '',
    this.requestedBy = '',
    this.notes = '',
  });

  factory LabReport.fromJson(Map<String, dynamic> json) {
    String dateStr = '';
    if (json['date'] != null) {
      try {
        dateStr = DateTime.parse(json['date'].toString()).toString().substring(0, 10);
      } catch (e) {
        dateStr = json['date'].toString();
      }
    }
    
    return LabReport(
      id: json['_id'] ?? '',
      reportId: json['reportId'] ?? '',
      patientId: json['patientId'] ?? '',
      name: json['name'] ?? json['testType'] ?? '',
      testType: json['testType'] ?? '',
      date: dateStr,
      status: json['status'] ?? 'pending',
      testResults: json['testResults'] ?? '',
      normalRange: json['normalRange'] ?? '',
      interpretation: json['interpretation'] ?? '',
      recommendations: json['recommendations'] ?? '',
      findings: json['findings'] ?? '',
      instructions: json['instructions'] ?? '',
      pdfUrl: json['pdfUrl'] ?? '',
      requestedBy: json['requestedBy'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'reportId': reportId,
      'patientId': patientId,
      'name': name,
      'testType': testType,
      'date': date,
      'status': status,
      'testResults': testResults,
      'normalRange': normalRange,
      'interpretation': interpretation,
      'recommendations': recommendations,
      'findings': findings,
      'instructions': instructions,
      'pdfUrl': pdfUrl,
      'requestedBy': requestedBy,
      'notes': notes,
    };
  }
}
