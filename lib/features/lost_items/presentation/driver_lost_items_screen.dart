import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/driver_lost_item_model.dart';
import '../providers/driver_lost_item_provider.dart';
import 'respond_lost_item_sheet.dart';

class DriverLostItemsScreen extends ConsumerStatefulWidget {
  const DriverLostItemsScreen({super.key});

  @override
  ConsumerState<DriverLostItemsScreen> createState() => _DriverLostItemsScreenState();
}

class _DriverLostItemsScreenState extends ConsumerState<DriverLostItemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverLostItemProvider.notifier).loadLostItems();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lostState = ref.watch(driverLostItemProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lost & Found Items'),
        centerTitle: true,
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: lostState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(driverLostItemProvider.notifier).loadLostItems(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Action Needed'),
                  if (lostState.pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${lostState.pendingCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('History / All'),
                  if (lostState.resolvedItems.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${lostState.resolvedItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(driverLostItemProvider.notifier).loadLostItems(),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Pending Items (Action Needed)
            _buildItemsList(
              items: lostState.pendingItems,
              isLoading: lostState.isLoading,
              isPendingTab: true,
            ),

            // Tab 2: Resolved / History Items
            _buildItemsList(
              items: lostState.resolvedItems,
              isLoading: lostState.isLoading,
              isPendingTab: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList({
    required List<DriverLostItemModel> items,
    required bool isLoading,
    required bool isPendingTab,
  }) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isPendingTab ? const Color(0xFFF0FDF4) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    isPendingTab ? '🎉' : '📦',
                    style: const TextStyle(fontSize: 38),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isPendingTab ? 'No Pending Inquiries!' : 'No Past Lost Items',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPendingTab
                    ? 'Great job! You have responded to all passenger lost item inquiries.'
                    : 'Any resolved or previous lost item reports will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildLostItemCard(item);
      },
    );
  }

  Widget _buildLostItemCard(DriverLostItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isPending ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
          width: item.isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: item.statusBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(item.categoryEmoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      item.categoryDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: item.statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    item.statusDisplayName.toUpperCase(),
                    style: TextStyle(
                      color: item.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ride ID & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ride #${item.rideId}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      item.reportedAt.isNotEmpty
                          ? (item.reportedAt.length >= 10 ? item.reportedAt.substring(0, 10) : item.reportedAt)
                          : '',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Passenger Description Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    item.description.isNotEmpty ? item.description : 'No description provided.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),

                // Route (Pickup & Dropoff)
                if (item.pickupAddress.isNotEmpty || item.dropoffAddress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (item.pickupAddress.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.trip_origin, size: 12, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.pickupAddress,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (item.dropoffAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.dropoffAddress,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                // Driver Note (if responded)
                if (item.driverNote != null && item.driverNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.isFound ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.isFound ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isFound ? Icons.check_circle_outline : Icons.info_outline,
                          size: 16,
                          color: item.isFound ? const Color(0xFF15803D) : Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Note: "${item.driverNote}"',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.isFound ? const Color(0xFF15803D) : Colors.red.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 22),

                // Actions: Call Passenger & Respond
                Row(
                  children: [
                    if (item.contactPhone.isNotEmpty) ...[
                      InkWell(
                        onTap: () => _makePhoneCall(item.contactPhone),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.phone_rounded, color: AppColors.secondary, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Call Passenger',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    // Action Button
                    if (item.isPending)
                      Expanded(
                        child: InkWell(
                          onTap: () => showRespondLostItemSheet(context, item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Respond / Check Car',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          item.isFound
                              ? 'Marked as Found • Handover pending'
                              : item.isReturned
                                  ? 'Item successfully returned'
                                  : 'Marked not found in car',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: item.statusColor,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
