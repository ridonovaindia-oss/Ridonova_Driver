import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../wallet_model.dart';
import '../../wallet_provider.dart';

class PayoutHistoryScreen extends ConsumerStatefulWidget {
  final String? highlightPayoutId;

  const PayoutHistoryScreen({super.key, this.highlightPayoutId});

  @override
  ConsumerState<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends ConsumerState<PayoutHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  static const List<String> _tabLabels = ['All', 'Completed', 'In Progress', 'Failed'];

  List<PayoutItemModel> _items = [];
  int _page = 1;
  static const int _limit = 15;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadPayouts(reset: true);
      }
    });

    _scrollController.addListener(_onScroll);

    // Seed with existing provider payouts initially for instant paint, then fetch fresh page 1
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cached = ref.read(walletProvider).payouts;
      if (cached.isNotEmpty && mounted) {
        setState(() => _items = cached);
      }
      _loadPayouts(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 180 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadPayouts(reset: false);
    }
  }

  String _queryStatusForTab(int index) {
    switch (index) {
      case 1:
        return 'completed';
      case 2:
        return 'processing';
      case 3:
        return 'failed';
      default:
        return 'all';
    }
  }

  Future<void> _loadPayouts({required bool reset}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final tabIndex = _tabController.index;
    final queryStatus = _queryStatusForTab(tabIndex);

    // For 'In Progress' or 'Failed' tabs which map to 2 backend statuses
    // (pending+processing or failed+rejected), fetch 'all' and filter client-side
    // so neither status is accidentally hidden if backend only supports single-status query.
    final apiStatusParam = (tabIndex == 2 || tabIndex == 3) ? 'all' : queryStatus;

    final response = await _apiService.get(
      ApiConstants.driverPayouts,
      queryParameters: {
        'page': _page,
        'limit': _limit,
        'status': apiStatusParam,
      },
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final dataPayload = (raw is Map) ? (raw['data'] ?? raw) : raw;
        List<PayoutItemModel> fetched = [];

        if (dataPayload is Map && dataPayload['payouts'] is List) {
          fetched = (dataPayload['payouts'] as List)
              .map((e) => PayoutItemModel.fromJson(e as Map<String, dynamic>?))
              .toList();
        } else if (dataPayload is List) {
          fetched = dataPayload
              .map((e) => PayoutItemModel.fromJson(e as Map<String, dynamic>?))
              .toList();
        }

        final bool reachedEnd = fetched.length < _limit;

        setState(() {
          if (reset) {
            _items = fetched;
          } else {
            final existingIds = _items.map((e) => e.id).toSet();
            _items = [
              ..._items,
              ...fetched.where((e) => e.id.isEmpty || !existingIds.contains(e.id)),
            ];
          }
          _page += 1;
          _hasMore = !reachedEnd;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Failed to parse payout history.';
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = response.errorMessage ?? 'Could not load payout history.';
      });
    }
  }

  List<PayoutItemModel> _filteredItems(List<PayoutItemModel> source) {
    switch (_tabController.index) {
      case 1: // Completed
        return source.where((p) => p.isCompleted).toList();
      case 2: // In Progress
        return source.where((p) => p.isInProgress).toList();
      case 3: // Failed / Rejected
        return source.where((p) => p.isFailedOrRejected).toList();
      default:
        return source;
    }
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour12:$minute $amPm';
    } catch (_) {
      return raw.length >= 16 ? raw.substring(0, 16).replaceAll('T', ' ') : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to real-time socket updates from walletProvider
    ref.listen<List<PayoutItemModel>>(
      walletProvider.select((s) => s.payouts),
      (previous, next) {
        if (!mounted || next.isEmpty) return;
        // Merge updated payout statuses reactively without full page reload
        setState(() {
          final Map<String, PayoutItemModel> liveById = {
            for (final p in next)
              if (p.id.isNotEmpty) p.id: p,
          };
          _items = _items.map((existing) {
            final updated = liveById[existing.id];
            return updated ?? existing;
          }).toList();
        });
      },
    );

    final visibleItems = _filteredItems(_items);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payout History'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(walletProvider.notifier).fetchWalletEarnings();
              _loadPayouts(reset: true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(walletProvider.notifier).fetchWalletEarnings(),
            _loadPayouts(reset: true),
          ]);
        },
        child: _isLoading && visibleItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && visibleItems.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _loadPayouts(reset: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : visibleItems.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 140),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${_tabLabels[_tabController.index].toLowerCase()} payouts found.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleItems.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= visibleItems.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final payout = visibleItems[index];
                          final isHighlighted = widget.highlightPayoutId != null &&
                              widget.highlightPayoutId!.isNotEmpty &&
                              payout.id == widget.highlightPayoutId;
                          return _buildPayoutCard(payout, isHighlighted: isHighlighted);
                        },
                      ),
      ),
    );
  }

  Widget _buildPayoutCard(PayoutItemModel p, {bool isHighlighted = false}) {
    final bool isCompleted = p.isCompleted;
    final bool isFailedOrRejected = p.isFailedOrRejected;
    final bool isUpi = p.payoutMethod.toLowerCase() == 'upi';

    final String statusLabel = isCompleted
        ? 'Credited'
        : isFailedOrRejected
            ? (p.isRejected ? 'Rejected' : 'Failed')
            : 'In Progress';

    final Color badgeBg = isCompleted
        ? const Color(0xFFDCFCE7)
        : isFailedOrRejected
            ? const Color(0xFFFEE2E2)
            : (p.normalizedStatus == 'processing'
                ? const Color(0xFFDBEAFE)
                : const Color(0xFFFEF3C7));

    final Color badgeFg = isCompleted
        ? const Color(0xFF15803D)
        : isFailedOrRejected
            ? const Color(0xFFB91C1C)
            : (p.normalizedStatus == 'processing'
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFB45309));

    final String utrValue = p.utr.isNotEmpty ? p.utr : (isCompleted ? p.transactionId : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isHighlighted ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Amount + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isUpi ? const Color(0xFF0284C7) : AppColors.secondary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isUpi ? Icons.flash_on_rounded : Icons.account_balance_rounded,
                      size: 18,
                      color: isUpi ? const Color(0xFF0284C7) : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹ ${p.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isFailedOrRejected
                              ? Colors.red.shade700
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isUpi ? 'UPI Transfer' : 'Bank IMPS Transfer',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Account
          if (p.accountDetails.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.accountDetails,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          // Completed: Copyable UTR Chip
          if (isCompleted && utrValue.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'UTR: $utrValue',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Color(0xFF15803D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: utrValue));
                      AppFlushbar.success(
                        context,
                        title: 'UTR Copied',
                        message: 'UTR $utrValue copied to clipboard.',
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 15, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Failed / Rejected: Failure Reason + Refunded to Wallet Sub-badge
          if (isFailedOrRejected) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.failureReason.isNotEmpty) ...[
                    Text(
                      'Reason: ${p.failureReason}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.replay_rounded, size: 13, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 5),
                        Text(
                          '₹${p.amount.toStringAsFixed(2)} Refunded to Wallet',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Timestamps Footer
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTimestamp(p.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (isCompleted && p.completedAt.isNotEmpty)
                Text(
                  'Credited: ${_formatTimestamp(p.completedAt)}',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                )
              else if (isFailedOrRejected && p.refundedAt.isNotEmpty)
                Text(
                  'Refunded: ${_formatTimestamp(p.refundedAt)}',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF1D4ED8)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
