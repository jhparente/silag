import 'package:flutter/material.dart';
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/services/evacuation_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hotline_service.dart';
import '../models/hotline_model.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final _hotlineService = HotlineService();
  final _evacuationService = EvacuationService();

  late Future<List<HotlineModel>> _hotlinesFuture;
  late Future<List<EvacuationModel>> _evacuationCentersFuture;

  @override
  void initState() {
    super.initState();
    // Fetch only global + personal hotlines
    _hotlinesFuture = _hotlineService.fetchMyHotlines();
    _evacuationCentersFuture = _evacuationService.fetchEvacuationCenters();
  }

  void _refreshList() {
    setState(() {
      _hotlinesFuture = _hotlineService.fetchMyHotlines();
      _evacuationCentersFuture = _evacuationService.fetchEvacuationCenters();
    });
  }

  // --- FUNCTION TO CALL NUMBER ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll('-', '').replaceAll(' ', ''),
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (!await launchUrl(launchUri)) {
          throw 'Could not launch $launchUri';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer')),
        );
      }
    }
  }

  // --- FUNCTION TO LAUNCH MAP ---
  Future<void> _launchMap(double latitude, double longitude) async {
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not launch map')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch map')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Emergency Hotlines",
                  style: TextStyle(
                    color: Color(0xFF101C45),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Poppins',
                  ),
                ),
                IconButton(
                  onPressed: _showAddContactDialog,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 24,
                    color: Color(0xFF101C45),
                  ),
                  tooltip: "Add Contact",
                ),
              ],
            ),
            const SizedBox(height: 5),

            // --- HOTLINE LIST ---
            FutureBuilder<List<HotlineModel>>(
              future: _hotlinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final hotlines = snapshot.data!;

                if (hotlines.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No contacts found.")),
                  );
                }

                return Column(
                  children: hotlines
                      .map((hotline) => _buildHotlineCard(hotline))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 35),

            // --- EVACUATION CENTERS LIST ---
            const Text(
              "Evacuation Centers",
              style: TextStyle(
                color: Color(0xFF101C45),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 15),

            FutureBuilder<List<EvacuationModel>>(
              future: _evacuationCentersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final centers = snapshot.data ?? [];

                if (centers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No evacuation centers found.")),
                  );
                }

                return Column(
                  children: centers
                      .map((site) => _buildEvacuationCenterCard(site))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 35),
            // --- GUIDELINES ---
            const Text(
              "Guidelines",
              style: TextStyle(
                color: Color(0xFF101C45),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),

            const SizedBox(height: 15),

            _buildGuidelineTile("I. Immediate Actions (When Rain & Wind Start)", [
              _buildGuidelineStep("1. Secure Your Home Immediately"),
              _buildGuidelineBullet(
                "Bring pets inside: Do not leave them tied up outside where they can be trapped.",
              ),
              _buildGuidelineBullet(
                "Anchor loose items: Bring in anything from the yard/balcony (laundry, plants) that could become flying debris.",
              ),
              _buildGuidelineBullet(
                "Reinforce windows: If you have storm shutters, close them. Stay away from glass.",
              ),
              _buildGuidelineBullet(
                "Charge devices: Fully charge mobile phones, power banks, and emergency lights.",
              ),
              _buildGuidelineStep(
                "2. Manage Utilities (Electricity, Water, Gas)",
              ),
              _buildGuidelineBullet(
                "Turn off the main power switch if you see water rising inside your house.",
              ),
              _buildGuidelineBullet(
                "Unplug appliances to protect them from power surges.",
              ),
              _buildGuidelineBullet(
                "Close the LPG tank valve tightly to prevent gas leaks.",
              ),
              _buildGuidelineBullet(
                "Store clean water in containers/bathtubs in case water services are cut.",
              ),
              _buildGuidelineStep("3. Monitor Official Updates"),
              _buildGuidelineBullet(
                "Tune in: Listen to battery-operated radios or check social media (PAGASA, NDRRMC).",
              ),
              _buildGuidelineBullet(
                "Yellow Warning: Monitor weather conditions.",
              ),
              _buildGuidelineBullet(
                "Orange Warning: Alert for possible evacuation.",
              ),
              _buildGuidelineBullet(
                "Red Warning: Evacuation is often mandatory; serious flooding expected.",
              ),
            ]),

            _buildGuidelineTile("II. Flood Safety Protocols", [
              _buildGuidelineStep("1. During Evacuation"),
              _buildGuidelineBullet("Move to higher ground immediately."),
              _buildGuidelineBullet(
                "Do not walk or drive through moving water.",
              ),
              _buildGuidelineStep("2. After the Flood"),
              _buildGuidelineBullet(
                "Wait for official advice before returning home.",
              ),
              _buildGuidelineBullet(
                "Check for structural damage before entering.",
              ),
            ]),

            _buildGuidelineTile("III. Emergency \"Go Bag\" Checklist", [
              _buildGuidelineBullet(
                "Drinking water and non-perishable food (3-day supply).",
              ),
              _buildGuidelineBullet("First aid kit and medicines."),
              _buildGuidelineBullet("Flashlight, batteries, and whistle."),
              _buildGuidelineBullet(
                "Important documents (ID, land title) in waterproof bags.",
              ),
              _buildGuidelineBullet("Power bank and extra phone cables."),
            ]),
          ],
        ),
      ),
    );
  }

  // --- GUIDELINE WIDGETS ---
  Widget _buildGuidelineTile(String title, List<Widget> content) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF101C45),
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        iconColor: const Color(0xFF101C45),
        collapsedIconColor: const Color(0xFF101C45),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF101C45),
          fontWeight: FontWeight.w600,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildGuidelineBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                height: 1.4,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvacuationCenterCard(EvacuationModel site) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF101C45),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: const Border(
                top: BorderSide(color: Color(0xFF101C45), width: 8),
                left: BorderSide(color: Color(0xFF101C45), width: 8),
                right: BorderSide(color: Color(0xFF101C45), width: 8),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              image: site.evacuationImageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(site.evacuationImageUrl),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {},
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        site.address,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => _launchMap(site.latitude, site.longitude),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.near_me,
                      size: 22,
                      color: Color(0xFF101C45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HOTLINE CARD HELPER ---
  Widget _buildHotlineCard(HotlineModel hotline) {
    return GestureDetector(
      onTap: () => _makePhoneCall(hotline.number),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF101C45),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Title
            Expanded(
              flex: 5,
              child: Text(
                hotline.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  height: 1.2,
                ),
              ),
            ),
            // Divider
            Container(
              height: 30,
              width: 1,
              color: Colors.white,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            ),
            // Number & Icon
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hotline.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.phone, color: Colors.greenAccent, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Add Contact",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Name",
                hintText: "e.g. Mom",
              ),
            ),
            TextField(
              controller: numberController,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: "Number",
                hintText: "0912...",
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF101C45),
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  numberController.text.isNotEmpty) {
                // Capitalize the name logic
                String rawName = nameController.text;
                String capitalizedName = rawName
                    .split(' ')
                    .map(
                      (word) => word.isNotEmpty
                          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                          : '',
                    )
                    .join(' ');

                // Wrapped in a try/catch to handle network errors safely
                try {
                  await _hotlineService.addLocalHotline(
                    capitalizedName,
                    numberController.text,
                  );
                  _refreshList(); // Fetch the newly updated list
                  if (context.mounted) Navigator.pop(context); // Close dialog
                } catch (e) {
                  if (context.mounted) {
                    // Show a popup if the backend rejects it or Wi-Fi is down
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "Safety & Resources",
        style: TextStyle(
          color: Color(0xFF101C45),
          fontWeight: FontWeight.bold,
          fontSize: 23,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
