// Platform utilities for cross-platform compatibility
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PlatformUtils {
  // Platform detection
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && io.Platform.isAndroid;
  static bool get isIOS => !kIsWeb && io.Platform.isIOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => !kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);

  // Open URL in browser
  static Future<bool> openUrl(String url) async {
    try {
      // Format URL with correct server address
      final String formattedUrl = url.startsWith('http') 
          ? url 
          : '${getBaseApiUrl().replaceAll('/api', '')}$url';

      if (isWeb) {
        html.window.open(formattedUrl, '_blank');
        return true;
      } else {
        final Uri uri = Uri.parse(formattedUrl);
        return await canLaunchUrl(uri) 
            ? await launchUrl(uri, mode: LaunchMode.externalApplication)
            : false;
      }
    } catch (e) {
      return false;
    }
  }

  // Web-only utilities
  static void viewFileWeb(String url) {
    if (isWeb) {
      final String formattedUrl = url.startsWith('http') ? url : getBaseApiUrl().replaceAll('/api', '') + url;
      html.window.open(formattedUrl, '_blank');
    }
  }

  static void downloadFileWeb(String url, String fileName) {
    if (isWeb) {
      final String formattedUrl = url.startsWith('http') ? url : getBaseApiUrl().replaceAll('/api', '') + url;
      html.AnchorElement(href: formattedUrl)
        ..download = fileName
        ..click();
    }
  }

  // Server IP configuration
  static String _serverIp = '192.168.29.159'; // Default IP (development machine)
  static String _customServerIp = '192.168.29.159';
  static bool _useCustomIp = true;
  
  // Flag to indicate if we're running on a physical device
  static bool _isPhysicalDevice = false;

  // Update server IP
  static Future<void> updateServerIp(String newIp) async {
    _customServerIp = newIp;
    _useCustomIp = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', newIp);
      await prefs.setBool('use_custom_ip', true);
    } catch (_) {}
  }

  // Get current server IP
  static String getServerIp() => _useCustomIp ? _customServerIp : _serverIp;

  // Load IP settings from preferences
  static Future<void> initServerIp() async {
    try {
      // Check if we're on a physical device
      if (isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _isPhysicalDevice = !androidInfo.isPhysicalDevice;
        print('Running on ${_isPhysicalDevice ? 'emulator' : 'physical device'}');
      }
      
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('server_ip');
      final useCustom = prefs.getBool('use_custom_ip') ?? false;

      if (savedIp != null && savedIp.isNotEmpty && useCustom) {
        _customServerIp = savedIp;
        _useCustomIp = true;
        print('Using custom server IP: $_customServerIp');
      }
    } catch (e) {
      print('Error initializing server IP: $e');
    }
  }

  // Get platform-specific base URL for API
  // Get Android SDK version
  static Future<int> getAndroidSdkVersion() async {
    if (isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0; // Return 0 for non-Android platforms
  }

  static String getBaseApiUrl() {
    // For Android devices - always use the custom IP
    if (isAndroid && !isWeb) {
      final url = 'http://$_customServerIp:5000/api';
      print('Android device using API URL: $url');
      return url;
    }
    
    // For custom IP configuration
    if (_useCustomIp && _customServerIp.isNotEmpty) {
      final url = 'http://$_customServerIp:5000/api';
      print('Using custom API URL: $url');
      return url;
    }

    // For web platform
    if (isWeb) {
      try {
        final uri = Uri.parse(html.window.location.href);
        final origin = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ":${uri.port}" : ""}';
        final url = '$origin/api';
        print('Web platform using API URL: $url');
        return url;
      } catch (e) {
        print('Error parsing web URL: $e, using default /api');
        return '/api';
      }
    } 
    
    // For iOS devices
    if (isIOS) {
      final url = 'http://${getServerIp()}:5000/api';
      print('iOS device using API URL: $url');
      return url;
    }
    
    // For all other platforms (desktop, etc.)
    return 'http://localhost:5000/api';
  }




}
