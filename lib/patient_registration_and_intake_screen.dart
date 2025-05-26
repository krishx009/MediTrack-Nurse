import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'models/patient.dart';
import 'services/api_service.dart';

class PatientRegistrationAndIntakeScreen extends StatefulWidget {
  const PatientRegistrationAndIntakeScreen({Key? key}) : super(key: key);

  @override
  State<PatientRegistrationAndIntakeScreen> createState() =>
      _PatientRegistrationAndIntakeScreenState();
}

class _PatientRegistrationAndIntakeScreenState
    extends State<PatientRegistrationAndIntakeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Registration form controllers
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _addressController = TextEditingController();
  final _medicalHistoryController = TextEditingController();

  // Intake form controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bpController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _chiefComplaintController = TextEditingController();

  final ApiService _apiService = ApiService();

  // Registration state
  String _selectedGender = 'Male';
  bool _isLoading = false;
  String? _photoPath;
  String? _idProofPath;
  File? _photoFile;
  File? _idProofFile;
  dynamic _photoWebFile;
  dynamic _idProofWebFile;
  DateTime? _selectedDate;

  // Section expansion states
  bool _personalInfoExpanded = true;
  bool _medicalHistoryExpanded = true;
  bool _vitalSignsExpanded = true;
  bool _complaintExpanded = true;

  // Animation delays for staggered appearance
  final List<int> _sectionDelays = [100, 200, 300, 400];

  // Intake state
  double _bmi = 0.0;
  String _bmiCategory = '';

  // Theme colors - Modern palette
  final Color _primaryColor = Color(0xFF6366F1); // Indigo
  final Color _secondaryColor = Color(0xFF4F46E5); // Darker indigo
  final Color _accentColor = Color(0xFFEC4899); // Pink
  final Color _backgroundColor = Color(0xFFF9FAFB); // Light gray
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF1F2937); // Dark gray
  final Color _lightTextColor = Color(0xFF6B7280); // Medium gray
  final Color _successColor = Color(0xFF10B981); // Green
  final Color _warningColor = Color(0xFFF59E0B); // Amber
  final Color _dangerColor = Color(0xFFEF4444); // Red
  final Color _shadowColor = Color(0xFFE5E7EB); // Light gray for shadows

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    // Default values for intake form
    _weightController.text = '70';
    _heightController.text = '170';
    _bpController.text = '120/80';
    _heartRateController.text = '72';
    _temperatureController.text = '98.6';

    // Add listeners to calculate BMI when height or weight changes
    _weightController.addListener(_calculateBMI);
    _heightController.addListener(_calculateBMI);

    // Calculate BMI initially
    _calculateBMI();
  }

  @override
  void dispose() {
    // Dispose animation controller
    _animationController.dispose();

    // Dispose registration controllers
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
    _medicalHistoryController.dispose();

    // Dispose intake controllers
    _weightController.removeListener(_calculateBMI);
    _heightController.removeListener(_calculateBMI);
    _weightController.dispose();
    _heightController.dispose();
    _bpController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _chiefComplaintController.dispose();

    // Dispose scroll controller
    _scrollController.dispose();

    super.dispose();
  }

  void _calculateBMI() {
    if (_weightController.text.isNotEmpty &&
        _heightController.text.isNotEmpty) {
      try {
        double weight = double.parse(_weightController.text);
        double heightCm = double.parse(_heightController.text);

        // Convert height from cm to meters
        double heightM = heightCm / 100;

        // Calculate BMI: weight (kg) / (height (m) * height (m))
        double bmi = weight / (heightM * heightM);

        // Determine BMI category
        String category;
        if (bmi < 18.5) {
          category = 'Underweight';
        } else if (bmi < 25) {
          category = 'Normal';
        } else if (bmi < 30) {
          category = 'Overweight';
        } else {
          category = 'Obese';
        }

        setState(() {
          _bmi = bmi;
          _bmiCategory = category;
        });
      } catch (e) {
        // Handle parsing errors
        setState(() {
          _bmi = 0.0;
          _bmiCategory = '';
        });
      }
    }
  }

  // Method to pick image from camera or gallery
  Future<void> _pickImage(ImageSource source, bool isPhoto) async {
    if (kIsWeb) {
      await _pickImageWeb(isPhoto);
    } else {
      await _pickImageMobile(source, isPhoto);
    }
  }

  // Mobile implementation for picking images
  Future<void> _pickImageMobile(ImageSource source, bool isPhoto) async {
    try {
      if (source == ImageSource.camera) {
        // Camera capture with retake functionality
        bool captureComplete = false;

        while (!captureComplete) {
          final ImagePicker picker = ImagePicker();
          // Set maxWidth and maxHeight to ensure reasonable file size
          final XFile? photo = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 800, // Reduced for better performance
            maxHeight: 800, // Reduced for better performance
            imageQuality: 80, // Slightly reduced quality for better performance
            preferredCameraDevice:
                CameraDevice.rear, // Use rear camera by default
          );

          if (photo == null) {
            // User cancelled the camera
            captureComplete = true;
            return;
          }

          // Verify the file exists and is readable
          File imageFile = File(photo.path);
          if (!await imageFile.exists()) {
            print('Image file does not exist: ${photo.path}');
            _showErrorSnackBar('Error: Image file not found after capture');
            captureComplete = true;
            return;
          }

          try {
            // Verify file can be read and get file info
            final bytes = await imageFile.readAsBytes();
            if (bytes.isEmpty) {
              print('Image file is empty: ${photo.path}');
              _showErrorSnackBar('Error: Captured image is empty');
              captureComplete = true;
              return;
            }

            // Get file info for debugging
            final fileSize = await imageFile.length();
            final fileExtension = imageFile.path.split('.').last.toLowerCase();
            print('Image captured successfully:');
            print('- Path: ${photo.path}');
            print('- Size: ${fileSize} bytes');
            print('- Extension: $fileExtension');
          } catch (e) {
            print('Error reading image file: $e');
            _showErrorSnackBar('Error reading captured image: $e');
            captureComplete = true;
            return;
          }

          // Show confirmation dialog
          bool? confirmed = await _showImageConfirmationDialog(imageFile);

          if (confirmed == null) {
            // Dialog dismissed
            captureComplete = true;
          } else if (confirmed) {
            // User confirmed the photo - create a copy of the file to ensure it's properly saved
            try {
              // Create a new file with a unique name in the app's temporary directory
              final tempDir = await getTemporaryDirectory();
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final newFileName = isPhoto
                  ? 'patient_photo_$timestamp.jpg'
                  : 'id_proof_$timestamp.jpg';
              final newFilePath = '${tempDir.path}/$newFileName';

              // Copy the file to ensure it's properly saved
              final bytes = await imageFile.readAsBytes();
              final newFile = File(newFilePath);
              await newFile.writeAsBytes(bytes);

              // Verify the new file exists and has content
              if (!await newFile.exists() || await newFile.length() == 0) {
                throw Exception('Failed to create a valid copy of the image');
              }

              print('Created copy of image at: $newFilePath');

              setState(() {
                if (isPhoto) {
                  _photoFile = newFile;
                  _photoPath = newFilePath;
                  print('Patient photo set: $newFilePath');
                } else {
                  _idProofFile = newFile;
                  _idProofPath = newFilePath;
                  print('ID proof set: $newFilePath');
                }
              });
            } catch (e) {
              print('Error creating copy of image file: $e');
              _showErrorSnackBar('Error saving image: $e');
              captureComplete = true;
              return;
            }

            captureComplete = true;
          }
          // If confirmed is false, the loop continues and camera reopens for retake
        }
      } else {
        // For gallery, use existing file_selector implementation
        const XTypeGroup typeGroup = XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png'],
        );

        final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

        if (file != null) {
          // Verify the file exists and is readable
          File imageFile = File(file.path);
          if (!await imageFile.exists()) {
            print('Selected image file does not exist: ${file.path}');
            _showErrorSnackBar('Error: Selected image file not found');
            return;
          }

          try {
            // Create a copy of the selected file in the app's temporary directory
            final tempDir = await getTemporaryDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileExtension = file.path.split('.').last.toLowerCase();
            final newFileName = isPhoto
                ? 'patient_photo_$timestamp.$fileExtension'
                : 'id_proof_$timestamp.$fileExtension';
            final newFilePath = '${tempDir.path}/$newFileName';

            // Copy the file to ensure it's properly saved
            final bytes = await imageFile.readAsBytes();
            if (bytes.isEmpty) {
              print('Selected image file is empty: ${file.path}');
              _showErrorSnackBar('Error: Selected image is empty');
              return;
            }

            final newFile = File(newFilePath);
            await newFile.writeAsBytes(bytes);

            // Verify the new file exists and has content
            if (!await newFile.exists() || await newFile.length() == 0) {
              throw Exception('Failed to create a valid copy of the image');
            }

            print('Created copy of selected image at: $newFilePath');
            print('Image size: ${await newFile.length()} bytes');

            setState(() {
              if (isPhoto) {
                _photoFile = newFile;
                _photoPath = newFilePath;
                print('Patient photo set from gallery: $newFilePath');
              } else {
                _idProofFile = newFile;
                _idProofPath = newFilePath;
                print('ID proof set from gallery: $newFilePath');
              }
            });
          } catch (e) {
            print('Error processing selected image file: $e');
            _showErrorSnackBar('Error processing selected image: $e');
            return;
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  // Web implementation for picking images
  Future<void> _pickImageWeb(bool isPhoto) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          if (isPhoto) {
            _photoWebFile = bytes;
            _photoPath = file.name;
            print('Photo selected: ${file.name}, size: ${bytes.length} bytes');
          } else {
            _idProofWebFile = bytes;
            _idProofPath = file.name;
            print(
                'ID Proof selected: ${file.name}, size: ${bytes.length} bytes');
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  void _viewImage(String? imagePath) {
    if (imagePath == null) return;

    if (kIsWeb) {
      _viewImageWeb(imagePath);
    } else {
      _viewImageMobile(imagePath);
    }
  }

  // Mobile implementation for viewing images
  void _viewImageMobile(String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Image Preview'),
              backgroundColor: _primaryColor,
              automaticallyImplyLeading: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Hero(
                tag: 'image-$imagePath',
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Web implementation for viewing images
  void _viewImageWeb(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: _successColor),
            SizedBox(width: 10),
            Text('File Selected', style: TextStyle(color: _textColor)),
          ],
        ),
        content: Text('File: $imagePath has been selected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _selectedDate ?? DateTime(now.year - 20, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  int _calculateAge(String dateString) {
    try {
      if (_selectedDate != null) {
        final today = DateTime.now();
        int age = today.year - _selectedDate!.year;
        if (today.month < _selectedDate!.month ||
            (today.month == _selectedDate!.month &&
                today.day < _selectedDate!.day)) {
          age--;
        }
        return age;
      }

      final parts = dateString.split('/');
      if (parts.length != 3) return 0;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final birthday = DateTime(year, month, day);
      final today = DateTime.now();

      int age = today.year - birthday.year;
      if (today.month < birthday.month ||
          (today.month == birthday.month && today.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  // Submit both patient registration and visit data
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Step 1: Register the patient
        final patientData = {
          'name': _nameController.text,
          'age': _calculateAge(_dobController.text),
          'gender': _selectedGender,
          'contact': _phoneController.text,
          'emergencyContact': _emergencyContactController.text,
          'address': _addressController.text,
          'medicalHistory': _medicalHistoryController.text,
        };

        // Register patient
        final result = await _apiService.registerPatient(patientData);

        if (!result['success']) {
          setState(() {
            _isLoading = false;
          });

          _showErrorSnackBar('Registration failed: ${result['message']}');
          return;
        }

        final patientId =
            result['_id']; // Use _id instead of patientId for uploads

        // Step 2: Upload files if available
        if (_photoWebFile != null ||
            _idProofWebFile != null ||
            _photoFile != null ||
            _idProofFile != null) {
          print('Uploading files for patient ID: $patientId');

          try {
            final uploadResult = await _apiService.uploadPatientFiles(
                patientId,
                kIsWeb ? _photoWebFile : _photoFile,
                kIsWeb ? _idProofWebFile : _idProofFile);

            if (!uploadResult['success']) {
              setState(() {
                _isLoading = false;
              });

              _showErrorSnackBar(
                  'File upload failed: ${uploadResult['message']}');
              return;
            } else {
              print('Files uploaded successfully: ${uploadResult['message']}');
              // If we have patient info in the result, we can use it
              if (uploadResult.containsKey('patient')) {
                print('Patient data after upload: ${uploadResult['patient']}');
              }
            }
          } catch (e) {
            print('Error during file upload: $e');
            setState(() {
              _isLoading = false;
            });

            _showErrorSnackBar('Error during file upload: $e');
            return;
          }
        } else {
          print('No files to upload');
        }

        // Step 3: Add visit data
        final visitData = {
          'patientId': patientId,
          'date': DateTime.now().toIso8601String(),
          'weight': double.parse(_weightController.text),
          'height': double.parse(_heightController.text),
          'BP': _bpController.text,
          'heartRate': int.parse(_heartRateController.text),
          'temperature': double.parse(_temperatureController.text),
          'chiefComplaint': _chiefComplaintController.text,
          'bmi': _bmi.toStringAsFixed(1),
          'bmiCategory': _bmiCategory,
        };

        // Add visit
        final visitResult = await _apiService.addPatientVisit(visitData);

        setState(() {
          _isLoading = false;
        });

        if (visitResult['success']) {
          // Show success animation
          _showSuccessDialog();
        } else {
          _showErrorSnackBar(
              'Failed to save visit data: ${visitResult['message']}');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        _showErrorSnackBar('An error occurred: $e');
      }
    } else {
      // Form validation failed - scroll to the top to show errors
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // Shake animation for error feedback
      _animateErrorShake();
    }
  }

  void _animateErrorShake() {
    // Create a temporary controller for the shake animation
    final shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    final shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: shakeController,
        curve: Curves.elasticIn,
      ),
    );

    shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        shakeController.dispose();
      }
    });

    shakeController.forward();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 5,
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _successColor.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: _successColor,
                        size: 80,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Patient registered and visit data saved successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: _lightTextColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to previous screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      elevation: 2,
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    physics: BouncingScrollPhysics(),
                    children: [
                      _buildPatientHeader(),
                      SizedBox(height: 24),

                      // Animated sections with staggered delays
                      _buildAnimatedSection(
                        index: 0,
                        expanded: _personalInfoExpanded,
                        onToggle: () => setState(() =>
                            _personalInfoExpanded = !_personalInfoExpanded),
                        title: 'Personal Information',
                        icon: Icons.person,
                        child: _buildPersonalInfoSection(),
                      ),
                      SizedBox(height: 16),

                      _buildAnimatedSection(
                        index: 1,
                        expanded: _medicalHistoryExpanded,
                        onToggle: () => setState(() =>
                            _medicalHistoryExpanded = !_medicalHistoryExpanded),
                        title: 'Medical History',
                        icon: Icons.medical_information,
                        child: _buildMedicalHistorySection(),
                      ),
                      SizedBox(height: 16),

                      _buildAnimatedSection(
                        index: 2,
                        expanded: _vitalSignsExpanded,
                        onToggle: () => setState(
                            () => _vitalSignsExpanded = !_vitalSignsExpanded),
                        title: 'Vital Signs',
                        icon: Icons.favorite,
                        child: _buildVitalSignsSection(),
                      ),
                      SizedBox(height: 16),

                      _buildAnimatedSection(
                        index: 3,
                        expanded: _complaintExpanded,
                        onToggle: () => setState(
                            () => _complaintExpanded = !_complaintExpanded),
                        title: 'Chief Complaint',
                        icon: Icons.note_add,
                        child: _buildComplaintSection(),
                      ),

                      SizedBox(
                          height: 100), // Extra space for the floating button
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildSubmitButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: _textColor),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Text(
            'Patient Registration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.help_outline, color: _primaryColor),
            onPressed: () {
              // Show help info
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text('Help Information'),
                  content: SingleChildScrollView(
                    child: Text(
                      'This form is used to register new patients and record their initial visit details. Complete all sections to save the patient record.\n\n'
                      '• Personal Information: Enter basic patient details\n'
                      '• Medical History: Record medical history and upload documents\n'
                      '• Vital Signs: Enter health metrics\n'
                      '• Chief Complaint: Record the main health concern',
                      style: TextStyle(
                        color: _lightTextColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                      style:
                          TextButton.styleFrom(foregroundColor: _primaryColor),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Patient Registration',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Complete the form to register a new patient',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: _calculateFormProgress()),
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${(value * 100).toInt()}% Complete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  double _calculateFormProgress() {
    // Count filled fields
    int filledFields = 0;
    int totalFields = 11; // Total required fields

    if (_nameController.text.isNotEmpty) filledFields++;
    if (_dobController.text.isNotEmpty) filledFields++;
    if (_phoneController.text.isNotEmpty) filledFields++;
    if (_emergencyContactController.text.isNotEmpty) filledFields++;
    if (_addressController.text.isNotEmpty) filledFields++;
    if (_medicalHistoryController.text.isNotEmpty) filledFields++;
    if (_weightController.text.isNotEmpty) filledFields++;
    if (_heightController.text.isNotEmpty) filledFields++;
    if (_bpController.text.isNotEmpty) filledFields++;
    if (_heartRateController.text.isNotEmpty) filledFields++;
    if (_temperatureController.text.isNotEmpty) filledFields++;

    return filledFields / totalFields;
  }

  Widget _buildAnimatedSection({
    required int index,
    required bool expanded,
    required VoidCallback onToggle,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Section header with toggle
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: _primaryColor,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: expanded ? 0.5 : 0),
                            duration: Duration(milliseconds: 300),
                            builder: (context, value, _) {
                              return Transform.rotate(
                                angle: value * 3.14159 * 2,
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: _primaryColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Animated content
                  AnimatedCrossFade(
                    firstChild: Container(height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                      ),
                      child: child,
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOut,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter patient name';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildDateField(),
        SizedBox(height: 16),
        _buildGenderSelector(),
        SizedBox(height: 16),
        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter phone number';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildInputField(
          controller: _emergencyContactController,
          label: 'Emergency Contact',
          icon: Icons.contact_phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter emergency contact';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildInputField(
          controller: _addressController,
          label: 'Address',
          icon: Icons.home,
          maxLines: 2,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMedicalHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          controller: _medicalHistoryController,
          label: 'Medical History',
          icon: Icons.history_edu,
          maxLines: 4,
          hintText:
              'Enter any pre-existing conditions, allergies, surgeries, or medications...',
        ),
        SizedBox(height: 24),
        Text(
          'Upload Documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDocumentUploadCard(
                title: 'Patient Photo',
                icon: Icons.person,
                path: _photoPath,
                onUpload: () => _showImagePickerModal(true),
                onView: () => _viewImage(_photoPath),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildDocumentUploadCard(
                title: 'ID Proof',
                icon: Icons.badge,
                path: _idProofPath,
                onUpload: () => _showImagePickerModal(false),
                onView: () => _viewImage(_idProofPath),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalSignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date and time display
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(DateTime.now()),
                    style: TextStyle(
                      color: _lightTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Height and weight
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _weightController,
                label: 'Weight (kg)',
                icon: Icons.fitness_center,
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildInputField(
                controller: _heightController,
                label: 'Height (cm)',
                icon: Icons.height,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),

        // BMI Card with animation
        if (_bmi > 0)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getBmiColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.monitor_weight,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BMI: ${_bmi.toStringAsFixed(1)} kg/m²',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _bmiCategory,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: 20),

        // Other vital signs
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _bpController,
                label: 'Blood Pressure',
                icon: Icons.speed,
                hintText: '120/80',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildInputField(
                controller: _heartRateController,
                label: 'Heart Rate (bpm)',
                icon: Icons.favorite,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        _buildInputField(
          controller: _temperatureController,
          label: 'Temperature (°F)',
          icon: Icons.thermostat,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildComplaintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          controller: _chiefComplaintController,
          label: 'Chief Complaint',
          icon: Icons.medical_services,
          maxLines: 5,
          hintText:
              'Describe patient\'s main health concerns, symptoms, and their duration...',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter chief complaint';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: _primaryColor.withOpacity(0.4),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_alt, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Register Patient',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.97, end: 1.0),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 16,
            color: _textColor,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _primaryColor, size: 20),
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 60, minHeight: 50),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _dangerColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
          onTap: () {
            // Subtle animation when field is tapped
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.97, end: 1.0),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextFormField(
          controller: _dobController,
          readOnly: true,
          onTap: () => _selectDate(context),
          style: TextStyle(
            fontSize: 16,
            color: _textColor,
          ),
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.calendar_today, color: _primaryColor, size: 20),
              ),
            ),
            suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select date of birth';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Gender',
            style: TextStyle(
              fontSize: 14,
              color: _lightTextColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildGenderOption('Male', Icons.male),
              SizedBox(width: 12),
              _buildGenderOption('Female', Icons.female),
              SizedBox(width: 12),
              _buildGenderOption('Other', Icons.person),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = gender;
          });
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
              begin: isSelected ? 0.9 : 1.0, end: isSelected ? 1.0 : 0.95),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _primaryColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  gender,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required IconData icon,
    required String? path,
    required VoidCallback onUpload,
    required VoidCallback onView,
  }) {
    final bool hasFile = path != null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              hasFile ? _successColor.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                hasFile ? _successColor.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onUpload,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasFile
                          ? _successColor.withOpacity(0.1)
                          : _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasFile ? Icons.check_circle : icon,
                      color: hasFile ? _successColor : _primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    hasFile ? path!.split('/').last : 'Tap to upload',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _lightTextColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (hasFile)
                    TextButton(
                      onPressed: onView,
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryColor,
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImagePickerModal(bool isPhoto) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageMobile(ImageSource.camera, isPhoto);
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageMobile(ImageSource.gallery, isPhoto);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.9, end: 1.0),
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _primaryColor,
                size: 28,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBmiColor() {
    if (_bmiCategory == 'Underweight') {
      return _warningColor;
    } else if (_bmiCategory == 'Normal') {
      return _successColor;
    } else if (_bmiCategory == 'Overweight') {
      return _warningColor;
    } else {
      return _dangerColor;
    }
  }

  // Show a dialog to confirm the captured image
  Future<bool?> _showImageConfirmationDialog(File imageFile) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Confirm Photo'),
                backgroundColor: _primaryColor,
                automaticallyImplyLeading: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Use this photo?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: _dangerColor,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Retake'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check),
                          SizedBox(width: 8),
                          Text('Use Photo'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
