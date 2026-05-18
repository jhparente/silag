import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:silag/main_screen.dart'; // Import your MainScreen here
import '../services/auth_service.dart';
import 'signup.dart';
import 'forgot_password.dart';

class Login extends StatefulWidget {
  final String? initialErrorMessage;

  const Login({super.key, this.initialErrorMessage});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _authService = AuthService();

  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _inlineErrorMessage;

  void _handleMobileChanged(String value) {
    if (!value.startsWith('0')) return;

    final updated = value.replaceFirst(RegExp(r'^0+'), '');
    _mobileController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialErrorMessage != null &&
        widget.initialErrorMessage!.isNotEmpty) {
      _inlineErrorMessage = widget.initialErrorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialErrorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      });
    }
  }

  // --- LOGIN LOGIC ---
  Future<void> _handleLogin() async {
    final mobileDigits = _mobileController.text.trim();

    // 1. Basic validation
    if (mobileDigits.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both mobile number and password."),
        ),
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

    setState(() => _isLoading = true);
    setState(() => _inlineErrorMessage = null);

    try {
      // 2. Call your Python Backend!
      final user = await _authService.login(
        mobileNumber: '+63$mobileDigits',
        password: _passwordController.text.trim(),
      );

      // 3. Success! Show a welcome message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome back, ${user.username}!"),
            backgroundColor: Colors.green,
          ),
        );

        // 4. DESTROY the login page and go to MainScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      // 5. If Python throws an error (e.g., "Invalid username or password."), show it here!
      if (mounted) {
        final errorText = e.toString().replaceAll('Exception: ', '');
        if (errorText.toLowerCase().contains('banned')) {
          setState(
            () => _inlineErrorMessage = 'Account is banned. Contact the admin.',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText), backgroundColor: Colors.redAccent),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- LOGO OR ICON ---
                Image.asset(
                  'icons/690077655_1761743564788727_1218448248378351958_n.png',
                  height: 90,
                  width: 90,
                ),
                const SizedBox(height: 20),

                // --- HEADER TEXT ---
                const Text(
                  "Welcome Back",
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
                  "Sign in to access your community dashboard",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 40),

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
                const SizedBox(height: 20),

                // --- PASSWORD FIELD ---
                _buildLabel("Password"),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration:
                      _inputDecoration(
                        hint: "Enter your password",
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

                // --- FORGOT PASSWORD (Placeholder) ---
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPassword(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Color(0xFF101C45),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // --- LOGIN BUTTON ---
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
                    onPressed: _isLoading ? null : _handleLogin,
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
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),
                if (_inlineErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _inlineErrorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 30),

                // --- SIGN UP PROMPT ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Signup(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xFF101C45),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
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
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
