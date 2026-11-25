import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'wallet_model.dart';

enum WalletStatus { initial, loading, success, error }

class WalletState {
  final WalletModel wallet;
  final WalletStatus status;
  final String? errorMessage;
  final String? errorCode;
  final List<PayoutItemModel> payouts;
  final List<WalletTransactionModel> transactions;
  final bool isPayoutLoading;
  final bool isTransactionsLoading;
  final bool isBankUpdating;
  final bool isDuesPaying;
  final String? payoutSuccessMessage;
  final PayoutRequestResult? lastPayoutResult;

  WalletState({
    required this.wallet,
    this.status = WalletStatus.initial,
    this.errorMessage,
    this.errorCode,
    this.payouts = const [],
    this.transactions = const [],
    this.isPayoutLoading = false,
    this.isTransactionsLoading = false,
    this.isBankUpdating = false,
    this.isDuesPaying = false,
    this.payoutSuccessMessage,
    this.lastPayoutResult,
  });

  WalletState copyWith({
    WalletModel? wallet,
    WalletStatus? status,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    List<PayoutItemModel>? payouts,
    List<WalletTransactionModel>? transactions,
    bool? isPayoutLoading,
    bool? isTransactionsLoading,
    bool? isBankUpdating,
    bool? isDuesPaying,
    String? payoutSuccessMessage,
    bool clearPayoutMessage = false,
    PayoutRequestResult? lastPayoutResult,
    bool clearLastPayoutResult = false,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      payouts: payouts ?? this.payouts,
      transactions: transactions ?? this.transactions,
      isPayoutLoading: isPayoutLoading ?? this.isPayoutLoading,
      isTransactionsLoading: isTransactionsLoading ?? this.isTransactionsLoading,
      isBankUpdating: isBankUpdating ?? this.isBankUpdating,
      isDuesPaying: isDuesPaying ?? this.isDuesPaying,
      payoutSuccessMessage: clearPayoutMessage ? null : (payoutSuccessMessage ?? this.payoutSuccessMessage),
      lastPayoutResult: clearLastPayoutResult ? null : (lastPayoutResult ?? this.lastPayoutResult),
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiService _apiService;
  String? _pendingIdempotencyKey;

  WalletNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(WalletState(wallet: WalletModel())) {
    fetchWalletEarnings();
    fetchPayouts();
    fetchTransactions();
  }

  /// 1. Fetch Wallet & Earnings (GET /driver/wallet)
  Future<void> fetchWalletEarnings({String? token}) async {
    state = state.copyWith(status: WalletStatus.loading, clearError: true);

    final response = await _apiService.get(ApiConstants.driverWallet, token: token);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final walletModel = WalletModel.fromJson(raw);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('wallet_balance', walletModel.balance);
        } catch (_) {}

        state = state.copyWith(wallet: walletModel, status: WalletStatus.success);
      } catch (e) {
        state = state.copyWith(
          status: WalletStatus.error,
          errorMessage: 'Failed to parse wallet response: $e',
        );
      }
    } else {
      state = state.copyWith(
        status: WalletStatus.error,
        errorMessage: response.errorMessage ?? 'Failed to fetch wallet & earnings.',
      );
    }
  }

  /// 2. Instant Cashout / Withdrawal Request (POST /driver/payout-request)
  /// Adheres strictly to production-ready idempotency, error-code parsing, and async status.
  Future<PayoutRequestResult> requestPayout({
    double? amount,
    String? payoutMethod,
    String? token,
  }) async {
    final requestedAmount = amount ?? state.wallet.availableBalance;
    final minAmount = state.wallet.payoutRules.minPayoutAmount;
    final resolvedMethod = (payoutMethod ?? state.wallet.bankDetails.defaultMethod).toLowerCase();

    // Guard: Client-side minimum payout check
    if (requestedAmount < minAmount) {
      const errCode = 'BELOW_MIN_PAYOUT';
      final errMsg = 'Minimum withdrawal amount is ₹${minAmount.toStringAsFixed(2)} as per platform policy.';
      state = state.copyWith(errorMessage: errMsg, errorCode: errCode);
      return PayoutRequestResult(
        isSuccess: false,
        amount: requestedAmount,
        payoutMethod: resolvedMethod,
        message: errMsg,
        errorCode: errCode,
      );
    }

    // Guard: Client-side available balance check
    if (requestedAmount > state.wallet.availableBalance) {
      const errCode = 'INSUFFICIENT_OR_BLOCKED_BALANCE';
      final errMsg = 'Requested amount exceeds available balance (₹${state.wallet.availableBalance.toStringAsFixed(2)}).';
      state = state.copyWith(errorMessage: errMsg, errorCode: errCode);
      return PayoutRequestResult(
        isSuccess: false,
        amount: requestedAmount,
        payoutMethod: resolvedMethod,
        message: errMsg,
        errorCode: errCode,
      );
    }

    // Guard: Daily limit check
    if (state.wallet.payoutRules.isDailyLimitReached) {
      const errCode = 'DAILY_LIMIT_REACHED';
      const errMsg = 'Max 2 payouts per day allowed. Daily limit reached, available tomorrow.';
      state = state.copyWith(errorMessage: errMsg, errorCode: errCode);
      return PayoutRequestResult(
        isSuccess: false,
        amount: requestedAmount,
        payoutMethod: resolvedMethod,
        message: errMsg,
        errorCode: errCode,
      );
    }

    // Reuse existing key on network retries, or generate fresh UUID v4 for new attempt
    final idempotencyKey = _pendingIdempotencyKey ?? const Uuid().v4();
    _pendingIdempotencyKey = idempotencyKey;

    state = state.copyWith(
      isPayoutLoading: true,
      clearError: true,
      clearPayoutMessage: true,
      clearLastPayoutResult: true,
    );

    final destinationLabel = resolvedMethod == 'upi'
        ? state.wallet.bankDetails.upiDestinationLabel
        : state.wallet.bankDetails.bankDestinationLabel;

    final response = await _apiService.post(
      ApiConstants.payoutRequest,
      data: {
        'amount': requestedAmount,
        'payoutMethod': resolvedMethod,
      },
      headers: {
        'Idempotency-Key': idempotencyKey,
      },
      token: token,
    );

    if (response.isSuccess) {
      // Clear key after successful execution
      _pendingIdempotencyKey = null;

      final dynamic raw = response.data is String ? jsonDecode(response.data) : response.data;
      final Map<String, dynamic> dataPayload =
          (raw is Map) ? (raw['data'] is Map ? raw['data'] : raw) : {};

      final payoutStatus = (dataPayload['status'] ?? 'processing').toString().toLowerCase();
      final payoutId = (dataPayload['payoutId'] ?? dataPayload['id'] ?? '').toString();
      final utr = (dataPayload['utr'] ?? dataPayload['utrNumber'] ?? '').toString();
      final successMsg = raw is Map && raw['message'] != null
          ? raw['message'].toString()
          : (payoutStatus == 'processing'
              ? 'Withdrawal initiated successfully via IMPS/UPI.'
              : 'Withdrawal request submitted for review.');

      final result = PayoutRequestResult(
        isSuccess: true,
        status: payoutStatus,
        payoutId: payoutId,
        amount: requestedAmount,
        payoutMethod: resolvedMethod,
        destination: destinationLabel,
        utr: utr,
        message: successMsg,
        httpStatusCode: response.statusCode,
      );

      state = state.copyWith(
        isPayoutLoading: false,
        payoutSuccessMessage: successMsg,
        lastPayoutResult: result,
      );

      // Refresh wallet balance and payouts history in background
      await Future.wait([
        fetchWalletEarnings(token: token),
        fetchPayouts(token: token),
        fetchTransactions(token: token),
      ]);

      return result;
    } else {
      final dynamic raw = response.data is String ? jsonDecode(response.data) : response.data;
      final Map<String, dynamic> errorPayload = (raw is Map) ? Map<String, dynamic>.from(raw) : {};

      final String? parsedCode = (errorPayload['code'] ??
              errorPayload['errorCode'] ??
              errorPayload['error'])
          ?.toString();

      final String errMsg = errorPayload['message']?.toString() ??
          response.errorMessage ??
          'Failed to process payout request.';

      final bool isNetworkOrTimeout = response.statusCode == null ||
          response.statusCode == 504 ||
          response.statusCode == 408;

      if (!isNetworkOrTimeout) {
        // Business logic rejection: safe to clear key
        _pendingIdempotencyKey = null;
      }

      final result = PayoutRequestResult(
        isSuccess: false,
        status: 'failed',
        amount: requestedAmount,
        payoutMethod: resolvedMethod,
        destination: destinationLabel,
        message: errMsg,
        errorCode: parsedCode,
        httpStatusCode: response.statusCode,
        isNetworkError: isNetworkOrTimeout,
      );

      state = state.copyWith(
        isPayoutLoading: false,
        errorMessage: errMsg,
        errorCode: parsedCode,
        lastPayoutResult: result,
      );

      return result;
    }
  }

  /// 3. Update Bank & UPI Details (PUT /driver/bank-details)
  /// Dedicated endpoint prevents overwriting verified driver KYC documents.
  Future<ApiResponse> updateBankDetails({
    required String accountHolder,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? upiId,
    String? defaultMethod,
    String? token,
  }) async {
    state = state.copyWith(isBankUpdating: true, clearError: true);

    final payload = {
      'accountHolder': accountHolder.trim(),
      'accountNumber': accountNumber.trim(),
      'ifscCode': ifscCode.trim().toUpperCase(),
      'bankName': bankName.trim(),
      if (upiId != null && upiId.trim().isNotEmpty) 'upiId': upiId.trim(),
      if (defaultMethod != null && defaultMethod.isNotEmpty)
        'defaultMethod': defaultMethod.toLowerCase(),
    };

    final response = await _apiService.put(
      ApiConstants.driverBankDetails,
      data: payload,
      token: token,
    );

    state = state.copyWith(isBankUpdating: false);

    if (response.isSuccess) {
      // Re-fetch wallet so fresh masked account & linked flags are reflected
      await fetchWalletEarnings(token: token);
    } else {
      state = state.copyWith(
        errorMessage: response.errorMessage ?? 'Failed to update bank details.',
      );
    }

    return response;
  }

  /// 4. Fetch Driver Payout History (GET /driver/payouts)
  Future<void> fetchPayouts({
    int page = 1,
    int limit = 20,
    String status = 'all',
    String? token,
  }) async {
    final response = await _apiService.get(
      ApiConstants.driverPayouts,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status.isNotEmpty && status != 'all') 'status': status,
      },
      token: token,
    );

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final dataPayload = (raw is Map) ? (raw['data'] ?? raw) : raw;
        List<PayoutItemModel> payoutList = [];

        if (dataPayload is Map && dataPayload['payouts'] is List) {
          payoutList = (dataPayload['payouts'] as List)
              .map((e) => PayoutItemModel.fromJson(e as Map<String, dynamic>?))
              .toList();
        } else if (dataPayload is List) {
          payoutList = dataPayload
              .map((e) => PayoutItemModel.fromJson(e as Map<String, dynamic>?))
              .toList();
        }

        state = state.copyWith(payouts: payoutList);
      } catch (_) {}
    }
  }

  /// 5. Confirm Cash Collection & Commission Auto-Deduct (POST /driver/rides/{id}/collect-cash)
  Future<bool> collectCash({
    required String rideId,
    required double amount,
    String? token,
  }) async {
    final response = await _apiService.post(
      ApiConstants.collectCash(rideId),
      data: {'amount': amount},
      token: token,
    );

    if (response.isSuccess) {
      await fetchWalletEarnings(token: token);
      await fetchTransactions(token: token);
      return true;
    } else {
      state = state.copyWith(
        errorMessage: response.errorMessage ?? 'Failed to collect cash.',
      );
      return false;
    }
  }

  /// 6. Fetch Driver Wallet Transactions / Ledger (GET /driver/wallet/transactions)
  Future<void> fetchTransactions({String? token}) async {
    state = state.copyWith(isTransactionsLoading: true);

    try {
      final response = await _apiService.get(
        ApiConstants.driverWalletTransactions,
        queryParameters: {'page': 1, 'limit': 30},
        token: token,
      );

      if (response.isSuccess && response.data != null) {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final dataPayload = (raw is Map) ? (raw['data'] ?? raw['transactions'] ?? raw) : raw;
        List<WalletTransactionModel> txns = [];

        if (dataPayload is Map && dataPayload['transactions'] is List) {
          txns = (dataPayload['transactions'] as List)
              .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>?))
              .toList();
        } else if (dataPayload is List) {
          txns = dataPayload
              .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>?))
              .toList();
        }

        state = state.copyWith(transactions: txns, isTransactionsLoading: false);
        return;
      }
    } catch (_) {}

    state = state.copyWith(isTransactionsLoading: false);
  }

  /// 7. Realtime Socket Handler for Payout Status (payout_status_updated)
  void applyLivePayoutUpdate(Map<String, dynamic> data) {
    final payoutId = (data['payoutId'] ?? data['id'] ?? '').toString();
    final updatedStatus = (data['status'] ?? '').toString().toLowerCase();
    final utr = (data['utr'] ?? data['utrNumber'] ?? '').toString();
    final failureReason = (data['failureReason'] ?? data['reason'] ?? '').toString();
    final newBalance = (data['newWalletBalance'] ?? data['balance'] as num?)?.toDouble();

    // 1. Update payout in local payouts list
    if (payoutId.isNotEmpty) {
      final updatedList = state.payouts.map((p) {
        if (p.id == payoutId || (p.transactionId.isNotEmpty && p.transactionId == payoutId)) {
          return p.copyWith(
            status: updatedStatus.isNotEmpty ? updatedStatus : p.status,
            utr: utr.isNotEmpty ? utr : p.utr,
            failureReason: failureReason.isNotEmpty ? failureReason : p.failureReason,
            completedAt: updatedStatus == 'completed' ? DateTime.now().toIso8601String() : p.completedAt,
            refundedAt: (updatedStatus == 'failed' || updatedStatus == 'rejected')
                ? DateTime.now().toIso8601String()
                : p.refundedAt,
          );
        }
        return p;
      }).toList();

      state = state.copyWith(payouts: updatedList);
    }

    // 2. Update wallet balance if returned in socket payload
    if (newBalance != null) {
      final updatedWallet = state.wallet.copyWith(
        balance: newBalance,
        availableBalance: newBalance,
        formattedBalance: '₹ ${newBalance.toStringAsFixed(2)}',
      );
      state = state.copyWith(wallet: updatedWallet);
    }

    // 3. Sync full earnings & transactions ledger in background
    fetchWalletEarnings();
    fetchTransactions();
    fetchPayouts();
  }

  /// 6b. Fetch Pending Commission Dues (GET /driver/wallet/dues)
  Future<void> fetchDues({String? token}) async {
    final response = await _apiService.get(ApiConstants.driverWalletDues, token: token);
    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final data = raw is Map ? (raw['data'] ?? raw) : null;
        if (data is Map) {
          final bal = (data['balance'] as num?)?.toDouble() ?? state.wallet.balance;
          final due = (data['amountDue'] as num?)?.toDouble() ??
              (data['pendingDues'] as num?)?.toDouble() ??
              (bal < 0 ? bal.abs() : 0.0);
          state = state.copyWith(
            wallet: state.wallet.copyWith(
              balance: bal,
              availableBalance: (data['availableBalance'] as num?)?.toDouble() ?? (bal > 0 ? bal : 0.0),
              formattedBalance: data['formattedBalance']?.toString() ?? '₹ ${bal.toStringAsFixed(2)}',
              pendingDues: due,
              hasPendingDues: due > 0,
              canClearDues: due > 0,
              razorpayConfigured: data['razorpayConfigured'] == true,
              razorpayKeyId: data['razorpayKeyId']?.toString() ?? state.wallet.razorpayKeyId,
              walletStatus: data['walletStatus']?.toString() ?? state.wallet.walletStatus,
              walletStatusText: data['walletStatusText']?.toString() ?? state.wallet.walletStatusText,
              canAcceptRides: data['canAcceptRides'] ?? state.wallet.canAcceptRides,
              statusMessage: data['statusMessage']?.toString() ?? state.wallet.statusMessage,
            ),
          );
        }
      } catch (_) {}
    }
  }

  /// 6c. Create Razorpay Order for Clearing Negative Wallet Dues (POST /driver/wallet/dues/create-order)
  Future<Map<String, dynamic>?> createDuesOrder({required double amount, String? token}) async {
    state = state.copyWith(isDuesPaying: true, clearError: true);
    final response = await _apiService.post(
      ApiConstants.driverWalletDuesCreateOrder,
      data: {'amount': amount, 'purpose': 'clear_dues'},
      token: token,
    );
    state = state.copyWith(isDuesPaying: false);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final data = raw is Map ? (raw['data'] ?? raw) : null;
        if (data is Map) return Map<String, dynamic>.from(data);
      } catch (_) {}
    }

    state = state.copyWith(
      errorMessage: response.errorMessage ?? 'Failed to initiate dues payment.',
    );
    return null;
  }

  /// 6d. Verify Razorpay Payment for Dues Settlement (POST /driver/wallet/dues/verify)
  Future<bool> verifyDuesPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? token,
  }) async {
    state = state.copyWith(isDuesPaying: true, clearError: true);
    final response = await _apiService.post(
      ApiConstants.driverWalletDuesVerify,
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      },
      token: token,
    );
    state = state.copyWith(isDuesPaying: false);

    if (response.isSuccess) {
      await fetchWalletEarnings(token: token);
      await fetchTransactions(token: token);
      return true;
    }

    state = state.copyWith(
      errorMessage: response.errorMessage ?? 'Could not verify dues payment.',
    );
    return false;
  }

  /// 8. Realtime Live Socket Wallet Update Handler (driver_wallet_updated socket event)
  void applyLiveWalletUpdate({
    required double balance,
    double? amountAdded,
    String? reason,
    String? rideId,
  }) {
    final currentWallet = state.wallet;
    final updatedBalance = balance;
    final formatted = '₹ ${updatedBalance.toStringAsFixed(2)}';
    final normReason = (reason ?? '').toLowerCase();

    double updatedTips = currentWallet.totalTipsToday;
    if (normReason == 'tip' && amountAdded != null && amountAdded > 0) {
      updatedTips += amountAdded;
    }

    // Only credit ride_fare / tip / bonus to netEarnings — NEVER add dues_settlement / wallet_recharge / commission debits!
    final isRideEarningCredit =
        normReason == 'ride_fare' || normReason == 'tip' || normReason == 'bonus' || normReason == 'incentive';
    final nextNetEarnings = isRideEarningCredit && amountAdded != null && amountAdded > 0
        ? currentWallet.netEarnings + amountAdded
        : currentWallet.netEarnings;

    final updatedWallet = currentWallet.copyWith(
      balance: updatedBalance,
      availableBalance: updatedBalance,
      formattedBalance: formatted,
      pendingDues: updatedBalance < 0 ? updatedBalance.abs() : 0.0,
      hasPendingDues: updatedBalance < 0,
      canClearDues: updatedBalance < 0,
      totalTipsToday: updatedTips,
      netEarnings: nextNetEarnings,
    );

    state = state.copyWith(wallet: updatedWallet);

    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('wallet_balance', updatedBalance);
    }).catchError((_) {});

    fetchWalletEarnings();
    fetchTransactions();
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});
