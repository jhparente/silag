// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:silag/main_screen.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Signup — 3-step flow:
//   Step 1: Fill in username, mobile number, password
//   Step 2: Enter OTP sent via SMS
//   Step 3: Account created → navigate to MainScreen
// ---------------------------------------------------------------------------

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Step tracking: 1 = form, 2 = OTP
  int _step = 1;

  // Step 1 controllers
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2 – OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;

  // OTP resend timer
  int _resendCooldown = 0;
  Timer? _resendTimer;

  // Verified phone token from backend
  String? _phoneVerificationToken;

  // Animation controller for step transitions
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
    // Silently try to get location in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation(silent: true);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ---- Location ----
  Future<void> _getCurrentLocation({bool silent = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (_) {
      // Location is optional now — don't block the user
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ---- Step 1 → Step 2: validate form and send OTP ----
  Future<void> _handleSendOtp() async {
    final mobileDigits = _mobileController.text.trim();

    if (_usernameController.text.trim().isEmpty ||
        mobileDigits.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnack('Please fill in all fields.');
      return;
    }
    if (mobileDigits.length != 10 || !mobileDigits.startsWith('9')) {
      _showSnack('Enter a valid PH mobile number (9XXXXXXXXX).');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack('Passwords do not match.');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fullMobile = '+63$mobileDigits';
      final result = await _authService.requestRegistrationOtp(
        mobileNumber: fullMobile,
      );

      if (!mounted) return;

      // Show debug code hint in development
      final debugCode = result['debug_code'] as String?;

      _transitionToStep(2);
      _startResendTimer();

      if (debugCode != null) {
        // Staging mode: show OTP in a dialog so testers can proceed
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.bug_report, color: Color(0xFF101C45)),
                SizedBox(width: 8),
                Text('Staging Mode', style: TextStyle(fontFamily: 'Poppins', fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SMS is in staging mode. Your verification code is:',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  debugCode,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101C45),
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- Step 2: verify OTP ----
  Future<void> _handleVerifyOtp() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      _showSnack('Please enter all 6 digits of your OTP.');
      return;
    }

    final mobileDigits = _mobileController.text.trim();
    final fullMobile = '+63$mobileDigits';

    setState(() => _isLoading = true);
    try {
      final token = await _authService.verifyRegistrationOtp(
        mobileNumber: fullMobile,
        otpCode: code,
      );
      _phoneVerificationToken = token;

      // OTP verified → create account
      await _createAccount();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- Final step: create the account ----
  Future<void> _createAccount() async {
    try {
      final mobileDigits = _mobileController.text.trim();
      final user = await _authService.register(
        username: _usernameController.text.trim(),
        mobileNumber: '+63$mobileDigits',
        password: _passwordController.text.trim(),
        phoneVerificationToken: _phoneVerificationToken!,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (!mounted) return;
      _showSnack('Account created! Welcome, ${user.username}!', color: Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ---- Resend OTP ----
  Future<void> _handleResendOtp() async {
    if (_resendCooldown > 0) return;
    final mobileDigits = _mobileController.text.trim();
    setState(() => _isLoading = true);
    try {
      final result = await _authService.requestRegistrationOtp(
        mobileNumber: '+63$mobileDigits',
      );
      _startResendTimer();
      final debugCode = result['debug_code'] as String?;
      if (!mounted) return;
      if (debugCode != null) {
        _showSnack('Staging: your OTP is $debugCode');
      } else {
        _showSnack('New OTP sent successfully!', color: Colors.green);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendTimer() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  void _transitionToStep(int step) {
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _step = step);
      _animCtrl.forward();
      // Auto-focus first OTP field
      if (step == 2) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
      }
    });
  }

  void _showSnack(String msg, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF101C45)),
          onPressed: () {
            if (_step == 2) {
              _transitionToStep(1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  // ============================================================
  // STEP 1: Registration form
  // ============================================================
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          Image.asset('icons/SILAG LOGO - 1 - Edited.png', height: 72, width: 72),
          const SizedBox(height: 16),

          const Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold,
              color: Color(0xFF101C45), fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Join your community dashboard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 32),

          // Step indicator
          _buildStepIndicator(1),
          const SizedBox(height: 28),

          // Username
          _buildLabel('Username'),
          TextField(
            controller: _usernameController,
            maxLength: 20,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            decoration: _inputDecoration(hint: 'e.g. JuanDelaCruz', icon: Icons.person_outline),
          ),
          const SizedBox(height: 20),

          // Mobile
          _buildLabel('Mobile Number'),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: _inputDecoration(hint: '9XXXXXXXXX', icon: Icons.phone_android)
                .copyWith(
              prefixText: '+63 ',
              prefixStyle: const TextStyle(
                color: Color(0xFF101C45), fontWeight: FontWeight.w600, fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Location indicator (subtle, optional)
          Row(
            children: [
              Icon(
                _isLocating
                    ? Icons.my_location
                    : (_latitude != null ? Icons.location_on : Icons.location_off),
                size: 14,
                color: _latitude != null ? const Color(0xFF101C45) : Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isLocating
                      ? 'Getting location...'
                      : (_latitude != null
                          ? 'Location captured'
                          : 'Location not available (optional)'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _latitude != null ? Colors.grey[600] : Colors.grey[400],
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              if (!_isLocating)
                GestureDetector(
                  onTap: _getCurrentLocation,
                  child: Text(
                    'Refresh',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12,
                      color: const Color(0xFF101C45), fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Password
          _buildLabel('Password'),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration(hint: 'Create a password', icon: Icons.lock_outline)
                .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Confirm Password
          _buildLabel('Confirm Password'),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: _inputDecoration(hint: 'Re-enter your password', icon: Icons.lock_outline)
                .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Send OTP Button
          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101C45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: _isLoading ? null : _handleSendOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Send Verification Code',
                      style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.bold, fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2: OTP Verification
  // ============================================================
  Widget _buildStep2() {
    final mobileDigits = _mobileController.text.trim();
    final maskedMobile = mobileDigits.length >= 4
        ? '+63 9${' ' * 0}${'*' * 6}${mobileDigits.substring(mobileDigits.length - 4)}'
        : '+63 $mobileDigits';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('icons/SILAG LOGO - 1 - Edited.png', height: 72, width: 72),
          const SizedBox(height: 16),

          const Text(
            'Verify Your Number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold,
              color: Color(0xFF101C45), fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Poppins'),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to\n'),
                TextSpan(
                  text: maskedMobile,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF101C45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Step indicator
          _buildStepIndicator(2),
          const SizedBox(height: 36),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => _buildOtpBox(i)),
          ),
          const SizedBox(height: 10),

          // Resend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive the code? ",
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey[600]),
              ),
              _resendCooldown > 0
                  ? Text(
                      'Resend in ${_resendCooldown}s',
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13,
                        color: Colors.grey, fontWeight: FontWeight.w600,
                      ),
                    )
                  : GestureDetector(
                      onTap: _isLoading ? null : _handleResendOtp,
                      child: const Text(
                        'Resend',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13,
                          color: Color(0xFF101C45), fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 40),

          // SMS preview hint
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF101C45).withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sms_outlined, size: 20, color: Color(0xFF101C45)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Check your SMS from SILAG for the 6-digit verification code.',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Verify Button
          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101C45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: _isLoading ? null : _handleVerifyOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Verify & Create Account',
                      style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.bold, fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF101C45),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF101C45), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
          // Auto-submit when all 6 digits filled
          final code = _otpControllers.map((c) => c.text).join();
          if (code.length == 6 && !_isLoading) {
            _handleVerifyOtp();
          }
        },
      ),
    );
  }

  // Step indicator dots
  Widget _buildStepIndicator(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [1, 2].map((step) {
        final isActive = step == currentStep;
        final isDone = step < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive || isDone
                ? const Color(0xFF101C45)
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 8, color: Colors.white)
              : null,
        );
      }).toList(),
    );
  }

  // ---- UI Helpers ----
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF101C45), fontWeight: FontWeight.bold,
          fontSize: 14, fontFamily: 'Poppins',
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, fontFamily: 'Poppins'),
      prefixIcon: Icon(icon, color: Colors.grey[500]),
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
}
