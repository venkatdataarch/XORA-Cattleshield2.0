import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_provider.dart';

/// List of Indian states for the state dropdown.
const _indianStates = <String>[
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

/// Farmer registration form screen.
///
/// Collects personal and location details, validates Aadhaar using the
/// Verhoeff algorithm, and submits via [authProvider].
class FarmerRegistrationScreen extends ConsumerStatefulWidget {
  /// The phone number pre-filled from OTP verification.
  final String phone;

  const FarmerRegistrationScreen({super.key, required this.phone});

  @override
  ConsumerState<FarmerRegistrationScreen> createState() =>
      _FarmerRegistrationScreenState();
}

class _FarmerRegistrationScreenState
    extends ConsumerState<FarmerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _fatherNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _villageController;
  late final TextEditingController _districtController;
  late final TextEditingController _mobileController;
  late final TextEditingController _aadhaarController;
  late final TextEditingController _occupationController;

  String? _selectedState;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _fatherNameController = TextEditingController();
    _addressController = TextEditingController();
    _villageController = TextEditingController();
    _districtController = TextEditingController();
    _mobileController = TextEditingController(text: widget.phone);
    _aadhaarController = TextEditingController();
    _occupationController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _addressController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _mobileController.dispose();
    _aadhaarController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Aadhaar Verhoeff validation
  // ---------------------------------------------------------------------------

  /// Multiplication table used by the Verhoeff algorithm.
  static const _verhoeffMultiply = <List<int>>[
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  /// Permutation table used by the Verhoeff algorithm.
  static const _verhoeffPermute = <List<int>>[
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  /// Validates a number string using the Verhoeff checksum algorithm.
  static bool _isValidVerhoeff(String number) {
    int c = 0;
    final digits = number.split('').reversed.toList();
    for (int i = 0; i < digits.length; i++) {
      final digit = int.tryParse(digits[i]);
      if (digit == null) return false;
      c = _verhoeffMultiply[c][_verhoeffPermute[i % 8][digit]];
    }
    return c == 0;
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text.trim(),
      'fatherOrHusbandName': _fatherNameController.text.trim(),
      'address': _addressController.text.trim(),
      'village': _villageController.text.trim(),
      'district': _districtController.text.trim(),
      'state': _selectedState,
      'phone': _mobileController.text.trim(),
      'aadhaarNumber': _aadhaarController.text.trim(),
      'occupation': _occupationController.text.trim(),
    };

    final success =
        await ref.read(authProvider.notifier).registerFarmer(data);

    if (success && mounted) {
      context.go('/farmer');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for errors.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Farmer Registration',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            children: [
              const SizedBox(height: 8),

              // Full Name
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),

              const SizedBox(height: 16),

              // Father / Husband Name
              _buildTextField(
                controller: _fatherNameController,
                label: 'Father / Husband Name',
                hint: 'Enter father or husband name',
                icon: Icons.family_restroom_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'This field is required'
                    : null,
              ),

              const SizedBox(height: 16),

              // Address
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Enter your full address',
                icon: Icons.location_on_outlined,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Address is required'
                    : null,
              ),

              const SizedBox(height: 16),

              // Village
              _buildTextField(
                controller: _villageController,
                label: 'Village',
                hint: 'Enter your village name',
                icon: Icons.holiday_village_outlined,
              ),

              const SizedBox(height: 16),

              // District
              _buildTextField(
                controller: _districtController,
                label: 'District',
                hint: 'Enter your district',
                icon: Icons.map_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'District is required'
                    : null,
              ),

              const SizedBox(height: 16),

              // State dropdown
              DropdownButtonFormField<String>(
                value: _selectedState,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'State',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                items: _indianStates
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedState = value),
                validator: (v) =>
                    v == null ? 'Please select your state' : null,
              ),

              const SizedBox(height: 16),

              // Mobile Number (pre-filled, read-only)
              _buildTextField(
                controller: _mobileController,
                label: 'Mobile Number',
                hint: '10-digit mobile number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                readOnly: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),

              const SizedBox(height: 16),

              // Aadhaar Number
              _buildTextField(
                controller: _aadhaarController,
                label: 'Aadhaar Number',
                hint: 'Enter 12-digit Aadhaar number',
                icon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Aadhaar number is required';
                  }
                  if (value.trim().length != 12) {
                    return 'Aadhaar number must be 12 digits';
                  }
                  if (!_isValidVerhoeff(value.trim())) {
                    return 'Invalid Aadhaar number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Occupation
              _buildTextField(
                controller: _occupationController,
                label: 'Occupation',
                hint: 'e.g. Farming, Dairy, Agriculture',
                icon: Icons.work_outline,
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable text field builder
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      ),
      validator: validator,
    );
  }
}
