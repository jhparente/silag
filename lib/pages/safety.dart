import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/models/sensor_model.dart';
import 'package:silag/pages/subpages/evacuation_map_page.dart';
import 'package:silag/pages/subpages/site_overview_map_page.dart';
import 'package:silag/services/evacuation_request_service.dart';
import 'package:silag/services/evacuation_service.dart';
import 'package:silag/services/sensor_service.dart';
import 'package:silag/widgets/skeleton_loader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hotline_service.dart';
import '../models/hotline_model.dart';

class SafetyPage extends StatefulWidget {
  final bool scrollToEvacuationCenters;
  const SafetyPage({super.key, this.scrollToEvacuationCenters = false});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final _hotlineService = HotlineService();
  final _evacuationService = EvacuationService();
  final _evacuationRequestService = EvacuationRequestService();
  final _sensorService = SensorService();

  late Future<List<HotlineModel>> _hotlinesFuture;
  late Future<List<EvacuationModel>> _evacuationCentersFuture;
  List<SensorModel> _cachedSensors = [];
  List<EvacuationModel> _cachedEvacuationSites = [];
  bool _isRequestingEvacuation = false;
  int _localHotlineCount = 0; // tracks only the user's local hotlines

  // ── Distance filter ──────────────────────────────────────────────────────
  /// 500   = within 500 m  (default)
  /// 1000  = within 1 km
  /// 2000  = within 2 km
  /// -1    = "Closest Available" – show the 2 nearest, ignoring distance cap
  /// null  = no filter (show all)
  int? _distanceFilterMeters = 500;
  double? _userLat;
  double? _userLng;
  bool _isFetchingLocation = false;

  // Evacuation request status tracking
  String? _myEvacuationStatus; // 'pending' | 'accepted' | null
  bool _isCheckingEvacuationStatus = true;
  Timer? _statusPoller;
  bool _shownAcceptedBanner = false;

