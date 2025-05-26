// This file defines the PatientDocument class for managing patient documents
import 'dart:convert';

class PatientDocument {
  final String id;
  final String name;
  final String path;
  final String type;
  final String uploadedBy;
  final String uploadedAt;
  final String? contentType; // Original content type from server

  // Computed property for MIME type
  String? get mimeType {
    if (contentType != null && contentType!.isNotEmpty) {
      return contentType;
    }
    
    // Try to determine MIME type from file extension
    if (name.isNotEmpty) {
      final extension = name.split('.').last.toLowerCase();
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'pdf':
          return 'application/pdf';
        case 'doc':
          return 'application/msword';
        case 'docx':
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        case 'txt':
          return 'text/plain';
        default:
          return 'application/octet-stream';
      }
    }
    
    return 'application/octet-stream';
  }

  PatientDocument({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.uploadedBy,
    required this.uploadedAt,
    this.contentType,
  });

  factory PatientDocument.fromJson(Map<String, dynamic> json) {
    String uploadedByStr = 'Unknown';
    if (json['uploadedBy'] != null) {
      if (json['uploadedBy'] is String) {
        uploadedByStr = json['uploadedBy'];
      } else if (json['uploadedBy'] is Map) {
        uploadedByStr = json['uploadedBy']['name'] ?? 'Unknown';
      }
    }

    String uploadedAtStr = '';
    if (json['uploadedAt'] != null) {
      try {
        if (json['uploadedAt'] is String) {
          uploadedAtStr =
              DateTime.parse(json['uploadedAt']).toString().substring(0, 10);
        } else if (json['uploadedAt'] is DateTime) {
          uploadedAtStr = json['uploadedAt'].toString().substring(0, 10);
        } else {
          uploadedAtStr = json['uploadedAt'].toString();
        }
      } catch (e) {
        uploadedAtStr = json['uploadedAt'].toString();
      }
    }

    // Store the original content type for MIME type determination
    String? originalContentType = json['contentType'];
    
    // Process the display type
    String displayType = json['type'] ?? json['contentType'] ?? 'Other';
    if (displayType.contains('/')) {
      displayType = displayType.split('/').last.toUpperCase();
    }

    return PatientDocument(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: displayType,
      uploadedBy: uploadedByStr,
      uploadedAt: uploadedAtStr,
      contentType: originalContentType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
      'contentType': contentType,
    };
  }
}
