class DailyEarningsModel {
  final double netEarnings;
  final double cashCollected;
  final double onlineEarnings;
  final int tripsCompleted;
  final double grossEarnings;
  final double platformCommission;
  final double tips;
  final String formattedNetEarnings;
  final String formattedCashCollected;
  final String formattedTips;

  DailyEarningsModel({
    this.netEarnings = 0.0,
    this.cashCollected = 0.0,
    this.onlineEarnings = 0.0,
    this.tripsCompleted = 0,
    this.grossEarnings = 0.0,
    this.platformCommission = 0.0,
    this.tips = 0.0,
    this.formattedNetEarnings = '₹ 0.00',
    this.formattedCashCollected = '₹ 0.00',
    this.formattedTips = '₹ 0.00',
  });

  factory DailyEarningsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DailyEarningsModel();
    final tipVal =
        (json['tips'] as num?)?.toDouble() ??
        (json['tipAmount'] as num?)?.toDouble() ??
        (json['totalTips'] as num?)?.toDouble() ??
        0.0;
    return DailyEarningsModel(
      netEarnings: (json['netEarnings'] as num?)?.toDouble() ?? 0.0,
      cashCollected: (json['cashCollected'] as num?)?.toDouble() ?? 0.0,
      onlineEarnings: (json['onlineEarnings'] as num?)?.toDouble() ?? 0.0,
      tripsCompleted: (json['tripsCompleted'] as num?)?.toInt() ?? 0,
      grossEarnings: (json['grossEarnings'] as num?)?.toDouble() ?? 0.0,
      platformCommission:
          (json['platformCommission'] as num?)?.toDouble() ?? 0.0,
      tips: tipVal,
      formattedNetEarnings:
          json['formattedNetEarnings']?.toString() ?? '₹ 0.00',
      formattedCashCollected:
          json['formattedCashCollected']?.toString() ?? '₹ 0.00',
      formattedTips:
          json['formattedTips']?.toString() ?? '₹ ${tipVal.toStringAsFixed(2)}',
    );
  }
}

class DailyIncentiveModel {
  final String title;
  final String subtitle;
  final int targetTrips;
  final int completedTrips;
  final int remainingTrips;
  final double bonusAmount;
  final double progressPercentage;
  final bool isAchieved;
  final String progressText;
  final String remainingText;

  DailyIncentiveModel({
    this.title = 'Daily Incentive Goal',
    this.subtitle = 'Earn ₹150 Bonus on 5 Trips',
    this.targetTrips = 5,
    this.completedTrips = 0,
    this.remainingTrips = 5,
    this.bonusAmount = 150.0,
    this.progressPercentage = 0.0,
    this.isAchieved = false,
    this.progressText = '0 of 5 trips completed',
    this.remainingText = '5 trips left',
  });

  factory DailyIncentiveModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DailyIncentiveModel();
    return DailyIncentiveModel(
      title: json['title']?.toString() ?? 'Daily Incentive Goal',
      subtitle: json['subtitle']?.toString() ?? '',
      targetTrips: (json['targetTrips'] as num?)?.toInt() ?? 5,
      completedTrips: (json['completedTrips'] as num?)?.toInt() ?? 0,
      remainingTrips: (json['remainingTrips'] as num?)?.toInt() ?? 5,
      bonusAmount: (json['bonusAmount'] as num?)?.toDouble() ?? 150.0,
      progressPercentage:
          (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      isAchieved: json['isAchieved'] == true,
      progressText: json['progressText']?.toString() ?? '',
      remainingText: json['remainingText']?.toString() ?? '',
    );
  }
}

class WeeklySummaryItem {
  final String day;
  final String dayName;
  final String date;
  final int trips;
  final double earnings;
  final String formattedEarnings;

  WeeklySummaryItem({
    this.day = '',
    this.dayName = '',
    this.date = '',
    this.trips = 0,
    this.earnings = 0.0,
    this.formattedEarnings = '₹ 0.00',
  });

