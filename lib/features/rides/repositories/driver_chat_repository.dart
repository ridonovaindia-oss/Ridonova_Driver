import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../models/driver_chat_model.dart';

abstract class IDriverChatRepository {
  String? get lastErrorMessage => null;
  Future<DriverChatHistoryResponse> getChatHistory(String rideId, {String? token});
  Future<ChatMessageModel?> sendMessage(String rideId, String text, {String? token});
  Future<bool> markAsRead(String rideId, {String? token});
  Future<List<String>> getQuickReplies({String? token});
}

class DriverChatRepository implements IDriverChatRepository {
  final ApiService _apiService;
  String? _lastErrorMessage;

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  DriverChatRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  @override
  Future<DriverChatHistoryResponse> getChatHistory(String rideId, {String? token}) async {
    _lastErrorMessage = null;
    try {
      final endpoint = ApiConstants.rideChat(rideId);
      var response = await _apiService.get(endpoint, token: token);
      if (!response.isSuccess && response.statusCode == 404) {
        response = await _apiService.get('/driver/rides/$rideId/chat', token: token);
      }

      if (response.isSuccess && response.data != null) {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        if (raw is Map) {
          return DriverChatHistoryResponse.fromJson(Map<String, dynamic>.from(raw));
        }
      } else {
        _lastErrorMessage = response.errorMessage;
        dev.log(
          'Failed fetching chat history (status=${response.statusCode}): ${response.errorMessage}',
          name: 'DriverChatRepository',
        );
      }
    } catch (e) {
      _lastErrorMessage = 'Unable to load messages.';
      dev.log('Error fetching chat history: $e', name: 'DriverChatRepository');
    }

    return DriverChatHistoryResponse(
      rideId: rideId,
      status: 'active',
      canChat: true,
      quickReplies: DriverChatHistoryResponse.defaultQuickReplies,
      messages: [],
    );
  }

  @override
  Future<ChatMessageModel?> sendMessage(String rideId, String text, {String? token}) async {
    _lastErrorMessage = null;
    final cleanText = text.trim();
    try {
      final endpoint = ApiConstants.rideChat(rideId);
      var response = await _apiService.post(
        endpoint,
        data: {'message': cleanText},
        token: token,
      );
      if (!response.isSuccess && response.statusCode == 404) {
        response = await _apiService.post(
          '/driver/rides/$rideId/chat',
          data: {'message': cleanText},
          token: token,
        );
      }

      if (response.isSuccess) {
        if (response.data != null) {
          final raw = response.data is String ? jsonDecode(response.data) : response.data;
          if (raw is Map) {
            final rawMap = Map<String, dynamic>.from(raw);
            final dataObj = rawMap['data'] is Map
                ? Map<String, dynamic>.from(rawMap['data'] as Map)
                : rawMap;

            Map<String, dynamic>? msgMap;
            if (dataObj['message'] is Map) {
              msgMap = Map<String, dynamic>.from(dataObj['message'] as Map);
            } else if (dataObj['chatMessage'] is Map) {
              msgMap = Map<String, dynamic>.from(dataObj['chatMessage'] as Map);
            } else if (dataObj['chat'] is Map) {
              msgMap = Map<String, dynamic>.from(dataObj['chat'] as Map);
            } else if (dataObj['id'] != null || dataObj['_id'] != null) {
              msgMap = dataObj;
            }

            if (msgMap != null) {
              final parsed = ChatMessageModel.fromJson(msgMap);
              return parsed.message.trim().isNotEmpty
                  ? parsed
                  : parsed.copyWith(message: cleanText);
            }
          }
        }

        // Server accepted the message (2xx) without echoing a full message entity
        return ChatMessageModel(
          id: 'sent_${DateTime.now().millisecondsSinceEpoch}',
          rideId: rideId,
          senderId: 'driver',
          senderRole: 'driver',
          senderName: 'Driver',
          message: cleanText,
          isRead: false,
          createdAt: DateTime.now(),
        );
      } else {
        _lastErrorMessage = response.errorMessage ?? 'Failed to send message.';
        dev.log(
          'Failed sending chat message (status=${response.statusCode}): ${response.errorMessage}',
          name: 'DriverChatRepository',
        );
      }
    } catch (e) {
      _lastErrorMessage = 'Network error while sending message.';
      dev.log('Error sending chat message: $e', name: 'DriverChatRepository');
    }
    return null;
  }

  @override
  Future<bool> markAsRead(String rideId, {String? token}) async {
    try {
      final endpoint = ApiConstants.rideChatRead(rideId);
      var response = await _apiService.post(endpoint, token: token);
      if (!response.isSuccess && response.statusCode == 404) {
        response = await _apiService.post('/driver/rides/$rideId/chat/read', token: token);
      }
      return response.isSuccess;
    } catch (e) {
      dev.log('Error marking chat as read: $e', name: 'DriverChatRepository');
      return false;
    }
  }

  @override
  Future<List<String>> getQuickReplies({String? token}) async {
    try {
      final response = await _apiService.get(ApiConstants.driverChatQuickReplies, token: token);
      if (response.isSuccess && response.data != null) {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        dynamic list;
        if (raw is Map) {
          final data = raw['data'];
          if (data is Map && data['quickReplies'] is List) {
            list = data['quickReplies'];
          } else if (data is List) {
            list = data;
          } else if (raw['quickReplies'] is List) {
            list = raw['quickReplies'];
          }
        } else {
          list = raw;
        }
        if (list is List && list.isNotEmpty) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      dev.log('Error fetching driver quick replies: $e', name: 'DriverChatRepository');
    }
    return DriverChatHistoryResponse.defaultQuickReplies;
  }
}

final driverChatRepositoryProvider = Provider<IDriverChatRepository>((ref) {
  return DriverChatRepository();
});
