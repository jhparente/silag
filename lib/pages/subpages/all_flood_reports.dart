import 'package:flutter/material.dart';
import 'package:silag/models/flood_report_model.dart';
import 'package:silag/services/flood_report_service.dart';
import 'package:silag/widgets/report_details_dialog.dart';

class AllFloodReportsPage extends StatefulWidget {
  const AllFloodReportsPage({super.key});

  @override
  State<AllFloodReportsPage> createState() => _AllFloodReportsPageState();
}

class _AllFloodReportsPageState extends State<AllFloodReportsPage> {
  final _floodReportService = FloodReportService();
  late Future<List<FloodReportModel>> _allReportsFuture;

  @override
  void initState() {
    super.initState();
    // Fetching ALL reports using the new service method
    _allReportsFuture = _floodReportService.fetchAllValidReports();
  }

  // Helper for time calculation
  String _getTimeAgo(DateTime acceptedAt) {
    final diff = DateTime.now().difference(acceptedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  String _truncateDescription(String text, {int maxLength = 100}) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    if (maxLength <= 3) {
      return trimmed.substring(0, maxLength);
    }
    return '${trimmed.substring(0, maxLength - 3).trimRight()}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1, // Slight shadow for a clean look
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
          "All Flood Reports",
          style: TextStyle(
            color: Color(0xFF101C45),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: FutureBuilder<List<FloodReportModel>>(
        future: _allReportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF101C45)),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading reports"));
          }

          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(
              child: Text("No reports from the last 32 hours."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _buildReportListItem(reports[index]);
            },
          );
        },
      ),
    );
  }

  // --- LIST ITEM WIDGET ---
  Widget _buildReportListItem(FloodReportModel report) {
    final description = _truncateDescription(report.safeDescription);
    return GestureDetector(
      // Reusing the global function we created in the widgets folder!
      onTap: () => showReportDetails(context, report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Thumbnail Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: Image.network(
                report.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),

            // Text Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.floodLevel,
                      style: const TextStyle(
                        color: Color(0xFF101C45),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      report.uploaderName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      report.address,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(report.acceptedAt ?? report.reportedAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Arrow indicator
            const Padding(
              padding: EdgeInsets.only(right: 15.0),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