  factory WeeklySummaryItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WeeklySummaryItem();
    return WeeklySummaryItem(
      day: json['day']?.toString() ?? '',
      dayName: json['dayName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      trips: (json['trips'] as num?)?.toInt() ?? 0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      formattedEarnings: json['formattedEarnings']?.toString() ?? '₹ 0.00',
    );
  }
}

class BankDetailsModel {
  final String accountHolder;
  final String accountNumber;
  final String bankName;
  final String ifscCode;
  final String upiId;
  final String defaultMethod;
  final bool isBankLinked;
  final bool isUpiLinked;

  BankDetailsModel({
    this.accountHolder = '',
    this.accountNumber = '',
    this.bankName = '',
    this.ifscCode = '',
    this.upiId = '',
    this.defaultMethod = 'bank',
    this.isBankLinked = false,
    this.isUpiLinked = false,
  });

  bool get hasAnyLinkedAccount => isBankLinked || isUpiLinked;

  /// Ensures account number is always masked for UI privacy
  String get maskedAccountNumber {
    final trimmed = accountNumber.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'not linked') {
      return 'Not Linked';
    }
    if (trimmed.contains('•') || trimmed.contains('*') || trimmed.toUpperCase().contains('X')) {
      return trimmed;
    }
    if (trimmed.length > 4) {
      return '••••••••${trimmed.substring(trimmed.length - 4)}';
    }
    return trimmed;
  }

  /// Display-friendly bank destination string, e.g. "HDFC Bank (••••1098)"
  String get bankDestinationLabel {
    if (!isBankLinked) return 'Bank Not Linked';
    final name = bankName.isNotEmpty ? bankName : 'Bank Account';
    final acct = maskedAccountNumber;
    if (acct.isNotEmpty && acct != 'Not Linked') {
      final shortMask = acct.length > 8
          ? '••••${acct.substring(acct.length - 4)}'
          : acct;
      return '$name ($shortMask)';
    }
    return name;
  }

  /// Display-friendly UPI destination string, e.g. "UPI: ramesh@okhdfcbank"
  String get upiDestinationLabel {
    if (!isUpiLinked || upiId.isEmpty) return 'UPI Not Linked';
    return 'UPI: $upiId';
  }

  factory BankDetailsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BankDetailsModel();
    final rawAcct = (json['accountNumber'] ?? json['maskedAccountNumber'] ?? '').toString().trim();
    final rawIfsc = (json['ifscCode'] ?? '').toString().trim();
    final rawBankName = (json['bankName'] ?? '').toString().trim();
    final rawUpi = (json['upiId'] ?? '').toString().trim();
    final rawHolder = (json['accountHolder'] ?? json['accountHolderName'] ?? '').toString().trim();

    final hasExplicitBankFlag = json.containsKey('isBankLinked');
    final hasExplicitUpiFlag = json.containsKey('isUpiLinked');

    final bankLinked = hasExplicitBankFlag
        ? json['isBankLinked'] == true
        : (rawAcct.isNotEmpty &&
            rawAcct.toLowerCase() != 'not linked' &&
            rawIfsc.isNotEmpty);
    final upiLinked = hasExplicitUpiFlag
        ? json['isUpiLinked'] == true
        : rawUpi.isNotEmpty;

    final rawDefault = (json['defaultMethod'] ?? '').toString().toLowerCase().trim();
    final resolvedDefault = rawDefault == 'upi'
        ? (upiLinked ? 'upi' : (bankLinked ? 'bank' : 'upi'))
        : (bankLinked ? 'bank' : (upiLinked ? 'upi' : 'bank'));

    return BankDetailsModel(
      accountHolder: rawHolder,
      accountNumber: rawAcct,
      bankName: rawBankName,
      ifscCode: rawIfsc,
      upiId: rawUpi,
      defaultMethod: resolvedDefault,
      isBankLinked: bankLinked,
      isUpiLinked: upiLinked,
    );
  }
}

class PayoutRulesModel {
  final double minPayoutAmount;
  final int maxPayoutsPerDay;
  final int todayPayoutsCount;
  final int payoutsRemainingToday;
  final double instantCashoutFee;
  final String payoutMode;

