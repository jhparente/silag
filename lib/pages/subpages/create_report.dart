import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:silag/services/flood_report_service.dart';

class CreateReportPage extends StatefulWidget {
  const CreateReportPage({super.key});

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  // Services & Helpers
  final _picker = ImagePicker();
  final _floodReportService = FloodReportService();

  // State Variables
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

  // Form Controllers
  final _descriptionController = TextEditingController();
  String _selectedFloodLevel = '1 ft - Low';

  final List<String> _floodLevels = [
    '1 ft - Low',
    '2 ft - High',
    '3 ft - Critical',
    '4 ft - Severe',
    '5 ft - Extreme',
    '6 ft - Dangerous',
    '7 ft - Catastrophic',
  ];

  // --- GET GPS LOCATION ---
  Future<void> _getCurrentLocation() async {
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

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not get location: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // --- SHOW CAMERA OR GALLERY PROMPT ---
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF101C45)),
              title: const Text(
                'Take a Photo',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF101C45),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- HANDLE IMAGE SELECTION ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = pickedFile;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to pick image. Please check permissions."),
          ),
        );
      }
    }
  }

  // --- SUBMIT REPORT LOGIC ---
  Future<void> _submitReport() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a photo.")));
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please get your current location first."),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _floodReportService.submitFloodReport(
        latitude: _latitude!,
        longitude: _longitude!,
        floodLevel: _selectedFloodLevel,
        description: _descriptionController.text,
        imageFile: File(_selectedImage!.path),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted, pending admin review")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF101C45),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Submit Flood Report",
          style: TextStyle(
            color: Color(0xFF101C45),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF101C45)),
                  SizedBox(height: 15),
                  Text(
                    "Uploading Report...",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101C45),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- IMAGE BOX ---
                  GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF101C45),
                          width: 1.5,
                        ),
                        image: _selectedImageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_selectedImageBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 50,
                                  color: Color(0xFF101C45),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Tap to select photo",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF101C45),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    "Additional Information",
                    style: TextStyle(
                      color: Color(0xFF101C45),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- LOCATION BUTTON ---
                  _buildFormLabel("Location"),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLocating ? null : _getCurrentLocation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF101C45),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: const Color(0xFF101C45),
                      ),
                      icon: _isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF101C45),
                              ),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        _latitude != null
                            ? 'Lat: ${_latitude!.toStringAsFixed(5)},  Lng: ${_longitude!.toStringAsFixed(5)}'
                            : 'Get Current Location',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- FLOOD LEVEL ---
                  _buildFormLabel("Flood Level"),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFloodLevel,
                    decoration: _inputDecoration(""),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF101C45),
                    ),
                    items: _floodLevels.map((String level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(
                          level,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) =>
                        setState(() => _selectedFloodLevel = newValue!),
                  ),
                  const SizedBox(height: 15),

                  // --- DESCRIPTION ---
                  _buildFormLabel("Description"),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 120,
                    decoration: _inputDecoration(
                      "Add details about the situation...",
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- SUBMIT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF101C45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _submitReport,
                      child: const Text(
                        "Submit Report",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF101C45),
          fontWeight: FontWeight.bold,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey[500],
        fontSize: 13,
        fontFamily: 'Poppins',
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF101C45), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
