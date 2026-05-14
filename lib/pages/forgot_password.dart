import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/local_notification_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _authService = AuthService();

  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _otpSent = false;
  bool _isSending = false;
  bool _isResetting = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  StreamSubscription<RemoteMessage>? _messageSub;

  @override
  void initState() {
    super.initState();
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      final data = message.data;
      final type = data['type']?.toString();
      final title =
          message.notification?.title ?? data['title']?.toString() ?? 'SILAG';
      final body =
          message.notification?.body ??
          data['body']?.toString() ??
          'Notification received.';

      if (type == 'password_reset_otp') {
        LocalNotificationService().showOtpNotification(
          title: title,
          body: body,
        );
        _showMessage('OTP sent via notification.');
        return;
      }

      if (title.isNotEmpty) {
        _showMessage('$title\n$body');
      } else {
        _showMessage(body);
      }
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

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<String?> _getDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<void> _sendOtp() async {
    final mobileDigits = _mobileController.text.trim();

    if (mobileDigits.isEmpty) {
      _showMessage('Please enter your mobile number.', isError: true);
      return;
    }

    if (mobileDigits.length != 10 || !mobileDigits.startsWith('9')) {
      _showMessage(
        'Enter a valid PH mobile number (9XXXXXXXXX).',
        isError: true,
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final token = await _getDeviceToken();
      if (token == null) {
        _showMessage(
          'Unable to get notification token. Enable notifications and try again.',
          isError: true,
        );
        return;
      }

      await _authService.requestPasswordResetOtp(
        mobileNumber: '+63$mobileDigits',
        deviceToken: token,
      );

      if (!mounted) return;
      setState(() => _otpSent = true);
      _showMessage('OTP sent. Check your notifications.');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final mobileDigits = _mobileController.text.trim();
    final otpCode = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (otpCode.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please complete all fields.', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isResetting = true);

    try {
      await _authService.resetPasswordWithOtp(
        mobileNumber: '+63$mobileDigits',
        otpCode: otpCode,
        newPassword: newPassword,
      );

      if (!mounted) return;
      _showMessage('Password reset successfully. You can log in now.');
      Navigator.pop(context);
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
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
                const Icon(
                  Icons.shield_moon,
                  size: 80,
                  color: Color(0xFF101C45),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Forgot Password',
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
                  'We will send a one-time code via notification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 36),

                _buildLabel('Mobile Number'),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  onChanged: _handleMobileChanged,
                  enabled: !_otpSent,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration:
                      _inputDecoration(
                        hint: '9XXXXXXXXX',
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

                if (!_otpSent) ...[
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
                      onPressed: _isSending ? null : _sendOtp,
                      child: _isSending
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Send OTP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  _buildLabel('OTP Code'),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: _inputDecoration(
                      hint: 'Enter the 6-digit code',
                      prefixIcon: Icons.shield,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('New Password'),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration:
                        _inputDecoration(
                          hint: 'Enter your new password',
                          prefixIcon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey[500],
                            ),
                            onPressed: () {
                              setState(
                                () =>
                                    _obscureNewPassword = !_obscureNewPassword,
                              );
                            },
                          ),
                        ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Confirm Password'),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration:
                        _inputDecoration(
                          hint: 'Confirm your new password',
                          prefixIcon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey[500],
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                          ),
                        ),
                  ),
                  const SizedBox(height: 20),

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
                      onPressed: _isResetting ? null : _resetPassword,
                      child: _isResetting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Reset Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: _isSending ? null : _sendOtp,
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: Color(0xFF101C45),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: const Text(
                      'Change mobile number',
                      style: TextStyle(
                        color: Color(0xFF101C45),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    _messageSub?.cancel();
    _mobileController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
