import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/pages/subpages/evacuation_map_page.dart';
import 'package:silag/services/evacuation_request_service.dart';
import 'package:silag/services/evacuation_service.dart';
import 'package:silag/widgets/skeleton_loader.dart';
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
  final _evacuationRequestService = EvacuationRequestService();

  late Future<List<HotlineModel>> _hotlinesFuture;
  late Future<List<EvacuationModel>> _evacuationCentersFuture;
  bool _isRequestingEvacuation = false;
  int _localHotlineCount = 0; // tracks only the user's local hotlines

  // Evacuation request status tracking
  String? _myEvacuationStatus; // 'pending' | 'accepted' | null
  Timer? _statusPoller;
  bool _shownAcceptedBanner = false;

  @override
  void initState() {
    super.initState();
    _hotlinesFuture = _hotlineService.fetchMyHotlines();
    _evacuationCentersFuture = _evacuationService.fetchEvacuationCenters();
    _startStatusPolling();

    // Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final type = message.data['type'];
      if (type == 'evacuation_accepted' && mounted) {
        _onEvacuationAccepted(showBanner: true);
      }
    });
  }

  @override
  void dispose() {
    _statusPoller?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _checkEvacuationStatus(); // immediate check
    _statusPoller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkEvacuationStatus(),
    );
  }

  Future<void> _checkEvacuationStatus() async {
    final data = await _evacuationRequestService.getMyEvacuationRequest();
    if (!mounted) return;
    final status = data?['status'] as String?;
    setState(() => _myEvacuationStatus = status);
    if (status == 'accepted' && !_shownAcceptedBanner) {
      _onEvacuationAccepted(showBanner: false);
    }
  }

  void _onEvacuationAccepted({required bool showBanner}) {
    _shownAcceptedBanner = true;
    setState(() => _myEvacuationStatus = 'accepted');
    if (showBanner && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00C97A),
          duration: const Duration(seconds: 6),
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🚨 Your evacuation request has been accepted! Help is on the way.',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _refreshList() {
    setState(() {
      _hotlinesFuture = _hotlineService.fetchMyHotlines();
      _evacuationCentersFuture = _evacuationService.fetchEvacuationCenters();
    });
  }

  Future<void> _deleteHotline(HotlineModel hotline) async {
    // Safety guard — only local hotlines (ownerId != null) can be deleted
    if (hotline.ownerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Contact',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "${hotline.name}" from your local hotlines?',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _hotlineService.deleteLocalHotline(hotline.id);
      _refreshList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  String _cleanExceptionMessage(Object error) {
    return error.toString().replaceAll('Exception: ', '').trim();
  }

  Future<Position> _getCurrentPositionForEvacuation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Please enable it in app settings.',
      );
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _requestEvacuation() async {
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Request Evacuation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will send your current location to responders. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF101C45),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Send Request',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldSend != true || !mounted) return;

    setState(() => _isRequestingEvacuation = true);

    try {
      final position = await _getCurrentPositionForEvacuation();
      await _evacuationRequestService.requestEvacuation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Immediately switch the card to PENDING — no need to wait for the
      // background poller to fire. This prevents the button from being
      // clickable again after a successful request.
      if (mounted) {
        setState(() => _myEvacuationStatus = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF101C45),
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Evacuation request sent. Keep your phone nearby for updates.',
                    style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              'Could not send evacuation request: ${_cleanExceptionMessage(e)}',
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequestingEvacuation = false);
    }
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

  // --- FUNCTION TO OPEN IN-APP MAP ---
  void _openEvacuationMap(EvacuationModel site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvacuationMapPage(
          destLatitude: site.latitude,
          destLongitude: site.longitude,
          destName: site.name,
        ),
      ),
    );
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
            const Text(
              "Emergency Hotlines",
              style: TextStyle(
                color: Color(0xFF101C45),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 5),

            // --- HOTLINE LIST ---
            FutureBuilder<List<HotlineModel>>(
              future: _hotlinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: List.generate(
                      3,
                      (_) => const HotlineCardSkeleton(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _buildConnectionErrorCard();
                }

                final hotlines = snapshot.data!;

                // Split into global (owner_id == null) and local (user-owned)
                final globalHotlines =
                    hotlines.where((h) => h.ownerId == null).toList();
                final localHotlines =
                    hotlines.where((h) => h.ownerId != null).toList();

                // Sync local count for the add-button limit check
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted &&
                      _localHotlineCount != localHotlines.length) {
                    setState(
                        () => _localHotlineCount = localHotlines.length);
                  }
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── GLOBAL HOTLINES ──────────────────────────────
                    if (globalHotlines.isNotEmpty) ..._buildGlobalSection(globalHotlines),

                    // Separator between sections
                    if (globalHotlines.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Color(0xFFE8ECF4), thickness: 1),
                      ),

                    // ── LOCAL HOTLINES ───────────────────────────────
                    _buildLocalSection(localHotlines),
                  ],
                );
              },
            ),
            const SizedBox(height: 35),

            const Text(
              "Request Evacuation",
              style: TextStyle(
                color: Color(0xFF101C45),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 15),

            _buildEvacuationRequestCard(),
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
                  return Column(
                    children: List.generate(
                      2,
                      (_) => const EvacuationCenterSkeleton(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _buildConnectionErrorCard();
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

  Widget _buildEvacuationRequestCard() {
    final isAccepted = _myEvacuationStatus == 'accepted';
    final isPending = _myEvacuationStatus == 'pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAccepted
            ? const Color(0xFFE6FFF3)
            : const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? const Color(0xFF00C97A) : const Color(0xFFBED3FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C97A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'ACCEPTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                )
              else if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'PENDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_myEvacuationStatus != null) const SizedBox(height: 10),
          Text(
            isAccepted
                ? 'Evacuation Accepted'
                : 'Emergency Evacuation Request',
            style: TextStyle(
              color: isAccepted ? const Color(0xFF00874F) : const Color(0xFF101C45),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAccepted
                ? 'Your request was accepted. Help is on the way. Stay at your location and keep your phone nearby.'
                : isPending
                    ? 'Your evacuation request is being reviewed by responders.'
                    : 'If you need immediate help, send your current location to responders.',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isAccepted
                ? ElevatedButton.icon(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C97A),
                      disabledBackgroundColor: const Color(0xFF00C97A),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.local_shipping, color: Colors.white),
                    label: const Text(
                      'Evacuation is Underway',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: (isPending || _isRequestingEvacuation)
                        ? null
                        : _requestEvacuation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101C45),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isRequestingEvacuation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _isRequestingEvacuation
                          ? 'Sending Request...'
                          : isPending
                              ? 'Request Sent – Awaiting Response'
                              : 'Request Evacuation',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
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
                  onTap: () => _openEvacuationMap(site),
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

  // ── GLOBAL HOTLINES SECTION ──────────────────────────────────────────────
  List<Widget> _buildGlobalSection(List<HotlineModel> globals) {
    return [
      Row(
        children: [
          const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF6B7BA4)),
          const SizedBox(width: 4),
          const Text(
            'Official Hotlines',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7BA4),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ...globals.map((h) => _buildHotlineCard(h, isLocal: false)),
    ];
  }

  // ── LOCAL HOTLINES SECTION ───────────────────────────────────────────────
  Widget _buildLocalSection(List<HotlineModel> locals) {
    final slotsLeft = 3 - locals.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header row with Add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 14,
                    color: Color(0xFF6B7BA4)),
                const SizedBox(width: 4),
                const Text(
                  'My Contacts',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7BA4),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: locals.length >= 3
                        ? Colors.orange.withValues(alpha: 0.15)
                        : const Color(0xFF101C45).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${locals.length}/3',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: locals.length >= 3
                          ? Colors.orange
                          : const Color(0xFF101C45),
                    ),
                  ),
                ),
              ],
            ),
            Tooltip(
              message: locals.length >= 3
                  ? 'Maximum 3 personal hotlines'
                  : 'Add personal hotline',
              child: GestureDetector(
                onTap: locals.length >= 3 ? null : _showAddContactDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: locals.length >= 3
                        ? Colors.grey.withValues(alpha: 0.1)
                        : const Color(0xFF101C45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: locals.length >= 3
                            ? Colors.grey
                            : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: locals.length >= 3
                              ? Colors.grey
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (locals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Column(
                children: const [
                  Icon(Icons.contact_phone_outlined,
                      size: 32, color: Color(0xFFCED4E6)),
                  SizedBox(height: 6),
                  Text(
                    'No personal hotlines yet.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap Add to save up to 3 contacts.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ...locals.map((h) => _buildHotlineCard(h, isLocal: true)),

        // Hint text
        if (locals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              slotsLeft > 0
                  ? '$slotsLeft slot${slotsLeft == 1 ? '' : 's'} remaining · Long-press to delete'
                  : 'Maximum reached · Long-press to delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: slotsLeft > 0 ? Colors.grey : Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // ── HOTLINE CARD ─────────────────────────────────────────────────────────
  Widget _buildHotlineCard(HotlineModel hotline, {required bool isLocal}) {
    return GestureDetector(
      onTap: () => _makePhoneCall(hotline.number),
      onLongPress: isLocal ? () => _deleteHotline(hotline) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isLocal
              ? const Color(0xFF1A2755)
              : const Color(0xFF101C45),
          borderRadius: BorderRadius.circular(15),
          border: isLocal
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Badge icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocal ? Icons.person_rounded : Icons.shield_rounded,
                color: isLocal ? Colors.lightBlueAccent : Colors.white70,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              flex: 5,
              child: Text(
                hotline.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Divider
            Container(
              height: 28,
              width: 1,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
            // Number & phone icon
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      hotline.number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.phone_rounded,
                      color: Colors.greenAccent, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog() {
    if (_localHotlineCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only save up to 3 personal hotlines.'),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Add Local Hotline",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You can save up to 3 personal hotlines.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
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
                String rawName = nameController.text;
                String capitalizedName = rawName
                    .split(' ')
                    .map(
                      (word) => word.isNotEmpty
                          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                          : '',
                    )
                    .join(' ');

                try {
                  await _hotlineService.addLocalHotline(
                    capitalizedName,
                    numberController.text,
                  );
                  _refreshList();
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
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

  /// Friendly error card shown when the backend / network is unreachable.
  Widget _buildConnectionErrorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFE65100), size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to connect',
                  style: TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check your internet connection or wait for the server to come online.',
                  style: TextStyle(
                    color: Color(0xFF795548),
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
