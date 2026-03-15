import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import 'subpages/edit_profile_page.dart'; // Make sure this import matches your file path!

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  late Future<ProfileModel> _profileFuture;

  int _currentSliderValue = 0;
  bool _isSliderInitialized = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.fetchUserProfile();
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
          "Your Profile",
          style: TextStyle(
            color: Color(0xFF101C45),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          // --- THE EDIT BUTTON ---
          IconButton(
            icon: const Icon(Icons.edit_square, color: Color(0xFF101C45)),
            tooltip: "Edit Profile",
            onPressed: () async {
              // Navigate to Edit screen and wait for the result
              final didUpdate = await Navigator.push(
                context,
                MaterialPageRoute(
                  // We pass the current profile data so the edit screen has it
                  builder: (context) => EditProfilePage(
                    profile: _isSliderInitialized
                        ? snapshotData
                        : ProfileModel(),
                  ),
                ),
              );

              // If the edit screen returns true, refresh the profile!
              if (didUpdate == true) {
                setState(() {
                  _profileFuture = _profileService.fetchUserProfile();
                  _isSliderInitialized = false; // Reset so the slider updates
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<ProfileModel>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF101C45)),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Profile not found."));
          }

          final profile = snapshot.data!;

          // Hacky workaround to pass the profile data to the edit button above
          snapshotData = profile;

          // --- THE CLAMP LOGIC ---
          if (!_isSliderInitialized) {
            int dbValue = profile.alertThreshold ?? 0;
            if (dbValue > 7) dbValue = 7;
            _currentSliderValue = dbValue;
            _isSliderInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP PROFILE CARD
                _buildProfileHeader(profile),
                const SizedBox(height: 25),

                // 2. ADDITIONAL INFORMATION
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

                _buildInfoField(
                  "Username",
                  profile.username ?? "Not set",
                  Icons.person_outline,
                ),
                _buildInfoField(
                  "Location",
                  profile.geocodedAddress ?? "Not set",
                  Icons.location_on_outlined,
                ),
                _buildInfoField(
                  "Contact",
                  profile.mobileNumber ?? "Not set",
                  Icons.phone_outlined,
                ),

                const SizedBox(height: 25),

                // 3. PERSONAL ALERT THRESHOLD
                const Text(
                  "Personal Alert Threshold",
                  style: TextStyle(
                    color: Color(0xFF101C45),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 15),

                // SLIDER UI (Locked)
                _buildThresholdSlider(),
              ],
            ),
          );
        },
      ),
    );
  }

  // A small variable to hold the snapshot data so the app bar button can access it
  late ProfileModel snapshotData;

  // --- WIDGET: TOP HEADER CARD ---
  Widget _buildProfileHeader(ProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101C45),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            backgroundImage:
                profile.profilePictureUrl != null &&
                    profile.profilePictureUrl!.isNotEmpty
                ? NetworkImage(profile.profilePictureUrl!)
                : null,
            child:
                profile.profilePictureUrl == null ||
                    profile.profilePictureUrl!.isEmpty
                ? const Icon(Icons.person, size: 40, color: Color(0xFF101C45))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username ?? "Unknown User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Text(
                      "Verified ",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: INFO FIELD TILES ---
  Widget _buildInfoField(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF101C45), size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: CUSTOM SLIDER (LOCKED) ---
  Widget _buildThresholdSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            "Current Alert Level: $_currentSliderValue ft",
            style: const TextStyle(
              color: Color(0xFF101C45),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF101C45),
              inactiveTrackColor: Colors.grey[300],
              thumbColor: const Color(0xFF101C45),
              overlayColor: const Color(0xFF101C45).withOpacity(0.2),
              trackHeight: 8.0,
              // The disabled colors are used when onChanged is null
              disabledActiveTrackColor: const Color(
                0xFF101C45,
              ).withOpacity(0.6),
              disabledInactiveTrackColor: Colors.grey[200],
              disabledThumbColor: const Color(0xFF101C45).withOpacity(0.6),
            ),
            child: Slider(
              value: _currentSliderValue.toDouble(),
              min: 0,
              max: 7,
              divisions: 7,
              label: "${_currentSliderValue}ft",
              onChanged: null, // THIS LOCKS THE SLIDER ON THE VIEW PAGE!
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
    );
  }
}
