// This file contains the patient provider for state management
import 'package:flutter/foundation.dart';
// Import all models from the models.dart file to avoid conflicts
import '../models/models.dart';
import '../services/api_service.dart';

class PatientProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Patient list state
  List<Patient> _patients = [];
  bool _isLoading = false;
  String? _error;

  // Current patient state
  Patient? _currentPatient;
  List<PatientDocument> _documents = [];

  // Getters
  List<Patient> get patients => _patients;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Patient? get currentPatient => _currentPatient;
  List<PatientDocument> get documents => _documents;

  // Load all patients
  Future<void> loadPatients() async {
    _setLoading(true);

    try {
      final result = await _apiService.getPatients();

      if (result['success']) {
        _patients = result['patients'];
        _error = null;
      } else {
        _error = result['message'];
      }
    } catch (e) {
      _error = 'Failed to load patients: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Load patient by ID
  Future<void> loadPatientById(String patientId) async {
    _setLoading(true);

    try {
      final result = await _apiService.getPatientById(patientId);

      if (result['success']) {
        _currentPatient = result['patient'];
        _error = null;
      } else {
        _error = result['message'];
      }
    } catch (e) {
      _error = 'Failed to load patient: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Load patient documents
  Future<void> loadPatientDocuments(String patientId) async {
    _setLoading(true);

    try {
      final result = await _apiService.getPatientDocuments(patientId);

      if (result['success'] && result['documents'] != null) {
        try {
          _documents = List<PatientDocument>.from(
              result['documents'].map((doc) => PatientDocument.fromJson(doc)));
          _error = null;
        } catch (e) {
          _error = 'Error processing documents: $e';
          _documents = [];
        }
      } else {
        _error = result['message'] ?? 'Failed to load documents';
        _documents = [];
      }
    } catch (e) {
      _error = 'Failed to load documents: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Upload patient document
  Future<Map<String, dynamic>> uploadDocument(
    String patientId, dynamic document,
    {String? customName, String? documentType, String? mimeType}) async {
  _setLoading(true);

  try {
    print('Uploading document for patient: $patientId');
    print('Document type: $documentType');
    print('MIME type: $mimeType');
    
    // Add retry mechanism for more reliable uploads
    int maxRetries = 2;
    int currentRetry = 0;
    Map<String, dynamic> result = {};
    
    while (currentRetry <= maxRetries) {
      try {
        result = await _apiService.uploadPatientDocument(
          patientId,
          document,
          customName: customName,
          documentType: documentType,
          mimeType: mimeType,
        );
        
        if (result['success']) {
          // Upload successful, break the retry loop
          break;
        } else {
          // Upload failed, increment retry counter
          currentRetry++;
          if (currentRetry <= maxRetries) {
            print('Upload failed, retrying (${currentRetry}/$maxRetries)...');
            // Wait before retrying
            await Future.delayed(Duration(seconds: 1));
          }
        }
      } catch (e) {
        print('Error during upload attempt ${currentRetry + 1}: $e');
        currentRetry++;
        if (currentRetry <= maxRetries) {
          await Future.delayed(Duration(seconds: 1));
        } else {
          // Rethrow the exception if all retries failed
          throw e;
        }
      }
    }

    if (result['success']) {
      // Reload documents after successful upload
      await loadPatientDocuments(patientId);
      _error = null;
    } else {
      _error = result['message'];
    }

    return result;
  } catch (e) {
    _error = 'Failed to upload document: $e';
    return {
      'success': false,
      'message': 'Failed to upload document: $e',
    };
  } finally {
    _setLoading(false);
  }
}

  // Delete patient document
  Future<Map<String, dynamic>> deleteDocument(
      String patientId, String documentId) async {
    _setLoading(true);

    try {
      final result = await _apiService.deleteDocument(patientId, documentId);

      if (result['success']) {
        // Remove document from local list
        try {
          _documents.removeWhere((doc) => doc.id == documentId);
          notifyListeners();
          _error = null;
        } catch (e) {
          _error = 'Error removing document: $e';
        }
      } else {
        _error = result['message'] ?? 'Failed to delete document';
      }

      return result;
    } catch (e) {
      _error = 'Failed to delete document: $e';
      return {
        'success': false,
        'message': 'Failed to delete document: $e',
      };
    } finally {
      _setLoading(false);
    }
  }

  // Rename patient document
  Future<Map<String, dynamic>> renameDocument(
      String patientId, String documentId, String newName) async {
    _setLoading(true);

    try {
      final result =
          await _apiService.renameDocument(patientId, documentId, newName);

      if (result['success'] && result['document'] != null) {
        try {
          // Update document in local list
          final index = _documents.indexWhere((doc) => doc.id == documentId);
          if (index != -1) {
            final updatedDoc = PatientDocument.fromJson(result['document']);
            _documents[index] = updatedDoc;
            notifyListeners();
          } else {
            // If document not found in local list, refresh the entire list
            await loadPatientDocuments(patientId);
          }
          _error = null;
        } catch (e) {
          print('Error updating document in provider: $e');
          _error = 'Error updating document: $e';
        }
      } else {
        _error = result['message'] ?? 'Failed to rename document';
      }

      return result;
    } catch (e) {
      print('Error in renameDocument provider: $e');
      _error = 'Failed to rename document: $e';
      return {
        'success': false,
        'message': 'Failed to rename document: $e',
      };
    } finally {
      _setLoading(false);
    }
  }

  // Set loading state and notify listeners
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
