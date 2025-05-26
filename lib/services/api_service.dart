import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
// Using shared_preferences instead of flutter_secure_storage
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:mime/mime.dart';
import '../utils/file_utils.dart';
import '../models/models.dart';
import '../utils/platform_utils.dart';

class ApiService {
  // Base URL configuration using platform utilities
  String get baseUrl {
    // This already includes the '/api' segment
    return PlatformUtils.getBaseApiUrl();
  }

  // Get URL for a file
  String getFileUrl(String? fileId) {
    if (fileId == null || fileId.isEmpty) {
      return '';
    }

    // Debug print to help diagnose URL construction issues
    print('Constructing URL for fileId: $fileId');

    // Check if the fileId is a path with format 'patientId/documents/documentId'
    if (fileId.contains('/documents/')) {
      final url = '$baseUrl/api/patient/$fileId';
      print('Document URL constructed: $url');
      return url;
    }

    // For patient photos and ID proofs
    if (fileId.contains('/photo/')) {
      final url = '$baseUrl/api/patient/$fileId';
      print('Photo URL constructed: $url');
      return url;
    }
    if (fileId.contains('/idproof/')) {
      final url = '$baseUrl/api/patient/$fileId';
      print('ID Proof URL constructed: $url');
      return url;
    }

    // For direct photo and idproof endpoints
    if (fileId.contains('/photo')) {
      final url = '$baseUrl/api/patient/$fileId';
      print('Direct photo URL constructed: $url');
      return url;
    }
    if (fileId.contains('/idproof')) {
      final url = '$baseUrl/api/patient/$fileId';
      print('Direct ID proof URL constructed: $url');
      return url;
    }

    // Default case for other file types
    final url = '$baseUrl/api/files/$fileId';
    print('Default URL constructed: $url');
    return url;
  }

