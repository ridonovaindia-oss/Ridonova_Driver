import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../models/driver_chat_model.dart';
import '../../providers/driver_chat_provider.dart';

class DriverChatScreen extends ConsumerStatefulWidget {
  final String rideId;
  final String riderName;
  final String? riderPhone;
  final String? pickupAddress;
  final String? destinationAddress;

  const DriverChatScreen({
    super.key,
    required this.rideId,
    this.riderName = 'Passenger',
    this.riderPhone,
    this.pickupAddress,
    this.destinationAddress,
  });

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverChatProvider(widget.rideId).notifier).setChatScreenActive(true);
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String value) {
    _typingDebounce?.cancel();
    ref.read(driverChatProvider(widget.rideId).notifier).sendTyping(true);

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(driverChatProvider(widget.rideId).notifier).sendTyping(false);
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _typingDebounce?.cancel();
    ref.read(driverChatProvider(widget.rideId).notifier).sendTyping(false);
    ref.read(driverChatProvider(widget.rideId).notifier).sendCustomMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _sendQuickReply(String reply) {
    ref.read(driverChatProvider(widget.rideId).notifier).sendQuickReply(reply);
    _scrollToBottom();
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _getQuickReplyIcon(String reply) {
    final lower = reply.toLowerCase();
    if (lower.contains('arrived')) return Icons.check_circle_rounded;
    if (lower.contains('traffic')) return Icons.traffic_rounded;
    if (lower.contains('pickup')) return Icons.place_rounded;
    if (lower.contains('waiting')) return Icons.access_time_rounded;
    if (lower.contains('ok') || lower.contains('got it')) return Icons.thumb_up_alt_rounded;
    return Icons.chat_bubble_outline_rounded;
  }

  Color _getQuickReplyColor(String reply) {
    final lower = reply.toLowerCase();
    if (lower.contains('arrived')) return const Color(0xFF10B981);
    if (lower.contains('traffic')) return const Color(0xFFF59E0B);
    if (lower.contains('pickup')) return const Color(0xFF3B82F6);
    if (lower.contains('waiting')) return const Color(0xFF8B5CF6);
    if (lower.contains('ok') || lower.contains('got it')) return const Color(0xFF10B981);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(driverChatProvider(widget.rideId));

    ref.listen<DriverChatState>(driverChatProvider(widget.rideId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
      if (next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          next.errorMessage != previous?.errorMessage &&
          mounted) {
        AppFlushbar.error(
          context,
          title: 'Message Not Sent',
          message: next.errorMessage!,
        );
      }
    });

    final hasPhone = widget.riderPhone != null && widget.riderPhone!.trim().isNotEmpty;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(driverChatProvider(widget.rideId).notifier).setChatScreenActive(false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  widget.riderName.isNotEmpty ? widget.riderName[0].toUpperCase() : 'P',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.riderName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chatState.isRiderTyping)
                      const Text(
                        'typing...',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      )
                    else if (widget.pickupAddress != null && widget.pickupAddress!.isNotEmpty)
                      Text(
                        widget.pickupAddress!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      const Text(
                        'In-Ride Live Chat',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh messages',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              onPressed: () {
                ref.read(driverChatProvider(widget.rideId).notifier).refreshMessages(silent: false);
              },
            ),
            if (hasPhone)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => _makeCall(widget.riderPhone!),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_rounded, color: AppColors.success, size: 20),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Chat messages list
              Expanded(
                child: chatState.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref
                            .read(driverChatProvider(widget.rideId).notifier)
                            .refreshMessages(silent: false),
                        child: chatState.messages.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.45,
                                    child: _buildEmptyState(),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: chatState.messages.length + (chatState.isRiderTyping ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == chatState.messages.length) {
                                    return _buildTypingIndicator();
                                  }
                                  final msg = chatState.messages[index];
                                  return _buildMessageBubble(msg);
                                },
                              ),
                      ),
              ),

              // Bottom Section: Quick Replies + Input Field
              _buildBottomActionArea(chatState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start conversation with Passenger',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use 1-tap quick replies below for safe communication while driving',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.riderName} is typing...',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isMe = msg.isMe;
    final bubbleColor = msg.isFailed
        ? AppColors.error.withValues(alpha: 0.9)
        : (isMe ? AppColors.primary : Colors.white);

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isMe ? 0.08 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName : 'Passenger',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          Text(
            msg.message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isMe ? Colors.white : AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.isFailed ? 'Failed • Tap to retry' : msg.formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: msg.isFailed ? FontWeight.w600 : FontWeight.normal,
                  color: isMe ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF94A3B8),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                if (msg.isFailed)
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: Colors.white,
                  )
                else if (msg.isPending)
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: Colors.white70,
                  )
                else
                  Icon(
                    msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 13,
                    color: msg.isRead ? const Color(0xFF93C5FD) : Colors.white70,
                  ),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: msg.isFailed
          ? GestureDetector(
              onTap: () => ref
                  .read(driverChatProvider(widget.rideId).notifier)
                  .retryFailedMessage(msg.id),
              child: bubble,
            )
          : bubble,
    );
  }

  Widget _buildBottomActionArea(DriverChatState chatState) {
    if (!chatState.canChat) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'Ride completed. Chat closed.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1-Tap Big Quick Reply Chips for Safe Driving
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 10, bottom: 4),
            child: Row(
              children: const [
                Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  '1-Tap Quick Replies',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: chatState.quickReplies.map((reply) {
                final icon = _getQuickReplyIcon(reply);
                final color = _getQuickReplyColor(reply);

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _sendQuickReply(reply),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 15, color: color),
                            const SizedBox(width: 6),
                            Text(
                              reply,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Custom text field bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _textController,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
