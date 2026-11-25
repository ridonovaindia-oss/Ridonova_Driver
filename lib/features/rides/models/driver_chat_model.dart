import 'package:intl/intl.dart';

class ChatMessageModel {
  final String id;
  final String rideId;
  final String senderId;
  final String senderRole; // 'driver' | 'rider'
  final String senderName;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final bool isPending;
  final bool isFailed;

  ChatMessageModel({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.isPending = false,
    this.isFailed = false,
  });

  bool get isMe {
    final role = senderRole.toLowerCase().trim();
    return role == 'driver' || role == 'captain';
  }

  String get formattedTime {
    try {
      return DateFormat('hh:mm a').format(createdAt.toLocal());
    } catch (_) {
      return '';
    }
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['created_at'] ?? json['createdAt'] ?? json['timestamp'];
    if (rawDate != null) {
      if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else {
        parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    final senderMap = json['sender'] is Map
        ? Map<String, dynamic>.from(json['sender'] as Map)
        : null;

    final rawRole = json['sender_role'] ??
        json['senderRole'] ??
        json['role'] ??
        senderMap?['role'] ??
        'driver';
    final roleStr = rawRole.toString();
    final isDriverRole = roleStr.toLowerCase().trim() == 'driver' ||
        roleStr.toLowerCase().trim() == 'captain';

    final rawName = json['sender_name'] ??
        json['senderName'] ??
        senderMap?['fullName'] ??
        senderMap?['full_name'] ??
        senderMap?['name'];

    return ChatMessageModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      rideId: (json['ride_id'] ?? json['rideId'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['senderId'] ?? senderMap?['id'] ?? senderMap?['_id'] ?? '').toString(),
      senderRole: roleStr,
      senderName: (rawName != null && rawName.toString().trim().isNotEmpty)
          ? rawName.toString()
          : (isDriverRole ? 'Driver' : 'Passenger'),
      message: (json['message'] ?? json['message_text'] ?? json['messageText'] ?? json['text'] ?? json['content'] ?? json['body'] ?? '').toString(),
      isRead: json['is_read'] == true || json['isRead'] == true,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'sender_name': senderName,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? rideId,
    String? senderId,
    String? senderRole,
    String? senderName,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    bool? isPending,
    bool? isFailed,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class DriverChatHistoryResponse {
  final String rideId;
  final String status;
  final bool canChat;
  final String role;
  final List<String> quickReplies;
  final List<ChatMessageModel> messages;

  static const List<String> defaultQuickReplies = [
    'I have arrived at your pickup point',
    'Stuck in traffic, reaching in 2-3 mins',
    'Please come to the pickup point',
    'I am waiting outside',
    'OK, got it!',
  ];

  DriverChatHistoryResponse({
    required this.rideId,
    required this.status,
    required this.canChat,
    this.role = 'driver',
    this.quickReplies = defaultQuickReplies,
    this.messages = const [],
  });

  factory DriverChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final rawReplies = data['quickReplies'] ?? data['quick_replies'];
    List<String> replies = defaultQuickReplies;
    if (rawReplies is List && rawReplies.isNotEmpty) {
      replies = rawReplies.map((e) => e.toString()).toList();
    }

    final rawMsgs = data['messages'] ?? data['chatMessages'] ?? data['history'];
    List<ChatMessageModel> parsedMessages = [];
    if (rawMsgs is List) {
      parsedMessages = rawMsgs
          .whereType<Map>()
          .map((m) => ChatMessageModel.fromJson(Map<String, dynamic>.from(m)))
          .where((m) => m.message.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final statusStr = (data['status'] ?? '').toString().toLowerCase();
    final canChatBool = data['canChat'] != null
        ? (data['canChat'] == true)
        : (data['can_chat'] != null
            ? (data['can_chat'] == true)
            : (statusStr != 'completed' && statusStr != 'cancelled'));

    return DriverChatHistoryResponse(
      rideId: (data['rideId'] ?? data['ride_id'] ?? '').toString(),
      status: statusStr,
      canChat: canChatBool,
      role: (data['role'] ?? 'driver').toString(),
      quickReplies: replies,
      messages: parsedMessages,
    );
  }
}
