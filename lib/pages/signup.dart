import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:silag/main_screen.dart'; // Make sure this path is correct for your app!
import '../services/auth_service.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _authService = AuthService();

  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation(silentErrors: true);
    });
  }

  void _handleMobileChanged(String value) {
    if (!value.startsWith('0')) return;

    final updated = value.replaceFirst(RegExp(r'^0+'), '');
    _mobileController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  Future<void> _getCurrentLocation({bool silentErrors = false}) async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (!mounted || silentErrors) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // --- SIGNUP LOGIC ---
  Future<void> _handleSignup() async {
    final mobileDigits = _mobileController.text.trim();

    // 1. Basic validation
    if (_usernameController.text.isEmpty ||
        mobileDigits.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    if (mobileDigits.length != 10 || !mobileDigits.startsWith('9')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid PH mobile number (9XXXXXXXXX).'),
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    if (_latitude == null || _longitude == null) {
      await _getCurrentLocation(silentErrors: true);
    }

    setState(() => _isLoading = true);

    try {
      // 2. Call the register function in your Python Backend
      // This will automatically save the access_token inside the service!
      final user = await _authService.register(
        username: _usernameController.text.trim(),
        mobileNumber: '+63$mobileDigits',
        password: _passwordController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );

      // 3. Success! Show a welcome message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Account created! Welcome, ${user.username}!"),
            backgroundColor: Colors.green,
          ),
        );

        // 4. Destroy the signup/login pages and route directly to MainScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) =>
              false, // This prevents them from hitting the back button to return to Login
        );
      }
    } catch (e) {
      // 5. Show backend errors (like "Mobile number already exists")
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF101C45)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- HEADER TEXT ---
                const Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101C45),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Join your community dashboard today",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 40),

                // --- USERNAME FIELD ---
                _buildLabel("Username"),
                TextField(
                  controller: _usernameController,
                  decoration: _inputDecoration(
                    hint: "e.g. JuanDelaCruz",
                    prefixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 20),

                // --- MOBILE NUMBER FIELD ---
                _buildLabel("Mobile Number"),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  onChanged: _handleMobileChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration:
                      _inputDecoration(
                        hint: "9XXXXXXXXX",
                        prefixIcon: Icons.phone_android,
                      ).copyWith(
                        prefixText: '+63 ',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF101C45),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.my_location,
                      size: 18,
                      color: _isLocating
                          ? Colors.orange
                          : const Color(0xFF101C45),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLocating
                            ? 'Getting your location...'
                            : (_latitude != null && _longitude != null)
                            ? 'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}'
                            : 'Location not available',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontFamily: 'Poppins',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLocating ? null : _getCurrentLocation,
                      child: const Text(
                        'Refresh',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFF101C45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- PASSWORD FIELD ---
                _buildLabel("Password"),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration:
                      _inputDecoration(
                        hint: "Create a password",
                        prefixIcon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[500],
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                ),
                const SizedBox(height: 20),

                // --- CONFIRM PASSWORD FIELD ---
                _buildLabel("Confirm Password"),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration:
                      _inputDecoration(
                        hint: "Re-enter your password",
                        prefixIcon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[500],
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                      ),
                ),
                const SizedBox(height: 40),

                // --- SIGN UP BUTTON ---
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101C45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF101C45),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
      prefixIcon: Icon(prefixIcon, color: Colors.grey[500]),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF101C45), width: 2),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
