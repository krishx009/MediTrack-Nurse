// This file defines all the routes for the nurse app
import 'package:flutter/material.dart';

// Import all screens
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'patient_registration_and_intake_screen.dart';
import 'patient_details_screen.dart';
import 'patient_intake_screen.dart';
import 'diagnosis_details_screen.dart';
import 'settings_screen.dart';

// Route names as constants
class Routes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String patientRegistration =
      '/patient_registration_and_intake_screen';
  static const String patientDetails = '/patient_details';
  static const String patientIntake = '/patient_intake';
  static const String diagnosisDetails = '/diagnosis_details';
  static const String settings = '/settings';

  // Define all routes
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      dashboard: (context) => const DashboardScreen(),
      patientRegistration: (context) =>
          const PatientRegistrationAndIntakeScreen(),
      patientDetails: (context) => const PatientDetailsScreen(),
      patientIntake: (context) => const PatientIntakeScreen(),
      diagnosisDetails: (context) => const DiagnosisDetailsScreen(),
      settings: (context) => const SettingsScreen(),
    };
  }

  // Navigation helper methods with type safety
  static Future<T?> navigateToPatientDetails<T>(
      BuildContext context, dynamic patient) {
    // Validate patient object type before navigation
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Patient data is missing')),
      );
      return Future.value(null);
    }

    return Navigator.pushNamed(
      context,
      patientDetails,
      arguments: patient,
    );
  }

  static Future<T?> navigateToPatientIntake<T>(
      BuildContext context, dynamic patient) {
    // Validate patient object type before navigation
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Patient data is missing')),
      );
      return Future.value(null);
    }

    return Navigator.pushNamed(
      context,
      patientIntake,
      arguments: patient,
    );
  }

  static Future<T?> navigateToDiagnosisDetails<T>(
      BuildContext context, dynamic diagnosis, dynamic patient) {
    // Validate diagnosis and patient objects before navigation
    if (diagnosis == null || patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Diagnosis or patient data is missing')),
      );
      return Future.value(null);
    }

    return Navigator.pushNamed(
      context,
      diagnosisDetails,
      arguments: {'diagnosis': diagnosis, 'patient': patient},
    );
  }
}
