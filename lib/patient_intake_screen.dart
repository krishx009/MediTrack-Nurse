import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models/patient.dart';
import 'services/api_service.dart';

class PatientIntakeScreen extends StatefulWidget {
  const PatientIntakeScreen({Key? key}) : super(key: key);

  @override
  State<PatientIntakeScreen> createState() => _PatientIntakeScreenState();
}

class _PatientIntakeScreenState extends State<PatientIntakeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  // Form controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bpController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _chiefComplaintController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  late Patient patient;
  bool isNewVisit = true;
  double _bmi = 0.0;
  String _bmiCategory = '';
  bool _showSuccessAnimation = false;

  // Colors
  final Color _primaryColor = const Color(0xFF3366FF);
  final Color _accentColor = const Color(0xFF00CCBB);
  final Color _backgroundColor = const Color(0xFFF9FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3142);

  // BMI color mapping
  final Map<String, Color> _bmiColors = {
    'Underweight': const Color(0xFF2196F3),
    'Normal': const Color(0xFF4CAF50),
    'Overweight': const Color(0xFFFFA000),
    'Obese': const Color(0xFFF44336),
    '': Colors.grey.shade700,
  };

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // Default values
    _weightController.text = '70';
    _heightController.text = '170';
    _bpController.text = '120/80';
    _heartRateController.text = '72';
    _temperatureController.text = '98.6';

    // Add listeners to calculate BMI when height or weight changes
    _weightController.addListener(_calculateBMI);
    _heightController.addListener(_calculateBMI);

    // Get the patient from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      patient = args['patient'];
      isNewVisit = args['isNewVisit'] ?? true;

      // Pre-fill form if editing an existing visit
      if (!isNewVisit && args.containsKey('visit')) {
        final visit = args['visit'];
        _weightController.text = visit['weight'].toString();
        _heightController.text = visit['height'].toString();
        _bpController.text = visit['BP'];
        _heartRateController.text = visit['heartRate'].toString();
        _temperatureController.text = visit['temperature'].toString();
        _chiefComplaintController.text = visit['chiefComplaint'] ?? '';

        // Calculate BMI for existing visit
        _calculateBMI();
      }
    });
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

  @override
  void dispose() {
    _animationController.dispose();
    _weightController.removeListener(_calculateBMI);
    _heightController.removeListener(_calculateBMI);
    _weightController.dispose();
    _heightController.dispose();
    _bpController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _chiefComplaintController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Prepare visit data
      final visitData = {
        'patientId': patient.id,
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
      final result = await _apiService.addPatientVisit(visitData);

      if (result['success']) {
        setState(() {
          _isLoading = false;
          _showSuccessAnimation = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Patient visit data saved successfully!'),
              ],
            ),
            backgroundColor: _accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Delay navigation to show animation
        Future.delayed(const Duration(milliseconds: 1500), () {
          Navigator.pop(context);
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Failed to save data: ${result['message']}'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          isNewVisit ? 'New Patient Visit' : 'Edit Visit',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeInAnimation,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientInfoCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Visit Information', Icons.calendar_today),
                    const SizedBox(height: 12),
                    _buildDateTimeSection(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Vital Signs', Icons.favorite),
                    const SizedBox(height: 12),
                    _buildVitalsCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Chief Complaint', Icons.description),
                    const SizedBox(height: 12),
                    _buildComplaintField(),
                    const SizedBox(height: 40),
                    _buildSubmitButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_primaryColor),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saving patient data...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showSuccessAnimation)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: _accentColor,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Success!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Patient visit recorded'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: _primaryColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: _primaryColor,
                child: Text(
                  ModalRoute.of(context)?.settings.arguments != null
                      ? (ModalRoute.of(context)!.settings.arguments
                              as Map<String, dynamic>)['patient']
                          .name
                          .substring(0, 1)
                      : 'P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              title: Text(
                ModalRoute.of(context)?.settings.arguments != null
                    ? (ModalRoute.of(context)!.settings.arguments
                            as Map<String, dynamic>)['patient']
                        .name
                    : 'Patient Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _textColor,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  ModalRoute.of(context)?.settings.arguments != null
                      ? '${(ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>)['patient'].age} years • ${(ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>)['patient'].gender}'
                      : 'Age • Gender',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              trailing: ElevatedButton.icon(
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Details'),
                onPressed: () {
                  _showPatientDetailsDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  foregroundColor: _primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (ModalRoute.of(context)?.settings.arguments != null)
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(
                      icon: Icons.badge,
                      label: 'ID',
                      value: (ModalRoute.of(context)!.settings.arguments
                              as Map<String, dynamic>)['patient']
                          .patientId,
                    ),
                    _buildInfoChip(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: (ModalRoute.of(context)!.settings.arguments
                              as Map<String, dynamic>)['patient']
                          .phoneNumber
                          .toString()
                          .substring(
                              0,
                              min(
                                  10,
                                  (ModalRoute.of(context)!.settings.arguments
                                          as Map<String, dynamic>)['patient']
                                      .phoneNumber
                                      .toString()
                                      .length)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  Widget _buildInfoChip(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: _primaryColor,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final formattedTime = DateFormat('h:mm a').format(now);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.event,
                color: _primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isNewVisit ? _accentColor : Colors.grey.shade500,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isNewVisit ? 'NEW VISIT' : 'FOLLOW-UP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildVitalField(
                    controller: _weightController,
                    label: 'Weight',
                    keyboardType: TextInputType.number,
                    suffixText: 'kg',
                    prefixIcon: Icons.monitor_weight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVitalField(
                    controller: _heightController,
                    label: 'Height',
                    keyboardType: TextInputType.number,
                    suffixText: 'cm',
                    prefixIcon: Icons.height,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // BMI Display
            if (_bmi > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bmiColors[_bmiCategory]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _bmiColors[_bmiCategory]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _bmiColors[_bmiCategory],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.device_thermostat,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Body Mass Index (BMI)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _bmi.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _bmiColors[_bmiCategory],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _bmiColors[_bmiCategory],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _bmiCategory,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVitalField(
                    controller: _bpController,
                    label: 'Blood Pressure',
                    hintText: '120/80',
                    prefixIcon: Icons.favorite,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVitalField(
                    controller: _heartRateController,
                    label: 'Heart Rate',
                    keyboardType: TextInputType.number,
                    suffixText: 'bpm',
                    prefixIcon: Icons.timeline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVitalField(
              controller: _temperatureController,
              label: 'Temperature',
              keyboardType: TextInputType.number,
              suffixText: '°F',
              prefixIcon: Icons.thermostat,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    String? suffixText,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffixText,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: _primaryColor,
                size: 20,
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primaryColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      style: TextStyle(
        color: _textColor,
        fontWeight: FontWeight.w500,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildComplaintField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _chiefComplaintController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Describe reason for visit',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                    style: TextStyle(
                      color: _textColor,
                      height: 1.5,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter chief complaint';
                      }
                      return null;
                    },
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.format_bold),
                          onPressed: () {
                            // Formatting action
                          },
                          iconSize: 20,
                          color: Colors.grey.shade700,
                          tooltip: 'Bold',
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_italic),
                          onPressed: () {
                            // Formatting action
                          },
                          iconSize: 20,
                          color: Colors.grey.shade700,
                          tooltip: 'Italic',
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          onPressed: () {
                            // Formatting action
                          },
                          iconSize: 20,
                          color: Colors.grey.shade700,
                          tooltip: 'Bullet list',
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.mic, size: 16),
                          label: const Text('Voice'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Voice to text activated'),
                                backgroundColor: _accentColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isNewVisit
                        ? 'Submit Patient Visit'
                        : 'Update Patient Visit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward),
                ],
              ),
      ),
    );
  }

  void _showPatientDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Patient Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPatientDetailRow(
                icon: Icons.badge_outlined,
                title: 'Patient ID',
                value: patient.patientId,
              ),
              const Divider(height: 24),
              _buildPatientDetailRow(
                icon: Icons.phone_outlined,
                title: 'Phone Number',
                value: patient.phoneNumber,
              ),
              const Divider(height: 24),
              _buildPatientDetailRow(
                icon: Icons.contact_phone_outlined,
                title: 'Emergency Contact',
                value: patient.emergencyContact,
              ),
              const Divider(height: 24),
              _buildPatientDetailRow(
                icon: Icons.history_edu_outlined,
                title: 'Medical History',
                value: patient.medicalHistory,
                isMultiLine: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientDetailRow({
    required IconData icon,
    required String title,
    required String value,
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: _primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _textColor,
                  height: isMultiLine ? 1.5 : 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Help & Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildHelpItem(
                icon: Icons.info_outline,
                title: 'About This Form',
                description:
                    'This form collects essential patient vital signs and complaints during a clinic visit.',
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                icon: Icons.calculate_outlined,
                title: 'BMI Calculation',
                description:
                    'BMI is automatically calculated based on height and weight entries.',
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                icon: Icons.history_outlined,
                title: 'Data Saving',
                description:
                    'All information is securely saved to the patient\'s electronic medical record.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: _accentColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
