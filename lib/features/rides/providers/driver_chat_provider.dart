import 'dart:async';
import 'dart:developer' as dev;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/services/socket_service.dart';
import '../models/driver_chat_model.dart';
import '../repositories/driver_chat_repository.dart';

class DriverChatState {
  final String rideId;
  final List<ChatMessageModel> messages;
  final List<String> quickReplies;
  final bool isLoading;
  final bool isSending;
  final bool isRiderTyping;
  final bool canChat;
  final int unreadCount;
  final String? errorMessage;
  final ChatMessageModel? latestIncomingMessage;

  const DriverChatState({
    required this.rideId,
    this.messages = const [],
    this.quickReplies = DriverChatHistoryResponse.defaultQuickReplies,
    this.isLoading = false,
    this.isSending = false,
    this.isRiderTyping = false,
    this.canChat = true,
    this.unreadCount = 0,
    this.errorMessage,
    this.latestIncomingMessage,
  });

  DriverChatState copyWith({
    String? rideId,
    List<ChatMessageModel>? messages,
    List<String>? quickReplies,
    bool? isLoading,
    bool? isSending,
    bool? isRiderTyping,
    bool? canChat,
    int? unreadCount,
    String? errorMessage,
    ChatMessageModel? latestIncomingMessage,
    bool clearLatestIncomingMessage = false,
  }) {
    return DriverChatState(
      rideId: rideId ?? this.rideId,
      messages: messages ?? this.messages,
      quickReplies: quickReplies ?? this.quickReplies,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isRiderTyping: isRiderTyping ?? this.isRiderTyping,
      canChat: canChat ?? this.canChat,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
      latestIncomingMessage: clearLatestIncomingMessage
          ? null
          : (latestIncomingMessage ?? this.latestIncomingMessage),
    );
  }
}

class DriverChatNotifier extends StateNotifier<DriverChatState> {
  final String rideId;
  final IDriverChatRepository _repository;
  final SocketService _socketService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;
  StreamSubscription? _connectionSub;
  Timer? _bannerTimer;
  Timer? _typingTimer;
  Timer? _syncTimer;
  bool _isChatScreenOpen = false;
  bool _isSyncing = false;

  DriverChatNotifier({
    required this.rideId,
    required IDriverChatRepository repository,
    required SocketService socketService,
  })  : _repository = repository,
        _socketService = socketService,
        super(DriverChatState(rideId: rideId)) {
    _initSocketListeners();
    loadChat();
  }

  Map<String, dynamic>? _extractMessagePayload(Map<String, dynamic> data) {
    final container = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;

    if (container['message'] is Map) {
      return Map<String, dynamic>.from(container['message'] as Map);
    }
    if (container['chatMessage'] is Map) {
      return Map<String, dynamic>.from(container['chatMessage'] as Map);
    }
    if (container['chat'] is Map) {
      return Map<String, dynamic>.from(container['chat'] as Map);
    }
    return container;
  }

