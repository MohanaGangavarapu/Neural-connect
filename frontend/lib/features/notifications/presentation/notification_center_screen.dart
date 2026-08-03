import 'package:flutter/material.dart';
import '../domain/notifications_repository.dart';

class NotificationCenterScreen extends StatefulWidget {
  final NotificationsRepository repository;

  const NotificationCenterScreen({super.key, required this.repository});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.repository.fetchNotifications();
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification notif) async {
    if (notif.read) return;
    try {
      await widget.repository.markAsRead(notif.id);
      _loadNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read: $e')),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'FRIEND_REQUEST':
        return Icons.person_add;
      case 'FRIEND_ACCEPTED':
        return Icons.people;
      case 'FRIEND_WORD':
        return Icons.auto_awesome;
      case 'INACTIVITY':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'FRIEND_REQUEST':
        return const Color(0xFF2E6BFF); // Electric Blue
      case 'FRIEND_ACCEPTED':
        return const Color(0xFFD2FF26); // Lime Green
      case 'FRIEND_WORD':
        return const Color(0xFFD2FF26); // Lime Green
      case 'INACTIVITY':
        return Colors.orangeAccent;
      default:
        return Colors.white60;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2036), // Deep Navy
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A2B), // Darker Navy
        elevation: 0,
        title: const Text(
          'notification workspace',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD2FF26)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Text(
                        'Your workspace is quiet.',
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFD2FF26),
                      backgroundColor: const Color(0xFF252B4D),
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          return Card(
                            color: const Color(0xFF252B4D), // Navy Slate
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: notif.read
                                    ? Colors.white.withOpacity(0.05)
                                    : const Color(0xFFD2FF26).withOpacity(0.4),
                                width: notif.read ? 1 : 1.5,
                              ),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () => _markAsRead(notif),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getColorForType(notif.type).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconForType(notif.type),
                                  color: _getColorForType(notif.type),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                notif.message,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: notif.read ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  _timeAgo(notif.createdAt),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ),
                              trailing: notif.read
                                  ? null
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD2FF26),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
