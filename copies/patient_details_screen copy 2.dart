import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Import models and services
import '../lib/models/models.dart';
import '../lib/services/api_service.dart';
import '../lib/providers/patient_provider.dart';

// Import utilities
import '../lib/utils/file_utils.dart';
import '../lib/utils/image_utils.dart';
import '../lib/utils/permission_utils.dart';
import '../lib/utils/platform_utils.dart';

class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Patient patient;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _photoUrl;
  String? _idProofUrl;
  List<PatientDocument> _documents = [];
  List<Prescription> _prescriptions = [];

  // Animation controllers
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get patient data from route arguments with proper type checking
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Patient) {
      patient = routeArgs;

      // Initialize the patient provider with the current patient
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      patientProvider.loadPatientById(patient.id).then((_) {
        // After loading patient data, load files, documents and prescriptions
        _loadPatientFiles();
        _loadPatientDocuments();
        _loadPatientPrescriptions();
      });
    } else {
      // Handle case where patient data is missing or invalid
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid patient data'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  Future<void> _loadPatientFiles() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch patient data to get latest file URLs
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.loadPatientById(patient.id);

      if (patientProvider.currentPatient != null) {
        patient = patientProvider.currentPatient!;
      }

      // DIRECT APPROACH: Create direct URLs to the backend endpoints
      // These endpoints stream the files directly from GridFS
      final baseApiUrl = _apiService.baseUrl;

      // Construct URLs without duplicate 'api' path segment
      final photoUrl = '$baseApiUrl/patient/${patient.id}/photo';
      final idProofUrl = '$baseApiUrl/patient/${patient.id}/idproof';

      // Set URLs in a single setState call to avoid multiple rebuilds
      setState(() {
        _photoUrl = photoUrl;
        _idProofUrl = idProofUrl;
        _isLoading = false;
      });

      // Print debug info
      print('Patient ID: ${patient.id}');
      print('Photo URL set to: $_photoUrl');
      print('ID Proof URL set to: $_idProofUrl');
      print('Base API URL: $baseApiUrl');
      print('Auth token available: ${_apiService.getToken() != null}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error loading patient files: $e');
    }
  }

  // View image in a full-screen dialog with authentication
  void _viewImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      _showErrorSnackBar('No image available');
      return;
    }

    // Handle web platform specially
    if (kIsWeb) {
      _apiService.viewFileWeb(imageUrl);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Full screen image with auth token
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(20),
              child: Center(
                child: Hero(
                  tag: 'image-${imageUrl.hashCode}',
                  child: Image.network(
                    imageUrl,
                    headers: {
                      'Authorization': 'Bearer ${_apiService.getToken() ?? ''}',
                      'Cache-Control': 'no-cache',
                      'Pragma': 'no-cache',
                    },
                    fit: BoxFit.contain,
                    // Force network image refresh by adding timestamp
                    key: ValueKey(
                        'viewer_${DateTime.now().millisecondsSinceEpoch}'),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.black26,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.white,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Loading image...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        color: Colors.black26,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade300, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to load image',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _viewImage(imageUrl); // Retry
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4361EE),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Download button
            Positioned(
              bottom: 40,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF4361EE),
                child: const Icon(Icons.download),
                onPressed: () {
                  // Implement download functionality here
                  _showInfoSnackBar('Downloading image...');
                  // Close the dialog and show confirmation
                  Navigator.of(context).pop();
                  _showSuccessSnackBar('Image downloaded successfully');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPatientDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the PatientProvider to load documents
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.loadPatientDocuments(patient.id);

      setState(() {
        _isLoading = false;
        // Get documents from the provider
        _documents = patientProvider.documents;
      });

      // Check for errors from the provider
      if (patientProvider.error != null) {
        _showWarningSnackBar('Warning: ${patientProvider.error}');
        // Clear the error after showing it
        patientProvider.clearError();
      }
    } catch (e) {
      // Handle any unexpected errors
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error loading documents: $e');
    }
  }

  Future<void> _refreshPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the PatientProvider to refresh patient data
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.loadPatientById(patient.id);

      // Update local patient object if provider has current patient
      if (patientProvider.currentPatient != null) {
        setState(() {
          patient = patientProvider.currentPatient!;
        });

        // Reload files and documents
        _loadPatientFiles();
        await _loadPatientDocuments();
      }

      setState(() {
        _isLoading = false;
      });

      // Check for errors from the provider
      if (patientProvider.error != null) {
        _showErrorSnackBar('Error: ${patientProvider.error}');
        // Clear the error after showing it
        patientProvider.clearError();
      }
    } catch (e) {
      // Handle any unexpected errors
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error refreshing patient data: $e');
    }
  }

  Future<void> _pickAndUploadFile(String type) async {
    if (kIsWeb) {
      await _pickAndUploadFileWeb(type);
    } else {
      await _pickAndUploadFileMobile(type);
    }
  }

  // Mobile implementation for picking and uploading files
  Future<void> _pickAndUploadFileMobile(String type) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isLoading = true;
        });

        // Check if file exists and is readable
        final File photoFile = File(image.path);
        if (!await photoFile.exists()) {
          setState(() {
            _isLoading = false;
          });

          _showErrorSnackBar('Error: File does not exist or cannot be read');
          return;
        }

        final result = await _apiService.uploadPatientFiles(
          patient.id,
          type == 'photo' ? photoFile : null,
          type == 'idProof' ? photoFile : null,
        );

        setState(() {
          _isLoading = false;
          if (result['success']) {
            // Update the URLs directly since we can't modify the patient object
            if (type == 'photo' && result['photoUrl'] != null) {
              _photoUrl = _apiService.getFileUrl(result['photoUrl']);
            } else if (type == 'idProof' && result['idProofUrl'] != null) {
              _idProofUrl = _apiService.getFileUrl(result['idProofUrl']);
            }

            _showSuccessSnackBar('File uploaded successfully');

            // Refresh patient data to ensure we have the latest state
            _refreshPatientData();
          } else {
            _showErrorSnackBar('Error: ${result['message']}');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error picking image: $e');
    }
  }

  // Web implementation for picking and uploading files
  Future<void> _pickAndUploadFileWeb(String type) async {
    try {
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = 'image/*';
      input.click();

      await input.onChange.first;
      if (input.files!.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        final html.File file = input.files![0];

        // Pass the web file directly to the API service
        final result = await _apiService.uploadPatientFiles(
          patient.id,
          type == 'photo' ? file : null,
          type == 'idProof' ? file : null,
        );

        setState(() {
          _isLoading = false;
          if (result['success']) {
            // Update the URLs directly since we can't modify the patient object
            if (type == 'photo' && result['photoUrl'] != null) {
              _photoUrl = _apiService.getFileUrl(result['photoUrl']);
            } else if (type == 'idProof' && result['idProofUrl'] != null) {
              _idProofUrl = _apiService.getFileUrl(result['idProofUrl']);
            }

            _showSuccessSnackBar('File uploaded successfully');

            // Refresh patient data to ensure we have the latest state
            _refreshPatientData();
          } else {
            _showErrorSnackBar('Error: ${result['message']}');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _pickAndUploadDocument() async {
    if (kIsWeb) {
      await _pickAndUploadDocumentWeb();
    } else {
      await _pickAndUploadDocumentMobile();
    }
  }

  // Mobile implementation for picking and uploading documents
  Future<void> _pickAndUploadDocumentMobile() async {
    try {
      // First request storage permission
      bool hasPermission =
          await PermissionUtils.requestStoragePermission(context);
      if (!hasPermission) {
        return; // Permission denied
      }

      // Use file_selector with allowed extensions
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Documents',
        extensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      final XFile? result = await openFile(acceptedTypeGroups: [typeGroup]);

      if (result != null) {
        // Show dialog to get document name and type
        final documentDetails = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => _buildDocumentDetailsDialog(result.name),
        );

        if (documentDetails != null) {
          setState(() {
            _isLoading = true;
          });

          // Create file object
          final File file = File(result.path);

          // Validate file using FileUtils
          final validationResult = await FileUtils.validateFile(file);
          if (!validationResult['isValid']) {
            setState(() {
              _isLoading = false;
            });

            _showErrorSnackBar('Error: ${validationResult['message']}');
            return;
          }

          // Use the PatientProvider for document upload
          final patientProvider =
              Provider.of<PatientProvider>(context, listen: false);
          final uploadResult = await patientProvider.uploadDocument(
            patient.id,
            file,
            customName: documentDetails['name'],
            documentType: documentDetails['type'],
          );

          setState(() {
            _isLoading = false;
            if (uploadResult['success']) {
              _showSuccessSnackBar('Document uploaded successfully');

              // Refresh patient data to show the new document
              _refreshPatientData();
            } else {
              _showErrorSnackBar('Error: ${uploadResult['message']}');
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error picking document: $e');
    }
  }

  // Web implementation for picking and uploading documents using file_selector
  Future<void> _pickAndUploadDocumentWeb() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Documents',
        extensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        final documentDetails = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => _buildDocumentDetailsDialog(file.name),
        );

        if (documentDetails != null) {
          setState(() {
            _isLoading = true;
          });

          // Read file bytes
          final Uint8List bytes = await file.readAsBytes();

          // Use the PatientProvider for document upload
          final patientProvider =
              Provider.of<PatientProvider>(context, listen: false);

          // Create a web-specific upload method that passes the bytes and metadata
          Map<String, dynamic> uploadResult = await _uploadWebDocument(
            patientId: patient.id,
            fileBytes: bytes,
            fileName: documentDetails['name'] ?? file.name,
            fileType: FileUtils.getMimeType(file.name),
            documentType: documentDetails['type'],
          );

          setState(() {
            _isLoading = false;
            if (uploadResult['success']) {
              _showSuccessSnackBar('Document uploaded successfully');

              // Refresh patient data to show the new document
              _refreshPatientData();
            } else {
              _showErrorSnackBar('Error: ${uploadResult['message']}');
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error picking document: $e');
    }
  }

  // Helper method to determine MIME type from file extension
  String _getMimeType(String fileName) {
    // Use the FileUtils class to get the MIME type
    return FileUtils.getMimeType(fileName);
  }

  // Helper method to upload a web document
  Future<Map<String, dynamic>> _uploadWebDocument({
    required String patientId,
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    String? documentType,
  }) async {
    try {
      // Create the multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${_apiService.baseUrl}/patient/upload/$patientId/documents'),
      );

      // Add authorization header
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add the file to the request
      request.files.add(
        http.MultipartFile.fromBytes(
          'documents',
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(fileType),
        ),
      );

      // Add document metadata
      request.fields['name'] = fileName;
      request.fields['type'] = documentType ?? fileType;

      // Send the request and get the response
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Parse the response with proper error handling
      try {
        if (response.body.isNotEmpty) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (response.statusCode == 200) {
            return {
              'success': true,
              'message': 'Document uploaded successfully',
              'file': data['files'] != null &&
                      data['files'] is List &&
                      data['files'].isNotEmpty
                  ? data['files'][0]
                  : null,
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Failed to upload document',
            };
          }
        } else {
          return {
            'success': response.statusCode == 200,
            'message': response.statusCode == 200
                ? 'Document uploaded successfully'
                : 'Server returned empty response',
          };
        }
      } catch (e) {
        debugPrint('Error parsing response: $e');
        return {
          'success': response.statusCode == 200,
          'message': response.statusCode == 200
              ? 'Document uploaded successfully'
              : 'Failed to parse server response: $e',
        };
      }
    } catch (e) {
      debugPrint('Error uploading web document: $e');
      return {
        'success': false,
        'message': 'Error uploading document: $e',
      };
    }
  }

  Widget _buildDocumentDetailsDialog(String? fileName) {
    // Safely extract filename without extension for the default name
    String defaultName = '';
    if (fileName != null && fileName.isNotEmpty) {
      final parts = fileName.split('.');
      if (parts.length > 1) {
        // Remove the extension for the default name
        defaultName = parts.take(parts.length - 1).join('.');
      } else {
        defaultName = fileName;
      }
    }

    final nameController = TextEditingController(text: defaultName);
    String selectedType = 'Medical Report';

    // Try to determine document type from file extension
    if (fileName != null && fileName.isNotEmpty) {
      final parts = fileName.split('.');
      if (parts.length > 1) {
        final extension = parts.last.toLowerCase();
        if (['jpg', 'jpeg', 'png'].contains(extension)) {
          selectedType = 'Medical Report';
        } else if (['pdf'].contains(extension)) {
          selectedType = 'Lab Result';
        } else if (['doc', 'docx'].contains(extension)) {
          selectedType = 'Prescription';
        }
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Document Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Document Name',
                hintText: 'Enter document name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: InputDecoration(
                labelText: 'Document Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: [
                'Medical Report',
                'Prescription',
                'Lab Result',
                'Insurance',
                'Consent Form',
                'Other'
              ].map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  selectedType = value;
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': nameController.text,
                'type': selectedType,
              });
            } else {
              _showWarningSnackBar('Please enter a document name');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Upload'),
        ),
      ],
    );
  }

  Future<void> _viewDocument(PatientDocument document) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result = await _apiService.viewDocument(patient.id, document.id);

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        final bytes = result['data'] as Uint8List;
        final contentType = result['contentType'] as String?;
        final fileName = result['fileName'] as String? ?? document.name;

        if (contentType != null) {
          if (kIsWeb) {
            final blob = html.Blob([bytes], contentType);
            final url = html.Url.createObjectUrlFromBlob(blob);
            // Open in new tab if browser can render, else download
            if (contentType.startsWith('image/') ||
                contentType == 'application/pdf' ||
                contentType.startsWith('text/')) {
              html.window.open(url, '_blank');
            } else {
              final anchor = html.AnchorElement(href: url)
                ..setAttribute('download', fileName)
                ..click();
            }
            html.Url.revokeObjectUrl(url);
            return;
          }
          if (contentType.startsWith('image/')) {
            // Show image in a dialog
            showDialog(
              context: context,
              builder: (_) => Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      title: Text(fileName),
                      automaticallyImplyLeading: false,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    InteractiveViewer(
                      child: Image.memory(bytes),
                    ),
                  ],
                ),
              ),
            );
          } else if (contentType == 'application/pdf') {
            // Handle PDF files
            final directory = await getTemporaryDirectory();
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(bytes);

            final uri = Uri.file(filePath);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              _showErrorSnackBar('Could not open PDF: $fileName');
            }
          } else {
            // Handle other file types
            final directory = await getTemporaryDirectory();
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(bytes);

            final uri = Uri.file(filePath);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _showErrorSnackBar('Could not open file: $fileName');
            }
          }
        }
      } else {
        _showErrorSnackBar('Error: ${result['message']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error viewing document: $e');
    }
  }

  Future<void> _downloadDocument(PatientDocument document) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result =
          await _apiService.downloadDocument(patient.id, document.id);

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        final bytes = result['data'] as Uint8List;
        final contentType = result['contentType'] as String?;
        final fileName = result['fileName'] as String? ?? document.name;

        if (kIsWeb) {
          // For web, create a blob and trigger download
          final blob = html.Blob([bytes], contentType);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          // For mobile/desktop, save to downloads directory
          final directory = await getDownloadsDirectory();
          if (directory != null) {
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(bytes);

            _showSuccessSnackBar('Document downloaded to: $filePath');
          } else {
            throw Exception('Could not access downloads directory');
          }
        }
      } else {
        _showErrorSnackBar('Error: ${result['message']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error downloading document: $e');
    }
  }

  Future<void> _showRenameDocumentDialog(PatientDocument document) async {
    final TextEditingController nameController =
        TextEditingController(text: document.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Document'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Document Name',
            hintText: 'Enter new document name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, nameController.text);
              } else {
                _showWarningSnackBar('Please enter a document name');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != document.name) {
      setState(() {
        _isLoading = true;
      });

      try {
        final patientProvider =
            Provider.of<PatientProvider>(context, listen: false);
        final result = await patientProvider.renameDocument(
            patient.id, document.id, newName);

        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          setState(() {
            _documents = patientProvider.documents;
          });

          _showSuccessSnackBar('Document renamed successfully');
        } else {
          _showErrorSnackBar('Error: ${result['message']}');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        _showErrorSnackBar('Error renaming document: $e');
      }
    }
  }

  Future<void> _confirmDeleteDocument(PatientDocument document) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final patientProvider =
            Provider.of<PatientProvider>(context, listen: false);
        final result =
            await patientProvider.deleteDocument(patient.id, document.id);

        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          setState(() {
            _documents = patientProvider.documents;
          });

          _showSuccessSnackBar('Document deleted successfully');
        } else {
          _showErrorSnackBar('Error: ${result['message']}');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        _showErrorSnackBar('Error deleting document: $e');
      }
    }
  }

  // Load prescriptions for the patient
  Future<void> _loadPatientPrescriptions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getPatientPrescriptions(patient.id);
      if (response['success']) {
        setState(() {
          _prescriptions = (response['prescriptions'] as List)
              .map((p) => Prescription.fromJson(p))
              .toList();
        });
      } else {
        _showErrorSnackBar(
            'Error loading prescriptions: ${response['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading prescriptions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Generate and download PDF for a prescription
  Future<void> _generatePrescriptionPDF(String prescriptionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Downloading PDF for prescription: $prescriptionId'); // Debug log

      // First, ensure the PDF exists by calling the generate endpoint
      try {
        final generateResponse =
            await _apiService.generatePrescriptionPDF(prescriptionId);
        print('PDF generation response: $generateResponse');
      } catch (e) {
        print('Warning: PDF generation call failed: $e');
        // Continue anyway, as the PDF might already exist
      }

      if (kIsWeb) {
        // For web platform, use window.open with proper authentication
        final url =
            '${_apiService.getBaseUrl()}/prescriptions/$prescriptionId/get-pdf';

        // Get token for authentication
        final token = await _apiService.getToken();
        if (token == null) {
          throw Exception('Authentication token not found');
        }

        // Show loading indicator
        _showInfoSnackBar('Preparing PDF for download...');

        // Use JavaScript to handle the download with proper headers
        final js = '''
        (function() {
          var xhr = new XMLHttpRequest();
          xhr.open('GET', '$url', true);
          xhr.setRequestHeader('Authorization', 'Bearer $token');
          xhr.responseType = 'blob';
          
          xhr.onload = function() {
            if (this.status === 200) {
              var blob = new Blob([this.response], {type: 'application/pdf'});
              var link = document.createElement('a');
              link.href = window.URL.createObjectURL(blob);
              link.download = 'prescription_$prescriptionId.pdf';
              link.style.display = 'none';
              document.body.appendChild(link);
              link.click();
              document.body.removeChild(link);
              window.URL.revokeObjectURL(link.href);
            } else {
              console.error('PDF download failed with status: ' + this.status);
              alert('Failed to download PDF. Please try again.');
            }
          };
          
          xhr.onerror = function() {
            console.error('PDF download network error');
            alert('Network error occurred while downloading PDF.');
          };
          
          xhr.send();
        })();
        ''';

        // Execute the JavaScript using a script element
        final scriptTag = html.ScriptElement()
          ..type = 'text/javascript'
          ..text = js;
        html.document.body?.append(scriptTag);

        // Remove the script tag after execution
        Future.delayed(Duration(milliseconds: 100), () {
          scriptTag.remove();
        });

        _showSuccessSnackBar('PDF download initiated');
      } else {
        // For mobile platforms, download and save the file
        final url =
            '${_apiService.getBaseUrl()}/prescriptions/$prescriptionId/get-pdf';

        // Get token for authentication
        final token = await _apiService.getToken();
        if (token == null) {
          throw Exception('Authentication token not found');
        }

        // Make the request with authentication
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          // Save the file
          final fileName = 'prescription_$prescriptionId.pdf';
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';

          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          _showSuccessSnackBar('PDF saved to: $filePath',
              action: SnackBarAction(
                label: 'Open',
                onPressed: () async {
                  if (await canLaunch('file://$filePath')) {
                    await launch('file://$filePath');
                  }
                },
              ));
        } else {
          throw Exception('Failed to download PDF: ${response.statusCode}');
        }
      }

      // Refresh prescriptions list
      _loadPatientPrescriptions();
    } catch (e) {
      print('Exception downloading PDF: $e'); // Debug log
      _showErrorSnackBar('Error downloading PDF: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // View prescription PDF
  Future<void> _viewPrescriptionPDF(String pdfUrl) async {
    try {
      final url = _apiService.getBaseUrl() + pdfUrl;
      print('Opening PDF URL: $url'); // Debug log

      if (kIsWeb) {
        // For web platform
        html.window.open(url, '_blank');
      } else {
        // For mobile platforms
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          _showErrorSnackBar('Could not open PDF');
        }
      }
    } catch (e) {
      print('Error viewing PDF: $e'); // Debug log
      _showErrorSnackBar('Error viewing PDF: $e');
    }
  }

  // Download prescription PDF
  Future<void> _downloadPrescriptionPDF(String pdfUrl) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = _apiService.getBaseUrl() + pdfUrl;
      print('Downloading PDF from URL: $url'); // Debug log

      // Extract filename from URL
      final fileName = pdfUrl.split('/').last;

      if (kIsWeb) {
        // For web platform, use the downloadFileWeb method from ApiService
        _apiService.downloadFileWeb(
            url, fileName); // This is a void method, don't use await

        _showSuccessSnackBar('PDF downloaded successfully');
      } else {
        // For mobile platforms
        final result = await _apiService.fetchDocumentBytes('', pdfUrl);

        if (result['success']) {
          // Use platform-specific download methods
          final bytes = result['bytes'];
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';

          // Write the file
          final file = File(filePath);
          await file.writeAsBytes(bytes);

          // Show success message with option to open the file
          _showSuccessSnackBar('PDF saved to: $filePath',
              action: SnackBarAction(
                label: 'Open',
                onPressed: () async {
                  if (await canLaunch('file://$filePath')) {
                    await launch('file://$filePath');
                  }
                },
              ));
        } else {
          throw Exception(result['message']);
        }
      }
    } catch (e) {
      print('Error downloading PDF: $e'); // Debug log
      _showErrorSnackBar('Error downloading PDF: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper methods for showing SnackBars
  void _showSuccessSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        action: action,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define a gradient color scheme for the app
    final primaryColor = Color(0xFF4361EE);
    final secondaryColor = Color(0xFF3A0CA3);
    final accentColor = Color(0xFF4CC9F0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Custom app bar with back button and refresh
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 8,
              right: 8,
              bottom: 8,
            ),
            color: primaryColor,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshPatientData,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Patient info card - separated as requested
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Hero(
                      tag: 'patient-${patient.id}',
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: primaryColor.withOpacity(0.2),
                        child: _photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _photoUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      patient.name
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 32,
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                patient.name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 32,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ).animate().scale(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(
                                duration: const Duration(milliseconds: 300),
                              ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${patient.patientId}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ).animate().fadeIn(
                                duration: const Duration(milliseconds: 300),
                                delay: const Duration(milliseconds: 100),
                              ),
                          const SizedBox(height: 4),
                          Text(
                            '${patient.age} years, ${patient.gender}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ).animate().fadeIn(
                                duration: const Duration(milliseconds: 300),
                                delay: const Duration(milliseconds: 200),
                              ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                color: primaryColor,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                patient.phoneNumber,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ).animate().fadeIn(
                                duration: const Duration(milliseconds: 300),
                                delay: const Duration(milliseconds: 300),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 500),
                ),
          ),

          // Tab bar - separated as requested
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: primaryColor, width: 3),
                insets: const EdgeInsets.symmetric(horizontal: 16),
              ),
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              padding: const EdgeInsets.all(4),
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  return states.contains(MaterialState.focused)
                      ? null
                      : Colors.transparent;
                },
              ),
              tabs: [
                Tab(
                  text: 'Overview',
                  icon: Icon(Icons.dashboard_outlined),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  text: 'Visits',
                  icon: Icon(Icons.calendar_today_outlined),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  text: 'Documents',
                  icon: Icon(Icons.folder_outlined),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  text: 'Prescriptions',
                  icon: Icon(Icons.medication_outlined),
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ).animate().fadeIn(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 200),
              ),

          // Tab content
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildOverviewTab()
                          .animate(
                            target: _tabController.index == 0 ? 1 : 0,
                          )
                          .slideX(
                            begin: 0.1,
                            end: 0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                      _buildVisitsTab()
                          .animate(
                            target: _tabController.index == 1 ? 1 : 0,
                          )
                          .slideX(
                            begin: 0.1,
                            end: 0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                      _buildDocumentsTab()
                          .animate(
                            target: _tabController.index == 2 ? 1 : 0,
                          )
                          .slideX(
                            begin: 0.1,
                            end: 0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                      _buildPrescriptionsTab()
                          .animate(
                            target: _tabController.index == 3 ? 1 : 0,
                          )
                          .slideX(
                            begin: 0.1,
                            end: 0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                    ],
                  ),
                  if (_isLoading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CircularProgressIndicator(
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(primaryColor),
    );
  }

  Widget _buildFloatingActionButton(Color primaryColor) {
    // Show different FAB based on current tab
    if (_tabController.index == 2) {
      return FloatingActionButton(
        onPressed: _pickAndUploadDocument,
        backgroundColor: primaryColor,
        child: const Icon(Icons.upload_file, color: Colors.white),
        elevation: 4,
      ).animate().scale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
    } else {
      return FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/patient_intake',
            arguments: {'patient': patient, 'isNewVisit': true},
          ).then((_) {
            _refreshPatientData();
          });
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        elevation: 4,
      ).animate().scale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
    }
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshPatientData,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(
              'Personal Information',
              [
                InfoItem(label: 'Age', value: '${patient.age} years'),
                InfoItem(label: 'Gender', value: patient.gender),
                InfoItem(label: 'Phone', value: patient.phoneNumber),
                InfoItem(
                    label: 'Emergency Contact',
                    value: patient.emergencyContact),
              ],
              icon: Icons.person,
              color: Colors.blue,
            ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
            const SizedBox(height: 16),
            _buildInfoSection(
              'Address',
              [
                InfoItem(label: 'Full Address', value: patient.address),
              ],
              icon: Icons.location_on,
              color: Colors.orange,
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 300),
                  delay: const Duration(milliseconds: 100),
                ),
            const SizedBox(height: 16),
            _buildInfoSection(
              'Medical History',
              [
                InfoItem(
                    label: 'Medical History', value: patient.medicalHistory),
              ],
              icon: Icons.medical_services,
              color: Colors.red,
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 300),
                  delay: const Duration(milliseconds: 200),
                ),
            const SizedBox(height: 16),
            _buildInfoSection(
              'Visit Summary',
              [
                InfoItem(label: 'Total Visits', value: '${patient.visitCount}'),
                InfoItem(
                  label: 'Last Visit',
                  value: patient.lastVisitDate.isNotEmpty
                      ? patient.lastVisitDate
                      : 'No visits yet',
                ),
              ],
              icon: Icons.calendar_today,
              color: Colors.green,
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 300),
                  delay: const Duration(milliseconds: 300),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsTab() {
    if (patient.diagnoses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ).animate().scale(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 16),
            Text(
              'No visits recorded yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 300),
                ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/patient_intake',
                  arguments: {'patient': patient, 'isNewVisit': true},
                ).then((_) {
                  _refreshPatientData();
                });
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Visit',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361EE),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 600),
                ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshPatientData,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(8.0),
        itemCount: patient.diagnoses.length,
        itemBuilder: (context, index) {
          final diagnosis = patient.diagnoses[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/diagnosis_details',
                  arguments: {
                    'patient': patient,
                    'diagnosis': diagnosis,
                  },
                );
              },
              splashColor: const Color(0xFF4361EE).withOpacity(0.1),
              highlightColor: const Color(0xFF4361EE).withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4361EE).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.event,
                                size: 20,
                                color: Color(0xFF4361EE),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visit Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  diagnosis.date,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(diagnosis.status)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: _getStatusColor(diagnosis.status)),
                          ),
                          child: Text(
                            diagnosis.status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(diagnosis.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medical_information,
                            size: 20,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Condition',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                diagnosis.condition,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (diagnosis.details != null &&
                        diagnosis.details!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diagnosis.details!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (diagnosis.vitals != null) ...[
                      Text(
                        'Vitals',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVitalsGrid(diagnosis.vitals!),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/diagnosis_details',
                              arguments: {
                                'patient': patient,
                                'diagnosis': diagnosis,
                              },
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4361EE),
                            side: const BorderSide(color: Color(0xFF4361EE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 100 * index),
              );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildVitalsGrid(Vitals vitals) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildVitalChip(
          Icons.favorite_outline,
          'BP: ${vitals.bloodPressure}',
          Colors.red.shade100,
          Colors.red.shade700,
        ),
        _buildVitalChip(
          Icons.monitor_heart_outlined,
          'HR: ${vitals.heartRate} bpm',
          Colors.purple.shade100,
          Colors.purple.shade700,
        ),
        _buildVitalChip(
          Icons.thermostat_outlined,
          'Temp: ${vitals.temperature}°F',
          Colors.orange.shade100,
          Colors.orange.shade700,
        ),
      ],
    );
  }

  Widget _buildVitalChip(
    IconData icon,
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    ).animate().scale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
  }

  Widget _buildDocumentsTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_open,
                color: const Color(0xFF4361EE),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Patient Documents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
          const SizedBox(height: 16),
          // Patient Photo Card
          _buildPhotoCard().animate().fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 100),
              ),
          const SizedBox(height: 12),
          // Patient ID Proof Card
          _buildIdProofCard().animate().fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 200),
              ),
          const SizedBox(height: 24),

          Row(
            children: [
              Icon(
                Icons.description,
                color: const Color(0xFF4361EE),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Additional Documents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ).animate().fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 300),
              ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPatientData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _documents.isEmpty
                      ? ListView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.1),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    size: 80,
                                    color: Colors.grey.shade300,
                                  ).animate().scale(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        curve: Curves.elasticOut,
                                      ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No documents uploaded yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ).animate().fadeIn(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        delay:
                                            const Duration(milliseconds: 300),
                                      ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _pickAndUploadDocument,
                                    icon: const Icon(Icons.upload_file,
                                        color: Colors.white),
                                    label: const Text('Upload Document',
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4361EE),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 2,
                                    ),
                                  ).animate().fadeIn(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        delay:
                                            const Duration(milliseconds: 600),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final document = _documents[index];
                            return _buildDocumentCard(document)
                                .animate()
                                .fadeIn(
                                  duration: const Duration(milliseconds: 300),
                                  delay: Duration(milliseconds: 100 * index),
                                );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(PatientDocument document) {
    IconData iconData;
    Color iconColor;

    // Determine icon based on document type
    final String docType = document.type.toLowerCase();
    if (docType.contains('medical') || docType.contains('report')) {
      iconData = Icons.description;
      iconColor = Colors.blue.shade700;
    } else if (docType.contains('prescription')) {
      iconData = Icons.medication;
      iconColor = Colors.green.shade700;
    } else if (docType.contains('lab') || docType.contains('result')) {
      iconData = Icons.science;
      iconColor = Colors.purple.shade700;
    } else if (docType.contains('insurance')) {
      iconData = Icons.health_and_safety;
      iconColor = Colors.red.shade700;
    } else if (docType.contains('consent') || docType.contains('form')) {
      iconData = Icons.assignment;
      iconColor = Colors.orange.shade700;
    } else if (docType.contains('image') ||
        docType.contains('jpg') ||
        docType.contains('jpeg') ||
        docType.contains('png')) {
      iconData = Icons.image;
      iconColor = Colors.blue.shade700;
    } else if (docType.contains('pdf')) {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red.shade700;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = Colors.grey.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          iconData,
          color: iconColor,
          size: 36,
        ),
        title: Text(
          document.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => _viewDocument(document),
              tooltip: 'View Document',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showRenameDocumentDialog(document),
              tooltip: 'Rename Document',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadDocument(document),
              tooltip: 'Download Document',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDeleteDocument(document),
              tooltip: 'Delete Document',
            ),
          ],
        ),
        onTap: () => _viewDocument(document),
      ),
    );
  }

  // ---------------------------------------------------------

  Widget _buildPhotoCard() {
    final bool hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: hasPhoto ? Colors.green.shade200 : Colors.grey.shade200,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasPhoto ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.photo_camera,
                color: hasPhoto ? Colors.green.shade600 : Colors.grey.shade400,
                size: 24,
              ),
            ),
            title: const Text('Patient Photo'),
            subtitle: Text(
              hasPhoto ? 'Uploaded' : 'Not uploaded',
              style: TextStyle(
                color: hasPhoto ? Colors.green.shade600 : Colors.grey.shade600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPhoto)
                  IconButton(
                    icon: const Icon(
                      Icons.visibility,
                      color: Color(0xFF4361EE),
                    ),
                    onPressed: () => _viewImage(_photoUrl),
                    tooltip: 'View Photo',
                  ),
                IconButton(
                  icon: Icon(
                    hasPhoto ? Icons.edit : Icons.upload_file,
                    color: const Color(0xFF4361EE),
                  ),
                  onPressed: () => _pickAndUploadFile('photo'),
                  tooltip: hasPhoto ? 'Update Photo' : 'Upload Photo',
                ),
              ],
            ),
          ),
          if (hasPhoto)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => _viewImage(_photoUrl),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _photoUrl!,
                      headers: {
                        'Authorization':
                            'Bearer ${_apiService.getToken() ?? ''}',
                        'Cache-Control': 'no-cache',
                        'Pragma': 'no-cache',
                      },
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // Force network image refresh by adding timestamp
                      key: ValueKey(
                          'photo_${DateTime.now().millisecondsSinceEpoch}'),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade400,
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                const Text('Failed to load image'),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _refreshPatientData(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4361EE),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No photo uploaded',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _pickAndUploadFile('photo'),
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Upload Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4361EE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdProofCard() {
    final bool hasIdProof = _idProofUrl != null && _idProofUrl!.isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: hasIdProof ? Colors.green.shade200 : Colors.grey.shade200,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    hasIdProof ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.badge,
                color:
                    hasIdProof ? Colors.green.shade600 : Colors.grey.shade400,
                size: 24,
              ),
            ),
            title: const Text('ID Proof'),
            subtitle: Text(
              hasIdProof ? 'Uploaded' : 'Not uploaded',
              style: TextStyle(
                color:
                    hasIdProof ? Colors.green.shade600 : Colors.grey.shade600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIdProof)
                  IconButton(
                    icon: const Icon(
                      Icons.visibility,
                      color: Color(0xFF4361EE),
                    ),
                    onPressed: () => _viewImage(_idProofUrl),
                    tooltip: 'View ID Proof',
                  ),
                IconButton(
                  icon: Icon(
                    hasIdProof ? Icons.edit : Icons.upload_file,
                    color: const Color(0xFF4361EE),
                  ),
                  onPressed: () => _pickAndUploadFile('idProof'),
                  tooltip: hasIdProof ? 'Update ID Proof' : 'Upload ID Proof',
                ),
              ],
            ),
          ),
          if (hasIdProof)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => _viewImage(_idProofUrl),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _idProofUrl!,
                      headers: {
                        'Authorization':
                            'Bearer ${_apiService.getToken() ?? ''}',
                        'Cache-Control': 'no-cache',
                        'Pragma': 'no-cache',
                      },
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // Force network image refresh by adding timestamp
                      key: ValueKey(
                          'idproof_${DateTime.now().millisecondsSinceEpoch}'),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade400,
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                const Text('Failed to load image'),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _refreshPatientData(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4361EE),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ID proof uploaded',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _pickAndUploadFile('idProof'),
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Upload ID Proof'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4361EE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<InfoItem> items,
      {required IconData icon, required Color color}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _buildInfoItem(item)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '${item.label}:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the prescriptions tab
  Widget _buildPrescriptionsTab() {
    return RefreshIndicator(
      onRefresh: _loadPatientPrescriptions,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.medication,
                            color: Colors.purple.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Prescriptions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Total: ${_prescriptions.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 300)),
                    const Divider(height: 32),
                    if (_prescriptions.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ).animate().scale(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.elasticOut,
                                ),
                            const SizedBox(height: 16),
                            Text(
                              'No prescriptions found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ).animate().fadeIn(
                                  duration: const Duration(milliseconds: 500),
                                  delay: const Duration(milliseconds: 300),
                                ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _prescriptions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 32),
                        itemBuilder: (context, index) {
                          final prescription = _prescriptions[index];
                          return _buildPrescriptionCard(prescription, index);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a card for each prescription
  Widget _buildPrescriptionCard(Prescription prescription, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(prescription.date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Diagnosis: ${prescription.diagnosis}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Doctor ID: ${prescription.doctorId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.download,
                size: 16,
                color: Colors.white,
              ),
              label:
                  const Text('Get PDF', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                ),
              ),
              onPressed: () => _generatePrescriptionPDF(prescription.id),
            ),
          ],
        ).animate().fadeIn(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: 100 * index),
            ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.medication,
                    size: 16,
                    color: Colors.purple.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Medications',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...prescription.medications.map((med) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.medicine,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              med.dosage,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              med.duration,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (med.notes != null && med.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Notes: ${med.notes}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              if (prescription.clinicalNotes != null &&
                  prescription.clinicalNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note,
                            size: 16,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Clinical Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prescription.clinicalNotes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: 200 * index),
            ),
      ],
    );
  }
}

class InfoItem {
  final String label;
  final String value;

  InfoItem({required this.label, required this.value});
}
