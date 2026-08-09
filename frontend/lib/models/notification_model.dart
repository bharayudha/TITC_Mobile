import 'package:magang_titc/models/member_model.dart';
import 'package:magang_titc/models/activity_model.dart';

class NotificationModel {
  final int id;
  final String action;
  final String componentKey;
  bool isRead;
  final String dateNotified;
  final MemberModel? actor;
  final String? url;
  final String content;
  final Map<String, dynamic>? route;

  NotificationModel({
    required this.id,
    required this.action,
    required this.componentKey,
    required this.isRead,
    required this.dateNotified,
    this.actor,
    this.url,
    required this.content,
    this.route,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actorJson = json['xprofile'] ?? json['actor'];
    
    // Some endpoints return 'read_at', others might use 'is_read'
    bool readStatus = false;
    if (json.containsKey('read_at')) {
      readStatus = json['read_at'] != null;
    } else if (json.containsKey('is_read')) {
      readStatus = json['is_read'] == 1 || json['is_read'] == true;
    }

    return NotificationModel(
      id: json['id'] ?? 0,
      action: json['action'] ?? '',
      componentKey: json['component_key'] ?? json['src_object_type'] ?? '',
      isRead: readStatus,
      dateNotified: json['created_at'] ?? json['date_notified'] ?? '',
      actor: actorJson != null ? MemberModel.fromJson(actorJson) : null,
      url: json['url'] ?? json['link'],
      content: json['content'] ?? json['message'] ?? 'Notification',
      route: json['route'] as Map<String, dynamic>?,
    );
  }
}
