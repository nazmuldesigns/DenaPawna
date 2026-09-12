import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
}

class NotificationService {
  const NotificationService(this.client);

  final SupabaseClient? client;

  Future<List<AppNotification>> loadNotifications() async {
    final configuredClient = client;
    final userId = configuredClient?.auth.currentUser?.id;
    if (configuredClient == null || userId == null) return const [];

    final rows = await configuredClient
        .from('user_notifications')
        .select('id, title, message, created_at, read_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) {
      final createdAt = DateTime.tryParse('${row['created_at']}');
      if (createdAt == null) {
        throw const FormatException('Invalid notification timestamp');
      }
      return AppNotification(
        id: '${row['id']}',
        title: '${row['title']}',
        message: '${row['message']}',
        createdAt: createdAt,
        isRead: row['read_at'] != null,
      );
    }).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    final configuredClient = client;
    final userId = configuredClient?.auth.currentUser?.id;
    if (configuredClient == null || userId == null) return;

    await configuredClient
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }
}
