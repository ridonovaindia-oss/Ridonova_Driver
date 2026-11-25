class SupportCategory {
  final String id;
  final String name;
  final String nameHi;
  final bool requiresRideId;
  final String priority;

  SupportCategory({
    this.id = '',
    this.name = '',
    this.nameHi = '',
    this.requiresRideId = false,
    this.priority = 'medium',
  });

  factory SupportCategory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SupportCategory();
    return SupportCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameHi: json['nameHi']?.toString() ?? '',
      requiresRideId: json['requiresRideId'] == true,
      priority: json['priority']?.toString() ?? 'medium',
    );
  }
}

class StatusBadge {
  final String status;
  final String label;
  final String labelHi;
  final String color;

  StatusBadge({
    this.status = '',
    this.label = '',
    this.labelHi = '',
    this.color = 'orange',
  });

  factory StatusBadge.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StatusBadge();
    return StatusBadge(
      status: json['status']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      labelHi: json['labelHi']?.toString() ?? '',
      color: json['color']?.toString() ?? 'orange',
    );
  }
}

class SupportTicket {
  final String id;
  final String ticketId;
  final String ticketNumber;
  final String category;
  final String categoryName;
  final String subject;
  final String description;
  final String? rideId;
  final String priority;
  final String status;
  final StatusBadge statusBadge;
  final String? resolutionNotes;
  final String? resolvedAt;
  final String createdAt;

  SupportTicket({
    this.id = '',
    this.ticketId = '',
    this.ticketNumber = '',
    this.category = '',
    this.categoryName = '',
    this.subject = '',
    this.description = '',
    this.rideId,
    this.priority = 'medium',
    this.status = 'pending',
    StatusBadge? statusBadge,
    this.resolutionNotes,
    this.resolvedAt,
    this.createdAt = '',
  }) : statusBadge = statusBadge ?? StatusBadge();

  factory SupportTicket.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SupportTicket();
    return SupportTicket(
      id: json['id']?.toString() ?? json['ticketId']?.toString() ?? '',
      ticketId: json['ticketId']?.toString() ?? json['id']?.toString() ?? '',
      ticketNumber: json['ticketNumber']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rideId: json['rideId']?.toString(),
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'pending',
      statusBadge: StatusBadge.fromJson(json['statusBadge'] as Map<String, dynamic>?),
      resolutionNotes: (json['resolutionNotes'] ?? json['resolution'])?.toString(),
      resolvedAt: (json['resolvedAt'] ?? json['resolved_at'])?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
    );
  }
}

class SupportMessage {
  final String id;
  final String sender;
  final String senderName;
  final String text;
  final String createdAt;

  SupportMessage({
    this.id = '',
    this.sender = '',
    this.senderName = '',
    this.text = '',
    this.createdAt = '',
  });

  factory SupportMessage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SupportMessage();
    return SupportMessage(
      id: json['id']?.toString() ?? '',
      sender: (json['sender'] ?? json['senderRole'] ?? json['sender_role'] ?? '').toString(),
      senderName: (json['senderName'] ?? json['sender_name'] ?? '').toString(),
      text: (json['text'] ?? json['message'] ?? json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? json['timestamp'] ?? '').toString(),
    );
  }
}

class TicketDetailModel {
  final SupportTicket ticket;
  final String assignedAgentName;
  final List<SupportMessage> messages;

  TicketDetailModel({
    SupportTicket? ticket,
    this.assignedAgentName = '',
    this.messages = const [],
  }) : ticket = ticket ?? SupportTicket();

  factory TicketDetailModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TicketDetailModel();
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;
    final ticketData = data['ticket'] is Map<String, dynamic> ? data['ticket'] : data;

    List<SupportMessage> msgs = [];
    if (ticketData['messages'] is List) {
      msgs = (ticketData['messages'] as List)
          .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>?))
          .toList();
    }

    return TicketDetailModel(
      ticket: SupportTicket.fromJson(ticketData),
      assignedAgentName: ticketData['assignedAgentName']?.toString() ?? data['assignedAgentName']?.toString() ?? 'Support Team',
      messages: msgs,
    );
  }
}

class SupportCounts {
  final int total;
  final int pending;
  final int inProgress;
  final int resolved;
  final int closed;

  SupportCounts({
    this.total = 0,
    this.pending = 0,
    this.inProgress = 0,
    this.resolved = 0,
    this.closed = 0,
  });

  factory SupportCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SupportCounts();
    return SupportCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      inProgress: (json['inProgress'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      closed: (json['closed'] as num?)?.toInt() ?? 0,
    );
  }
}
