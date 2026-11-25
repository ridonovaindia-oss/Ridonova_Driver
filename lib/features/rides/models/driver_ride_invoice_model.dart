import '../../../../core/network/api_constants.dart';

class InvoiceLineItemModel {
  final String label;
  final double amount;

  InvoiceLineItemModel({
    required this.label,
    required this.amount,
  });

  factory InvoiceLineItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItemModel(
      label: json['label']?.toString() ?? json['title']?.toString() ?? json['name']?.toString() ?? 'Fare Item',
      amount: double.tryParse(json['amount']?.toString() ?? json['fare']?.toString() ?? json['price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class InvoiceTripModel {
  final String pickup;
  final String dropoff;
  final double distanceKm;
  final int durationMins;

  InvoiceTripModel({
    this.pickup = '',
    this.dropoff = '',
    this.distanceKm = 0.0,
    this.durationMins = 0,
  });

  factory InvoiceTripModel.fromJson(Map<String, dynamic> json) {
    return InvoiceTripModel(
      pickup: json['pickup']?.toString() ?? json['pickupAddress']?.toString() ?? json['pickup_address']?.toString() ?? '',
      dropoff: json['dropoff']?.toString() ?? json['dropAddress']?.toString() ?? json['dropoff_address']?.toString() ?? '',
      distanceKm: double.tryParse(json['distanceKm']?.toString() ?? json['distance']?.toString() ?? '0') ?? 0.0,
      durationMins: int.tryParse(json['durationMins']?.toString() ?? json['duration']?.toString() ?? '0') ?? 0,
    );
  }
}

class InvoiceGstModel {
  final double cgst;
  final double sgst;
  final double total;

  InvoiceGstModel({
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.total = 0.0,
  });

  factory InvoiceGstModel.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final cgstVal = double.tryParse(json['cgst']?.toString() ?? '0') ?? 0.0;
      final sgstVal = double.tryParse(json['sgst']?.toString() ?? '0') ?? 0.0;
      final totalVal = double.tryParse(json['total']?.toString() ?? json['amount']?.toString() ?? '0') ?? (cgstVal + sgstVal);
      return InvoiceGstModel(cgst: cgstVal, sgst: sgstVal, total: totalVal);
    } else if (json is num) {
      final totalVal = json.toDouble();
      return InvoiceGstModel(cgst: totalVal / 2, sgst: totalVal / 2, total: totalVal);
    }
    return InvoiceGstModel();
  }
}

class InvoicePaymentModel {
  final String method;
  final String status;
  final String transactionId;

  InvoicePaymentModel({
    this.method = 'CASH',
    this.status = 'PAID',
    this.transactionId = '',
  });

  factory InvoicePaymentModel.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return InvoicePaymentModel(
        method: json['method']?.toString() ?? json['paymentMethod']?.toString() ?? json['mode']?.toString() ?? 'CASH',
        status: json['status']?.toString() ?? 'PAID',
        transactionId: json['transactionId']?.toString() ?? json['txnId']?.toString() ?? json['id']?.toString() ?? '',
      );
    } else if (json is String) {
      return InvoicePaymentModel(method: json, status: 'PAID');
    }
    return InvoicePaymentModel();
  }
}

class InvoiceRiderModel {
  final String name;
  final String phone;

  InvoiceRiderModel({
    this.name = '',
    this.phone = '',
  });

  factory InvoiceRiderModel.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return InvoiceRiderModel(
        name: json['name']?.toString() ?? json['fullName']?.toString() ?? json['riderName']?.toString() ?? '',
        phone: json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? json['mobile']?.toString() ?? '',
      );
    } else if (json is String) {
      return InvoiceRiderModel(name: json);
    }
    return InvoiceRiderModel();
  }
}

class DriverRideInvoiceModel {
  final String rideId;
  final String invoiceNumber;
  final String invoiceDate;
  final InvoiceTripModel trip;
  final List<InvoiceLineItemModel> lines;
  final double subtotal;
  final InvoiceGstModel gst;
  final double tip;
  final double grandTotal;
  final InvoicePaymentModel payment;
  final InvoiceRiderModel rider;

  DriverRideInvoiceModel({
    required this.rideId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.trip,
    required this.lines,
    required this.subtotal,
    required this.gst,
    required this.tip,
    required this.grandTotal,
    required this.payment,
    required this.rider,
  });

  String get htmlInvoiceUrl => ApiConstants.rideInvoiceHtml(rideId);

  factory DriverRideInvoiceModel.fromJson(String rideId, Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? rawJson['data'] as Map<String, dynamic>
        : (rawJson['invoice'] is Map<String, dynamic>)
            ? rawJson['invoice'] as Map<String, dynamic>
            : rawJson;

    // Parse Trip
    InvoiceTripModel trip;
    if (json['trip'] is Map<String, dynamic>) {
      trip = InvoiceTripModel.fromJson(json['trip']);
    } else {
      trip = InvoiceTripModel.fromJson(json);
    }

    // Parse Line Items
    List<InvoiceLineItemModel> lines = [];
    final rawLines = json['lines'] ?? json['items'] ?? json['fareBreakdown'] ?? json['fareLines'];
    if (rawLines is List) {
      for (var item in rawLines) {
        if (item is Map<String, dynamic>) {
          lines.add(InvoiceLineItemModel.fromJson(item));
        }
      }
    }

    // Subtotal
    final subtotal = double.tryParse(json['subtotal']?.toString() ?? json['netFare']?.toString() ?? json['baseTotal']?.toString() ?? '0') ?? 0.0;

    // GST
    final gst = InvoiceGstModel.fromJson(json['gst'] ?? json['tax']);

    // Tip
    final tip = double.tryParse(json['tip']?.toString() ?? json['driverTip']?.toString() ?? '0') ?? 0.0;

    // Grand Total
    final grandTotal = double.tryParse(
          json['grandTotal']?.toString() ?? json['total']?.toString() ?? json['fare']?.toString() ?? json['finalFare']?.toString() ?? '0',
        ) ??
        0.0;

    // Payment
    final payment = InvoicePaymentModel.fromJson(json['payment'] ?? json['paymentDetails'] ?? json['paymentMethod']);

    // Rider
    final rider = InvoiceRiderModel.fromJson(json['rider'] ?? json['customer'] ?? json['passenger']);

    // Invoice Number
    final invNumber = json['invoiceNumber']?.toString() ?? json['invoiceNo']?.toString() ?? 'INV-${rideId.length > 6 ? rideId.substring(0, 6).toUpperCase() : rideId}';

    // Invoice Date
    final invDate = json['invoiceDate']?.toString() ?? json['completedAt']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toLocal().toString().split('.')[0];

    return DriverRideInvoiceModel(
      rideId: rideId,
      invoiceNumber: invNumber,
      invoiceDate: invDate,
      trip: trip,
      lines: lines,
      subtotal: subtotal,
      gst: gst,
      tip: tip,
      grandTotal: grandTotal,
      payment: payment,
      rider: rider,
    );
  }
}

