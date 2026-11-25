import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_flushbar.dart';
import '../models/driver_ride_invoice_model.dart';
import '../ride_provider.dart';

/// Shows the Driver In-App Trip Invoice & Receipt Bottom Sheet Modal
void showDriverRideInvoiceSheet(
  BuildContext context, {
  required String rideId,
  String? preloadedRiderName,
  double? preloadedTotal,
}) {
  if (rideId.isEmpty) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => _DriverRideInvoiceSheetModal(
      rideId: rideId,
      preloadedRiderName: preloadedRiderName,
      preloadedTotal: preloadedTotal,
    ),
  );
}

class _DriverRideInvoiceSheetModal extends ConsumerStatefulWidget {
  final String rideId;
  final String? preloadedRiderName;
  final double? preloadedTotal;

  const _DriverRideInvoiceSheetModal({
    required this.rideId,
    this.preloadedRiderName,
    this.preloadedTotal,
  });

  @override
  ConsumerState<_DriverRideInvoiceSheetModal> createState() => _DriverRideInvoiceSheetModalState();
}

class _DriverRideInvoiceSheetModalState extends ConsumerState<_DriverRideInvoiceSheetModal> {
  bool _isLoading = true;
  String? _errorMessage;
  DriverRideInvoiceModel? _invoice;

  @override
  void initState() {
    super.initState();
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final invoice = await ref.read(rideProvider.notifier).getDriverRideInvoice(widget.rideId);

    if (mounted) {
      if (invoice != null) {
        setState(() {
          _invoice = invoice;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Could not load invoice details. Make sure the ride is completed.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyInvoiceLink(String rideId) async {
    final url = await RideNotifier.getInvoiceShareLink(rideId);
    if (!mounted) return;
    if (url == null) {
      AppFlushbar.error(context, title: 'Invoice', message: 'Could not create invoice link. Please try again.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppFlushbar.success(
      context,
      title: 'Invoice Link Copied',
      message: 'Printable receipt link (valid 30 minutes) copied to clipboard.',
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
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

          // Modal Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Receipt & Tax Invoice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Official Ridonova Captain Bill',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Body
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildInvoiceBody(_invoice!),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 18),
            const Text(
              'Generating Trip Tax Invoice...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Fetching fare lines & GST breakdown for ride ${widget.rideId.length > 8 ? widget.rideId.substring(0, 8) : widget.rideId}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Invoice Not Available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Invoices are only generated for completed trips.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _fetchInvoice,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceBody(DriverRideInvoiceModel invoice) {
    final isCash = invoice.payment.method.toUpperCase().contains('CASH');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Invoice Meta Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INVOICE NUMBER',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCash ? AppColors.success.withValues(alpha: 0.2) : const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCash ? AppColors.success.withValues(alpha: 0.5) : const Color(0xFF3B82F6).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCash ? Icons.payments_rounded : Icons.account_balance_wallet_rounded,
                            size: 14,
                            color: isCash ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'PAID VIA ${invoice.payment.method.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCash ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFF334155)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completed: ${invoice.invoiceDate}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                    if (invoice.payment.transactionId.isNotEmpty)
                      Text(
                        'Txn: ${invoice.payment.transactionId}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Trip Route Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (invoice.rider.name.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Passenger: ${invoice.rider.name}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                ],

                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.circle, size: 12, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PICKUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            invoice.trip.pickup.isNotEmpty ? invoice.trip.pickup : 'Pickup Location',
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dropoff
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.location_on, size: 14, color: AppColors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DROP-OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            invoice.trip.dropoff.isNotEmpty ? invoice.trip.dropoff : 'Drop-off Destination',
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (invoice.trip.distanceKm > 0 || invoice.trip.durationMins > 0) ...[
                  const Divider(height: 18),
                  Row(
                    children: [
                      if (invoice.trip.distanceKm > 0) ...[
                        const Icon(Icons.straighten_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${invoice.trip.distanceKm} km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(width: 14),
                      ],
                      if (invoice.trip.durationMins > 0) ...[
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${invoice.trip.durationMins} mins', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Itemized Earnings & Fare Breakdown
          const Text(
            'Itemized Fare Breakdown',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Line Items
                if (invoice.lines.isNotEmpty) ...[
                  for (final line in invoice.lines) ...[
                    _buildFareRow(
                      label: line.label,
                      amount: line.amount,
                      isDeduction: line.amount < 0,
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  _buildFareRow(label: 'Standard Trip Fare', amount: invoice.subtotal > 0 ? invoice.subtotal : invoice.grandTotal),
                  const SizedBox(height: 8),
                ],

                const Divider(height: 16),

                // Subtotal
                if (invoice.subtotal > 0) ...[
                  _buildFareRow(
                    label: 'Subtotal (Net Fare)',
                    amount: invoice.subtotal,
                    isSemiBold: true,
                  ),
                  const SizedBox(height: 8),
                ],

                // Taxes (GST 5%)
                if (invoice.gst.total > 0) ...[
                  if (invoice.gst.cgst > 0) ...[
                    _buildFareRow(
                      label: 'CGST (2.5%)',
                      amount: invoice.gst.cgst,
                      isSecondary: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (invoice.gst.sgst > 0) ...[
                    _buildFareRow(
                      label: 'SGST (2.5%)',
                      amount: invoice.gst.sgst,
                      isSecondary: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (invoice.gst.cgst == 0 && invoice.gst.sgst == 0) ...[
                    _buildFareRow(
                      label: 'GST Taxes (5%)',
                      amount: invoice.gst.total,
                      isSecondary: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                ],

                // Customer Tip
                if (invoice.tip > 0) ...[
                  _buildFareRow(
                    label: 'Customer Tip (Direct)',
                    amount: invoice.tip,
                    highlightColor: AppColors.success,
                  ),
                  const SizedBox(height: 6),
                ],

                const Divider(height: 20, thickness: 1.2),

                // Grand Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Billed Amount',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '₹ ${invoice.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Action Buttons (Print / PDF & Share Link)
          Row(
            children: [
              // Download / Print PDF Button
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => RideNotifier.openPrintableInvoice(invoice.rideId),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 50,
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
                        Icon(Icons.print_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'DOWNLOAD / PRINT PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Copy Link Button
              InkWell(
                onTap: () => _copyInvoiceLink(invoice.rideId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Center(
                    child: Icon(Icons.share_outlined, color: AppColors.secondary, size: 20),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              'Printable receipt includes official GSTIN & Ridonova company seal',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow({
    required String label,
    required double amount,
    bool isDeduction = false,
    bool isSemiBold = false,
    bool isSecondary = false,
    Color? highlightColor,
  }) {
    final formattedAmt = '${isDeduction ? '-' : ''}₹ ${amount.abs().toStringAsFixed(2)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSecondary ? 12 : 13,
            fontWeight: isSemiBold ? FontWeight.bold : FontWeight.w500,
            color: isSecondary ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        Text(
          formattedAmt,
          style: TextStyle(
            fontSize: isSecondary ? 12 : 13,
            fontWeight: isSemiBold ? FontWeight.bold : FontWeight.w600,
            color: highlightColor ?? (isDeduction ? AppColors.error : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

