import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../models/driver_lost_item_model.dart';
import '../providers/driver_lost_item_provider.dart';

/// Opens the Captain Response Bottom Sheet Modal for a Reported Lost Item
void showRespondLostItemSheet(BuildContext context, DriverLostItemModel item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => RespondLostItemSheet(item: item),
  );
}

class RespondLostItemSheet extends ConsumerStatefulWidget {
  final DriverLostItemModel item;

  const RespondLostItemSheet({super.key, required this.item});

  @override
  ConsumerState<RespondLostItemSheet> createState() => _RespondLostItemSheetState();
}

class _RespondLostItemSheetState extends ConsumerState<RespondLostItemSheet> {
  bool? _selectedFound; // true = Yes found, false = Not found
  final TextEditingController _noteController = TextEditingController();
  bool _confirmedInspected = false;
  String? _validationError;

  @override
  void dispose() {
    _noteController.dispose();
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

  Future<void> _submit() async {
    setState(() => _validationError = null);

    if (_selectedFound == null) {
      setState(() => _validationError = 'Please select whether you found the item or not.');
      return;
    }

    if (_selectedFound == false && !_confirmedInspected) {
      setState(() => _validationError = 'Please confirm that you thoroughly checked your vehicle.');
      return;
    }

    final success = await ref.read(driverLostItemProvider.notifier).submitResponse(
          widget.item.id,
          found: _selectedFound!,
          note: _noteController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      AppFlushbar.success(
        context,
        title: _selectedFound! ? 'Item Marked as Found! 🎉' : 'Response Recorded',
        message: _selectedFound!
            ? 'Passenger has been notified. They may reach out to coordinate handover.'
            : 'Passenger notified that the item was not found in vehicle.',
      );
    } else {
      final error = ref.read(driverLostItemProvider).errorMessage;
      setState(() => _validationError = error ?? 'Failed to submit response. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lostState = ref.watch(driverLostItemProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final item = widget.item;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Drag Handle
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Lost Item Inquiry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'ACTION REQUIRED',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Item Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.categoryEmoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.categoryDisplayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Ride #${item.rideId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.contactPhone.isNotEmpty)
                          InkWell(
                            onTap: () => _makePhoneCall(item.contactPhone),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone_rounded, color: AppColors.secondary, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Call',
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item.description.isNotEmpty
                            ? '"${item.description}"'
                            : 'No specific description provided by passenger.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (item.pickupAddress.isNotEmpty || item.dropoffAddress.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.trip_origin, size: 12, color: AppColors.success),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.pickupAddress,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.dropoffAddress,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Response Choice Prompt
              const Text(
                'Did you find this item in your vehicle?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Two Choice Cards: Found vs Not Found
              Row(
                children: [
                  // Choice 1: Yes, Found
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFound = true;
                          _validationError = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedFound == true ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedFound == true
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE2E8F0),
                            width: _selectedFound == true ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _selectedFound == true
                                    ? const Color(0xFFDCFCE7)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: _selectedFound == true
                                    ? const Color(0xFF16A34A)
                                    : Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yes, I Found It',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedFound == true
                                    ? const Color(0xFF15803D)
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Item is safe in car',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: _selectedFound == true
                                    ? const Color(0xFF166534)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Choice 2: No, Not Found
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFound = false;
                          _validationError = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedFound == false ? const Color(0xFFFEF2F2) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedFound == false
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE2E8F0),
                            width: _selectedFound == false ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _selectedFound == false
                                    ? const Color(0xFFFEE2E2)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cancel_rounded,
                                color: _selectedFound == false
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No, Not in Car',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedFound == false
                                    ? const Color(0xFF991B1B)
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Checked thoroughly',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: _selectedFound == false
                                    ? const Color(0xFF7F1D1D)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 5. Contextual Inputs based on selection
              if (_selectedFound == true) ...[
                const Text(
                  'Handover Note for Passenger (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g., Found under rear seat. Safe in car boot. You can call me to collect.',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Passenger will be notified with your note to coordinate item return.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_selectedFound == false) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _confirmedInspected = !_confirmedInspected;
                      _validationError = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _confirmedInspected,
                        activeColor: const Color(0xFFDC2626),
                        onChanged: (val) {
                          setState(() {
                            _confirmedInspected = val ?? false;
                            _validationError = null;
                          });
                        },
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 10.0),
                          child: Text(
                            'I confirm that I have thoroughly checked the rear seats, door pockets, seat pockets, floor mats, and boot.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Optional note: e.g., Checked entire car but item was not found.',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],

              if (_validationError != null) ...[
                const SizedBox(height: 12),
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
                          _validationError!,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 6. Confirm & Submit Action Button
              InkWell(
                onTap: lostState.isSubmitting ? null : _submit,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _selectedFound == false
                        ? const Color(0xFFDC2626)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedFound == false
                                ? const Color(0xFFDC2626)
                                : AppColors.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: lostState.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selectedFound == false
                                ? 'CONFIRM ITEM NOT FOUND'
                                : 'CONFIRM & NOTIFY PASSENGER',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
