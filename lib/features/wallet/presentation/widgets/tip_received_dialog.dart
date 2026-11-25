import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Triggers and displays the In-App Tip Received Celebration Dialog
void showTipCelebrationDialog(
  BuildContext context, {
  required double amount,
  String? rideId,
  String? method,
  VoidCallback? onViewWallet,
}) {
  // Trigger tactile celebration haptic feedback
  try {
    HapticFeedback.heavyImpact();
  } catch (_) {}

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => TipReceivedDialog(
      amount: amount,
      rideId: rideId,
      method: method,
      onViewWallet: onViewWallet,
    ),
  );
}

class TipReceivedDialog extends StatefulWidget {
  final double amount;
  final String? rideId;
  final String? method;
  final VoidCallback? onViewWallet;

  const TipReceivedDialog({
    super.key,
    required this.amount,
    this.rideId,
    this.method,
    this.onViewWallet,
  });

  @override
  State<TipReceivedDialog> createState() => _TipReceivedDialogState();
}

class _TipReceivedDialogState extends State<TipReceivedDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = widget.amount.toStringAsFixed(widget.amount % 1 == 0 ? 0 : 2);
    final methodStr = (widget.method?.isNotEmpty == true) ? widget.method!.toUpperCase() : 'PASSENGER WALLET';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Celebration Trophy / Heart Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. Large Green Celebration Headline
              Text(
                '+ ₹$formattedAmount Tip Received! 🎉',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF047857),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // 3. Passenger appreciation description
              const Text(
                'Your passenger appreciated your great service and rewarded you with a tip!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),

              if (widget.rideId != null && widget.rideId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ride #${widget.rideId!.length > 8 ? widget.rideId!.substring(0, 8).toUpperCase() : widget.rideId} • $methodStr',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 4. 0% Commission Transparency Notice Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF059669),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100% Yours • Zero Commission',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '100% of this tip has been credited to your wallet. 0% platform deduction.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF047857),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 5. Actions Row (View Wallet & Dismiss)
              Row(
                children: [
                  // Dismiss Button
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Great! 👍',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // View Wallet Button
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (widget.onViewWallet != null) {
                          widget.onViewWallet!();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'View Wallet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

