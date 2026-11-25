class AuthResponseModel {
  final bool success;
  final String message;
  final AuthData? data;
  final int? attemptsLeft;
  final bool? blocked;
  final int? retryAfter;
  final bool? cooldown;
  final bool? isNewUser;

  AuthResponseModel({
    required this.success,
    required this.message,
    this.data,
    this.attemptsLeft,
    this.blocked,
    this.retryAfter,
    this.cooldown,
    this.isNewUser,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;

    bool? isNewUser;
    if (json['isNewUser'] != null) {
      isNewUser =
          json['isNewUser'] == true ||
          json['isNewUser'].toString().toLowerCase() == 'true';
    } else if (dataMap?['isNewUser'] != null) {
      isNewUser =
          dataMap!['isNewUser'] == true ||
          dataMap['isNewUser'].toString().toLowerCase() == 'true';
    } else if (dataMap?['user'] != null &&
        dataMap!['user'] is Map &&
        dataMap['user']['isNewUser'] != null) {
      isNewUser =
          dataMap['user']['isNewUser'] == true ||
          dataMap['user']['isNewUser'].toString().toLowerCase() == 'true';
    }

    int? attemptsLeft;
    if (json['attemptsLeft'] != null) {
      attemptsLeft = json['attemptsLeft'] is int
          ? json['attemptsLeft']
          : int.tryParse(json['attemptsLeft'].toString());
    } else if (dataMap?['attemptsLeft'] != null) {
      attemptsLeft = dataMap!['attemptsLeft'] is int
          ? dataMap['attemptsLeft']
          : int.tryParse(dataMap['attemptsLeft'].toString());
    }

    bool? blocked;
    if (json['blocked'] != null) {
      blocked =
          json['blocked'] == true ||
          json['blocked'].toString().toLowerCase() == 'true';
    } else if (dataMap?['blocked'] != null) {
      blocked =
          dataMap!['blocked'] == true ||
          dataMap['blocked'].toString().toLowerCase() == 'true';
    }

    int? retryAfter;
    if (json['retryAfter'] != null) {
      retryAfter = json['retryAfter'] is int
          ? json['retryAfter']
          : int.tryParse(json['retryAfter'].toString());
    } else if (dataMap?['retryAfter'] != null) {
      retryAfter = dataMap!['retryAfter'] is int
          ? dataMap['retryAfter']
          : int.tryParse(dataMap['retryAfter'].toString());
    }

    bool? cooldown;
    if (json['cooldown'] != null) {
      cooldown =
          json['cooldown'] == true ||
          json['cooldown'].toString().toLowerCase() == 'true';
    } else if (dataMap?['cooldown'] != null) {
      cooldown =
          dataMap!['cooldown'] == true ||
          dataMap['cooldown'].toString().toLowerCase() == 'true';
    }

    AuthData? parsedData;
    if (dataMap != null) {
      parsedData = AuthData.fromJson(dataMap);
    } else if (json['token'] != null || json['user'] != null) {
      parsedData = AuthData.fromJson(json);
    }

    return AuthResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: parsedData,
      attemptsLeft: attemptsLeft,
      blocked: blocked,
      retryAfter: retryAfter,
      cooldown: cooldown,
      isNewUser: isNewUser ?? parsedData?.isNewUser,
    );
  }
}

class AuthData {
  final String? token;
  final UserModel? user;
  final SessionModel? session;
  final int? retryAfter;
  final int? attemptsLeft;
  final bool? blocked;
  final bool? cooldown;
  final bool? isNewUser;

  AuthData({
    this.token,
    this.user,
    this.session,
    this.retryAfter,
    this.attemptsLeft,
    this.blocked,
    this.cooldown,
    this.isNewUser,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    bool? isNewUser;
    if (json['isNewUser'] != null) {
      isNewUser =
          json['isNewUser'] == true ||
          json['isNewUser'].toString().toLowerCase() == 'true';
    } else if (json['user'] != null &&
        json['user'] is Map &&
        json['user']['isNewUser'] != null) {
      isNewUser =
          json['user']['isNewUser'] == true ||
          json['user']['isNewUser'].toString().toLowerCase() == 'true';
    }

    int? retryAfter;
    if (json['retryAfter'] != null) {
      retryAfter = json['retryAfter'] is int
          ? json['retryAfter']
          : int.tryParse(json['retryAfter'].toString());
    }

    int? attemptsLeft;
    if (json['attemptsLeft'] != null) {
      attemptsLeft = json['attemptsLeft'] is int
          ? json['attemptsLeft']
          : int.tryParse(json['attemptsLeft'].toString());
    }

    bool? blocked;
    if (json['blocked'] != null) {
      blocked =
          json['blocked'] == true ||
          json['blocked'].toString().toLowerCase() == 'true';
    }

    bool? cooldown;
    if (json['cooldown'] != null) {
      cooldown =
          json['cooldown'] == true ||
          json['cooldown'].toString().toLowerCase() == 'true';
    }

    UserModel? user;
    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      user = UserModel.fromJson(json['user']);
      if (isNewUser != null) {
        user = user.copyWith(isNewUser: isNewUser);
      }
    }

    return AuthData(
      token: json['token'],
      user: user,
      session: json['session'] != null
          ? SessionModel.fromJson(json['session'])
          : null,
      retryAfter: retryAfter,
      attemptsLeft: attemptsLeft,
      blocked: blocked,
      cooldown: cooldown,
      isNewUser: isNewUser,
    );
  }
}

class UserModel {
  final String id;
  final String phone;
  final String countryCode;
  final String? fullName;
  final String? email;
  final bool isEmailVerified;
  final String role;
  final String? gender;
  final String? dateOfBirth;
  final String? profilePhoto;
  final String? createdAt;
  final bool isNewUser;

  UserModel({
    required this.id,
    required this.phone,
    this.countryCode = '+91',
    this.fullName,
    this.email,
    this.isEmailVerified = false,
    required this.role,
    this.gender,
    this.dateOfBirth,
    this.profilePhoto,
    this.createdAt,
    required this.isNewUser,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      countryCode: (json['countryCode'] ?? json['country_code'] ?? '+91')
          .toString(),
      fullName: (json['fullName'] ?? json['full_name'])?.toString(),
      email: json['email']?.toString(),
      isEmailVerified: json['isEmailVerified'] == true || json['is_email_verified'] == true,
      role: (json['role'] ?? 'driver').toString(),
      gender: json['gender']?.toString(),
      dateOfBirth: (json['dateOfBirth'] ?? json['date_of_birth'])?.toString(),
      profilePhoto:
          (json['profilePhotoUrl'] ??
                  json['profile_photo_url'] ??
                  json['profilePhoto'] ??
                  json['profile_photo'])
              ?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
      isNewUser: json['isNewUser'] == true || json['is_new_user'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'countryCode': countryCode,
      'fullName': fullName,
      'email': email,
      'isEmailVerified': isEmailVerified,
      'role': role,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'profilePhotoUrl': profilePhoto,
      'createdAt': createdAt,
      'isNewUser': isNewUser,
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? countryCode,
    String? fullName,
    String? email,
    bool? isEmailVerified,
    String? role,
    String? gender,
    String? dateOfBirth,
    String? profilePhoto,
    String? createdAt,
    bool? isNewUser,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt ?? this.createdAt,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

class SessionModel {
  final String id;
  final String expiresAt;
  final String deviceName;

  SessionModel({
    required this.id,
    required this.expiresAt,
    required this.deviceName,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      expiresAt: json['expiresAt'] ?? '',
      deviceName: json['deviceName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'expiresAt': expiresAt, 'deviceName': deviceName};
  }
}
