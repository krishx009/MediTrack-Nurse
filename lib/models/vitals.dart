// This file defines the Vitals class for managing patient vital signs
import 'dart:convert';

class Vitals {
  final String bloodPressure;
  final String heartRate;
  final String respiratoryRate;
  final String temperature;
  final String oxygenSaturation;

  Vitals({
    required this.bloodPressure,
    required this.heartRate,
    required this.respiratoryRate,
    required this.temperature,
    required this.oxygenSaturation,
  });

  factory Vitals.fromJson(Map<String, dynamic> json) {
    return Vitals(
      bloodPressure: json['bloodPressure'] ?? json['BP'] ?? '',
      heartRate: json['heartRate']?.toString() ?? '',
      respiratoryRate: json['respiratoryRate']?.toString() ?? '16', // Default value
      temperature: json['temperature']?.toString() ?? '',
      oxygenSaturation: json['oxygenSaturation'] ?? '98%', // Default value
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bloodPressure': bloodPressure,
      'heartRate': heartRate,
      'respiratoryRate': respiratoryRate,
      'temperature': temperature,
      'oxygenSaturation': oxygenSaturation,
    };
  }
}
