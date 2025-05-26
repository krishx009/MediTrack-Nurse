// This file contains utility functions for handling image loading with proper error handling
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ImageUtils {
  // Load network image with error handling
  static Widget loadNetworkImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // Handle null or empty URL
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ?? const Icon(Icons.image_not_supported, size: 50);
    }
    
    // Create placeholder widget if not provided
    final placeholderWidget = placeholder ?? 
      Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    
    // Create error widget if not provided
    final errorWidgetFinal = errorWidget ?? 
      Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 40),
              SizedBox(height: 8),
              Text('Image not available', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    
    // Return image with error handling
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholderWidget;
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading image: $error');
        return errorWidgetFinal;
      },
    );
  }
  
  // Load file image with error handling
  static Widget loadFileImage({
    required File? file,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    // Handle null file
    if (file == null) {
      return errorWidget ?? const Icon(Icons.image_not_supported, size: 50);
    }
    
    // Create error widget if not provided
    final errorWidgetFinal = errorWidget ?? 
      Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 40),
              SizedBox(height: 8),
              Text('Image not available', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    
    // Return image with error handling
    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading image file: $error');
        return errorWidgetFinal;
      },
    );
  }
  
  // Load asset image with error handling
  static Widget loadAssetImage({
    required String assetPath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    // Create error widget if not provided
    final errorWidgetFinal = errorWidget ?? 
      Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 40),
              SizedBox(height: 8),
              Text('Image not available', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    
    // Return image with error handling
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading asset image: $error');
        return errorWidgetFinal;
      },
    );
  }
}
