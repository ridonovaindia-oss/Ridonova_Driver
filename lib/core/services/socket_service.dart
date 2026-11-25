import 'dart:async';
import 'dart:developer' as dev;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentToken;
  final Set<String> _joinedRideIds = {};

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  final StreamController<Map<String, dynamic>> _rideRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _tipReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _walletUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _payoutStatusUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _lostItemReportedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _lostItemUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get rideRequestStream => _rideRequestController.stream;
  Stream<Map<String, dynamic>> get rideStatusStream => _rideStatusController.stream;
  Stream<Map<String, dynamic>> get tipReceivedStream => _tipReceivedController.stream;
  Stream<Map<String, dynamic>> get walletUpdatedStream => _walletUpdatedController.stream;
  Stream<Map<String, dynamic>> get payoutStatusUpdatedStream => _payoutStatusUpdatedController.stream;
  Stream<Map<String, dynamic>> get lostItemReportedStream => _lostItemReportedController.stream;
  Stream<Map<String, dynamic>> get lostItemUpdatedStream => _lostItemUpdatedController.stream;
  Stream<Map<String, dynamic>> get chatMessageUpdates => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get chatTypingUpdates => _chatTypingController.stream;
  Stream<Map<String, dynamic>> get chatReadUpdates => _chatReadController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Initializes persistent Socket.IO connection on driver login or duty ON
  void initSocket(String token) {
    final activeToken = token;
    if (activeToken.isEmpty) return; // not logged in → no socket

    // If socket is already connected with the same valid token, do not reconnect
    if (_socket != null && _socket!.connected && _currentToken == activeToken) {
      return;
    }

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _currentToken = activeToken;

    dev.log('Initializing Socket.IO connection to ${ApiConstants.socketUrl} with auth token...', name: 'SocketService');

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setAuth({'token': activeToken})
          .setExtraHeaders({'Authorization': 'Bearer $activeToken'})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionController.add(true);
      dev.log('Driver Socket Connected successfully! Socket ID: ${_socket?.id}', name: 'SocketService');

      // Automatically join / re-join any active ride rooms after connect or reconnect
      for (final rideId in _joinedRideIds) {
        _socket!.emit('join_ride', {'rideId': rideId});
        dev.log('Auto-joined ride socket room on connect: $rideId', name: 'SocketService');
      }
    });

    _socket!.onReconnect((_) {
      _isConnected = true;
      _connectionController.add(true);
      for (final rideId in _joinedRideIds) {
        _socket!.emit('join_ride', {'rideId': rideId});
        dev.log('Auto-rejoined ride socket room on reconnect: $rideId', name: 'SocketService');
      }
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      _connectionController.add(false);
      dev.log('Driver Socket Disconnected: $reason', name: 'SocketService');
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      _connectionController.add(false);
      dev.log('Driver Socket Connect Error: $data', name: 'SocketService');
    });

    // Handle incoming ride booking broadcasts
    void handleNewRide(dynamic data) {
      dev.log('Received new ride request broadcast: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _rideRequestController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('new_ride_request', handleNewRide);
    _socket!.on('ride:new_request', handleNewRide);
    _socket!.on('ride.new_request', handleNewRide);

    // Handle ride status changed events (e.g., rider cancelled)
    void handleStatusChanged(dynamic data) {
      dev.log('Received ride status changed event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _rideStatusController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('ride:status_changed', handleStatusChanged);
    _socket!.on('ride.status_changed', handleStatusChanged);

    // Handle tip received event from passenger (tip_received)
    void handleTipReceived(dynamic data) {
      dev.log('Received tip_received event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _tipReceivedController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('tip_received', handleTipReceived);
    _socket!.on('driver:tip_received', handleTipReceived);

    // Handle driver wallet updated event (driver_wallet_updated)
    void handleWalletUpdated(dynamic data) {
      dev.log('Received driver_wallet_updated event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _walletUpdatedController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('driver_wallet_updated', handleWalletUpdated);
    _socket!.on('wallet:updated', handleWalletUpdated);

    // Handle payout status updated event (payout_status_updated)
    void handlePayoutStatusUpdated(dynamic data) {
      dev.log('Received payout_status_updated event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _payoutStatusUpdatedController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('payout_status_updated', handlePayoutStatusUpdated);
    _socket!.on('payout:status_updated', handlePayoutStatusUpdated);

    // Handle lost item reported by passenger (lost_item:reported)
    void handleLostItemReported(dynamic data) {
      dev.log('Received lost_item:reported event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _lostItemReportedController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('lost_item:reported', handleLostItemReported);

    // Handle lost item status updated (lost_item:updated)
    void handleLostItemUpdated(dynamic data) {
      dev.log('Received lost_item:updated event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _lostItemUpdatedController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('lost_item:updated', handleLostItemUpdated);

    // Handle in-ride chat message events (chat:message & common aliases)
    void handleChatMessage(dynamic data) {
      dev.log('Received chat message event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _chatMessageController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('chat:message', handleChatMessage);
    _socket!.on('chat_message', handleChatMessage);
    _socket!.on('new_message', handleChatMessage);
    _socket!.on('ride:chat_message', handleChatMessage);
    _socket!.on('message:new', handleChatMessage);

    // Handle typing indicator event (chat:typing & alias)
    void handleChatTyping(dynamic data) {
      dev.log('Received chat:typing event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _chatTypingController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('chat:typing', handleChatTyping);
    _socket!.on('chat_typing', handleChatTyping);

    // Handle chat read event (chat:read & alias)
    void handleChatRead(dynamic data) {
      dev.log('Received chat:read event: $data', name: 'SocketService');
      if (data != null && data is Map) {
        _chatReadController.add(Map<String, dynamic>.from(data));
      }
    }

    _socket!.on('chat:read', handleChatRead);
    _socket!.on('chat_read', handleChatRead);

    _socket!.connect();
  }

  /// Emits live GPS coordinates to Socket Server every 2–3 seconds
  void emitLocationUpdate({
    required double lat,
    required double lng,
    double heading = 0.0,
    double speed = 0.0,
    double accuracy = 0.0,
    String? vehicleType,
    String? plateNumber,
    String status = 'online',
    String? rideId,
  }) {
    final payload = {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'vehicleType': vehicleType ?? 'bike',
      'plateNumber': plateNumber ?? '',
      'status': status,
      'rideId': rideId,
    };

    if (_socket != null && _socket!.connected) {
      _socket!.emit('updateLocation', payload);
      _socket!.emit('driver:location_update', payload);
      dev.log('Emitted live GPS to socket: lat=$lat, lng=$lng, heading=$heading, rideId=$rideId', name: 'SocketService');
    } else {
      if (_socket != null && !_socket!.connected) {
        _socket!.connect();
      }
      dev.log('Socket not connected yet (connecting...). Skipping socket location emit.', name: 'SocketService');
    }
  }

  /// Joins ride tracking & chat socket room (persisted across reconnects)
  void joinRide(String rideId) {
    if (rideId.isEmpty) return;
    _joinedRideIds.add(rideId);
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_ride', {'rideId': rideId});
      dev.log('Joined ride socket room: $rideId', name: 'SocketService');
    } else if (_socket != null && !_socket!.connected) {
      _socket!.connect();
      dev.log('Queued ride socket room join until connected: $rideId', name: 'SocketService');
    }
  }

  /// Leaves ride tracking & chat socket room when ride finishes or is cancelled
  void leaveRide(String rideId) {
    if (rideId.isEmpty) return;
    _joinedRideIds.remove(rideId);
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_ride', {'rideId': rideId});
      dev.log('Left ride socket room: $rideId', name: 'SocketService');
    }
  }

  /// Sends typing indicator status over Socket.IO (chat:typing)
  void sendChatTyping(String rideId, bool isTyping) {
    if (rideId.isEmpty) return;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('chat:typing', {'rideId': rideId, 'isTyping': isTyping});
      dev.log('Emitted chat:typing (rideId=$rideId, isTyping=$isTyping)', name: 'SocketService');
    }
  }

  /// Sends read receipt event over Socket.IO (chat:read)
  void markChatRead(String rideId) {
    if (rideId.isEmpty) return;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('chat:read', {'rideId': rideId});
      dev.log('Emitted chat:read (rideId=$rideId)', name: 'SocketService');
    }
  }

  /// Closes socket connection on driver logout
  void disconnect() {
    _joinedRideIds.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentToken = null;
    _connectionController.add(false);
    dev.log('Disconnected and disposed SocketService', name: 'SocketService');
  }
}
