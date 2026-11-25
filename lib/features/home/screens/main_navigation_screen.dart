import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_flushbar.dart';
import '../../lost_items/presentation/driver_lost_items_screen.dart';
import '../../lost_items/providers/driver_lost_item_provider.dart';
import '../../wallet/presentation/screens/payout_history_screen.dart';
import '../../wallet/presentation/widgets/tip_received_dialog.dart';
import '../../wallet/wallet_provider.dart';
import 'tabs/driver_earnings_tab.dart';
import 'tabs/driver_map_home_tab.dart';
import 'tabs/driver_profile_tab.dart';
import 'tabs/driver_rides_tab.dart';

final mainNavTabProvider = StateProvider<int>((ref) => 0);

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  StreamSubscription? _tipSub;
  StreamSubscription? _walletSub;
  StreamSubscription? _payoutSub;
  StreamSubscription? _notifSub;
  StreamSubscription? _lostItemReportedSub;
  StreamSubscription? _lostItemUpdatedSub;

  final List<Widget> _tabs = const [
    DriverMapHomeTab(),
    DriverEarningsTab(),
    DriverRidesTab(),
    DriverProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    // 1. Realtime In-App Tip Received Socket Event (tip_received)
    _tipSub = SocketService().tipReceivedStream.listen((data) {
      if (!mounted) return;
      final amount =
          (data['amount'] as num?)?.toDouble() ??
          (data['tipAmount'] as num?)?.toDouble() ??
          0.0;
      final rideId = data['rideId']?.toString();
      final method = data['method']?.toString();

      if (amount > 0) {
        showTipCelebrationDialog(
          context,
          amount: amount,
          rideId: rideId,
          method: method,
          onViewWallet: () {
            ref.read(mainNavTabProvider.notifier).state = 1;
            ref.read(walletProvider.notifier).fetchWalletEarnings();
            ref.read(walletProvider.notifier).fetchTransactions();
          },
        );
      }

      // Background sync wallet & ledger
      ref.read(walletProvider.notifier).fetchWalletEarnings();
      ref.read(walletProvider.notifier).fetchTransactions();
    });

    // 2. Realtime Wallet Balance Updated Socket Event (driver_wallet_updated)
    _walletSub = SocketService().walletUpdatedStream.listen((data) {
      if (!mounted) return;
      final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
      final amountAdded =
          (data['amountAdded'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble();
      final reason = data['reason']?.toString();
      final rideId = data['rideId']?.toString();

      ref
          .read(walletProvider.notifier)
          .applyLiveWalletUpdate(
            balance: balance,
            amountAdded: amountAdded,
            reason: reason,
            rideId: rideId,
          );
    });

    // 3. Realtime Payout Status Updated Socket Event (payout_status_updated)
    _payoutSub = SocketService().payoutStatusUpdatedStream.listen((data) {
      if (!mounted) return;
      final status = (data['status'] ?? '').toString().toLowerCase();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final utr = (data['utr'] ?? data['utrNumber'] ?? '').toString();
      final failureReason = (data['failureReason'] ?? data['reason'] ?? '').toString();

      if (status == 'completed' || status == 'processed' || status == 'success') {
        AppFlushbar.success(
          context,
          title: 'Payout Credited! 🏦',
          message:
              '₹${amount.toStringAsFixed(2)} successfully credited to your bank${utr.isNotEmpty ? " (UTR: $utr)" : ""}.',
        );
      } else if (status == 'failed' || status == 'rejected') {
        AppFlushbar.error(
          context,
          title: 'Payout ${status == "rejected" ? "Rejected" : "Failed"} ⚠️',
          message:
              'Payout of ₹${amount.toStringAsFixed(2)} failed${failureReason.isNotEmpty ? " ($failureReason)" : ""}. Amount has been refunded to your wallet.',
        );
      }

      ref.read(walletProvider.notifier).applyLivePayoutUpdate(data);
    });

    // 4. Realtime Lost Item Reported Socket Event (lost_item:reported)
    _lostItemReportedSub = SocketService().lostItemReportedStream.listen((
      data,
    ) {
      if (!mounted) return;
      ref.read(driverLostItemProvider.notifier).handleIncomingReport(data);

      final category = data['category']?.toString() ?? 'item';
      final rideId = data['rideId']?.toString() ?? '';

      AppFlushbar.info(
        context,
        title: '📦 Lost Item Reported!',
        message:
            'A passenger reported a lost $category on ride #$rideId. Tap to inspect vehicle.',
      );
    });

    // 4. Realtime Lost Item Status Updated Socket Event (lost_item:updated)
    _lostItemUpdatedSub = SocketService().lostItemUpdatedStream.listen((data) {
      if (!mounted) return;
      ref.read(driverLostItemProvider.notifier).handleStatusUpdate(data);
    });

    // 5. FCM Push Notification Tap Stream
    _notifSub = NotificationService().notificationDataStream.listen((data) {
      if (!mounted) return;
      final type = data['type']?.toString();
      if (type == 'tip_received') {
        final tipAmount =
            double.tryParse(data['tipAmount']?.toString() ?? '') ??
            (data['amount'] as num?)?.toDouble() ??
            0.0;
        final rideId = data['rideId']?.toString();

        // Switch to Earnings Tab
        ref.read(mainNavTabProvider.notifier).state = 1;
        ref.read(walletProvider.notifier).fetchWalletEarnings();
        ref.read(walletProvider.notifier).fetchTransactions();

        if (tipAmount > 0) {
          showTipCelebrationDialog(
            context,
            amount: tipAmount,
            rideId: rideId,
            method: 'PASSENGER WALLET',
            onViewWallet: () {
              ref.read(mainNavTabProvider.notifier).state = 1;
            },
          );
        }
      } else if (type == 'lost_item' || type == 'lost_item_reported') {
        // Open Lost Items Screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverLostItemsScreen()),
        );
      } else if (type == 'PAYOUT_COMPLETED' || type == 'payout_completed') {
        final payoutId = data['payoutId']?.toString();
        ref.read(mainNavTabProvider.notifier).state = 1;
        ref.read(walletProvider.notifier).fetchWalletEarnings();
        ref.read(walletProvider.notifier).fetchPayouts();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PayoutHistoryScreen(highlightPayoutId: payoutId),
          ),
        );
      } else if (type == 'PAYOUT_FAILED' ||
          type == 'PAYOUT_REJECTED' ||
          type == 'payout_failed' ||
          type == 'payout_rejected') {
        final payoutId = data['payoutId']?.toString();
        ref.read(mainNavTabProvider.notifier).state = 1;
        ref.read(walletProvider.notifier).fetchWalletEarnings();
        ref.read(walletProvider.notifier).fetchPayouts();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PayoutHistoryScreen(highlightPayoutId: payoutId),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _tipSub?.cancel();
    _walletSub?.cancel();
    _payoutSub?.cancel();
    _notifSub?.cancel();
    _lostItemReportedSub?.cancel();
    _lostItemUpdatedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainNavTabProvider);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          elevation: 0,
          height: 65,
          onDestinationSelected: (index) {
            ref.read(mainNavTabProvider.notifier).state = index;
            if (index == 2) {
              ref.read(rideHistoryRefreshTriggerProvider.notifier).state++;
            } else if (index == 1) {
              ref.read(walletProvider.notifier).fetchWalletEarnings();
              ref.read(walletProvider.notifier).fetchPayouts();
              ref.read(walletProvider.notifier).fetchTransactions();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
              label: 'Earnings',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(
                Icons.alt_route_rounded,
                color: AppColors.primary,
              ),
              label: 'Rides',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: AppColors.primary,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
