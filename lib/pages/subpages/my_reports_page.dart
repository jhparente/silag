import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/flood_report_model.dart';
import '../../services/flood_report_service.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage>
    with SingleTickerProviderStateMixin {
  final FloodReportService _service = FloodReportService();
  late TabController _tabController;
  late Future<List<FloodReportModel>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reportsFuture = _service.fetchMyReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _reportsFuture = _service.fetchMyReports();
    });
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
          'My Reports',
          style: TextStyle(
            color: Color(0xFF101C45),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF101C45)),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF101C45),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF101C45),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Pending'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: FutureBuilder<List<FloodReportModel>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF101C45)),
            );
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }
          final all = snapshot.data ?? [];
          final approved =
              all.where((r) => r.reportStatus == 'Approved').toList();
          final pending =
              all.where((r) => r.reportStatus == 'Pending').toList();
          final rejected =
              all.where((r) => r.reportStatus == 'Rejected').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportList(approved, 'Approved'),
              _buildReportList(pending, 'Pending'),
              _buildReportList(rejected, 'Rejected'),
            ],
          );
        },
      ),
    );
  }

  // ── TAB CONTENT ──────────────────────────────────────────────────────────
  Widget _buildReportList(List<FloodReportModel> reports, String status) {
    if (reports.isEmpty) {
      return _buildEmptyState(status);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: reports.length,
      itemBuilder: (context, index) => _ReportCard(report: reports[index]),
    );
  }

  Widget _buildEmptyState(String status) {
    final (icon, message) = switch (status) {
      'Approved' => (
          Icons.check_circle_outline,
          'No approved reports yet.\nYour accepted reports will appear here.'
        ),
      'Rejected' => (
          Icons.cancel_outlined,
          'No rejected reports.\nReports declined by an admin will appear here.'
        ),
      _ => (
          Icons.hourglass_empty_rounded,
          'No pending reports.\nSubmit a flood report to get started.'
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontFamily: 'Poppins',
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFE65100), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to load reports',
              style: TextStyle(
                color: Color(0xFF101C45),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101C45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── REPORT CARD ───────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final FloodReportModel report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeIcon) = _badgeStyle(report.reportStatus);
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(
      report.reportedAt.toLocal(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ──
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: report.imageUrl.isNotEmpty
                ? Image.network(
                    report.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge + flood level row
                Row(
                  children: [
                    _StatusBadge(
                      label: report.reportStatus,
                      color: badgeColor,
                      icon: badgeIcon,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101C45).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        report.floodLevel,
                        style: const TextStyle(
                          color: Color(0xFF101C45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Color(0xFF101C45)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.geocodedAddress.isNotEmpty
                            ? report.geocodedAddress
                            : 'Unknown location',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Description
                if (report.safeDescription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    report.safeDescription,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Date
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey[100],
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 40, color: Colors.grey),
      ),
    );
  }

  (Color, IconData) _badgeStyle(String status) {
    return switch (status) {
      'Approved' => (const Color(0xFF2E7D32), Icons.check_circle_rounded),
      'Rejected' => (const Color(0xFFC62828), Icons.cancel_rounded),
      _ => (const Color(0xFFF57C00), Icons.hourglass_top_rounded),
    };
  }
}

// ── STATUS BADGE ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