  void _initSocketListeners() {
    _connectionSub = _socketService.connectionStream.listen((connected) {
      if (connected && mounted) {
        _socketService.joinRide(rideId);
        refreshMessages(silent: true);
      }
    });

    _messageSub = _socketService.chatMessageUpdates.listen((data) {
      try {
        final msgPayload = _extractMessagePayload(data);
        if (msgPayload == null) return;

        final incomingRideId = (data['rideId'] ??
                data['ride_id'] ??
                msgPayload['rideId'] ??
                msgPayload['ride_id'])
            ?.toString();
        if (incomingRideId != null &&
            incomingRideId.isNotEmpty &&
            incomingRideId != rideId) {
          return;
        }

        final newMsg = ChatMessageModel.fromJson(msgPayload);
        if (newMsg.message.trim().isEmpty) return;

        // Deduplication: prevent duplicate messages by server ID
        if (newMsg.id.isNotEmpty &&
            state.messages.any((m) => m.id == newMsg.id)) {
          return;
        }

        if (!newMsg.isMe) {
          _triggerIncomingAlert();

          _bannerTimer?.cancel();
          _bannerTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              state = state.copyWith(clearLatestIncomingMessage: true);
            }
          });

          state = state.copyWith(
            messages: [...state.messages, newMsg],
            unreadCount: _isChatScreenOpen ? 0 : (state.unreadCount + 1),
            latestIncomingMessage: newMsg,
          );

          if (_isChatScreenOpen) {
            markAsRead();
          }
        } else {
          // Replace matching optimistic message if present, else append
          final existingIndex = state.messages.indexWhere(
            (m) =>
                (m.id.startsWith('temp_') || m.id.startsWith('sent_')) &&
                m.message.trim() == newMsg.message.trim(),
          );
          if (existingIndex != -1) {
            final updatedList = List<ChatMessageModel>.from(state.messages);
            updatedList[existingIndex] = newMsg;
            state = state.copyWith(messages: updatedList);
          } else if (newMsg.id.isEmpty ||
              !state.messages.any((m) => m.id == newMsg.id)) {
            state = state.copyWith(messages: [...state.messages, newMsg]);
          }
        }
      } catch (e) {
        dev.log('Error handling socket chat message: $e', name: 'DriverChatNotifier');
      }
    });

    _typingSub = _socketService.chatTypingUpdates.listen((data) {
      try {
        final incomingRideId = (data['rideId'] ?? data['ride_id'])?.toString();
        if (incomingRideId != null &&
            incomingRideId.isNotEmpty &&
            incomingRideId != rideId) {
          return;
        }

        // Ignore our own echoed typing events
        final senderRole = (data['senderRole'] ??
                data['sender_role'] ??
                data['role'] ??
                '')
            .toString()
            .toLowerCase();
        if (senderRole == 'driver' || senderRole == 'captain') {
          return;
        }

        final isTyping = data['isTyping'] == true || data['is_typing'] == true;
        state = state.copyWith(isRiderTyping: isTyping);

        _typingTimer?.cancel();
        if (isTyping) {
          _typingTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              state = state.copyWith(isRiderTyping: false);
            }
          });
        }
      } catch (e) {
        dev.log('Error handling socket chat typing: $e', name: 'DriverChatNotifier');
      }
    });

    _readSub = _socketService.chatReadUpdates.listen((data) {
      try {
        final incomingRideId = (data['rideId'] ?? data['ride_id'])?.toString();
        if (incomingRideId != null &&
            incomingRideId.isNotEmpty &&
            incomingRideId != rideId) {
          return;
        }
        // Ignore self-echoed read receipts (only mark driver messages read when rider read them)
        final readByRole = (data['readByRole'] ?? data['role'] ?? '').toString().toLowerCase().trim();
        if (readByRole == 'driver' || readByRole == 'captain') {
          return;
        }

        // Mark all driver messages as read
        final updated = state.messages.map((m) {
          if (m.isMe && !m.isRead) {
            return m.copyWith(isRead: true);
          }
          return m;
        }).toList();

        state = state.copyWith(messages: updated);
      } catch (e) {
        dev.log('Error handling socket chat read: $e', name: 'DriverChatNotifier');
      }
    });
  }

  Future<void> _ensureSocketReady({String? token}) async {
    final activeToken = (token != null && token.isNotEmpty)
        ? token
        : await TokenStorage.getToken();
    if (activeToken != null && activeToken.isNotEmpty) {
      _socketService.initSocket(activeToken);
    }
    _socketService.joinRide(rideId);
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _isChatScreenOpen && state.canChat) {
        refreshMessages(silent: true);
      }
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void _triggerIncomingAlert() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    unawaited(_playIncomingSound());
  }

  Future<void> _playIncomingSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
      );
    } catch (_) {}
  }

  void setChatScreenActive(bool isOpen) {
    _isChatScreenOpen = isOpen;
    if (isOpen) {
      _startSyncTimer();
      markAsRead();
      refreshMessages(silent: true);
    } else {
      _stopSyncTimer();
    }
  }

  void dismissLatestBanner() {
    _bannerTimer?.cancel();
    state = state.copyWith(clearLatestIncomingMessage: true);
  }

  List<ChatMessageModel> _mergeServerWithLocal(List<ChatMessageModel> serverMessages) {
    // Keep any in-flight or failed local messages that haven't been confirmed on server
    final localOnly = state.messages.where((m) => m.isPending || m.isFailed).toList();
    final merged = List<ChatMessageModel>.from(serverMessages);

    for (final local in localOnly) {
      final alreadyConfirmed = serverMessages.any(
        (s) =>
            s.isMe &&
            s.message.trim() == local.message.trim() &&
            s.createdAt.difference(local.createdAt).inSeconds.abs() < 30,
      );
      if (!alreadyConfirmed) {
        merged.add(local);
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> loadChat() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final token = await TokenStorage.getToken();
    await _ensureSocketReady(token: token);

    final response = await _repository.getChatHistory(rideId, token: token);

    if (mounted) {
      final merged = _mergeServerWithLocal(response.messages);
      final computedUnread = _isChatScreenOpen
          ? 0
          : merged.where((m) => !m.isMe && !m.isRead).length;
      state = state.copyWith(
        isLoading: false,
        messages: merged,
        quickReplies: response.quickReplies.isNotEmpty
            ? response.quickReplies
            : DriverChatHistoryResponse.defaultQuickReplies,
        canChat: response.canChat,
        unreadCount: computedUnread,
      );

      // Only mark messages read on server when the chat screen is actually open
      if (_isChatScreenOpen) {
        markAsRead();
      }
    }
  }

  /// Silently syncs latest chat history from REST (fallback when socket misses events)
  Future<void> refreshMessages({bool silent = true}) async {
    if (_isSyncing || !mounted) return;
    _isSyncing = true;

    try {
      final token = await TokenStorage.getToken();
      await _ensureSocketReady(token: token);

      final response = await _repository.getChatHistory(rideId, token: token);
      if (!mounted) return;

      final previousIds = state.messages
          .where((m) => m.id.isNotEmpty)
          .map((m) => m.id)
          .toSet();
      final newIncoming = response.messages
          .where((m) => !m.isMe && m.id.isNotEmpty && !previousIds.contains(m.id))
          .toList();

      final merged = _mergeServerWithLocal(response.messages);

      if (newIncoming.isNotEmpty && !_isChatScreenOpen) {
        _triggerIncomingAlert();
        final latest = newIncoming.last;
        _bannerTimer?.cancel();
        _bannerTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            state = state.copyWith(clearLatestIncomingMessage: true);
          }
        });
        state = state.copyWith(
          messages: merged,
          quickReplies: response.quickReplies.isNotEmpty
              ? response.quickReplies
              : state.quickReplies,
          canChat: response.canChat,
          unreadCount: state.unreadCount + newIncoming.length,
          latestIncomingMessage: latest,
        );
      } else {
        state = state.copyWith(
          messages: merged,
          quickReplies: response.quickReplies.isNotEmpty
              ? response.quickReplies
              : state.quickReplies,
          canChat: response.canChat,
          unreadCount: _isChatScreenOpen ? 0 : state.unreadCount,
        );
        if (newIncoming.isNotEmpty && _isChatScreenOpen) {
          markAsRead();
        }
      }
    } catch (e) {
      if (!silent) {
        dev.log('Error refreshing chat messages: $e', name: 'DriverChatNotifier');
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _sendMessageInternal(String rawText, {String? retryTempId}) async {
    final clean = rawText.trim();
    if (clean.isEmpty || !state.canChat) return;

    final tempId = retryTempId ?? 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMsg = ChatMessageModel(
      id: tempId,
      rideId: rideId,
      senderId: 'driver',
      senderRole: 'driver',
      senderName: 'Driver',
      message: clean,
      isRead: false,
      createdAt: DateTime.now(),
      isPending: true,
      isFailed: false,
    );

    final updatedBeforeSend = retryTempId != null
        ? state.messages.map((m) => m.id == retryTempId ? optimisticMsg : m).toList()
        : [...state.messages, optimisticMsg];

    state = state.copyWith(
      messages: updatedBeforeSend,
      isSending: true,
      errorMessage: null,
      clearLatestIncomingMessage: true,
    );

    try {
      final token = await TokenStorage.getToken();
      await _ensureSocketReady(token: token);

      final confirmed = await _repository.sendMessage(rideId, clean, token: token);
      if (!mounted) return;

      if (confirmed != null) {
        // Deduplicate in case socket already delivered this confirmed message ID
        final alreadyHasConfirmedId =
            confirmed.id.isNotEmpty && state.messages.any((m) => m.id == confirmed.id);

        final updated = alreadyHasConfirmedId
            ? state.messages.where((m) => m.id != tempId).toList()
            : state.messages
                .map((m) => m.id == tempId
                    ? confirmed.copyWith(isPending: false, isFailed: false)
                    : m)
                .toList();

        state = state.copyWith(
          messages: updated,
          isSending: false,
          errorMessage: null,
        );
      } else {
        final errMsg = _repository.lastErrorMessage ??
            'Failed to send message. Tap the message to retry.';
        final updated = state.messages
            .map((m) => m.id == tempId
                ? m.copyWith(isPending: false, isFailed: true)
                : m)
            .toList();
        state = state.copyWith(
          messages: updated,
          isSending: false,
          errorMessage: errMsg,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final updated = state.messages
          .map((m) => m.id == tempId
              ? m.copyWith(isPending: false, isFailed: true)
              : m)
          .toList();
      state = state.copyWith(
        messages: updated,
        isSending: false,
        errorMessage: 'Failed to send message. Please try again.',
      );
    }
  }

  Future<void> sendQuickReply(String replyText) async {
    await _sendMessageInternal(replyText);
  }

  Future<void> sendCustomMessage(String text) async {
    await _sendMessageInternal(text);
  }

  Future<void> retryFailedMessage(String failedMessageId) async {
    final idx = state.messages.indexWhere((m) => m.id == failedMessageId);
    if (idx == -1) return;
    final failedMsg = state.messages[idx];
    await _sendMessageInternal(failedMsg.message, retryTempId: failedMsg.id);
  }

  void sendTyping(bool isTyping) {
    _socketService.sendChatTyping(rideId, isTyping);
  }

  Future<void> markAsRead() async {
    state = state.copyWith(unreadCount: 0, clearLatestIncomingMessage: true);
    final token = await TokenStorage.getToken();
    await _repository.markAsRead(rideId, token: token);
    _socketService.markChatRead(rideId);
  }

  void updateRideStatus(String status) {
    if (status == 'completed' || status == 'cancelled') {
      _stopSyncTimer();
      state = state.copyWith(canChat: false);
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _connectionSub?.cancel();
    _bannerTimer?.cancel();
    _typingTimer?.cancel();
    _syncTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final driverChatProvider =
    StateNotifierProvider.autoDispose.family<DriverChatNotifier, DriverChatState, String>(
        (ref, rideId) {
  final repo = ref.watch(driverChatRepositoryProvider);
  return DriverChatNotifier(
    rideId: rideId,
    repository: repo,
    socketService: SocketService(),
  );
});
