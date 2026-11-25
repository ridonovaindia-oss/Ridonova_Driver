import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../wallet_model.dart';

class PayoutReceiptModal extends StatelessWidget {
  final PayoutRequestResult result;
  final VoidCallback? onViewHistory;

  const PayoutReceiptModal({
    super.key,
    required this.result,
    this.onViewHistory,
  });

  static Future<void> show(
    BuildContext context, {
    required PayoutRequestResult result,
    VoidCallback? onViewHistory,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PayoutReceiptModal(
        result: result,
        onViewHistory: onViewHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = result.status.toLowerCase();
    final isCompleted = normalizedStatus == 'completed' ||
        normalizedStatus == 'processed' ||
        normalizedStatus == 'success';
    final isProcessing = normalizedStatus == 'processing';

    final String title;
    final String badgeText;
    final Color badgeBg;
    final Color badgeFg;
    final IconData heroIcon;
    final Color heroColor;
    final String noteText;

    if (isCompleted) {
      title = 'Withdrawal Credited';
      badgeText = 'Credited';
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
      heroIcon = Icons.check_circle_rounded;
      heroColor = const Color(0xFF16A34A);
      noteText = 'Amount has been credited to your account.';
    } else if (isProcessing) {
      title = 'Withdrawal Initiated';
      badgeText = 'Processing';
      badgeBg = const Color(0xFFDBEAFE);
      badgeFg = const Color(0xFF1D4ED8);
      heroIcon = Icons.sync_rounded;
      heroColor = const Color(0xFF2563EB);
      noteText = 'Amount will be credited to your account via IMPS/UPI shortly.';
    } else {
      title = 'Request Under Review';
      badgeText = 'Pending';
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFB45309);
      heroIcon = Icons.hourglass_top_rounded;
      heroColor = const Color(0xFFD97706);
      noteText = 'Your withdrawal request is under review and will be credited via IMPS/UPI shortly.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Hero Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: heroColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(heroIcon, color: heroColor, size: 36),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Receipt Details Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildRow(
                  'Amount',
                  '₹ ${result.amount.toStringAsFixed(2)}',
                  isBold: true,
                  valueFontSize: 18,
                  valueColor: AppColors.textPrimary,
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _buildRow(
                  'Destination',
                  result.destination.isNotEmpty
                      ? result.destination
                      : result.payoutMethod.toUpperCase(),
                ),
                const SizedBox(height: 10),
                _buildRow(
                  'Payout Method',
                  result.payoutMethod.toLowerCase() == 'upi'
                      ? 'UPI Instant Transfer'
                      : 'Bank IMPS Transfer',
                ),
                if (result.payoutId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildRow(
                    'Reference ID',
                    result.payoutId.length > 14
                        ? '...${result.payoutId.substring(result.payoutId.length - 12)}'
                        : result.payoutId,
                    isMonospace: true,
                  ),
                ],
                if (result.utr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'UTR Number',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Row(
                        children: [
                          Text(
                            result.utr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: result.utr));
                              AppFlushbar.success(
                                context,
                                title: 'UTR Copied',
                                message: 'UTR ${result.utr} copied to clipboard.',
                              );
                            },
                            child: const Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Async Info Note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    noteText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E40AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              if (onViewHistory != null) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.secondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onViewHistory!();
                    },
                    child: const Text(
                      'PAYOUT HISTORY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'DONE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double valueFontSize = 13,
    Color valueColor = AppColors.textPrimary,
    bool isMonospace = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
