import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

class FileService {
  static final ImagePicker _imagePicker = ImagePicker();

  // Pick image from camera
  static Future<File?> takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  // Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Pick multiple files
  static Future<List<File>> pickMultipleFiles() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'All Files',
        extensions: ['*'],
      );

      final List<XFile> files =
          await openFiles(acceptedTypeGroups: [typeGroup]);
      return files.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      debugPrint('Error picking files: $e');
      return [];
    }
  }

  // Pick a single file
  static Future<File?> pickSingleFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'All Files',
        extensions: ['*'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        return File(file.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  // Get file name from path
  static String getFileName(File file) {
    return path.basename(file.path);
  }

  // Get file extension
  static String getFileExtension(File file) {
    return path.extension(file.path).toLowerCase();
  }

  // Check if file is an image
  static bool isImage(File file) {
    final extension = getFileExtension(file);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
        .contains(extension);
  }

  // Check if file is a document
  static bool isDocument(File file) {
    final extension = getFileExtension(file);
    return ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt', '.rtf']
        .contains(extension);
  }
}
