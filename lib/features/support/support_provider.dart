import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'support_model.dart';

enum SupportStatus { initial, loading, success, error }

class SupportState {
  final List<SupportCategory> categories;
  final List<SupportTicket> tickets;
  final SupportCounts counts;
  final TicketDetailModel? currentTicketDetail;
  final SupportStatus status;
  final bool isActionLoading;
  final String? errorMessage;
  final String? successMessage;

  SupportState({
    this.categories = const [],
    this.tickets = const [],
    SupportCounts? counts,
    this.currentTicketDetail,
    this.status = SupportStatus.initial,
    this.isActionLoading = false,
    this.errorMessage,
    this.successMessage,
  }) : counts = counts ?? SupportCounts();

  SupportState copyWith({
    List<SupportCategory>? categories,
    List<SupportTicket>? tickets,
    SupportCounts? counts,
    TicketDetailModel? currentTicketDetail,
    bool clearCurrentTicket = false,
    SupportStatus? status,
    bool? isActionLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessage = false,
  }) {
    return SupportState(
      categories: categories ?? this.categories,
      tickets: tickets ?? this.tickets,
      counts: counts ?? this.counts,
      currentTicketDetail: clearCurrentTicket ? null : (currentTicketDetail ?? this.currentTicketDetail),
      status: status ?? this.status,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      errorMessage: errorMessage,
      successMessage: clearMessage ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SupportNotifier extends StateNotifier<SupportState> {
  final ApiService _apiService;

  SupportNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(SupportState()) {
    fetchCategories();
    fetchTickets();
  }

  /// 1. Fetch Support Categories (GET /driver/support/categories)
  Future<void> fetchCategories({String? token}) async {
    final response = await _apiService.get(ApiConstants.supportCategories, token: token);
    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final data = (raw is Map) ? (raw['data'] ?? raw) : raw;
        List<SupportCategory> catList = [];
        if (data is Map && data['categories'] is List) {
          catList = (data['categories'] as List)
              .map((e) => SupportCategory.fromJson(e as Map<String, dynamic>?))
              .toList();
        } else if (data is List) {
          catList = data.map((e) => SupportCategory.fromJson(e as Map<String, dynamic>?)).toList();
        }
        state = state.copyWith(categories: catList);
      } catch (_) {}
    }
  }

  /// 2. List Driver's Support Tickets (GET /driver/support/tickets)
  Future<void> fetchTickets({String? statusFilter, String? token}) async {
    state = state.copyWith(status: SupportStatus.loading, errorMessage: null);

    final query = <String, dynamic>{'page': 1, 'limit': 20};
    if (statusFilter != null && statusFilter != 'all') {
      query['status'] = statusFilter;
    }

    final response = await _apiService.get(ApiConstants.supportTickets, queryParameters: query, token: token);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final data = (raw is Map) ? (raw['data'] ?? raw) : raw;

        List<SupportTicket> ticketList = [];
        if (data is Map && data['tickets'] is List) {
          ticketList = (data['tickets'] as List)
              .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>?))
              .toList();
        } else if (data is List) {
          ticketList = data.map((e) => SupportTicket.fromJson(e as Map<String, dynamic>?)).toList();
        }

        SupportCounts counts = SupportCounts();
        if (data is Map && data['counts'] is Map) {
          counts = SupportCounts.fromJson(data['counts'] as Map<String, dynamic>?);
        }

        state = state.copyWith(
          tickets: ticketList,
          counts: counts,
          status: SupportStatus.success,
        );
      } catch (e) {
        state = state.copyWith(status: SupportStatus.error, errorMessage: 'Failed to parse tickets: $e');
      }
    } else {
      state = state.copyWith(
        status: SupportStatus.error,
        errorMessage: response.errorMessage ?? 'Failed to retrieve support tickets.',
      );
    }
  }

  /// 3. Raise Support Ticket (POST /driver/support/tickets) — guarded against double submission
  bool _creatingTicket = false;

  Future<bool> createTicket({
    required String category,
    required String subject,
    required String description,
    String? rideId,
    String? priority,
    List<String>? attachments,
    String? idempotencyKey,
    String? token,
  }) async {
    if (_creatingTicket || state.isActionLoading) return false;
    _creatingTicket = true;
    state = state.copyWith(isActionLoading: true, errorMessage: null, clearMessage: true);

    try {
      final body = {
        'category': category,
        'subject': subject,
        'description': description,
        if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
      };

      final response = await _apiService.post(ApiConstants.supportTickets, data: body, token: token);

      if (response.isSuccess) {
        // Keep isActionLoading = true until fetchTickets completes so the button never re-enables prematurely!
        await fetchTickets(token: token);
        state = state.copyWith(
          isActionLoading: false,
          successMessage: 'Support ticket raised successfully.',
        );
        return true;
      } else {
        state = state.copyWith(
          isActionLoading: false,
          errorMessage: response.errorMessage ?? 'Failed to raise support ticket.',
        );
        return false;
      }
    } finally {
      _creatingTicket = false;
    }
  }

  /// 4. Get Ticket Details & In-App Message Thread (GET /driver/support/tickets/{id})
  Future<void> fetchTicketDetails(String ticketId, {String? token}) async {
    state = state.copyWith(isActionLoading: true, errorMessage: null);

    final response = await _apiService.get(ApiConstants.supportTicketDetails(ticketId), token: token);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final detail = TicketDetailModel.fromJson(raw);
        state = state.copyWith(isActionLoading: false, currentTicketDetail: detail);
      } catch (e) {
        state = state.copyWith(isActionLoading: false, errorMessage: 'Failed to parse ticket details: $e');
      }
    } else {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: response.errorMessage ?? 'Failed to load ticket details.',
      );
    }
  }

  /// 5. Driver Reply on Ticket (POST /driver/support/tickets/{id}/reply)
  Future<bool> replyTicket({required String ticketId, required String message, String? token}) async {
    state = state.copyWith(isActionLoading: true, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.supportTicketReply(ticketId),
      data: {'message': message},
      token: token,
    );

    if (response.isSuccess) {
      state = state.copyWith(isActionLoading: false);
      await fetchTicketDetails(ticketId, token: token);
      await fetchTickets(token: token);
      return true;
    } else {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: response.errorMessage ?? 'Failed to submit reply.',
      );
      return false;
    }
  }
}

final supportProvider = StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  return SupportNotifier();
});
