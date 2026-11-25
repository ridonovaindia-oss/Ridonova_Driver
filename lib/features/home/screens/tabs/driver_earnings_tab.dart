import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../kyc/kyc_details_screen.dart';
import '../../../kyc/kyc_provider.dart';
import '../../../wallet/presentation/screens/payout_history_screen.dart';
import '../../../wallet/presentation/widgets/bank_details_sheet.dart';
import '../../../wallet/presentation/widgets/cashout_bottom_sheet.dart';
import '../../../wallet/presentation/widgets/pay_dues_bottom_sheet.dart';
import '../../../wallet/wallet_provider.dart';
import '../../../wallet/wallet_model.dart';

class DriverEarningsTab extends ConsumerStatefulWidget {
  const DriverEarningsTab({super.key});

  @override
  ConsumerState<DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends ConsumerState<DriverEarningsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchWalletEarnings();
      ref.read(walletProvider.notifier).fetchPayouts();
      ref.read(walletProvider.notifier).fetchTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final kycData = ref.watch(kycProvider).kycData;

    final kycStatus = wallet.kycStatus.isNotEmpty
        ? wallet.kycStatus
        : (kycData.kycStatus.isNotEmpty
            ? kycData.kycStatus
            : (kycData.drivingLicenseNumber.isNotEmpty ? 'approved' : 'pending'));
    final isKycApproved = kycStatus.toLowerCase() == 'approved';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings & Wallet'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Payout History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: walletState.status == WalletStatus.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(walletProvider.notifier).fetchWalletEarnings();
              ref.read(walletProvider.notifier).fetchPayouts();
              ref.read(walletProvider.notifier).fetchTransactions();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(walletProvider.notifier).fetchWalletEarnings(),
              ref.read(walletProvider.notifier).fetchPayouts(),
              ref.read(walletProvider.notifier).fetchTransactions(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Guard Banner: KYC Pending
                if (!isKycApproved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Color(0xFFB45309), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Complete KYC to enable earning withdrawals.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB45309),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const KycDetailsScreen()),
                            );
                          },
                          child: const Text('Verify KYC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // 2. Guard Banner: Negative or Blocked Dues (with actionable Pay Dues CTA)
                if (wallet.balance <= 0 || wallet.isWalletBlocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              wallet.isWalletBlocked ? Icons.block_rounded : Icons.warning_amber_rounded,
                              color: Colors.red.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                wallet.balance < 0
                                    ? 'Pending cash commission dues: ₹${wallet.effectivePendingDues.toStringAsFixed(2)}. Pay dues to keep accepting rides and withdrawing earnings.'
                                    : 'Wallet balance is ₹0.00. Complete rides to start earning and withdrawing.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (wallet.balance < 0 || wallet.hasPendingDues) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.payment_rounded, size: 16),
                              label: Text(
                                'PAY DUES NOW (₹${wallet.effectivePendingDues.toStringAsFixed(2)})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => PayDuesBottomSheet.show(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                // 3. Guard Banner: Daily Limit Reached
                else if (wallet.payoutRules.isDailyLimitReached)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Daily limit reached (${wallet.payoutRules.maxPayoutsPerDay}/${wallet.payoutRules.maxPayoutsPerDay} today). Available tomorrow.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 1. Wallet Balance Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, Color(0xFF1E427B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Wallet Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: wallet.walletStatus == 'active'
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              wallet.walletStatusText,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        wallet.formattedBalance.isNotEmpty ? wallet.formattedBalance : '₹ ${wallet.availableBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Linked Bank & UPI Summary Row with Manage CTA
                      InkWell(
                        onTap: () => BankDetailsSheet.show(context, wallet.bankDetails),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  wallet.bankDetails.isBankLinked
                                      ? wallet.bankDetails.bankDestinationLabel
                                      : (wallet.bankDetails.isUpiLinked
                                          ? wallet.bankDetails.upiDestinationLabel
                                          : 'Bank Details Not Linked'),
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (wallet.bankDetails.isBankLinked || wallet.bankDetails.isUpiLinked)
                                      ? Colors.green.withValues(alpha: 0.35)
                                      : Colors.amber.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (wallet.bankDetails.isBankLinked || wallet.bankDetails.isUpiLinked)
                                      ? 'Linked ✅'
                                      : 'Not Linked ⚠️',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instant Cashout Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => CashoutBottomSheet.show(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text(
                            'INSTANT CASHOUT TO BANK',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Today's Earnings Breakdown Grid
                const Text(
                  "Today's Overview",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Net Earnings',
                        amount: wallet.today.formattedNetEarnings.isNotEmpty
                            ? wallet.today.formattedNetEarnings
                            : '₹ ${wallet.today.netEarnings.toStringAsFixed(2)}',
                        icon: Icons.payments_outlined,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Cash Collected',
                        amount: wallet.today.formattedCashCollected.isNotEmpty
                            ? wallet.today.formattedCashCollected
                            : '₹ ${wallet.today.cashCollected.toStringAsFixed(2)}',
                        icon: Icons.money_outlined,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Trips Completed',
                        amount: '${wallet.today.tripsCompleted} Trips',
                        icon: Icons.done_all_rounded,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Tips Earned Today',
                        amount: '+ ₹ ${(wallet.today.tips > 0 ? wallet.today.tips : wallet.totalTipsToday).toStringAsFixed(2)}',
                        icon: Icons.volunteer_activism_rounded,
                        color: const Color(0xFF0D9488),
                        isHighlight: (wallet.today.tips > 0 || wallet.totalTipsToday > 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEarningMiniCard(
                        title: 'Platform Commission',
                        amount: '₹ ${wallet.today.platformCommission.toStringAsFixed(2)}',
                        icon: Icons.remove_circle_outline_rounded,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                // Zero Commission Transparency Notice
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '100% of customer tips are yours. Ridonova charges 0% platform commission on tips.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Daily Target & Incentive Progress Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.card_giftcard_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.dailyIncentive.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    wallet.dailyIncentive.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: (wallet.dailyIncentive.progressPercentage / 100.0).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: AppColors.primary,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              wallet.dailyIncentive.progressText.isNotEmpty
                                  ? wallet.dailyIncentive.progressText
                                  : '${wallet.dailyIncentive.completedTrips} of ${wallet.dailyIncentive.targetTrips} trips completed',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              wallet.dailyIncentive.remainingText.isNotEmpty
                                  ? wallet.dailyIncentive.remainingText
                                  : '${wallet.dailyIncentive.remainingTrips} trips left',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Weekly Summary List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Weekly Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Last 7 Days',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (wallet.weeklySummary.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('No weekly earnings summary available.'),
                    ),
                  )
                else
                  ...wallet.weeklySummary.map((item) => _buildDayEarningTile(
                        day: item.day.isNotEmpty ? item.day : item.dayName,
                        rides: '${item.trips} Trips',
                        amount: item.formattedEarnings.isNotEmpty ? item.formattedEarnings : '₹ ${item.earnings.toStringAsFixed(2)}',
                      )),

                const SizedBox(height: 20),

                // 5. Recent Transactions / Wallet Ledger
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (walletState.isTransactionsLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        '${walletState.transactions.length} records',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (walletState.transactions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Center(
                      child: Text(
                        walletState.isTransactionsLoading
                            ? 'Loading transaction history...'
                            : 'No recent transactions recorded.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...walletState.transactions.take(20).map((txn) => _buildTransactionCard(txn, wallet)),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningMiniCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlight ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: isHighlight ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF15803D) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(WalletTransactionModel txn, WalletModel wallet) {
    final isTip = txn.isTip;
    final isPayoutWithdrawal = txn.isPayoutWithdrawal;
    final isPayoutRefund = txn.isPayoutRefund;
    final isCredit = txn.isCredit;

    // Subtitle formatting adhering to spec:
    // Debit Transaction: -₹500.00 with subtitle "Payout Withdrawal to HDFC Bank (••••1098)"
    // Credit / Refund Transaction: +₹500.00 with badge "Refund" and subtitle "Payout Refund (Failed): <reason>"
    String subtitleText = txn.displaySubtitle;
    if (isPayoutWithdrawal && subtitleText.isEmpty) {
      subtitleText = 'Payout Withdrawal to ${wallet.bankDetails.bankDestinationLabel}';
    } else if (isPayoutRefund && subtitleText.isEmpty) {
      subtitleText = txn.description.isNotEmpty
          ? 'Payout Refund (Failed): ${txn.description}'
          : 'Payout Refund (Failed): Amount credited back';
    }

    final Color iconBg = isTip
        ? const Color(0xFFDCFCE7)
        : isPayoutRefund
            ? const Color(0xFFDCFCE7)
            : isPayoutWithdrawal
                ? const Color(0xFFFEE2E2)
                : isCredit
                    ? const Color(0xFFE0F2FE)
                    : const Color(0xFFFEE2E2);

    final IconData icon = isTip
        ? Icons.star_rounded
        : isPayoutRefund
            ? Icons.replay_rounded
            : isPayoutWithdrawal
                ? Icons.arrow_upward_rounded
                : isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded;

    final Color iconColor = (isTip || isPayoutRefund)
        ? const Color(0xFF15803D)
        : isPayoutWithdrawal
            ? Colors.red.shade700
            : isCredit
                ? const Color(0xFF0284C7)
                : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isTip || isPayoutRefund)
              ? const Color(0xFF86EFAC)
              : isPayoutWithdrawal
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFF1F5F9),
          width: (isTip || isPayoutRefund || isPayoutWithdrawal) ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        txn.displayTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTip) ...[
                      const SizedBox(width: 6),
                      _buildTag('TIP', const Color(0xFF16A34A)),
                    ] else if (isPayoutRefund) ...[
                      const SizedBox(width: 6),
                      _buildTag('REFUND', const Color(0xFF059669)),
                    ] else if (isPayoutWithdrawal) ...[
                      const SizedBox(width: 6),
                      _buildTag('CASHOUT', Colors.red.shade700),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                if (subtitleText.isNotEmpty) ...[
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isPayoutRefund
                          ? const Color(0xFF15803D)
                          : isPayoutWithdrawal
                              ? Colors.red.shade800
                              : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                ],

                Row(
                  children: [
                    if (txn.referenceId.isNotEmpty) ...[
                      Text(
                        '#${txn.referenceId.length > 8 ? txn.referenceId.substring(txn.referenceId.length - 8) : txn.referenceId}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      txn.createdAt.isNotEmpty
                          ? (txn.createdAt.length >= 10 ? txn.createdAt.substring(0, 10) : txn.createdAt)
                          : 'Recent',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'} ₹${txn.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? const Color(0xFF15803D) : Colors.red.shade700,
                ),
              ),
              if (txn.balanceAfter != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Bal: ₹${txn.balanceAfter!.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDayEarningTile({
    required String day,
    required String rides,
    required String amount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                rides,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
