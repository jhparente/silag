// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/profile_model.dart';
import '../../services/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  final ProfileModel profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ProfileService _profileService = ProfileService();

  late TextEditingController _usernameController;
  XFile? _selectedImage;
  late int _currentSliderValue;
  bool _isLoading = false;

  // Placeholder for real GPS coordinates
  double? _newLatitude;
  double? _newLongitude;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.profile.username ?? '',
    );
    // Initialize slider from database, clamp to 7 if it somehow went over
    int dbValue = widget.profile.alertThreshold ?? 0;
    _currentSliderValue = dbValue > 7 ? 7 : dbValue;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // --- CAPTURE REAL GPS LOCATION ---
  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      // 1. Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // 2. Check / request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Please enable it in app settings.',
        );
      }

      // 3. Get the actual position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _newLatitude = position.latitude;
        _newLongitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location captured: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // --- PICK IMAGE FUNCTION ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  // --- SAVE PROFILE FUNCTION ---
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _profileService.updateUserProfile(
        username: _usernameController.text.trim(),
        alertThreshold: _currentSliderValue,
        profileImage: _selectedImage != null
            ? File(_selectedImage!.path)
            : null,
        latitude: _newLatitude,
        longitude: _newLongitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Pop the screen and return 'true' to tell the ProfilePage to refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF101C45)),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            color: Color(0xFF101C45),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF101C45)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // --- 1. PROFILE PICTURE PICKER ---
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _selectedImage != null
                              ? FileImage(File(_selectedImage!.path))
                                    as ImageProvider
                              : (widget.profile.profilePictureUrl != null &&
                                        widget
                                            .profile
                                            .profilePictureUrl!
                                            .isNotEmpty
                                    ? NetworkImage(
                                        widget.profile.profilePictureUrl!,
                                      )
                                    : null),
                          child:
                              _selectedImage == null &&
                                  (widget.profile.profilePictureUrl == null ||
                                      widget.profile.profilePictureUrl!.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101C45),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- 2. EDITABLE USERNAME FIELD ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Account Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF101C45),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildEditableField(
                    "Username",
                    _usernameController,
                    Icons.person_outline,
                    maxLength: 20,
                  ),

                  const SizedBox(height: 15),

                  // --- 3. LOCATION UPDATE BUTTON ---
                  OutlinedButton.icon(
                    icon: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF101C45),
                            ),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: Color(0xFF101C45),
                          ),
                    label: Text(
                      _isLocating
                          ? "Getting location..."
                          : _newLatitude == null
                          ? "Update to Current Location"
                          : "Location Captured",
                      style: const TextStyle(
                        color: Color(0xFF101C45),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      side: const BorderSide(color: Color(0xFF101C45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLocating ? null : _captureLocation,
                  ),
                  const SizedBox(height: 35),

                  // --- 4. EDITABLE SLIDER ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Alert Threshold",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF101C45),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Active Slider Container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "$_currentSliderValue ft",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101C45),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF101C45),
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: const Color(0xFF101C45),
                            overlayColor: const Color(
                              0xFF101C45,
                            ).withOpacity(0.2),
                            trackHeight: 8.0,
                          ),
                          child: Slider(
                            value: _currentSliderValue.toDouble(),
                            min: 0,
                            max: 7,
                            divisions: 7,
                            onChanged: (newValue) {
                              setState(() {
                                _currentSliderValue = newValue.toInt();
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(8, (index) {
                              return Text(
                                "$index",
                                style: TextStyle(
                                  color: _currentSliderValue == index
                                      ? const Color(0xFF101C45)
                                      : Colors.grey[500],
                                  fontWeight: _currentSliderValue == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                      ),
                  ),

                  const SizedBox(height: 14),

                  // --- SMS PREVIEW CARD ---
                  if (_currentSliderValue > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        border: Border.all(color: const Color(0xFF101C45).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sms_outlined, size: 16, color: Color(0xFF101C45)),
                              const SizedBox(width: 6),
                              const Text(
                                'SMS Preview',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF101C45),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF101C45),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'SILAG',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFDDE4FF)),
                          const SizedBox(height: 10),
                          Text(
                            'SILAG FLOOD ALERT\n'
                            'Water level at [your area] is now X.X ft, reaching your personal alert threshold of $_currentSliderValue ft.\n'
                            'Please take necessary precautions and monitor updates closely. Move valuables to higher ground if needed.\n'
                            'Stay safe. -SILAG Flood Monitoring System',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You will receive this SMS when water reaches $_currentSliderValue ft.',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFF101C45),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Set a threshold above 0 ft to receive SMS flood alerts.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.amber[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),


                  const SizedBox(height: 24),

                  // --- 5. SAVE BUTTON ---
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101C45),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveProfile,
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : null,
      style: const TextStyle(
        color: Colors.black87,
        fontFamily: 'Poppins',
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF101C45)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          vertical: 22,
          horizontal: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF101C45), width: 2),
        ),
      ),
    );
  }
}
