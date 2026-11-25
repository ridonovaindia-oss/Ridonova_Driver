import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../models/cancel_reason_model.dart';
import '../providers/driver_cancel_ride_provider.dart';

/// Shows the Driver Ride Cancellation Bottom Sheet Modal
Future<bool?> showDriverCancelRideBottomSheet(
  BuildContext context, {
  required String rideId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DriverCancelRideBottomSheet(rideId: rideId),
  );
}

class DriverCancelRideBottomSheet extends ConsumerStatefulWidget {
  final String rideId;

  const DriverCancelRideBottomSheet({super.key, required this.rideId});

  @override
  ConsumerState<DriverCancelRideBottomSheet> createState() =>
      _DriverCancelRideBottomSheetState();
}

class _DriverCancelRideBottomSheetState
    extends ConsumerState<DriverCancelRideBottomSheet> {
  String? _selectedCode;
  String? _selectedLabel;
  final TextEditingController _otherReasonController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmCancel() async {
    setState(() => _errorMessage = null);

    if (_selectedCode == null) {
      setState(() => _errorMessage = 'Please select a reason for cancelling this trip.');
      return;
    }

    String finalReason = _selectedLabel ?? 'Driver cancelled';
    if (_selectedCode == 'other') {
      final customText = _otherReasonController.text.trim();
      if (customText.isEmpty) {
        setState(() => _errorMessage = 'Please provide details for your reason.');
        return;
      }
      finalReason = customText;
    }

    final success = await ref.read(cancelRideStateProvider.notifier).cancelRide(
          rideId: widget.rideId,
          code: _selectedCode!,
          reason: finalReason,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
      AppFlushbar.info(
        context,
        title: 'Ride Cancelled',
        message: 'The ride has been cancelled successfully.',
      );
    } else {
      final state = ref.read(cancelRideStateProvider);
      setState(() {
        _errorMessage = state.error?.toString() ?? 'Failed to cancel ride. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasonsAsync = ref.watch(driverCancelReasonsProvider);
    final cancelState = ref.watch(cancelRideStateProvider);
    final isSubmitting = cancelState.isLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Cancel Ride',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'RIDE #${widget.rideId.length > 8 ? widget.rideId.substring(widget.rideId.length - 8) : widget.rideId}',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Impact Warning Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Frequent cancellations may affect your acceptance score and daily incentive eligibility.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. Scrollable List of Reasons
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please select a reason for cancellation:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  reasonsAsync.when(
                    data: (reasons) => _buildReasonsList(reasons),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => _buildReasonsList(CancelReasonModel.fallbackReasons),
                  ),

                  // Expandable "Other" Reason Text Input
                  if (_selectedCode == 'other') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Provide more details:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _otherReasonController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Describe the issue (e.g. road construction, puncture)...',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              contentPadding: const EdgeInsets.all(10),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 5. Action Buttons (Keep Ride vs Confirm Cancel)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Secondary "Don't Cancel" Button
                Expanded(
                  child: InkWell(
                    onTap: isSubmitting ? null : () => Navigator.pop(context, false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Center(
                        child: Text(
                          "DON'T CANCEL",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Primary "Confirm Cancel" Button
                Expanded(
                  child: InkWell(
                    onTap: (isSubmitting || _selectedCode == null) ? null : _handleConfirmCancel,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _selectedCode == null
                            ? const Color(0xFFE2E8F0)
                            : AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedCode != null
                            ? [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'CONFIRM CANCEL',
                                style: TextStyle(
                                  color: _selectedCode == null
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
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

  Widget _buildReasonsList(List<CancelReasonModel> reasons) {
    return Column(
      children: reasons.map((reason) {
        final isSelected = _selectedCode == reason.code;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFFF87171) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: RadioListTile<String>(
                value: reason.code,
                groupValue: _selectedCode,
                activeColor: AppColors.error,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                dense: true,
                title: Text(
                  reason.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? const Color(0xFF991B1B) : AppColors.textPrimary,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedCode = value;
                    _selectedLabel = reason.label;
                    _errorMessage = null;
                  });
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
