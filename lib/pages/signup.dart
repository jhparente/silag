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

      if (permission == LocationPermission.deniedForever) {
        // User permanently blocked — direct them to Settings
        if (mounted && !silentErrors) {
          await _showLocationBlockedDialog(permanent: true);
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        // User just tapped "Deny" in the permission popup
        if (mounted && !silentErrors) {
          await _showLocationBlockedDialog(permanent: false);
        }
        return;
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

  /// Shows a dialog explaining that location is required to sign up.
  /// [permanent] = true → guides user to app Settings.
  /// [permanent] = false → offers a Retry button.
  Future<void> _showLocationBlockedDialog({required bool permanent}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.location_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Location Required'),
          ],
        ),
        content: Text(
          permanent
              ? 'Location permission has been permanently denied.\n\n'
                'SILAG needs your location to determine your barangay when creating an account.\n\n'
                'Please open Settings and enable Location for SILAG, then come back and try again.'
              : 'SILAG needs your location to determine your barangay when creating an account.\n\n'
                'Without it, we cannot register your account. Please allow location access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF101C45),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(permanent ? Icons.settings : Icons.refresh),
            label: Text(permanent ? 'Open Settings' : 'Retry'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (permanent) {
                await Geolocator.openAppSettings();
              } else {
                await _getCurrentLocation(silentErrors: false);
              }
            },
          ),
        ],
      ),
    );
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
      // Try once more in case it was silently skipped on init
      await _getCurrentLocation(silentErrors: false);

      // If still null after attempt, location is not available — block signup
      if (_latitude == null || _longitude == null) {
        if (mounted) {
          await _showLocationBlockedDialog(
            permanent: await Geolocator.checkPermission() ==
                LocationPermission.deniedForever,
          );
        }
        return;
      }
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
      if (!mounted) return;
      final errMsg = e.toString().replaceAll('Exception: ', '');

      // Show a dedicated modal for the Valenzuela City restriction
      if (errMsg.toLowerCase().contains('valenzuela') ||
          errMsg.toLowerCase().contains('restricted to residents')) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFD32F2F),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Not Available in Your Area',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101C45),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            content: const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 20),
              child: Text(
                'SILAG is a flood monitoring and alert system exclusively for residents of '
                'Valenzuela City, Metro Manila.\n\n'
                'Your current location is outside Valenzuela City, so we are unable to create an account for you at this time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101C45),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Generic snackbar for all other errors (e.g. mobile already exists)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
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
                // --- LOGO ---
                Image.asset(
                  'icons/690077655_1761743564788727_1218448248378351958_n.png',
                  height: 75,
                  width: 75,
                ),
                const SizedBox(height: 16),

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
                  maxLength: 20,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                  ],
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
