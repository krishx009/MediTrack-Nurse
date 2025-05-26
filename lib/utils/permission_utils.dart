// This file contains utility functions for handling permissions
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/platform_utils.dart';

class PermissionUtils {
  // Request storage permission
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // Get Android SDK version
    final sdkVersion = await PlatformUtils.getAndroidSdkVersion();
    print('Android SDK Version: $sdkVersion');
    
    if (Platform.isAndroid) {
      try {
        // For Android 13+ (API 33+)
        if (sdkVersion >= 33) {
          print('Using Android 13+ (API 33+) permission model');
          // Request all necessary permissions for file access
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();
          final audio = await Permission.audio.request();
          final storage = await Permission.storage.request(); // Still request for backward compatibility
          
          // Also request for external storage for better compatibility
          final manageExternal = await Permission.manageExternalStorage.request();
          
          print('Permission status - Photos: ${photos.name}, Videos: ${videos.name}, Audio: ${audio.name}, Storage: ${storage.name}, Manage External: ${manageExternal.name}');
          
          // For physical devices, we need to be more lenient with permissions
          // Consider it a success if we have at least storage or manage external storage
          final hasBasicStorageAccess = storage.isGranted || manageExternal.isGranted;
          
          if (hasBasicStorageAccess) {
            print('Basic storage access granted, proceeding');
            return true;
          }
          
          // If we don't have basic storage access, check media permissions
          final hasMediaAccess = photos.isGranted || videos.isGranted || audio.isGranted;
          
          if (hasMediaAccess) {
            print('Media access granted, proceeding');
            return true;
          }
          
          // If all permissions are denied, show dialog
          if (photos.isDenied && videos.isDenied && audio.isDenied && storage.isDenied && manageExternal.isDenied) {
            _showPermissionDeniedDialog(
              context,
              'Media Permissions Required',
              'Media permissions are required to access and save files. Please grant at least one of the requested permissions.',
              isPermanent: false,
            );
            return false;
          }
          
          // If any permission is permanently denied, show settings dialog
          if (photos.isPermanentlyDenied || videos.isPermanentlyDenied || audio.isPermanentlyDenied || 
              storage.isPermanentlyDenied || manageExternal.isPermanentlyDenied) {
            _showPermissionDeniedDialog(
              context,
              'Media Permissions Required',
              'Media permissions are required to access and save files. Please enable at least one of them in app settings.',
            );
            return false;
          }
          
          // If we reach here, we have at least one permission that's not denied or permanently denied
          return true;
        } 
        // For Android 11-12 (API 30-32)
        else if (sdkVersion >= 30) {
          print('Using Android 11-12 (API 30-32) permission model');
          // Try to request both types of storage permissions for maximum compatibility
          final storageStatus = await Permission.storage.request();
          final manageStatus = await Permission.manageExternalStorage.request();
          
          print('Permission status - Storage: ${storageStatus.name}, Manage External: ${manageStatus.name}');
          
          // We need at least one of these permissions to be granted
          final hasStorageAccess = storageStatus.isGranted || manageStatus.isGranted;
          
          if (!hasStorageAccess) {
            _showPermissionDeniedDialog(
              context,
              'Storage Permission Required',
              'Storage permission is required to access and save files. Please grant the requested permissions.',
              isPermanent: storageStatus.isPermanentlyDenied && manageStatus.isPermanentlyDenied,
            );
            return false;
          }
          
          return true;
        } 
        // For Android 10 and below (API 29 and below)
        else {
          print('Using Android 10 and below (API 29-) permission model');
          // For older Android versions, use the storage permission
          final status = await Permission.storage.request();
          
          print('Permission status - Storage: ${status.name}');
          
          if (!status.isGranted) {
            _showPermissionDeniedDialog(
              context,
              'Storage Permission Required',
              'Storage permission is required to access and save files. Please grant the requested permission.',
              isPermanent: status.isPermanentlyDenied,
            );
            return false;
          }
          
          return true;
        }
      } catch (e) {
        print('Error requesting storage permissions: $e');
        // In case of error, try the basic storage permission as fallback
        try {
          final status = await Permission.storage.request();
          return status.isGranted;
        } catch (e2) {
          print('Error requesting fallback storage permission: $e2');
          return false;
        }
      }
    } else if (Platform.isIOS) {
      // For iOS, request photo library permission
      final status = await Permission.photos.request();
      
      if (status.isDenied) {
        _showPermissionDeniedDialog(
          context,
          'Photos Permission Required',
          'Photos permission is required to save files.',
          isPermanent: false,
        );
        return false;
      }
      
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog(
          context,
          'Photos Permission Required',
          'Photos permission is required to save files. Please enable it in app settings.',
        );
        return false;
      }
      
      return status.isGranted;
    }
    
    // For other platforms, assume permission is granted
    return true;
  }
  
  // Request camera permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      _showPermissionDeniedDialog(
        context,
        'Camera Permission Required',
        'Camera permission is required to take photos. Please enable it in app settings.',
      );
      return false;
    } else {
      // Permission denied but not permanently
      _showPermissionDeniedDialog(
        context,
        'Camera Permission Required',
        'Camera permission is required to take photos.',
        isPermanent: false,
      );
      return false;
    }
  }
  
  // Show permission denied dialog
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
    {bool isPermanent = true}
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (isPermanent)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Use the correct method from the permission_handler package
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
}
