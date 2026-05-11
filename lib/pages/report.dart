import 'package:flutter/material.dart';
import 'package:silag/pages/subpages/all_flood_reports.dart';
import 'package:silag/pages/subpages/create_report.dart';
import 'package:silag/widgets/report_details_dialog.dart';
import 'package:silag/widgets/skeleton_loader.dart';
import '../services/community_status_services.dart';
import '../models/community_status_model.dart';
import '../services/flood_report_service.dart';
import '../models/flood_report_model.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _communityStatusService = CommunityStatusServices();
  final _floodReportService = FloodReportService();

  CommunitySafetyStatus? _stats;
  Future<List<FloodReportModel>>? _recentReportsFuture;

  bool _isLoading = true;
  bool _hasVoted = false;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _recentReportsFuture = _floodReportService.fetchRecentReports();
  }

  Future<void> _loadStats() async {
    final stats = await _communityStatusService.fetchCommunitySafetyStatus();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _markSafe() async {
    if (_hasVoted || _isVoting) return;
    setState(() => _isVoting = true);
    try {
      await _communityStatusService.castVote(true);
      setState(() {
        _hasVoted = true;
        _stats!.safeCount += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _markNotSafe() async {
    if (_hasVoted || _isVoting) return;
    setState(() => _isVoting = true);
    try {
      await _communityStatusService.castVote(false);
      setState(() {
        _hasVoted = true;
        _stats!.unsafeCount += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  String _getTimeAgo(DateTime acceptedAt) {
    final diff = DateTime.now().difference(acceptedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  Future<void> _refresh() async {
    await _loadStats();
    setState(() {
      _recentReportsFuture = _floodReportService.fetchRecentReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar(),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF101C45),
          onPressed: () async {
            // Wait for the CreateReportPage to close
            final bool? shouldRefresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateReportPage()),
            );

            // If a report was successfully submitted, refresh the recent images!
            if (shouldRefresh == true) {
              setState(() {
                _recentReportsFuture = _floodReportService.fetchRecentReports();
              });
            }
          },
          child: const Icon(Icons.camera_alt, color: Colors.white),
        ),
      ),

      body: _isLoading
          ? _buildReportSkeleton()
          : RefreshIndicator(
              color: const Color(0xFF101C45),
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            _stats!.safeCount.toString(),
                            "Marked Safe",
                            Icons.gpp_good,
                            Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            _stats!.unsafeCount.toString(),
                            "Not Safe",
                            Icons.gpp_bad,
                            Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            _stats!.todaysReports.toString(),
                            "Today's Reports",
                            null,
                            null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Are you safe?",
                      style: TextStyle(
                        color: Color(0xFF101C45),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_hasVoted || _isVoting)
                                ? null
                                : _markSafe,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: const BorderSide(
                                color: Color(0xFF101C45),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              foregroundColor: const Color(0xFF101C45),
                            ),
                            child: const Text(
                              "Yes, I'm safe",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_hasVoted || _isVoting)
                                ? null
                                : _markNotSafe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF101C45),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "No, I'm not safe",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_hasVoted)
                      const Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: Text(
                          "Thank you for updating your status.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recently Uploaded",
                          style: TextStyle(
                            color: Color(0xFF101C45),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AllFloodReportsPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "View All",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 180,
                      child: FutureBuilder<List<FloodReportModel>>(
                        future: _recentReportsFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !snapshot.hasError) {
                            return const SizedBox(
                              height: 180,
                              child: Center(child: _FloodReportRowSkeleton()),
                            );
                          }
                          if (snapshot.hasError) {
                            return const SizedBox(
                              height: 180,
                              child: Center(
                                child: _ConnectionErrorInline(),
                              ),
                            );
                          }

                          final reports = snapshot.data ?? [];
                          if (reports.isEmpty) {
                            return const Center(
                              child: Text("No recent reports."),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: reports.length,
                            itemBuilder: (context, index) {
                              return _buildImageCard(reports[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageCard(FloodReportModel report) {
    return GestureDetector(
      onTap: () => showReportDetails(context, report),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: NetworkImage(report.imageUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {},
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              stops: const [0.0, 0.5],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Reporter avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        (report.profilePictureUrl != null &&
                            report.profilePictureUrl!.isNotEmpty)
                        ? NetworkImage(report.profilePictureUrl!)
                        : null,
                    child:
                        (report.profilePictureUrl == null ||
                            report.profilePictureUrl!.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.uploaderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          report.floodLevel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          _getTimeAgo(report.acceptedAt ?? report.reportedAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
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

  Widget _buildStatCard(
    String number,
    String label,
    IconData? icon,
    Color? iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101C45),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          if (icon != null)
            Positioned(
              top: -5,
              right: -5,
              child: Icon(icon, color: iconColor, size: 16),
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
        "Flood Reports",
        style: TextStyle(
          color: Color(0xFF101C45),
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  /// Full-page skeleton shown while the community stats are loading.
  Widget _buildReportSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards row
          const ReportStatSkeleton(),
          const SizedBox(height: 30),
          // "Are you safe?" button row
          const LightShimmerBox(height: 20, width: 120, borderRadius: 6),
          const SizedBox(height: 15),
          const LightShimmerBox(height: 50, borderRadius: 10),
          const SizedBox(height: 40),
          // Section heading
          const LightShimmerBox(height: 18, width: 160, borderRadius: 6),
          const SizedBox(height: 10),
          // Horizontal image cards — use ListView to avoid overflow
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                width: 200,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: const LightShimmerBox(height: 180, borderRadius: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Private helper widgets ------------------------------------------------

/// Skeleton row for the horizontal recent-reports strip.
class _FloodReportRowSkeleton extends StatelessWidget {
  const _FloodReportRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        width: 200,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3FF),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: const LightShimmerBox(height: 180, borderRadius: 15),
        ),
      ),
    );
  }
}

/// Compact offline / error notice used inline inside the reports section.
class _ConnectionErrorInline extends StatelessWidget {
  const _ConnectionErrorInline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.wifi_off_rounded, color: Color(0xFFE65100), size: 20),
        SizedBox(width: 8),
        Text(
          'Could not load reports',
          style: TextStyle(
            color: Color(0xFFE65100),
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