  PayoutRulesModel({
    this.minPayoutAmount = 100.0,
    this.maxPayoutsPerDay = 2,
    this.todayPayoutsCount = 0,
    this.payoutsRemainingToday = 2,
    this.instantCashoutFee = 0.0,
    this.payoutMode = 'instant',
  });

  bool get isDailyLimitReached => payoutsRemainingToday <= 0;

  factory PayoutRulesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PayoutRulesModel();
    final maxPerDay = (json['maxPayoutsPerDay'] as num?)?.toInt() ?? 2;
    final remaining = (json['payoutsRemainingToday'] as num?)?.toInt() ?? maxPerDay;
    final todayCount = (json['todayPayoutsCount'] as num?)?.toInt() ??
        (maxPerDay - remaining).clamp(0, maxPerDay);

    return PayoutRulesModel(
      minPayoutAmount: (json['minPayoutAmount'] as num?)?.toDouble() ?? 100.0,
      maxPayoutsPerDay: maxPerDay,
      todayPayoutsCount: todayCount,
      payoutsRemainingToday: remaining,
      instantCashoutFee: (json['instantCashoutFee'] as num?)?.toDouble() ?? 0.0,
      payoutMode: json['payoutMode']?.toString() ?? 'instant',
    );
  }
}

class PayoutItemModel {
  final String id;
  final double amount;
  final String currency;
  final String payoutMethod; // 'bank' | 'upi'
  final String accountDetails;
  final String transactionId;
  final String status; // 'pending' | 'processing' | 'completed' | 'failed' | 'rejected'
  final String utr;
  final String failureReason;
  final double fee;
  final String createdAt;
  final String completedAt;
  final String refundedAt;

  PayoutItemModel({
    this.id = '',
    this.amount = 0.0,
    this.currency = 'INR',
    this.payoutMethod = 'bank',
    this.accountDetails = '',
    this.transactionId = '',
    this.status = 'pending',
    this.utr = '',
    this.failureReason = '',
    this.fee = 0.0,
    this.createdAt = '',
    this.completedAt = '',
    this.refundedAt = '',
  });

  /// Alias for backward compatibility
  String get method => payoutMethod;

  String get normalizedStatus => status.toLowerCase().trim();

  bool get isCompleted =>
      normalizedStatus == 'completed' ||
      normalizedStatus == 'processed' ||
      normalizedStatus == 'success';

  bool get isInProgress =>
      normalizedStatus == 'pending' || normalizedStatus == 'processing';

  bool get isFailed => normalizedStatus == 'failed';

  bool get isRejected => normalizedStatus == 'rejected';

  bool get isFailedOrRejected => isFailed || isRejected;

  bool get isRefunded => refundedAt.isNotEmpty || isFailedOrRejected;

