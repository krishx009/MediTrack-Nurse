import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_utils.dart';
import '../utils/file_utils.dart';

/// Enhanced API service with improved handling for physical Android devices
class ApiServiceUpdates {
  // Base URL configuration using platform utilities
  String get baseUrl {
    // This already includes the '/api' segment
    return PlatformUtils.getBaseApiUrl();
  }

  // Get URL for a file with improved logging
  String getFileUrl(String? fileId) {
    if (fileId == null || fileId.isEmpty) {
      print('getFileUrl: fileId is null or empty');
      return '';
    }

    // Debug print to help diagnose URL construction issues
    print('Constructing URL for fileId: $fileId');

    // Check if the fileId is a path with format 'patientId/documents/documentId'
    if (fileId.contains('/documents/')) {
      final url = '$baseUrl/patient/$fileId';
      print('Document URL constructed: $url');
      return url;
    }

    // For patient photos and ID proofs
    if (fileId.contains('/photo/')) {
      final url = '$baseUrl/patient/$fileId';
      print('Photo URL constructed: $url');
      return url;
    }
    if (fileId.contains('/idproof/')) {
      final url = '$baseUrl/patient/$fileId';
      print('ID Proof URL constructed: $url');
      return url;
    }

    // For direct photo and idproof endpoints
    if (fileId.contains('/photo')) {
      final url = '$baseUrl/patient/$fileId';
      print('Direct photo URL constructed: $url');
      return url;
    }
    if (fileId.contains('/idproof')) {
      final url = '$baseUrl/patient/$fileId';
      print('Direct ID proof URL constructed: $url');
      return url;
    }

    // Default case for other file types
    final url = '$baseUrl/files/$fileId';
    print('Default URL constructed: $url');
    return url;
  }

  /// Fetches document bytes securely using Authorization header with improved error handling
  Future<Map<String, dynamic>> fetchDocumentBytes(
      String patientId, String documentId) async {
    print(
        'Fetching document bytes - Patient ID: $patientId, Document ID: $documentId');
    final token = await _getToken();
    if (token == null) {
      print('Authentication token not found');
      return {
        'success': false,
        'message': 'Authentication token not found',
      };
    }

    // Validate IDs
    if (patientId.isEmpty || documentId.isEmpty) {
      print('Invalid patient ID or document ID');
      return {
        'success': false,
        'message': 'Invalid patient ID or document ID',
      };
    }

    try {
      final url = '$baseUrl/patient/$patientId/documents/$documentId';
      print('Fetching document from URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        print(
            'Document fetched successfully. Size: ${response.bodyBytes.length} bytes');
        return {
          'success': true,
          'bytes': response.bodyBytes,
          'contentType': response.headers['content-type'],
          'fileName': _extractFileNameFromHeader(
              response.headers['content-disposition']),
        };
      } else {
        String message = 'Failed to fetch document';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
        } catch (e) {
          print('Error parsing response body: $e');
        }

        print(
            'Error fetching document: $message, Status: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print(
            'Response body: ${response.body.length > 1000 ? response.body.substring(0, 1000) + "..." : response.body}');

        return {
          'success': false,
          'message': message,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Exception in fetchDocumentBytes: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// View document with improved error handling and logging
  Future<Map<String, dynamic>> viewDocument(
      String patientId, String documentId) async {
    try {
      print(
          'Viewing document - Patient ID: $patientId, Document ID: $documentId');
      final token = await getToken();
      if (token == null) {
        print('Authentication token not found');
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final url = '$baseUrl/patient/$patientId/documents/$documentId';
      print('Requesting document from URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        print(
            'Document fetched successfully. Size: ${response.bodyBytes.length} bytes');
        // Extract filename from content-disposition header or use documentId as fallback
        String? fileName =
            _extractFileNameFromHeader(response.headers['content-disposition']);
        print('Extracted filename from header: $fileName');

        // If filename couldn't be extracted, try to get it from the document metadata
        if (fileName == null || fileName.isEmpty) {
          try {
            // Try to get document metadata to find the name
            print('Fetching document metadata');
            final metadataUrl =
                '$baseUrl/patient/$patientId/documents/$documentId/metadata';
            print('Metadata URL: $metadataUrl');

            final metadataResponse = await http.get(
              Uri.parse(metadataUrl),
              headers: {
                'Authorization': 'Bearer $token',
              },
            );

            if (metadataResponse.statusCode == 200) {
              final metaData = jsonDecode(metadataResponse.body);
              fileName = metaData['name'] ?? 'document_$documentId';
              print('Filename from metadata: $fileName');
            } else {
              fileName = 'document_$documentId';
              print(
                  'Could not get metadata, using default filename: $fileName');
            }
          } catch (e) {
            // If metadata request fails, use a default name
            fileName = 'document_$documentId';
            print(
                'Error fetching metadata: $e, using default filename: $fileName');
          }
        }

        // Determine content type from headers or infer from filename
        String? contentType = response.headers['content-type'];
        if (contentType == null ||
            contentType.isEmpty ||
            contentType == 'application/octet-stream') {
          // Try to infer content type from filename
          contentType = FileUtils.getMimeType(fileName ?? 'unknown.bin');
          print('Inferred content type: $contentType');
        } else {
          print('Content type from header: $contentType');
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
        String message = 'Failed to view document';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
        } catch (e) {
          print('Error parsing response body: $e');
        }

        print(
            'Error viewing document: $message, Status: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print(
            'Response body: ${response.body.length > 1000 ? response.body.substring(0, 1000) + "..." : response.body}');

        return {
          'success': false,
          'message': message,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Exception in viewDocument: $e');
      return {
        'success': false,
        'message': 'Error viewing document: $e',
      };
    }
  }

  /// Download document with improved error handling and logging
  Future<Map<String, dynamic>> downloadDocument(
      String patientId, String documentId) async {
    try {
      print(
          'Downloading document - Patient ID: $patientId, Document ID: $documentId');
      final token = await getToken();
      if (token == null) {
        print('Authentication token not found');
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final url = '$baseUrl/patient/$patientId/documents/$documentId';
      print('Downloading document from URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        print(
            'Document downloaded successfully. Size: ${response.bodyBytes.length} bytes');
        String? fileName =
            _extractFileNameFromHeader(response.headers['content-disposition']);
        print('Extracted filename from header: $fileName');

        if (fileName == null || fileName.isEmpty) {
          fileName = 'document_$documentId';
          print('Using default filename: $fileName');
        }

        String? contentType = response.headers['content-type'];
        if (contentType == null || contentType.isEmpty) {
          contentType = FileUtils.getMimeType(fileName);
          print('Inferred content type: $contentType');
        } else {
          print('Content type from header: $contentType');
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
        String message = 'Failed to download document';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            message = data['message'];
          }
        } catch (e) {
          print('Error parsing response body: $e');
        }

        print(
            'Error downloading document: $message, Status: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print(
            'Response body: ${response.body.length > 1000 ? response.body.substring(0, 1000) + "..." : response.body}');

        return {
          'success': false,
          'message': message,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Exception in downloadDocument: $e');
      return {
        'success': false,
        'message': 'Error downloading document: $e',
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print(
          'Retrieved auth token: ${token != null ? "[Token available]" : "[No token]"}');
      return token;
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  // Private method for internal use
  Future<String?> _getToken() async {
    return getAuthToken();
  }

  // Public method to get token for external use
  Future<String?> getToken() async {
    return _getToken();
  }
}
