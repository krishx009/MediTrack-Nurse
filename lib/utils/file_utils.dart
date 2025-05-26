// This file contains utility functions for handling files, images, and validation
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:mime/mime.dart';

class FileUtils {
  // Maximum file size (20MB)
  static const int maxFileSize = 20 * 1024 * 1024;
  
  // Common file extensions by category (for reference and categorization)
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'svg'];
  static const List<String> documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'md'];
  static const List<String> spreadsheetExtensions = ['xls', 'xlsx', 'csv', 'ods'];
  static const List<String> presentationExtensions = ['ppt', 'pptx', 'odp'];
  static const List<String> archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz'];
  static const List<String> audioExtensions = ['mp3', 'wav', 'ogg', 'm4a', 'flac'];
  static const List<String> videoExtensions = ['mp4', 'avi', 'mov', 'wmv', 'mkv', 'webm'];
  
  // All supported extensions (for reference only - we now accept all extensions)
  static const List<String> commonExtensions = [
    ...imageExtensions,
    ...documentExtensions,
    ...spreadsheetExtensions,
    ...presentationExtensions,
    ...archiveExtensions,
    ...audioExtensions,
    ...videoExtensions,
  ];
  
  // Common MIME types by category (for reference and categorization)
  static const List<String> imageMimeTypes = [
    'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/webp', 'image/tiff', 'image/svg+xml'
  ];
  static const List<String> documentMimeTypes = [
    'application/pdf', 
    'application/msword', 
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    'application/rtf',
    'application/vnd.oasis.opendocument.text',
    'text/markdown'
  ];
  static const List<String> spreadsheetMimeTypes = [
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/csv',
    'application/vnd.oasis.opendocument.spreadsheet'
  ];
  static const List<String> presentationMimeTypes = [
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.oasis.opendocument.presentation'
  ];
  static const List<String> archiveMimeTypes = [
    'application/zip', 
    'application/x-rar-compressed', 
    'application/x-7z-compressed',
    'application/x-tar',
    'application/gzip'
  ];
  static const List<String> audioMimeTypes = [
    'audio/mpeg', 
    'audio/wav', 
    'audio/ogg',
    'audio/mp4',
    'audio/flac'
  ];
  static const List<String> videoMimeTypes = [
    'video/mp4', 
    'video/x-msvideo', 
    'video/quicktime',
    'video/x-ms-wmv',
    'video/x-matroska',
    'video/webm'
  ];
  
  // Check if file extension is allowed - now accepts all extensions
  static bool isAllowedExtension(String fileName) {
    // Check if the file has an extension at all
    return fileName.contains('.');
  }
  
  // Check if file size is within limits
  static Future<bool> isFileSizeValid(File file) async {
    final size = await file.length();
    return size <= maxFileSize;
  }
  
  // For web platform, check if file size is within limits
  static bool isWebFileSizeValid(html.File file) {
    return file.size <= maxFileSize;
  }
  
  // Get MIME type from file extension
  static String getMimeType(String fileName) {
    // First try using the system's MIME type detection
    final mimeType = lookupMimeType(fileName);
    if (mimeType != null) {
      return mimeType;
    }
    
    // If system detection fails, use our extended mapping
    if (!fileName.contains('.')) {
      return 'application/octet-stream'; // Default for files without extension
    }
    
    final extension = fileName.split('.').last.toLowerCase();
    
    // Images
    if (imageExtensions.contains(extension)) {
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'gif':
          return 'image/gif';
        case 'bmp':
          return 'image/bmp';
        case 'webp':
          return 'image/webp';
        case 'tiff':
          return 'image/tiff';
        case 'svg':
          return 'image/svg+xml';
        default:
          return 'image/jpeg'; // Fallback for other image types
      }
    }
    
    // Documents
    if (documentExtensions.contains(extension)) {
      switch (extension) {
        case 'pdf':
          return 'application/pdf';
        case 'doc':
          return 'application/msword';
        case 'docx':
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        case 'txt':
          return 'text/plain';
        case 'rtf':
          return 'application/rtf';
        case 'odt':
          return 'application/vnd.oasis.opendocument.text';
        case 'md':
          return 'text/markdown';
        default:
          return 'application/pdf'; // Fallback for other document types
      }
    }
    
    // Spreadsheets
    if (spreadsheetExtensions.contains(extension)) {
      switch (extension) {
        case 'xls':
          return 'application/vnd.ms-excel';
        case 'xlsx':
          return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        case 'csv':
          return 'text/csv';
        case 'ods':
          return 'application/vnd.oasis.opendocument.spreadsheet';
        default:
          return 'application/vnd.ms-excel'; // Fallback for other spreadsheet types
      }
    }
    
    // Presentations
    if (presentationExtensions.contains(extension)) {
      switch (extension) {
        case 'ppt':
          return 'application/vnd.ms-powerpoint';
        case 'pptx':
          return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
        case 'odp':
          return 'application/vnd.oasis.opendocument.presentation';
        default:
          return 'application/vnd.ms-powerpoint'; // Fallback for other presentation types
      }
    }
    
    // Archives
    if (archiveExtensions.contains(extension)) {
      switch (extension) {
        case 'zip':
          return 'application/zip';
        case 'rar':
          return 'application/x-rar-compressed';
        case '7z':
          return 'application/x-7z-compressed';
        case 'tar':
          return 'application/x-tar';
        case 'gz':
          return 'application/gzip';
        default:
          return 'application/zip'; // Fallback for other archive types
      }
    }
    
    // Audio
    if (audioExtensions.contains(extension)) {
      switch (extension) {
        case 'mp3':
          return 'audio/mpeg';
        case 'wav':
          return 'audio/wav';
        case 'ogg':
          return 'audio/ogg';
        case 'm4a':
          return 'audio/mp4';
        case 'flac':
          return 'audio/flac';
        default:
          return 'audio/mpeg'; // Fallback for other audio types
      }
    }
    
    // Video
    if (videoExtensions.contains(extension)) {
      switch (extension) {
        case 'mp4':
          return 'video/mp4';
        case 'avi':
          return 'video/x-msvideo';
        case 'mov':
          return 'video/quicktime';
        case 'wmv':
          return 'video/x-ms-wmv';
        case 'mkv':
          return 'video/x-matroska';
        case 'webm':
          return 'video/webm';
        default:
          return 'video/mp4'; // Fallback for other video types
      }
    }
    
    // Default fallback for any other file type
    return 'application/octet-stream';
  }
  
  // Check if a file is an image based on extension
  static bool isImageFile(String fileName) {
    if (!fileName.contains('.')) return false;
    final extension = fileName.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }
  
  // Check if a file is a document based on extension
  static bool isDocumentFile(String fileName) {
    if (!fileName.contains('.')) return false;
    final extension = fileName.split('.').last.toLowerCase();
    return documentExtensions.contains(extension);
  }
  
  // Check file type category
  static String getFileCategory(String fileName) {
    if (!fileName.contains('.')) return 'unknown';
    final extension = fileName.split('.').last.toLowerCase();
    
    if (imageExtensions.contains(extension)) return 'image';
    if (documentExtensions.contains(extension)) return 'document';
    if (spreadsheetExtensions.contains(extension)) return 'spreadsheet';
    if (presentationExtensions.contains(extension)) return 'presentation';
    if (archiveExtensions.contains(extension)) return 'archive';
    if (audioExtensions.contains(extension)) return 'audio';
    if (videoExtensions.contains(extension)) return 'video';
    
    return 'other';
  }
  
  // Validate file before upload - only checks if file exists and size
  static Future<Map<String, dynamic>> validateFile(File file) async {
    // Check if file exists
    if (!await file.exists()) {
      return {
        'isValid': false,
        'message': 'File does not exist or cannot be read',
      };
    }
    
    // Check file size
    if (!await isFileSizeValid(file)) {
      return {
        'isValid': false,
        'message': 'File size exceeds the maximum limit of 20MB.',
      };
    }
    
    // Get file category for information purposes
    final fileName = file.path.split('/').last;
    final category = getFileCategory(fileName);
    
    return {
      'isValid': true,
      'message': 'File is valid',
      'category': category,
      'mimeType': getMimeType(fileName),
    };
  }
  
  // Validate web file before upload - only checks size
  static Map<String, dynamic> validateWebFile(html.File file) {
    // Check file size
    if (!isWebFileSizeValid(file)) {
      return {
        'isValid': false,
        'message': 'File size exceeds the maximum limit of 20MB.',
      };
    }
    
    // Get file category for information purposes
    final category = getFileCategory(file.name);
    
    return {
      'isValid': true,
      'message': 'File is valid',
      'category': category,
      'mimeType': getMimeType(file.name),
    };
  }
}