  PayoutItemModel copyWith({
    String? id,
    double? amount,
    String? currency,
    String? payoutMethod,
    String? accountDetails,
    String? transactionId,
    String? status,
    String? utr,
    String? failureReason,
    double? fee,
    String? createdAt,
    String? completedAt,
    String? refundedAt,
  }) {
    return PayoutItemModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      payoutMethod: payoutMethod ?? this.payoutMethod,
      accountDetails: accountDetails ?? this.accountDetails,
      transactionId: transactionId ?? this.transactionId,
      status: status ?? this.status,
      utr: utr ?? this.utr,
      failureReason: failureReason ?? this.failureReason,
      fee: fee ?? this.fee,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      refundedAt: refundedAt ?? this.refundedAt,
    );
  }

  factory PayoutItemModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PayoutItemModel();
    return PayoutItemModel(
      id: (json['id'] ?? json['payoutId'] ?? json['_id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      payoutMethod: (json['payoutMethod'] ?? json['payout_method'] ?? json['method'] ?? 'bank')
          .toString()
          .toLowerCase(),
      accountDetails: (json['accountDetails'] ?? json['account_details'] ?? json['destination'] ?? '').toString(),
      transactionId: (json['transactionId'] ?? json['transaction_id'] ?? json['utr'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      utr: (json['utr'] ?? json['utrNumber'] ?? json['bankReferenceId'] ?? '').toString(),
      failureReason: (json['failureReason'] ?? json['failure_reason'] ?? json['rejectionReason'] ?? json['reason'] ?? '').toString(),
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      completedAt: (json['completedAt'] ?? json['completed_at'] ?? '').toString(),
      refundedAt: (json['refundedAt'] ?? json['refunded_at'] ?? '').toString(),
    );
  }
}

class WalletModel {
  final double balance;
  final double availableBalance;
  final String formattedBalance;
  final String currency;
  final String currencySymbol;
  final String walletStatus;
  final String walletStatusText;
  final String kycStatus; // 'approved' | 'pending' | 'submitted' | 'rejected' | ''
  final bool canAcceptRides;
  final String? statusMessage;
  final double pendingDues;
  final bool hasPendingDues;
  final bool canClearDues;
  final bool razorpayConfigured;
  final String? razorpayKeyId;
  final DailyEarningsModel today;
  final double netEarnings;
  final double cashCollected;
  final double totalEarningsToday;
  final double totalTipsToday;
  final int totalRidesToday;
  final DailyIncentiveModel dailyIncentive;
  final List<WeeklySummaryItem> weeklySummary;
  final BankDetailsModel bankDetails;
  final PayoutRulesModel payoutRules;

  WalletModel({
    this.balance = 0.0,
    this.availableBalance = 0.0,
    this.formattedBalance = '₹ 0.00',
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.walletStatus = 'active',
    this.walletStatusText = 'Active',
    this.kycStatus = '',
    this.canAcceptRides = true,
    this.statusMessage,
    this.pendingDues = 0.0,
    this.hasPendingDues = false,
    this.canClearDues = false,
    this.razorpayConfigured = false,
    this.razorpayKeyId,
    DailyEarningsModel? today,
    this.netEarnings = 0.0,
    this.cashCollected = 0.0,
    this.totalEarningsToday = 0.0,
    this.totalTipsToday = 0.0,
    this.totalRidesToday = 0,
    DailyIncentiveModel? dailyIncentive,
    this.weeklySummary = const [],
    BankDetailsModel? bankDetails,
    PayoutRulesModel? payoutRules,
  }) : today = today ?? DailyEarningsModel(),
       dailyIncentive = dailyIncentive ?? DailyIncentiveModel(),
       bankDetails = bankDetails ?? BankDetailsModel(),
       payoutRules = payoutRules ?? PayoutRulesModel();

  bool get isWalletBlocked =>
      walletStatus.toLowerCase() == 'blocked' ||
      walletStatus.toLowerCase() == 'suspended';

  bool get hasNegativeOrZeroBalance => balance <= 0 || availableBalance <= 0;

  double get effectivePendingDues =>
      pendingDues > 0 ? pendingDues : (balance < 0 ? balance.abs() : 0.0);

  WalletModel copyWith({
    double? balance,
    double? availableBalance,
    String? formattedBalance,
    String? currency,
    String? currencySymbol,
    String? walletStatus,
    String? walletStatusText,
    String? kycStatus,
    bool? canAcceptRides,
    String? statusMessage,
    double? pendingDues,
    bool? hasPendingDues,
    bool? canClearDues,
    bool? razorpayConfigured,
    String? razorpayKeyId,
    DailyEarningsModel? today,
    double? netEarnings,
    double? cashCollected,
    double? totalEarningsToday,
    double? totalTipsToday,
    int? totalRidesToday,
    DailyIncentiveModel? dailyIncentive,
    List<WeeklySummaryItem>? weeklySummary,
    BankDetailsModel? bankDetails,
    PayoutRulesModel? payoutRules,
  }) {
    return WalletModel(
      balance: balance ?? this.balance,
      availableBalance: availableBalance ?? this.availableBalance,
      formattedBalance: formattedBalance ?? this.formattedBalance,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      walletStatus: walletStatus ?? this.walletStatus,
      walletStatusText: walletStatusText ?? this.walletStatusText,
      kycStatus: kycStatus ?? this.kycStatus,
      canAcceptRides: canAcceptRides ?? this.canAcceptRides,
      statusMessage: statusMessage ?? this.statusMessage,
      pendingDues: pendingDues ?? this.pendingDues,
      hasPendingDues: hasPendingDues ?? this.hasPendingDues,
      canClearDues: canClearDues ?? this.canClearDues,
      razorpayConfigured: razorpayConfigured ?? this.razorpayConfigured,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      today: today ?? this.today,
      netEarnings: netEarnings ?? this.netEarnings,
      cashCollected: cashCollected ?? this.cashCollected,
      totalEarningsToday: totalEarningsToday ?? this.totalEarningsToday,
      totalTipsToday: totalTipsToday ?? this.totalTipsToday,
      totalRidesToday: totalRidesToday ?? this.totalRidesToday,
      dailyIncentive: dailyIncentive ?? this.dailyIncentive,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      bankDetails: bankDetails ?? this.bankDetails,
      payoutRules: payoutRules ?? this.payoutRules,
    );
  }

  factory WalletModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WalletModel();
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;

    List<WeeklySummaryItem> weekly = [];
    if (data['weeklySummary'] is List) {
      weekly = (data['weeklySummary'] as List)
          .map((e) => WeeklySummaryItem.fromJson(e as Map<String, dynamic>?))
          .toList();
    }

    final parsedToday = DailyEarningsModel.fromJson(
      data['today'] as Map<String, dynamic>?,
    );
    final tipsVal =
        (data['totalTipsToday'] as num?)?.toDouble() ??
        (data['todayTips'] as num?)?.toDouble() ??
        (data['todayBase']?['tips'] as num?)?.toDouble() ??
        parsedToday.tips;

    final rawKycStatus = (data['kycStatus'] ??
            data['kyc_status'] ??
            data['driverKycStatus'] ??
            data['driver']?['kycStatus'] ??
            '')
        .toString();

    final parsedBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
    final duesMap = data['dues'] is Map ? Map<String, dynamic>.from(data['dues'] as Map) : null;
    final parsedPendingDues = (data['pendingDues'] as num?)?.toDouble() ??
        (data['amountDue'] as num?)?.toDouble() ??
        (duesMap?['amountDue'] as num?)?.toDouble() ??
        (parsedBalance < 0 ? parsedBalance.abs() : 0.0);

    return WalletModel(
      balance: parsedBalance,
      availableBalance: (data['availableBalance'] as num?)?.toDouble() ?? parsedBalance,
      formattedBalance: data['formattedBalance']?.toString() ?? '₹ 0.00',
      currency: data['currency']?.toString() ?? 'INR',
      currencySymbol: data['currencySymbol']?.toString() ?? '₹',
      walletStatus: data['walletStatus']?.toString() ?? 'active',
      walletStatusText: data['walletStatusText']?.toString() ?? 'Active',
      kycStatus: rawKycStatus,
      canAcceptRides: data['canAcceptRides'] ?? true,
      statusMessage: data['statusMessage']?.toString(),
      pendingDues: parsedPendingDues,
      hasPendingDues: data['hasPendingDues'] == true || parsedPendingDues > 0,
      canClearDues: data['canClearDues'] == true || parsedPendingDues > 0,
      razorpayConfigured: duesMap?['razorpayConfigured'] == true || data['razorpayConfigured'] == true,
      razorpayKeyId: (duesMap?['razorpayKeyId'] ?? data['razorpayKeyId'])?.toString(),
      today: parsedToday,
      netEarnings: (data['netEarnings'] as num?)?.toDouble() ?? 0.0,
      cashCollected: (data['cashCollected'] as num?)?.toDouble() ?? 0.0,
      totalEarningsToday:
          (data['totalEarningsToday'] as num?)?.toDouble() ?? 0.0,
      totalTipsToday: tipsVal,
      totalRidesToday: (data['totalRidesToday'] as num?)?.toInt() ?? 0,
      dailyIncentive: DailyIncentiveModel.fromJson(
        data['dailyIncentive'] as Map<String, dynamic>?,
      ),
      weeklySummary: weekly,
      bankDetails: BankDetailsModel.fromJson(
        data['bankDetails'] as Map<String, dynamic>?,
      ),
      payoutRules: PayoutRulesModel.fromJson(
        data['payoutRules'] as Map<String, dynamic>?,
      ),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String type; // 'credit' | 'debit'
  final String reason; // 'tip' | 'ride_fare' | 'payout_withdrawal' | 'payout_refund' | 'payout' | 'commission' | 'bonus'
  final String title;
  final String description;
  final double amount;
  final double? balanceAfter;
  final String referenceId;
  final String referenceType; // 'ride_tip' | 'ride' | 'payout'
  final String createdAt;

  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.reason,
    required this.title,
    this.description = '',
    required this.amount,
    this.balanceAfter,
    this.referenceId = '',
    this.referenceType = '',
    this.createdAt = '',
  });

  bool get isTip =>
      reason.toLowerCase() == 'tip' ||
      referenceType.toLowerCase() == 'ride_tip' ||
      title.toLowerCase().contains('tip');

  bool get isPayoutWithdrawal =>
      reason.toLowerCase() == 'payout_withdrawal' ||
      (reason.toLowerCase() == 'payout' && !isCredit);

  bool get isPayoutRefund =>
      reason.toLowerCase() == 'payout_refund' ||
      (isCredit &&
          (reason.toLowerCase().contains('refund') ||
              title.toLowerCase().contains('refund')));

  bool get isCredit => type.toLowerCase() == 'credit';

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (isPayoutWithdrawal) return 'Payout Withdrawal';
    if (isPayoutRefund) return 'Payout Refund';
    if (isTip) return 'Captain Tip Received';
    return 'Transaction';
  }

  String get displaySubtitle {
    if (description.isNotEmpty) return description;
    if (isPayoutWithdrawal) return 'Payout Withdrawal to linked account';
    if (isPayoutRefund) return 'Payout Refund (Failed)';
    return '';
  }

  factory WalletTransactionModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return WalletTransactionModel(
        id: '',
        type: 'credit',
        reason: '',
        title: '',
        amount: 0.0,
      );
    }
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final rawReason = (json['reason'] ?? json['category'] ?? '').toString().toLowerCase();
    final rawType = (json['type'] ?? 'credit').toString().toLowerCase();
    final rawDesc = (json['subtitle'] ??
            json['description'] ??
            json['narration'] ??
            json['note'] ??
            '')
        .toString();

    String resolvedTitle = (json['title'] ?? '').toString();
    if (resolvedTitle.isEmpty) {
      if (rawReason == 'payout_withdrawal') {
        resolvedTitle = 'Payout Withdrawal';
      } else if (rawReason == 'payout_refund') {
        resolvedTitle = 'Payout Refund';
      } else if (rawReason == 'tip') {
        resolvedTitle = 'Captain Tip Received';
      } else if (rawReason == 'commission') {
        resolvedTitle = 'Platform Commission';
      } else if (rawReason == 'ride_fare') {
        resolvedTitle = 'Ride Earning';
      } else {
        resolvedTitle = 'Transaction';
      }
    }

    final balAfterRaw = json['balanceAfter'] ?? json['balance_after'] ?? json['balance'];

    return WalletTransactionModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: rawType,
      reason: rawReason,
      title: resolvedTitle,
      description: rawDesc,
      amount: rawAmount.abs(),
      balanceAfter: (balAfterRaw as num?)?.toDouble(),
      referenceId:
          (json['referenceId'] ?? json['reference_id'] ?? json['payoutId'] ?? json['rideId'] ?? '').toString(),
      referenceType: (json['referenceType'] ?? json['reference_type'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
    );
  }
}

class PayoutRequestResult {
  final bool isSuccess;
  final String status; // 'processing' | 'pending' | 'completed' | 'failed'
  final String payoutId;
  final double amount;
  final String payoutMethod;
  final String destination;
  final String utr;
  final String message;
  final String? errorCode;
  final int? httpStatusCode;
  final bool isNetworkError;

  const PayoutRequestResult({
    required this.isSuccess,
    this.status = 'processing',
    this.payoutId = '',
    this.amount = 0.0,
    this.payoutMethod = 'bank',
    this.destination = '',
    this.utr = '',
    this.message = '',
    this.errorCode,
    this.httpStatusCode,
    this.isNetworkError = false,
  });
}