  final _evacKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToEvacuationCenters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_evacKey.currentContext != null && mounted) {
            Scrollable.ensureVisible(
              _evacKey.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      });
    }
    _hotlinesFuture = _hotlineService.fetchMyHotlines();
    _evacuationCentersFuture = _evacuationService.fetchEvacuationCenters().then((sites) {
      _cachedEvacuationSites = sites;
      return sites;
    });
    _sensorService.fetchSensors().then((s) {
      if (mounted) setState(() => _cachedSensors = s);
    }).catchError((_) {});
    _startStatusPolling();
    // Start fetching location immediately so the default 500 m filter works.
    _ensureUserLocation();

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
    try {
      final data = await _evacuationRequestService.getMyEvacuationRequest();
      if (!mounted) return;
      final status = data?['status'] as String?;
      setState(() {
        _myEvacuationStatus = status;
        _isCheckingEvacuationStatus = false;
      });
      if (status == 'accepted' && !_shownAcceptedBanner) {
        _onEvacuationAccepted(showBanner: false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingEvacuationStatus = false);
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

  // ── Distance filter helpers ──────────────────────────────────────────────

  /// Fetch (or reuse) the user's current position for distance filtering.
  Future<void> _ensureUserLocation() async {
    if (_userLat != null && _userLng != null) return;
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      final pos = await _getCurrentPositionForEvacuation();
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        });
      }
    } catch (_) {
      // silently ignore – chips will stay active but filtering may be skipped
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  /// Apply selected distance filter to [all] centers.
  /// Returns the subset to display.
  List<EvacuationModel> _applyDistanceFilter(List<EvacuationModel> all) {
    if (_distanceFilterMeters == null || _userLat == null || _userLng == null) {
      return all;
    }

    // Sort all centers by distance ascending
    final sorted = [...all];
    sorted.sort((a, b) {
      final da = Geolocator.distanceBetween(_userLat!, _userLng!, a.latitude, a.longitude);
      final db = Geolocator.distanceBetween(_userLat!, _userLng!, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    if (_distanceFilterMeters == -1) {
      // "Closest Available": exclude full centers, then take top-2 nearest.
      final available = sorted.where((c) => !c.isFull).toList();
      if (available.isNotEmpty) return available.take(2).toList();
      // Fallback: all centers are full — still show the 2 nearest so the
      // user knows where to go, but the card's "FULL" badge will be visible.
      return sorted.take(2).toList();
    }

    // Radius filter
    return sorted
        .where((c) =>
            Geolocator.distanceBetween(_userLat!, _userLng!, c.latitude, c.longitude) <=
            _distanceFilterMeters!)
        .toList();
  }

  /// Format distance in metres to a readable string.
  String _formatDistance(EvacuationModel site) {
    if (_userLat == null || _userLng == null) return '';
    final d = Geolocator.distanceBetween(_userLat!, _userLng!, site.latitude, site.longitude);
    if (d < 1000) return '${d.toStringAsFixed(0)} m away';
    return '${(d / 1000).toStringAsFixed(1)} km away';
  }

  /// Called when the user taps a filter chip.
  Future<void> _onFilterTap(int? meters) async {
    if (_distanceFilterMeters == meters) {
      // Toggle off
      setState(() => _distanceFilterMeters = null);
      return;
    }
    setState(() => _distanceFilterMeters = meters);
    await _ensureUserLocation();
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
    // Navigate to the full page form
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (ctx) => const EvacuationRequestForm()),
    );

    if (submitted != true || !mounted) return;

    setState(() => _isRequestingEvacuation = true);

    // The form handles submission internally; we just update local state here
    // after it reports success.
    if (mounted) {
      setState(() {
        _isRequestingEvacuation = false;
        _myEvacuationStatus = 'pending';
      });
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
          otherSites: _cachedEvacuationSites, // all sites, incl. destination (it still gets the red pin)
          sensors: _cachedSensors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar(),
      body: RefreshIndicator(
        color: const Color(0xFF101C45),
        onRefresh: () async {
          // Re-fetch all data + user location in parallel
          await Future.wait([
            Future(() => setState(() {
              _hotlinesFuture = _hotlineService.fetchMyHotlines();
              _evacuationCentersFuture = _evacuationService
                  .fetchEvacuationCenters()
                  .then((sites) {
                _cachedEvacuationSites = sites;
                return sites;
              });
            })),
            _sensorService.fetchSensors().then((s) {
              if (mounted) setState(() => _cachedSensors = s);
            }).catchError((_) {}),
            _checkEvacuationStatus(),
            // Refresh location so distance filter stays accurate
            (() async {
              _userLat = null;
              _userLng = null;
              await _ensureUserLocation();
            })(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 40),
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

            // --- EVACUATION CENTERS HEADER + FILTER CHIPS ---
            Row(
              key: _evacKey,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Evacuation Centers",
                  style: TextStyle(
                    color: Color(0xFF101C45),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Poppins',
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteOverviewMapPage(
                          sites: _cachedEvacuationSites,
                          sensors: _cachedSensors,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF101C45)),
                  label: const Text(
                    'View Map',
                    style: TextStyle(
                      color: Color(0xFF101C45),
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF1FA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Distance Filter Chips ─────────────────────────────────────
            _buildDistanceFilterChips(),
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

                final allCenters = snapshot.data ?? [];
                final centers = _applyDistanceFilter(allCenters);

                if (allCenters.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No evacuation centers found.")),
                  );
                }

                if (centers.isEmpty) {
                  return _buildNoNearbyCard();
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
                    onPressed: (isPending || _isRequestingEvacuation || _isCheckingEvacuationStatus)
                        ? null
                        : _requestEvacuation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101C45),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: (_isRequestingEvacuation || _isCheckingEvacuationStatus)
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
                      _isCheckingEvacuationStatus
                          ? 'Checking Status...'
                          : _isRequestingEvacuation
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

  // ── Distance filter chip row ────────────────────────────────────────────
  Widget _buildDistanceFilterChips() {
    const chips = [
      (label: '500 m',             meters: 500),
      (label: '1 km',              meters: 1000),
      (label: '2 km',              meters: 2000),
      (label: 'Closest Available', meters: -1),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = _distanceFilterMeters == chip.meters;
          final isLoading  = isSelected && _isFetchingLocation;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onFilterTap(chip.meters),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF101C45)
                      : const Color(0xFFEEF1FA),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF101C45)
                        : const Color(0xFFCED4E6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ] else if (chip.meters == -1) ...[
                      const Icon(
                        Icons.near_me_rounded,
                        size: 14,
                        color: Color(0xFF101C45),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      const Icon(
                        Icons.social_distance_rounded,
                        size: 14,
                        color: Color(0xFF6B7BA4),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      chip.label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF101C45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state when no centers match the filter ──────────────────────
  Widget _buildNoNearbyCard() {
    final filterLabel = _distanceFilterMeters == 500
        ? '500 m'
        : _distanceFilterMeters == 1000
            ? '1 km'
            : '2 km';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCED4E6)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 36,
            color: Color(0xFF6B7BA4),
          ),
          const SizedBox(height: 10),
          Text(
            'No evacuation centers within $filterLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF101C45),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try the “Closest Available” filter to see the nearest centers regardless of distance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF6B7BA4),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _onFilterTap(-1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101C45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Show Closest Available',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            site.isFull
                                ? Icons.warning_rounded
                                : Icons.check_circle_rounded,
                            size: 14,
                            color: site.isFull
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            site.isFull
                                ? "FULL"
                                : "Available",
                            style: TextStyle(
                              color: site.isFull
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          // ── Distance badge ───────────────────────
                          if (_distanceFilterMeters != null &&
                              _userLat != null &&
                              _userLng != null) ...[
                            const SizedBox(width: 8),
                            const Text('\u00b7',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.social_distance_rounded,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDistance(site),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ],
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
    String? nameError;
    String? numberError;
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
              // Name field
              TextField(
                controller: nameController,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (nameError != null) {
                    setDialogState(() => nameError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Name",
                  hintText: "e.g. Mom",
                  errorText: nameError,
                ),
              ),
              // Number field
              TextField(
                controller: numberController,
                maxLength: 11,
                onChanged: (_) {
                  if (numberError != null) {
                    setDialogState(() => numberError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Number",
                  hintText: "0912...",
                  errorText: numberError,
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
              onPressed: isAdding ? null : () async {
                // Validate
                final nameVal = nameController.text.trim();
                final numVal = numberController.text.trim();
                String? newNameErr;
                String? newNumErr;

                if (nameVal.isEmpty) {
                  newNameErr = 'Please enter a name';
                } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(nameVal)) {
                  newNameErr = 'Name cannot contain special characters';
                }

                if (numVal.isEmpty) {
                  newNumErr = 'Please enter a number';
                } else if (!numVal.startsWith('09')) {
                  newNumErr = 'Number must start with 09';
                } else if (numVal.length != 11) {
                  newNumErr = 'Number must be 11 digits';
                }

                if (newNameErr != null || newNumErr != null) {
                  setDialogState(() {
                    nameError = newNameErr;
                    numberError = newNumErr;
                  });
                  return;
                }

                setDialogState(() {
                  nameError = null;
                  numberError = null;
                  isAdding = true;
                });

                String capitalizedName = nameVal
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
                    numVal,
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
                  if (mounted) setDialogState(() => isAdding = false);
                }
              },
              child: isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text("Add", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// EVACUATION REQUEST FORM  (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class EvacuationRequestForm extends StatefulWidget {
  const EvacuationRequestForm({super.key});

  @override
  State<EvacuationRequestForm> createState() => EvacuationRequestFormState();
}

class EvacuationRequestFormState extends State<EvacuationRequestForm> {
  final _evacuationRequestService = EvacuationRequestService();
  final _additionalInfoController = TextEditingController();
  final _pwdOthersSpecController = TextEditingController();
  final _picker = ImagePicker();

  bool _isSubmitting = false;
  File? _proofImage;
  bool _showPhotoError = false;

  // ── Household counts ─────────────────────────────────────────
  int _adultsMale = 0;
  int _adultsFemale = 0;
  int _minorsMale = 0;
  int _minorsFemale = 0;
  int _toddlersMale = 0;
  int _toddlersFemale = 0;
  int _infantsMale = 0;
  int _infantsFemale = 0;
  int _seniorsMale = 0;
  int _seniorsFemale = 0;

  // ── Health conditions ────────────────────────────────────────
  int _lactatingCount = 0;
  int _pregnantCount = 0;
  int _injuredCount = 0;
  int _pwdCount = 0;

  int get _total =>
      _adultsMale + _adultsFemale +
      _minorsMale + _minorsFemale +
      _toddlersMale + _toddlersFemale +
      _infantsMale + _infantsFemale +
      _seniorsMale + _seniorsFemale;

  @override
  void initState() {
    super.initState();
    _checkBypass();
  }

  Future<void> _checkBypass() async {
    try {
      final req = await _evacuationRequestService.getMyEvacuationRequest();
      if (req != null && req['status'] != null && mounted) {
        // User already has an active request! Pop immediately to prevent bypass.
        Navigator.pop(context, false);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    _pwdOthersSpecController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // close the source picker
    final picked = await _picker.pickImage(source: source, imageQuality: 75);
    if (picked != null && mounted) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF101C45)),
              title: const Text('Take a Photo', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF101C45)),
              title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_proofImage == null) {
      setState(() => _showPhotoError = true);
      return;
    }
    setState(() => _showPhotoError = false);

    setState(() => _isSubmitting = true);

    try {
      // Get GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await _evacuationRequestService.requestEvacuation(
        latitude: position.latitude,
        longitude: position.longitude,
        adultsMale: _adultsMale,
        adultsFemale: _adultsFemale,
        minorsMale: _minorsMale,
        minorsFemale: _minorsFemale,
        toddlersMale: _toddlersMale,
        toddlersFemale: _toddlersFemale,
        infantsMale: _infantsMale,
        infantsFemale: _infantsFemale,
        seniorsMale: _seniorsMale,
        seniorsFemale: _seniorsFemale,
        lactatingCount: _lactatingCount,
        pregnantCount: _pregnantCount,
        injuredCount: _injuredCount,
        pwdCount: _pwdCount,
        pwdTypeSpec: _pwdOthersSpecController.text.trim().isEmpty
            ? null
            : _pwdOthersSpecController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim().isEmpty
            ? null
            : _additionalInfoController.text.trim(),
        proofImage: _proofImage,
      );

      if (mounted) Navigator.pop(context, true); // signal success to SafetyPage
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── UI helpers ───────────────────────────────────────────────

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF101C45),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
        ],
      ),
    );
  }

  /// A compact row: label | M stepper | F stepper
  Widget _groupRow({
    required String label,
    required String ageRange,
    required int maleVal,
    required int femaleVal,
    required ValueChanged<int> onMaleChanged,
    required ValueChanged<int> onFemaleChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
                Text(ageRange,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          _stepper(label: 'M', value: maleVal, onChanged: onMaleChanged),
          const SizedBox(width: 12),
          _stepper(label: 'F', value: femaleVal, onChanged: onFemaleChanged),
        ],
      ),
    );
  }

  Widget _stepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B))),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: value > 0 ? () => setState(() => onChanged(value - 1)) : null,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: value > 0 ? const Color(0xFFE8ECF4) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.remove, size: 14,
                color: value > 0 ? const Color(0xFF101C45) : const Color(0xFFCBD5E1)),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF101C45)),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => onChanged(value + 1)),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF101C45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _countField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF1E293B))),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: value > 0 ? () => setState(() => onChanged(value - 1)) : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: value > 0 ? const Color(0xFFE8ECF4) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.remove, size: 14,
                      color: value > 0 ? const Color(0xFF101C45) : const Color(0xFFCBD5E1)),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF101C45))),
              ),
              GestureDetector(
                onTap: () => setState(() => onChanged(value + 1)),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101C45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF101C45)),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

            // ── Title ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF1FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_run_rounded,
                      color: Color(0xFF101C45), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request Evacuation',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF101C45))),
                      Text('Help us prepare the right resources for you.',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE8ECF4)),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════
            // SECTION 1 — HOUSEHOLD COUNT
            // ═══════════════════════════════════════════════════
            _sectionHeader(
              'Household Count',
              subtitle: 'How many people need evacuation?',
            ),
            _groupRow(
              label: 'Adults',
              ageRange: '18 years and above',
              maleVal: _adultsMale,
              femaleVal: _adultsFemale,
              onMaleChanged: (v) => _adultsMale = v,
              onFemaleChanged: (v) => _adultsFemale = v,
            ),
            _groupRow(
              label: 'Minors',
              ageRange: '4 – 17 years old',
              maleVal: _minorsMale,
              femaleVal: _minorsFemale,
              onMaleChanged: (v) => _minorsMale = v,
              onFemaleChanged: (v) => _minorsFemale = v,
            ),
            _groupRow(
              label: 'Toddlers',
              ageRange: '1 – 3 years old',
              maleVal: _toddlersMale,
              femaleVal: _toddlersFemale,
              onMaleChanged: (v) => _toddlersMale = v,
              onFemaleChanged: (v) => _toddlersFemale = v,
            ),
            _groupRow(
              label: 'Infants',
              ageRange: '0 – 11 months',
              maleVal: _infantsMale,
              femaleVal: _infantsFemale,
              onMaleChanged: (v) => _infantsMale = v,
              onFemaleChanged: (v) => _infantsFemale = v,
            ),
            _groupRow(
              label: 'Seniors',
              ageRange: '60 years and above',
              maleVal: _seniorsMale,
              femaleVal: _seniorsFemale,
              onMaleChanged: (v) => _seniorsMale = v,
              onFemaleChanged: (v) => _seniorsFemale = v,
            ),

            // ── Auto-total ──────────────────────────────────────
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Persons',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF101C45))),
                  Text(
                    '$_total',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF101C45)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE8ECF4)),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════
            // SECTION 2 — HEALTH CONDITIONS
            // ═══════════════════════════════════════════════════
            _sectionHeader(
              'Health / Special Conditions',
              subtitle: 'For medical preparedness',
            ),
            _countField(
              label: 'Lactating Women',
              value: _lactatingCount,
              onChanged: (v) => _lactatingCount = v,
            ),
            _countField(
              label: 'Pregnant Women',
              value: _pregnantCount,
              onChanged: (v) => _pregnantCount = v,
            ),

            _countField(
              label: 'Injured Persons',
              value: _injuredCount,
              onChanged: (v) => _injuredCount = v,
            ),
            _countField(
              label: 'Person with Disability (PWD)',
              value: _pwdCount,
              onChanged: (v) => _pwdCount = v,
            ),
            if (_pwdCount > 0) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _pwdOthersSpecController,
                decoration: InputDecoration(
                  labelText: 'Specify type of disability',
                  labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE8ECF4)),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════
            // SECTION 3 — ADDITIONAL INFORMATION
            // ═══════════════════════════════════════════════════
            _sectionHeader(
              'Additional Information',
              subtitle:
                  'List things responders must bring (e.g. oxygen, wheelchair, medications)',
            ),
            TextField(
              controller: _additionalInfoController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g. Oxygen tank needed, diabetic patient, etc.',
                hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFADB5C7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE8ECF4)),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════
            // SECTION 4 — PROOF PHOTO
            // ═══════════════════════════════════════════════════
            _sectionHeader(
              'Proof Photo',
              subtitle: 'Required — helps verify the request (e.g. current situation, Barangay ID)',
            ),
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _proofImage != null
                        ? const Color(0xFF00C97A)
                        : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: _proofImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_proofImage!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _proofImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo_outlined, size: 36, color: Color(0xFFADB5C7)),
                          SizedBox(height: 8),
                          Text('Tap to attach photo',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFFADB5C7))),
                          SizedBox(height: 4),
                          Text('Camera or Gallery',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Color(0xFFCBD5E1))),
                        ],
                      ),
              ),
            ),

            if (_showPhotoError) ...[
              const SizedBox(height: 8),
              const Text(
                'Please attach a proof photo before submitting.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Submit & Cancel buttons ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101C45),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Send Evacuation Request',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}
