import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/notifications_config.dart';
import '../domain/device_notifications.dart';
import '../domain/models.dart';

/// Notification payloads are displayed by Android/FCM while the process is
/// closed. This service displays them in the foreground and registers devices
/// through authenticated RPCs; it never stores a server credential.
class FirebaseDeviceNotifications implements DeviceNotifications {
  FirebaseDeviceNotifications(this.client);
  final SupabaseClient client;
  final _messages = StreamController<void>.broadcast();
  final _opened = StreamController<String>.broadcast();
  final _local = FlutterLocalNotificationsPlugin();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<bool>? _initializing;
  Future<void>? _binding;
  bool _disposed = false, _ready = false, _suspended = false;
  String? _registered, _token, _requestedUser;
  RemoteMessage? _initialMessage;
  String _status = 'Chưa bật thông báo điện thoại';
  static const channel = AndroidNotificationChannel(
    'smartpark_parking',
    'Nhắc giờ lấy xe',
    description: 'Vé đặt chỗ, giờ lấy xe và trạng thái gửi xe',
    importance: Importance.high,
  );
  @override
  Stream<void> get messages => _messages.stream;
  @override
  Stream<String> get openedBookings => _opened.stream;
  @override
  String get status => _status;

  Future<bool> _initialize() => _initializing ??= _initializeOnce();
  Future<bool> _initializeOnce() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _status =
          'Thông báo trong app đang hoạt động. Thông báo điện thoại hỗ trợ trên Android.';
      return false;
    }
    try {
      final app = await Firebase.initializeApp();
      if (app.options.projectId != NotificationsConfig.firebaseProjectId) {
        _status =
            'Cấu hình thông báo chưa khớp. Thông báo trong app vẫn hoạt động.';
        return false;
      }
      if (_disposed) return false;
      _subscriptions.add(
        client.auth.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.signedIn) {
            _suspended = false;
            unawaited(bindUser(state.session?.user.id));
          }
        }),
      );
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final parts = response.payload?.split('|');
          if (parts?.length == 2 &&
              parts![0] == client.auth.currentUser?.id &&
              !_disposed) {
            _opened.add(parts[1]);
          }
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) async {
          if (_disposed ||
              message.data['user_id'] != client.auth.currentUser?.id) {
            return;
          }
          _messages.add(null);
          final notification = message.notification;
          if (notification != null) {
            // Reusing the ID prevents multiple foreground cards for a retried job.
            final key =
                message.data['notification_id'] ?? message.messageId ?? '';
            final id = key.codeUnits.fold<int>(
              0,
              (a, b) => (a * 31 + b) & 0x7fffffff,
            );
            await _local.show(
              id,
              notification.title,
              notification.body,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'smartpark_parking',
                  'Nhắc giờ lấy xe',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: 'ic_notification',
                ),
              ),
              payload:
                  '${message.data['user_id']}|${message.data['booking_id'] ?? ''}',
            );
          }
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(_openMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          _token = token;
          _registered = null;
          unawaited(bindUser(client.auth.currentUser?.id));
        }),
      );
      _initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final parts = launch?.notificationResponse?.payload?.split('|');
        if (parts?.length == 2 && parts![0] == client.auth.currentUser?.id) {
          _opened.add(parts[1]);
        }
      }
      _ready = true;
      return true;
    } catch (_) {
      _status =
          'Chưa cấu hình thông báo điện thoại. Thông báo trong app vẫn hoạt động.';
      return false;
    }
  }

  void _openMessage(RemoteMessage message) {
    if (!_disposed && message.data['user_id'] == client.auth.currentUser?.id) {
      _messages.add(null);
      final booking = message.data['booking_id'];
      if (booking != null && booking.isNotEmpty) _opened.add(booking);
    }
  }

  @override
  Future<void> bindUser(String? userId) {
    if (_disposed || _suspended) return Future.value();
    _requestedUser = userId;
    return _binding ??= _bindRequested().whenComplete(() => _binding = null);
  }

  Future<void> _bindRequested() async {
    String? actor;
    do {
      actor = _requestedUser;
      if (_disposed || !await _initialize()) return;
      if (_initialMessage != null && actor != null) {
        final initial = _initialMessage!;
        _initialMessage = null;
        _openMessage(initial);
      }
      if (actor == null) {
        _registered = null;
        continue;
      }
      try {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          _status = 'Chưa được cấp quyền thông báo trên điện thoại';
          continue;
        }
        _token ??= await FirebaseMessaging.instance.getToken();
        if (_token == null) {
          _status = 'Chưa lấy được mã thiết bị. Thử lại khi có mạng.';
          continue;
        }
        if (_disposed || actor != client.auth.currentUser?.id) continue;
        final key = '$actor:$_token';
        if (_registered != key) {
          await client
              .rpc('register_push_device', params: {'p_token': _token})
              .timeout(const Duration(seconds: 12));
          _registered = key;
        }
        _status = 'Đã bật thông báo trên điện thoại';
      } catch (_) {
        _status = 'Chưa đăng ký được thông báo. Sẽ tự thử lại khi có mạng.';
      }
    } while (!_disposed && actor != _requestedUser);
  }

  @override
  Future<void> enable() async {
    if (!await _initialize()) throw ParkFailure(_status);
    await FirebaseMessaging.instance.requestPermission();
    await bindUser(client.auth.currentUser?.id);
  }

  @override
  Future<void> unregister() async {
    if (!_ready) return;
    _suspended = true;
    _requestedUser = null;
    // Finish a token registration before disabling it. If the server cannot
    // confirm logout cleanup, retain the signed-in session for a safe retry.
    await _binding;
    if (_token != null && client.auth.currentUser != null) {
      try {
        await client
            .rpc('unregister_push_device', params: {'p_token': _token})
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        _suspended = false;
        throw const ParkFailure(
          'Chưa thể ngừng thông báo trên thiết bị này. Kết nối mạng rồi đăng xuất lại.',
        );
      }
    }
    await _local.cancelAll();
    _registered = null;
    _requestedUser = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _initializing;
    await _binding;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _messages.close();
    await _opened.close();
  }
}
