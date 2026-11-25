class KycModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String mobileNumber;
  final String profilePhoto;
  final String aadharNumber;
  final String aadharDocUrl;
  final String panNumber;
  final String panDocUrl;
  final String drivingLicenseNumber;
  final String drivingLicenseDocUrl;
  final String drivingLicenseExpiry;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankIfscCode;
  final String bankName;
  final String upiId;
  final String kycStatus;
  final double? rating;

  KycModel({
    this.id = '',
    this.userId = '',
    this.fullName = '',
    this.email = '',
    this.mobileNumber = '',
    this.profilePhoto = '',
    this.aadharNumber = '',
    this.aadharDocUrl = '',
    this.panNumber = '',
    this.panDocUrl = '',
    this.drivingLicenseNumber = '',
    this.drivingLicenseDocUrl = '',
    this.drivingLicenseExpiry = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankIfscCode = '',
    this.bankName = '',
    this.upiId = '',
    this.kycStatus = '',
    this.rating,
  });

  bool get isKycApproved {
    final s = kycStatus.toLowerCase().trim();
    return s == 'approved' || s == 'verified';
  }

  bool get isKycRejected => kycStatus.toLowerCase().trim() == 'rejected';

  bool get isKycPending {
    final s = kycStatus.toLowerCase().trim();
    return s == 'pending' || s == 'submitted' || s == 'under_review';
  }

  bool get hasDriverProfile =>
      id.isNotEmpty ||
      aadharNumber.isNotEmpty ||
      panNumber.isNotEmpty ||
      drivingLicenseNumber.isNotEmpty ||
      kycStatus.isNotEmpty;

  String get maskedBankSummary {
    if (bankAccountNumber.isNotEmpty) {
      final last4 = bankAccountNumber.length > 4
          ? bankAccountNumber.substring(bankAccountNumber.length - 4)
          : bankAccountNumber;
      final prefix = bankName.isNotEmpty ? bankName : 'Bank';
      return '$prefix (••••$last4)';
    }
    if (upiId.isNotEmpty) return upiId;
    return '';
  }

  KycModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? mobileNumber,
    String? profilePhoto,
    String? aadharNumber,
    String? aadharDocUrl,
    String? panNumber,
    String? panDocUrl,
    String? drivingLicenseNumber,
    String? drivingLicenseDocUrl,
    String? drivingLicenseExpiry,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankIfscCode,
    String? bankName,
    String? upiId,
    String? kycStatus,
    double? rating,
  }) {
    return KycModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      aadharDocUrl: aadharDocUrl ?? this.aadharDocUrl,
      panNumber: panNumber ?? this.panNumber,
      panDocUrl: panDocUrl ?? this.panDocUrl,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      drivingLicenseDocUrl: drivingLicenseDocUrl ?? this.drivingLicenseDocUrl,
      drivingLicenseExpiry: drivingLicenseExpiry ?? this.drivingLicenseExpiry,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfscCode: bankIfscCode ?? this.bankIfscCode,
      bankName: bankName ?? this.bankName,
      upiId: upiId ?? this.upiId,
      kycStatus: kycStatus ?? this.kycStatus,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'mobileNumber': mobileNumber,
      'profilePhoto': profilePhoto,
      'aadharNumber': aadharNumber,
      'aadharDocUrl': aadharDocUrl,
      'panNumber': panNumber,
      'panDocUrl': panDocUrl,
      'drivingLicenseNumber': drivingLicenseNumber,
      'drivingLicenseDocUrl': drivingLicenseDocUrl,
      'drivingLicenseExpiry': drivingLicenseExpiry,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfscCode': bankIfscCode,
      'bankName': bankName,
      'upiId': upiId,
    };
  }

  factory KycModel.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'] ?? json['avgRating'] ?? json['avg_rating'];
    double? parsedRating;
    if (rawRating is num) {
      parsedRating = rawRating.toDouble();
    } else if (rawRating != null) {
      parsedRating = double.tryParse(rawRating.toString());
    }

    return KycModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      mobileNumber:
          (json['phone'] ?? json['mobileNumber'] ?? json['mobile_number'] ?? '')
              .toString(),
      profilePhoto:
          (json['profilePhoto'] ??
                  json['profile_photo'] ??
                  json['profilePhotoUrl'] ??
                  json['profile_photo_url'] ??
                  '')
              .toString(),
      aadharNumber: (json['aadharNumber'] ?? json['aadhar_number'] ?? '')
          .toString(),
      aadharDocUrl: (json['aadharDocUrl'] ?? json['aadhar_doc_url'] ?? '')
          .toString(),
      panNumber: (json['panNumber'] ?? json['pan_number'] ?? '').toString(),
      panDocUrl: (json['panDocUrl'] ?? json['pan_doc_url'] ?? '').toString(),
      drivingLicenseNumber:
          (json['drivingLicenseNumber'] ?? json['driving_license_number'] ?? '')
              .toString(),
      drivingLicenseDocUrl:
          (json['drivingLicenseDocUrl'] ??
                  json['driving_license_doc_url'] ??
                  '')
              .toString(),
      drivingLicenseExpiry:
          (json['drivingLicenseExpiry'] ?? json['driving_license_expiry'] ?? '')
              .toString(),
      bankAccountName:
          (json['bankAccountName'] ?? json['bank_account_name'] ?? '')
              .toString(),
      bankAccountNumber:
          (json['bankAccountNumber'] ?? json['bank_account_number'] ?? '')
              .toString(),
      bankIfscCode: (json['bankIfscCode'] ?? json['bank_ifsc_code'] ?? '')
          .toString(),
      bankName: (json['bankName'] ?? json['bank_name'] ?? '').toString(),
      upiId: (json['upiId'] ?? json['upi_id'] ?? '').toString(),
      kycStatus:
          (json['kycStatus'] ??
                  json['kyc_status'] ??
                  json['verificationStatus'] ??
                  json['verification_status'] ??
                  '')
              .toString(),
      rating: parsedRating,
    );
  }
}
