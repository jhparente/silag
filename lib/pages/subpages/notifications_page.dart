// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:silag/models/notification_model.dart';
import 'package:silag/services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Categorization Helpers
// ─────────────────────────────────────────────────────────────────────────────
enum NotifCategory { all, sensor, floodReport, evacuation }

NotifCategory _categorize(NotificationModel n) {
  final text = '${n.title} ${n.body}'.toLowerCase();
  if (text.contains('evacuation') || text.contains('rescue')) {
    return NotifCategory.evacuation;
  }
  if (text.contains('flood report') || text.contains('report status')) {
    return NotifCategory.floodReport;
  }
  // If it's a sensor reading, water level alert, etc.
  if (text.contains('sensor') ||
      text.contains('water level') ||
      text.contains('alert') ||
      text.contains('critical')) {
    return NotifCategory.sensor;
  }
  // Default to sensor if it doesn't match evac/report (most system alerts are sensor-related)
  return NotifCategory.sensor; 
}

enum SubFilter { all, unread, read, pending, approve, reject }

SubFilter _getSubFilterStatus(NotificationModel n) {
  final text = '${n.title} ${n.body}'.toLowerCase();
  if (text.contains('accept') || text.contains('approv') || text.contains('success')) {
    return SubFilter.approve;
  }
  if (text.contains('reject') || text.contains('declin')) {
    return SubFilter.reject;
  }
  return SubFilter.pending; // Assume pending if no final status is mentioned
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-page Notifications Screen
// ─────────────────────────────────────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  final List<NotificationModel> notifications;
  final VoidCallback? onNotificationsRead;

  const NotificationsPage({
    super.key,
    required this.notifications,
    this.onNotificationsRead,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notifService = NotificationService();
  late List<NotificationModel> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List.from(widget.notifications);
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isReadLocally).toList();
    if (unread.isEmpty) return;
    
    final unreadIds = unread.map((n) => n.id).toList();
    await _notifService.markAllAsRead(unreadIds);
    
    setState(() {
      for (final n in _notifications) {
        n.isReadLocally = true;
      }
    });
    widget.onNotificationsRead?.call();
  }

  Future<void> _openDetail(NotificationModel notif) async {
    if (!notif.isReadLocally) {
      await _notifService.markAsRead(notif.id);
      setState(() => notif.isReadLocally = true);
      widget.onNotificationsRead?.call();
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(notification: notif),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isReadLocally).length;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF101C45),
          elevation: 1,
          title: const Text(
            'Notifications',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            if (unreadCount > 0)
              TextButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all_rounded, color: Color(0xFF101C45), size: 18),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: Color(0xFF101C45),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF101C45),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF101C45),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              _buildTab('All', _notifications.where((n) => !n.isReadLocally).length),
              _buildTab('Sensor Readings', _notifications.where((n) => _categorize(n) == NotifCategory.sensor && !n.isReadLocally).length),
              _buildTab('Flood Report', _notifications.where((n) => _categorize(n) == NotifCategory.floodReport && !n.isReadLocally).length),
              _buildTab('Request Evacuation', _notifications.where((n) => _categorize(n) == NotifCategory.evacuation && !n.isReadLocally).length),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // All Tab (Filters: All, Unread, Read)
            _CategoryTabView(
              notifications: _notifications,
              category: NotifCategory.all,
              filterOptions: const [SubFilter.all, SubFilter.unread, SubFilter.read],
              onTapNotif: _openDetail,
            ),
            // Sensor Readings Tab (Filters: All, Unread, Read)
            _CategoryTabView(
              notifications: _notifications.where((n) => _categorize(n) == NotifCategory.sensor).toList(),
              category: NotifCategory.sensor,
              filterOptions: const [SubFilter.all, SubFilter.unread, SubFilter.read],
              onTapNotif: _openDetail,
            ),
            // Flood Report Tab (Filters: All, Pending, Approve, Reject)
            _CategoryTabView(
              notifications: _notifications.where((n) => _categorize(n) == NotifCategory.floodReport).toList(),
              category: NotifCategory.floodReport,
              filterOptions: const [SubFilter.all, SubFilter.pending, SubFilter.approve, SubFilter.reject],
              onTapNotif: _openDetail,
            ),
            // Evacuation Tab (Filters: All, Pending, Approve, Reject)
            _CategoryTabView(
              notifications: _notifications.where((n) => _categorize(n) == NotifCategory.evacuation).toList(),
              category: NotifCategory.evacuation,
              filterOptions: const [SubFilter.all, SubFilter.pending, SubFilter.approve, SubFilter.reject],
              onTapNotif: _openDetail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF101C45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Tab View (Handles Sub-filters)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryTabView extends StatefulWidget {
  final List<NotificationModel> notifications;
  final NotifCategory category;
  final List<SubFilter> filterOptions;
  final Function(NotificationModel) onTapNotif;

  const _CategoryTabView({
    required this.notifications,
    required this.category,
    required this.filterOptions,
    required this.onTapNotif,
  });

  @override
  State<_CategoryTabView> createState() => _CategoryTabViewState();
}

class _CategoryTabViewState extends State<_CategoryTabView> {
  SubFilter _selectedFilter = SubFilter.all;

  List<NotificationModel> get _filteredNotifications {
    return widget.notifications.where((n) {
      if (_selectedFilter == SubFilter.all) return true;
      
      // Read/Unread filters
      if (_selectedFilter == SubFilter.unread) return !n.isReadLocally;
      if (_selectedFilter == SubFilter.read) return n.isReadLocally;

      // Status filters
      final status = _getSubFilterStatus(n);
      return status == _selectedFilter;
    }).toList();
  }

  String _getTimeCategory(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    if (difference <= 7) return 'This Week';
    if (difference <= 14) return '1 week ago';
    if (difference <= 21) return '2 weeks ago';
    if (difference <= 28) return '3 weeks ago';
    return 'Previous Months';
  }

  String _filterName(SubFilter f) {
    switch (f) {
      case SubFilter.all: return 'All';
      case SubFilter.unread: return 'Unread';
      case SubFilter.read: return 'Read';
      case SubFilter.pending: return 'Pending';
      case SubFilter.approve: return 'Approved';
      case SubFilter.reject: return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredNotifications;
    // Sort by newest first
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        // Filter Chips Row
        Container(
          width: double.infinity,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterName(filter)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                    selectedColor: const Color(0xFFEBF0FE),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF101C45) : Colors.grey[700],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF101C45) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        // Notifications List
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications found.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) {
                    final groupedWidgets = <Widget>[];
                    String? currentCategory;
                    for (final notif in list) {
                      final category = _getTimeCategory(notif.createdAt);
                      if (category != currentCategory) {
                        currentCategory = category;
                        groupedWidgets.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      groupedWidgets.add(_NotificationCard(
                        notif: notif,
                        onTap: () => widget.onTapNotif(notif),
                      ));
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      itemCount: groupedWidgets.length,
                      itemBuilder: (_, i) => groupedWidgets[i],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Card UI
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;

  const _NotificationCard({required this.notif, required this.onTap});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(local);
  }

  IconData _getIcon() {
    final cat = _categorize(notif);
    if (cat == NotifCategory.sensor) return Icons.sensors_rounded;
    if (cat == NotifCategory.floodReport) return Icons.report_problem_rounded;
    if (cat == NotifCategory.evacuation) return Icons.directions_run_rounded;
    return Icons.campaign_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isReadLocally;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? const Color(0xFF101C45).withOpacity(0.3) : Colors.transparent,
          ),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: const Color(0xFF101C45).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnread ? const Color(0xFFEBF0FE) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(),
                  color: isUnread ? const Color(0xFF101C45) : Colors.grey[400],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              color: const Color(0xFF101C45),
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF101C45),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(
                          _formatTime(notif.createdAt),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Detail Page
// ─────────────────────────────────────────────────────────────────────────────
class NotificationDetailPage extends StatelessWidget {
  final NotificationModel notification;

  const NotificationDetailPage({super.key, required this.notification});

  String _formatFull(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('EEEE, MMMM d, y • h:mm a').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101C45),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notification',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero icon card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF101C45), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF101C45).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatFull(notification.createdAt),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF101C45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 14),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Meta info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildMeta(
                    icon: Icons.calendar_today_rounded,
                    label: 'Received',
                    value: _formatFull(notification.createdAt),
                  ),
                  const SizedBox(height: 10),
                  _buildMeta(
                    icon: Icons.group_rounded,
                    label: 'Audience',
                    value: notification.targetAudience == 'both'
                        ? 'Everyone'
                        : notification.targetAudience,
                  ),
                  const SizedBox(height: 10),
                  _buildMeta(
                    icon: Icons.check_circle_rounded,
                    label: 'Status',
                    value: 'Read',
                    valueColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Back button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101C45),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Notifications',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF101C45).withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF101C45),
            ),
          ),
        ),
      ],
    );
  }
}