  /// Fetches document bytes securely using Authorization header
  Future<Map<String, dynamic>> fetchDocumentBytes(
      String patientId, String documentId) async {
    final token = await _getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Authentication token not found',
      };
    }

    // Validate IDs
    if (patientId.isEmpty || documentId.isEmpty) {
      return {
        'success': false,
        'message': 'Invalid patient ID or document ID',
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/patient/$patientId/documents/$documentId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {
        'success': true,
        'bytes': response.bodyBytes,
        'contentType': response.headers['content-type'],
        'fileName':
            _extractFileNameFromHeader(response.headers['content-disposition']),
      };
    } else {
      String message = 'Failed to fetch document';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          message = data['message'];
        }
      } catch (_) {}

      print(
          'Error fetching document: $message, Status: ${response.statusCode}');

      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Helper to extract filename from content-disposition header
  String? _extractFileNameFromHeader(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final regex = RegExp(r'filename="([^"]+)"');
    final match = regex.firstMatch(contentDisposition);
    if (match != null && match.groupCount == 1) {
      return match.group(1);
    }
    return null;
  }

  // Get authentication token from storage
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Private method for internal use
  Future<String?> _getToken() async {
    return getAuthToken();
  }

  // Public method to get token for external use
  Future<String?> getToken() async {
    return _getToken();
  }

  // Save auth token to shared preferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // This duplicate login method has been removed

  // Save nurse data to shared preferences
  Future<void> _saveNurseData(Map<String, dynamic> nurseData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nurse_data', jsonEncode(nurseData));
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Get the base URL and print it for debugging
      String fullUrl = '$baseUrl/nurse/login';
      print('Attempting login with URL: $fullUrl');

      // For Android and iOS, verify we're using the proper IP address
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        String serverIp = PlatformUtils.getServerIp();
        if (!fullUrl.contains(serverIp)) {
          print(
              'WARNING: URL does not contain expected IP ($serverIp). URL: $fullUrl');
        } else {
          print(
              'CONFIRMED: Using correct IP address for physical device: $serverIp');
        }
      }

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save token and nurse data
        if (data['token'] != null) {
          await _saveToken(data['token']);
          print('Token saved successfully');
        } else {
          print('Warning: No token found in login response');
        }
        await _saveNurseData(data['nurse']);

        return {
          'success': true,
          'nurse': data['nurse'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('Login error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Register a new patient
  Future<Map<String, dynamic>> registerPatient(Map<String, dynamic> patientData,
      {File? photo, File? idProof}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/patient/register'),
        headers: headers,
        body: jsonEncode(patientData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Check if response is HTML instead of JSON (error case)
      if (response.body.trim().startsWith('<')) {
        return {
          'success': false,
          'message':
              'Server returned HTML instead of JSON. Please check if the backend server is running correctly.',
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Extract MongoDB ID for database operations
        final mongoId = data['_id'] ?? '';

        // Upload files if provided and we have a valid MongoDB ID
        if (mongoId.isNotEmpty &&
            _isValidMongoId(mongoId) &&
            (photo != null || idProof != null)) {
          print('Uploading files with MongoDB ID: $mongoId');
          await uploadPatientFiles(mongoId, photo, idProof);
        } else if ((photo != null || idProof != null)) {
          print(
              'Warning: Cannot upload files - invalid or missing MongoDB ID: $mongoId');
        }

        return {
          'success': true,
          'patientId': data['patientId'] ?? '',
          '_id': data['_id'] ?? '',
          'mongoId': data['_id'] ?? ''
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed'
      };
    } catch (e) {
      print('Error with patient registration: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Helper method to get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // Helper method to validate MongoDB ObjectId format
  bool _isValidMongoId(String id) {
    // MongoDB ObjectId is a 24-character hex string
    return id.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);
  }

  // Get all patients
  Future<Map<String, dynamic>> getPatients() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/patient/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<Patient> patients = (data as List)
            .map((patientJson) => Patient.fromJson(patientJson))
            .toList();

        return {
          'success': true,
          'patients': patients,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch patients',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Get patient by ID
  Future<Map<String, dynamic>> getPatientById(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format for database operations
      if (patientId.isEmpty || !_isValidMongoId(patientId)) {
        print(
            'Invalid MongoDB ObjectId format for getting patient: $patientId');
        return {
          'success': false,
          'message': 'Invalid patient ID format',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      try {
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          try {
            final patient = Patient.fromJson(data);
            return {
              'success': true,
              'patient': patient,
            };
          } catch (parseError) {
            print('Error parsing patient data: $parseError');
            return {
              'success': false,
              'message': 'Failed to parse patient data: $parseError',
            };
          }
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch patient details',
          };
        }
      } catch (parseError) {
        print('Error parsing response: $parseError');
        return {
          'success': false,
          'message': 'Failed to parse server response: $parseError',
        };
      }
    } catch (e) {
      print('Connection error: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Upload patient photo and ID proof
  Future<Map<String, dynamic>> _uploadPatientFiles(
      String patientId, File? photo, File? idProof) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/patient/upload/$patientId/profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (photo != null) {
        request.files
            .add(await http.MultipartFile.fromPath('photo', photo.path));
      }

      if (idProof != null) {
        request.files
            .add(await http.MultipartFile.fromPath('idProof', idProof.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Files uploaded successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to upload files',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Add a visit for a patient
  Future<Map<String, dynamic>> addVisit(
      String patientId, Map<String, dynamic> visitData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      print('Adding visit for patient $patientId with data: $visitData');

      // Ensure BP field is uppercase as expected by the backend controller
      if (visitData.containsKey('bp') && !visitData.containsKey('BP')) {
        visitData['BP'] = visitData['bp'];
        visitData.remove('bp');
      }

      // Ensure all required fields are present and have the correct types
      final cleanedVisitData = {
        'date': visitData['date'],
        'weight': num.parse(visitData['weight'].toString()),
        'height': num.parse(visitData['height'].toString()),
        'BP': visitData['BP'].toString(),
        'heartRate': num.parse(visitData['heartRate'].toString()),
        'temperature': num.parse(visitData['temperature'].toString()),
        'chiefComplaint': visitData['chiefComplaint'] ?? 'Regular checkup',
      };

      // Add optional fields if present
      if (visitData.containsKey('bmi')) {
        cleanedVisitData['bmi'] = visitData['bmi'].toString();
      }
      if (visitData.containsKey('bmiCategory')) {
        cleanedVisitData['bmiCategory'] = visitData['bmiCategory'].toString();
      }

      print('Cleaned visit data: $cleanedVisitData');

      // Verify MongoDB ObjectId format
      if (!_isValidMongoId(patientId)) {
        print('Invalid MongoDB ObjectId format: $patientId');
        return {
          'success': false,
          'message': 'Invalid patient ID format',
        };
      }

      // The backend route expects data in this format: { patientId: '...', visit: {...visitData} }
      final response = await http.post(
        Uri.parse('$baseUrl/patient/visit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patientId': patientId,
          'visit': cleanedVisitData,
        }),
      );

      print('Visit response status: ${response.statusCode}');
      print('Visit response body: ${response.body}');

      // Check if response is HTML instead of JSON (error case)
      if (response.body.trim().startsWith('<')) {
        print('Server returned HTML instead of JSON');
        return {
          'success': false,
          'message':
              'Server returned HTML instead of JSON. Please check if the backend server is running correctly.',
        };
      }

      // Try to parse the JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
        print('Visit response data: $data');

        // Check for error message in the response
        if (data.containsKey('error')) {
          print('Server returned error: ${data['error']}');
          return {
            'success': false,
            'message': 'Server error: ${data['error']}',
          };
        }
      } catch (e) {
        print('Failed to parse visit response: $e');
        return {
          'success': false,
          'message': 'Failed to parse server response: ${e.toString()}',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Visit added successfully',
          'patient': data.containsKey('patient')
              ? Patient.fromJson(data['patient'])
              : null,
          'visit': data.containsKey('visit') ? data['visit'] : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ??
              'Failed to add visit. Status code: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error adding visit: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Alias for addVisit to fix compatibility issues
  Future<Map<String, dynamic>> addPatientVisit(
      Map<String, dynamic> visitData) async {
    print('addPatientVisit called with data: $visitData');
    if (visitData.containsKey('patientId')) {
      // Try alternative endpoint if the main one fails
      try {
        final result = await addVisit(visitData['patientId'], visitData);
        if (result['success']) {
          return result;
        } else {
          // If the first attempt failed, try the alternative endpoint
          print('First attempt failed, trying alternative endpoint');
          return await _addVisitAlternative(visitData);
        }
      } catch (e) {
        print('Error in addPatientVisit: $e');
        // Try alternative endpoint as fallback
        return await _addVisitAlternative(visitData);
      }
    } else {
      return {
        'success': false,
        'message': 'Patient ID is required',
      };
    }
  }

  // Alternative endpoint for adding visits
  Future<Map<String, dynamic>> _addVisitAlternative(
      Map<String, dynamic> visitData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      print('Using alternative endpoint for visit with data: $visitData');

      // Try alternative endpoint format
      final response = await http.post(
        Uri.parse('$baseUrl/patient/visit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patientId': visitData['patientId'],
          'visit': visitData,
        }),
      );

      if (response.body.trim().startsWith('<')) {
        print('Alternative endpoint returned HTML');
        return {
          'success': false,
          'message':
              'Server returned HTML instead of JSON. Please check if the backend server is running correctly.',
        };
      }

      try {
        final data = jsonDecode(response.body);
        print('Alternative visit response: $data');

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'message': 'Visit added successfully via alternative endpoint',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ??
                'Failed to add visit via alternative endpoint',
          };
        }
      } catch (e) {
        print('Failed to parse alternative visit response: $e');
        return {
          'success': false,
          'message': 'Failed to parse server response: ${e.toString()}',
        };
      }
    } catch (e) {
      print('Error in alternative visit endpoint: $e');
      return {
        'success': false,
        'message': 'Connection error in alternative endpoint: ${e.toString()}',
      };
    }
  }

  // Get all visits for a patient
  Future<Map<String, dynamic>> getPatientVisits(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/visits'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'visits': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch visits',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Get all documents for a patient
  Future<Map<String, dynamic>> getPatientDocuments(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format for database operations
      if (patientId.isEmpty || !_isValidMongoId(patientId)) {
        print(
            'Invalid MongoDB ObjectId format for getting documents: $patientId');
        return {
          'success': false,
          'message': 'Invalid patient ID format',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/documents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        try {
          final dynamic data = jsonDecode(response.body);

          // Handle both new and old response formats
          if (data is Map<String, dynamic> &&
              data.containsKey('documents') &&
              data['documents'] is List) {
            // New format where response is {success: true, documents: [...]}
            return {
              'success': true,
              'documents': data['documents'],
            };
          } else if (data is List) {
            // Old format where response was directly a list of documents
            return {
              'success': true,
              'documents': data,
            };
          } else {
            // Unexpected format
            return {
              'success': true,
              'documents': [], // Empty list as fallback
            };
          }
        } catch (e) {
          print('Error parsing documents response: $e');
          return {
            'success': false,
            'message': 'Failed to parse documents response: $e',
          };
        }
      } else {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          print('Error parsing error response: $e');
        }

        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch documents',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Upload documents for a patient
  Future<Map<String, dynamic>> uploadPatientDocuments(
      String patientId, List<File> documents) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/patient/upload/$patientId/documents'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      for (var document in documents) {
        request.files
            .add(await http.MultipartFile.fromPath('documents', document.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Documents uploaded successfully',
          'files': data['files'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to upload documents',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Download a document
  Future<Map<String, dynamic>> downloadDocument(
      String patientId, String documentId) async {
    try {
      print(
          'Downloading document for patient $patientId, document $documentId');
      final token = await getToken();
      if (token == null) {
        print('Download failed: Not authenticated');
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final url = '$baseUrl/patient/$patientId/documents/$documentId';
      print('Download URL: $url');

      // Create a custom client with a longer timeout
      final client = http.Client();
      try {
        // Set a timeout for the request
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': '*/*', // Accept any content type
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        });

        // Send the request with a timeout
        final streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamedResponse);

        print('Download response status: ${response.statusCode}');
        print('Response headers: ${response.headers}');

        if (response.statusCode == 200) {
          // Extract filename from content-disposition header or use a default name
          String? fileName = _extractFileNameFromHeader(
              response.headers['content-disposition']);
          String? contentType = response.headers['content-type'];

          // If filename is not provided in headers, try to determine from document ID
          if (fileName == null || fileName.isEmpty) {
            fileName = 'document_$documentId';

            // Try to determine file extension from content type
            if (contentType != null) {
              final extension = _getExtensionFromMimeType(contentType);
              if (extension.isNotEmpty) {
                fileName = '$fileName.$extension';
              }
            }
          }

          // Verify that we actually got file data
          if (response.bodyBytes.isEmpty) {
            print('Error: Received empty file from server');
            return {
              'success': false,
              'message': 'Received empty file from server',
            };
          }

          // Sanitize filename for Android
          fileName = _sanitizeFileName(fileName);

          print(
              'Downloaded file: $fileName, type: $contentType, size: ${response.bodyBytes.length} bytes');

          return {
            'success': true,
            'data': response.bodyBytes,
            'contentType': contentType,
            'contentDisposition': response.headers['content-disposition'],
            'fileName': fileName,
          };
        } else {
          String errorMessage = 'Failed to download document';
          try {
            final data = jsonDecode(response.body);
            errorMessage = data['message'] ?? errorMessage;
          } catch (e) {
            print('Error parsing error response: $e');
            // If response body is not valid JSON, use status code in error message
            errorMessage = 'Server returned status code ${response.statusCode}';
          }

          print('Download failed: $errorMessage');
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } catch (e) {
        print('Error during download request: $e');
        return {
          'success': false,
          'message': 'Error during download request: $e',
        };
      } finally {
        client.close();
      }
    } catch (e) {
      print('Exception during document download: $e');
      return {
        'success': false,
        'message': 'Error downloading document: $e',
      };
    }
  }

  // Helper method to sanitize filenames for Android
  String _sanitizeFileName(String fileName) {
    // Replace invalid characters for Android filesystems
    return fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
  }
  
  // Helper method to get file extension from MIME type
  String _getExtensionFromMimeType(String mimeType) {
    final parts = mimeType.toLowerCase().split('/');
    if (parts.length < 2) return '';

    final type = parts[0];
    final subtype = parts[1];

    // Handle common MIME types
    switch (subtype) {
      case 'jpeg':
      case 'jpg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'pdf':
        return 'pdf';
      case 'msword':
        return 'doc';
      case 'vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'vnd.ms-excel':
        return 'xls';
      case 'vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'plain':
        return 'txt';
      default:
        // For other types, use the subtype as extension if it's simple
        if (subtype.length <= 5 &&
            !subtype.contains('.') &&
            !subtype.contains('-')) {
          return subtype;
        }
        return '';
    }
  }

  // View a document
  Future<Map<String, dynamic>> viewDocument(
      String patientId, String documentId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/documents/$documentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Extract filename from content-disposition header or use documentId as fallback
        String? fileName =
            _extractFileNameFromHeader(response.headers['content-disposition']);

        // If filename couldn't be extracted, try to get it from the document metadata
        if (fileName == null || fileName.isEmpty) {
          try {
            // Try to get document metadata to find the name
            final metadataResponse = await http.get(
              Uri.parse(
                  '$baseUrl/patient/$patientId/documents/$documentId/metadata'),
              headers: {
                'Authorization': 'Bearer $token',
              },
            );

            if (metadataResponse.statusCode == 200) {
              final metaData = jsonDecode(metadataResponse.body);
              fileName = metaData['name'] ?? 'document_$documentId';
            } else {
              fileName = 'document_$documentId';
            }
          } catch (e) {
            // If metadata request fails, use a default name
            fileName = 'document_$documentId';
          }
        }

        // Determine content type from headers or infer from filename
        String? contentType = response.headers['content-type'];
        if (contentType == null ||
            contentType.isEmpty ||
            contentType == 'application/octet-stream') {
          // Try to infer content type from filename
          contentType = FileUtils.getMimeType(fileName ?? 'unknown.bin');
        }

        return {
          'success': true,
          'data': response.bodyBytes,
          'contentType': contentType,
          'contentDisposition': response.headers['content-disposition'],
          'fileName': fileName,
          'fileSize': response.bodyBytes.length,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to view document',
        };
      }
    } catch (e) {
      print('Error viewing document: $e');
      return {
        'success': false,
        'message': 'Error viewing document: $e',
      };
    }
  }

  // Upload patient files (photo and ID proof)
  Future<Map<String, dynamic>> uploadPatientFiles(
      String patientId, dynamic photo, dynamic idProof) async {
    try {
      print('Uploading files for patient: $patientId');
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format for database operations
      if (!_isValidMongoId(patientId)) {
        print('Invalid MongoDB ObjectId format for file upload: $patientId');
        return {
          'success': false,
          'message': 'Invalid patient ID format for file upload',
        };
      }

      // Create a custom client with a longer timeout
      final client = http.Client();
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/patient/upload/$patientId/profile'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';

        // Add timeout and retry logic
        const int maxRetries = 2;
        int currentRetry = 0;
        bool success = false;
        http.Response? response;

        while (currentRetry <= maxRetries && !success) {
          try {
            // Handle different file types based on platform
            if (photo != null) {
              if (kIsWeb) {
                // For web - handle html.File
                if (photo is html.File) {
                  final reader = html.FileReader();
                  reader.readAsArrayBuffer(photo);
                  await reader.onLoad.first;

                  final bytes = reader.result as List<int>;
                  final filename = photo.name;
                  final mimeType =
                      photo.type.isNotEmpty ? photo.type : 'image/jpeg';

                  final parts = mimeType.split('/');
                  final mime = parts.length > 0 ? parts[0] : 'image';
                  final subtype = parts.length > 1 ? parts[1] : 'jpeg';

                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'photo',
                      bytes,
                      filename: filename,
                      contentType: MediaType(mime, subtype),
                    ),
                  );
                  print('Added web photo file: $filename, type: $mimeType');
                } else if (photo is List<int>) {
                  // Handle byte data
                  final filename = 'patient_photo.jpg';
                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'photo',
                      photo,
                      filename: filename,
                      contentType: MediaType('image', 'jpeg'),
                    ),
                  );
                  print('Added photo bytes as file: $filename');
                }
              } else {
                // For mobile/desktop
                if (photo is File) {
                  // Verify the file exists and is readable
                  if (!await photo.exists()) {
                    print('Photo file does not exist: ${photo.path}');
                    return {
                      'success': false,
                      'message':
                          'Photo file does not exist or is not accessible',
                    };
                  }

                  // Get file extension for proper content type
                  final extension = photo.path.split('.').last.toLowerCase();
                  final contentType = extension == 'png'
                      ? MediaType('image', 'png')
                      : MediaType('image', 'jpeg');

                  // Read file as bytes to ensure it's properly loaded
                  final bytes = await photo.readAsBytes();
                  if (bytes.isEmpty) {
                    print('Photo file is empty: ${photo.path}');
                    return {
                      'success': false,
                      'message': 'Photo file is empty',
                    };
                  }

                  // Use a simple filename without path separators and add timestamp to avoid conflicts
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  String filename = photo.path.split('/').last.split('\\').last;
                  // Sanitize filename for Android
                  filename = _sanitizeFileName(filename);
                  // Add timestamp to filename to avoid conflicts
                  final lastDotIndex = filename.lastIndexOf('.');
                  if (lastDotIndex > 0) {
                    final name = filename.substring(0, lastDotIndex);
                    final ext = filename.substring(lastDotIndex);
                    filename = '${name}_$timestamp$ext';
                  } else {
                    filename = '${filename}_$timestamp';
                  }

                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'photo',
                      bytes,
                      filename: filename,
                      contentType: contentType,
                    ),
                  );
                  print('Added mobile photo file: ${photo.path}');
                  print('- Filename: $filename');
                  print('- Content type: ${contentType.mimeType}');
                  print('- Size: ${bytes.length} bytes');
                }
              }
            }

            if (idProof != null) {
              if (kIsWeb) {
                // For web - handle html.File
                if (idProof is html.File) {
                  final reader = html.FileReader();
                  reader.readAsArrayBuffer(idProof);
                  await reader.onLoad.first;

                  final bytes = reader.result as List<int>;
                  final filename = idProof.name;
                  final mimeType =
                      idProof.type.isNotEmpty ? idProof.type : 'image/jpeg';

                  final parts = mimeType.split('/');
                  final mime = parts.length > 0 ? parts[0] : 'image';
                  final subtype = parts.length > 1 ? parts[1] : 'jpeg';

                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'idProof',
                      bytes,
                      filename: filename,
                      contentType: MediaType(mime, subtype),
                    ),
                  );
                  print('Added web idProof file: $filename, type: $mimeType');
                } else if (idProof is List<int>) {
                  // Handle byte data
                  final filename = 'id_proof.jpg';
                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'idProof',
                      idProof,
                      filename: filename,
                      contentType: MediaType('image', 'jpeg'),
                    ),
                  );
                  print('Added idProof bytes as file: $filename');
                }
              } else {
                // For mobile/desktop
                if (idProof is File) {
                  // Verify the file exists and is readable
                  if (!await idProof.exists()) {
                    print('ID Proof file does not exist: ${idProof.path}');
                    return {
                      'success': false,
                      'message':
                          'ID Proof file does not exist or is not accessible',
                    };
                  }

                  // Get file extension for proper content type
                  final extension = idProof.path.split('.').last.toLowerCase();
                  final contentType = extension == 'png'
                      ? MediaType('image', 'png')
                      : MediaType('image', 'jpeg');

                  // Read file as bytes to ensure it's properly loaded
                  final bytes = await idProof.readAsBytes();
                  if (bytes.isEmpty) {
                    print('ID Proof file is empty: ${idProof.path}');
                    return {
                      'success': false,
                      'message': 'ID Proof file is empty',
                    };
                  }

                  // Use a simple filename without path separators
                  final filename =
                      idProof.path.split('/').last.split('\\').last;

                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'idProof',
                      bytes,
                      filename: filename,
                      contentType: contentType,
                    ),
                  );
                  print('Added mobile idProof file: ${idProof.path}');
                  print('- Filename: $filename');
                  print('- Content type: ${contentType.mimeType}');
                  print('- Size: ${bytes.length} bytes');
                }
              }
            }

            print(
                'Sending file upload request (attempt ${currentRetry + 1})...');
            final streamedResponse = await request.send().timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Request timed out');
              },
            );

            response = await http.Response.fromStream(streamedResponse);
            print('Upload response status: ${response.statusCode}');
            print('Upload response body: ${response.body}');

            // If we get here, the request was successful
            success = true;
          } catch (retryError) {
            currentRetry++;
            print('Error during upload attempt $currentRetry: $retryError');

            if (currentRetry <= maxRetries) {
              print('Retrying upload in 2 seconds...');
              await Future.delayed(const Duration(seconds: 2));

              // Create a new request for the retry
              request = http.MultipartRequest(
                'POST',
                Uri.parse('$baseUrl/patient/upload/$patientId/profile'),
              );
              request.headers['Authorization'] = 'Bearer $token';
              request.headers['Accept'] = 'application/json';
            } else {
              print('Maximum retries reached, giving up');
              throw retryError;
            }
          }
        }

        if (response != null && success) {
          try {
            final data = jsonDecode(response.body);

            if (response.statusCode == 200) {
              // Extract file IDs from the response
              String? photoFileId;
              String? idProofFileId;

              if (data['patient'] != null) {
                if (data['patient']['photo'] != null && photo != null) {
                  photoFileId = data['patient']['photo'];
                  print('Photo file ID from response: $photoFileId');
                }

                if (data['patient']['idProof'] != null && idProof != null) {
                  idProofFileId = data['patient']['idProof'];
                  print('ID proof file ID from response: $idProofFileId');
                }
              }

              return {
                'success': true,
                'message': 'Files uploaded successfully',
                'patient': data['patient'],
                'photoUrl': photoFileId,
                'idProofUrl': idProofFileId,
              };
            } else {
              return {
                'success': false,
                'message': data['message'] ?? 'Failed to upload files',
              };
            }
          } catch (e) {
            print('Error parsing upload response: $e');
            // Handle case where response is not valid JSON
            return {
              'success': response.statusCode == 200,
              'message': response.statusCode == 200
                  ? 'Files uploaded successfully'
                  : 'Failed to upload files: ${response.body}',
            };
          }
        } else {
          return {
            'success': false,
            'message': 'Failed to upload files after multiple attempts',
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error uploading files: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Upload a patient document (handles both File and XFile objects)
  Future<Map<String, dynamic>> uploadPatientDocument(
    String patientId,
    dynamic document, {
    String? customName,
    String? documentType,
    String? mimeType,
  }) async {
    try {
      if (document == null) {
        return {
          'success': false,
          'message': 'No document provided',
        };
      }

      String fileName;
      List<int> fileBytes;
      String? detectedMimeType;

      // Handle different document types (File, XFile, etc.)
      if (document is File) {
        // Get the file path and sanitize it
        final filePath = document.path;
        fileName = customName ?? filePath.split('/').last.split('\\').last;
        fileName = _sanitizeFileName(fileName);
        
        // Add timestamp to avoid conflicts
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex > 0) {
          final name = fileName.substring(0, lastDotIndex);
          final ext = fileName.substring(lastDotIndex);
          fileName = '${name}_$timestamp$ext';
        } else {
          fileName = '${fileName}_$timestamp';
        }
        
        // Read file bytes with error handling
        try {
          fileBytes = await document.readAsBytes();
          if (fileBytes.isEmpty) {
            return {
              'success': false,
              'message': 'File is empty',
            };
          }
        } catch (e) {
          print('Error reading file bytes: $e');
          return {
            'success': false,
            'message': 'Error reading file: $e',
          };
        }
        
        // Detect MIME type if not provided
        if (mimeType == null || mimeType.isEmpty) {
          detectedMimeType = lookupMimeType(filePath);
          if (detectedMimeType == null || detectedMimeType.isEmpty) {
            // Try to determine from extension
            final extension = filePath.split('.').last.toLowerCase();
            if (extension == 'jpg' || extension == 'jpeg') {
              detectedMimeType = 'image/jpeg';
            } else if (extension == 'png') {
              detectedMimeType = 'image/png';
            } else if (extension == 'pdf') {
              detectedMimeType = 'application/pdf';
            } else if (extension == 'doc') {
              detectedMimeType = 'application/msword';
            } else if (extension == 'docx') {
              detectedMimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            } else {
              detectedMimeType = 'application/octet-stream';
            }
          }
        } else {
          detectedMimeType = mimeType;
        }
        
        print('File path: $filePath');
        print('File name: $fileName');
        print('MIME type: $detectedMimeType');
        print('File size: ${fileBytes.length} bytes');
      } else if (document is html.File) {
        // For web File object
        fileName = customName ?? document.name;
        fileName = _sanitizeFileName(fileName);
        
        // Add timestamp to avoid conflicts
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex > 0) {
          final name = fileName.substring(0, lastDotIndex);
          final ext = fileName.substring(lastDotIndex);
          fileName = '${name}_$timestamp$ext';
        } else {
          fileName = '${fileName}_$timestamp';
        }
        
        final reader = html.FileReader();
        reader.readAsArrayBuffer(document);
        await reader.onLoad.first;
        fileBytes = reader.result as List<int>;
        
        // Use the provided MIME type or the one from the file
        detectedMimeType = mimeType ?? document.type;
        if (detectedMimeType == null || detectedMimeType.isEmpty) {
          // Try to determine from filename
          final extension = fileName.split('.').last.toLowerCase();
          if (extension == 'jpg' || extension == 'jpeg') {
            detectedMimeType = 'image/jpeg';
          } else if (extension == 'png') {
            detectedMimeType = 'image/png';
          } else if (extension == 'pdf') {
            detectedMimeType = 'application/pdf';
          } else {
            detectedMimeType = 'application/octet-stream';
          }
        }
      } else {
        return {
          'success': false,
          'message': 'Unsupported document type',
        };
      }

      // Use the uploadDocument method to handle the actual upload
      return await uploadDocument(
        patientId: patientId,
        fileName: fileName,
        fileBytes: fileBytes,
        documentType: documentType,
        customName: customName,
        mimeType: detectedMimeType,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Error preparing document for upload: $e',
      };
    }
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String patientId,
    required String fileName,
    required List<int> fileBytes,
    bool isPrescription = false,
    String? documentType,
    String? customName,
    String? mimeType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Validate file bytes
      if (fileBytes.isEmpty) {
        print('Error: Empty file bytes for $fileName');
        return {
          'success': false,
          'message': 'File is empty or could not be read properly',
        };
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/patient/upload/$patientId/documents'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add document type metadata
      request.fields['type'] =
          isPrescription ? 'prescription' : (documentType ?? 'document');

      // Add custom name if provided
      if (customName != null && customName.isNotEmpty) {
        request.fields['customName'] = customName;
      }

      // Get proper MIME type for the file
      String fileMimeType;
      if (mimeType != null && mimeType.isNotEmpty) {
        // Use provided MIME type
        fileMimeType = mimeType;
      } else {
        // Try to detect MIME type
        fileMimeType = FileUtils.getMimeType(fileName);
      }
      
      // Parse MIME type into parts
      final parts = fileMimeType.split('/');
      final mime = parts.isNotEmpty ? parts[0] : 'application';
      final subtype = parts.length > 1 ? parts[1] : 'octet-stream';

      // Debug log
      print('Uploading file: $fileName with MIME type: $mime/$subtype');
      print('File size: ${fileBytes.length} bytes');

      request.files.add(
        http.MultipartFile.fromBytes(
          'documents',
          fileBytes,
          filename: fileName,
          contentType: MediaType(mime, subtype),
        ),
      );

      // Send request
      print('Sending document upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print('Document upload response status: ${response.statusCode}');
      print('Document upload response body: ${response.body}');

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 200) {
          return {
            'success': true,
            'message':
                '${isPrescription ? "Prescription" : "Document"} uploaded successfully',
            'file': data['files'] != null &&
                    data['files'] is List &&
                    data['files'].isNotEmpty
                ? data['files'][0]
                : null,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ??
                'Failed to upload ${isPrescription ? "prescription" : "document"}',
          };
        }
      } catch (parseError) {
        print('Error parsing document upload response: $parseError');
        return {
          'success': response.statusCode == 200,
          'message': response.statusCode == 200
              ? '${isPrescription ? "Prescription" : "Document"} uploaded successfully'
              : 'Failed to upload file: Server returned invalid response',
        };
      }
    } catch (e) {
      print('Exception during document upload: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // View file in web browser
  void viewFileWeb(String url) {
    if (kIsWeb) {
      html.window.open(url, '_blank');
    }
  }

  // Download file in web browser
  void downloadFileWeb(String url, String fileName) {
    if (kIsWeb) {
      html.AnchorElement anchorElement = html.AnchorElement(href: url);
      anchorElement.download = fileName;
      anchorElement.click();
    }
  }

  // Delete a document
  Future<Map<String, dynamic>> deleteDocument(
      String patientId, String documentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format for database operations
      if (patientId.isEmpty ||
          !_isValidMongoId(patientId) ||
          documentId.isEmpty ||
          !_isValidMongoId(documentId)) {
        print(
            'Invalid MongoDB ObjectId format for document delete: $patientId/$documentId');
        return {
          'success': false,
          'message': 'Invalid ID format for document delete',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/patient/$patientId/documents/$documentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Document deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete document',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Rename a document
  Future<Map<String, dynamic>> renameDocument(
      String patientId, String documentId, String newName) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format for database operations
      if (patientId.isEmpty ||
          !_isValidMongoId(patientId) ||
          documentId.isEmpty ||
          !_isValidMongoId(documentId)) {
        print(
            'Invalid MongoDB ObjectId format for document rename: $patientId/$documentId');
        return {
          'success': false,
          'message': 'Invalid ID format for document rename',
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/patient/$patientId/documents/$documentId/rename'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'newName': newName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'] ?? 'Document renamed successfully',
          'document': data['document'],
        };
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to rename document',
        };
      }
    } catch (e) {
      print('Error renaming document: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Get the base URL for API calls
  String getBaseUrl() {
    return baseUrl;
  }

  // Get lab reports for a specific patient
  Future<Map<String, dynamic>> getPatientLabReports(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/lab-reports/patient/$patientId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'labReports': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch lab reports',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching lab reports: $e',
      };
    }
  }

  // Get prescriptions for a specific patient
  Future<Map<String, dynamic>> getPatientPrescriptions(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format
      if (patientId.isEmpty || !_isValidMongoId(patientId)) {
        return {
          'success': false,
          'message': 'Invalid patient ID format',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/prescriptions/patient/$patientId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> prescriptionsJson = jsonDecode(response.body);
        return {
          'success': true,
          'prescriptions': prescriptionsJson,
        };
      } else {
        String message = 'Failed to fetch prescriptions';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
        } catch (_) {}

        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('Error fetching prescriptions: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Get a specific prescription by ID
  Future<Map<String, dynamic>> getPrescriptionById(
      String prescriptionId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format
      if (prescriptionId.isEmpty || !_isValidMongoId(prescriptionId)) {
        return {
          'success': false,
          'message': 'Invalid prescription ID format',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/prescriptions/$prescriptionId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final prescriptionJson = jsonDecode(response.body);
        return {
          'success': true,
          'prescription': prescriptionJson,
        };
      } else {
        String message = 'Failed to fetch prescription';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
        } catch (_) {}

        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('Error fetching prescription: $e');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // The getPatientPrescriptions method already exists above, so this duplicate has been removed

  // Generate PDF for a prescription
  Future<Map<String, dynamic>> generatePrescriptionPDF(
      String prescriptionId) async {
    try {
      print(
          'API Service: Generating PDF for prescription ID: $prescriptionId'); // Debug log
      final token = await _getToken();
      if (token == null) {
        print('API Service: Authentication token not found'); // Debug log
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format
      if (prescriptionId.isEmpty || !_isValidMongoId(prescriptionId)) {
        print('API Service: Invalid prescription ID format'); // Debug log
        return {
          'success': false,
          'message': 'Invalid prescription ID format',
        };
      }

      // Use the /pdf endpoint to generate the PDF (not get-pdf which returns the binary data)
      final url = '$baseUrl/prescriptions/$prescriptionId/pdf';
      print('API Service: Sending request to: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print(
          'API Service: Response status code: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print(
              'API Service: PDF generated successfully: ${data['pdfUrl']}'); // Debug log
          return {
            'success': true,
            'message': data['message'] ?? 'PDF generated successfully',
            'pdfUrl': data['pdfUrl'],
          };
        } catch (parseError) {
          print(
              'API Service: Error parsing response: $parseError'); // Debug log
          return {
            'success': false,
            'message': 'Error parsing server response',
          };
        }
      } else {
        String message = 'Failed to generate PDF';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
          print(
              'API Service: Error response body: ${response.body}'); // Debug log
        } catch (parseError) {
          print(
              'API Service: Error parsing response: $parseError'); // Debug log
          print(
              'API Service: Raw response body: ${response.body}'); // Debug log
        }

        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('API Service: Exception generating PDF: $e'); // Debug log
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Delete patient photo
  Future<Map<String, dynamic>> deletePatientPhoto(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format
      if (patientId.isEmpty || !_isValidMongoId(patientId)) {
        print('Invalid MongoDB ObjectId format for photo delete: $patientId');
        return {
          'success': false,
          'message': 'Invalid patient ID format',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/patient/$patientId/photo'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Patient photo deleted successfully',
        };
      } else {
        String message = 'Failed to delete patient photo';
        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? message;
        } catch (e) {
          // Use default message if parsing fails
        }
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting patient photo: ${e.toString()}',
      };
    }
  }

  // Generate PDF for a lab report
  Future<Map<String, dynamic>> generateLabReportPDF(String labReportId) async {
    try {
      print(
          'API Service: Generating PDF for lab report ID: $labReportId'); // Debug log
      final token = await _getToken();
      if (token == null) {
        print('API Service: Authentication token not found'); // Debug log
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format
      if (labReportId.isEmpty || !_isValidMongoId(labReportId)) {
        print('API Service: Invalid lab report ID format'); // Debug log
        return {
          'success': false,
          'message': 'Invalid lab report ID format',
        };
      }

      // Use the /pdf endpoint to generate the PDF (not get-pdf which returns the binary data)
      final url = '$baseUrl/lab-reports/$labReportId/pdf';
      print('API Service: Sending request to: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print(
          'API Service: Response status code: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print(
              'API Service: PDF generated successfully: ${data['pdfUrl']}'); // Debug log
          return {
            'success': true,
            'message': data['message'] ?? 'PDF generated successfully',
            'pdfUrl': data['pdfUrl'],
          };
        } catch (parseError) {
          print(
              'API Service: Error parsing response: $parseError'); // Debug log
          return {
            'success': false,
            'message': 'Error parsing server response',
          };
        }
      } else {
        String message = 'Failed to generate PDF';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
          print(
              'API Service: Error response body: ${response.body}'); // Debug log
        } catch (parseError) {
          print(
              'API Service: Error parsing response: $parseError'); // Debug log
          print(
              'API Service: Raw response body: ${response.body}'); // Debug log
        }

        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('API Service: Exception generating PDF: $e'); // Debug log
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Delete patient ID proof
  Future<Map<String, dynamic>> deletePatientIdProof(String patientId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }

      // Verify MongoDB ObjectId format
      if (patientId.isEmpty || !_isValidMongoId(patientId)) {
        print(
            'Invalid MongoDB ObjectId format for ID proof delete: $patientId');
        return {
          'success': false,
          'message': 'Invalid patient ID format',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/patient/$patientId/idproof'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Patient ID proof deleted successfully',
        };
      } else {
        String message = 'Failed to delete patient ID proof';
        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? message;
        } catch (e) {
          // Use default message if parsing fails
        }
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting patient ID proof: ${e.toString()}',
      };
    }
  }
}
