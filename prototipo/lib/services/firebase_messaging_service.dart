import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][background] ${message.messageId} ${message.notification?.title}');
}

class FirebaseMessagingService {
  static bool _fcmAvailable = true;
  static bool _listenersConfigured = false;
  static String? _currentUserId;
  static String? _currentBaseUrl;
  static final Set<int> _devSeedTriggeredForType = <int>{};
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'internal_alerts_channel',
        'Alertas Internos',
        description: 'Canal de notificações internas da oficina',
        importance: Importance.high,
      );

  static Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(const Duration(seconds: 3));

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      try {
        final token = await messaging.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw 'getToken timeout',
        );
        if (token != null) {
          debugPrint('[FCM] Token obtido com sucesso');
        }
      } catch (e) {
        debugPrint('[FCM] Falha silenciosa no getToken: $e');
      }
    } catch (e) {
      _fcmAvailable = false;
      debugPrint('[FCM] init falhou completamente: $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(initSettings);

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  static Future<void> configureInternalNotifications({
    required String baseUrl,
    required int internalUserTypeId,
    bool triggerDevLowStockSeed = false,
  }) async {
    final userId = await _resolveInternalUserId(
      baseUrl: baseUrl,
      internalUserTypeId: internalUserTypeId,
    );
    if (userId == null) return;

    _currentBaseUrl = baseUrl;
    _currentUserId = userId;

    await _registerCurrentToken(baseUrl: baseUrl, usuarioId: userId);

    if (!_listenersConfigured) {
      _configureListeners();
      _listenersConfigured = true;
    }

    if (triggerDevLowStockSeed && !_devSeedTriggeredForType.contains(internalUserTypeId)) {
      _devSeedTriggeredForType.add(internalUserTypeId);
      await _triggerDevLowStockSeed(baseUrl: baseUrl);
    }
  }

  static Future<void> configureClientNotifications({
    required String baseUrl,
    required String clientId,
    bool triggerDevClientSeed = false,
  }) async {
    _currentBaseUrl = baseUrl;
    _currentUserId = clientId;

    await _registerCurrentToken(baseUrl: baseUrl, usuarioId: clientId);

    if (!_listenersConfigured) {
      _configureListeners();
      _listenersConfigured = true;
    }

    final seedKey = clientId.hashCode;
    if (triggerDevClientSeed && !_devSeedTriggeredForType.contains(seedKey)) {
      _devSeedTriggeredForType.add(seedKey);
      await _triggerDevClientSeed(baseUrl: baseUrl);
    }
  }

  static void _configureListeners() {
    if (!_fcmAvailable) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM][foreground] ${message.messageId} ${message.notification?.title}');
      _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM][tap] ${message.messageId} ${message.notification?.title}');
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final baseUrl = _currentBaseUrl;
      final userId = _currentUserId;
      if (baseUrl == null || userId == null) return;
      await _upsertPushToken(
        baseUrl: baseUrl,
        usuarioId: userId,
        token: token,
      );
    });
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
  }

  static Future<String?> _resolveInternalUserId({
    required String baseUrl,
    required int internalUserTypeId,
  }) async {
    final uri = Uri.parse('$baseUrl/usuarios').replace(
      queryParameters: {'tipo_id': internalUserTypeId.toString()},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final List<dynamic> users = jsonDecode(response.body) as List<dynamic>;
    if (users.isEmpty) return null;

    final first = users.first as Map<String, dynamic>;
    return first['id'] as String?;
  }

  static Future<void> _registerCurrentToken({
    required String baseUrl,
    required String usuarioId,
  }) async {
    if (!_fcmAvailable) return;
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw 'getToken timeout',
      );
      if (token == null || token.isEmpty) return;
      await _upsertPushToken(baseUrl: baseUrl, usuarioId: usuarioId, token: token);
    } catch (e) {
      debugPrint('[FCM] getToken falhou: $e');
      if (e.toString().contains('FirebaseInstallationsException')) {
        _fcmAvailable = false;
      }
    }
  }

  static Future<void> _upsertPushToken({
    required String baseUrl,
    required String usuarioId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/push-tokens'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usuario_id': usuarioId,
        'fcm_registration_token': token,
      }),
    );

    if (response.statusCode != 201) {
      debugPrint('[FCM] Falha ao registrar token push: ${response.statusCode}');
    }
  }

  static Future<void> _triggerDevLowStockSeed({
    required String baseUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/dev/seed-low-stock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'produto_nome': 'Bateria Seed App Start',
        'quantidade_estoque': 2,
      }),
    );

    if (response.statusCode != 201) {
      debugPrint('[FCM] Seed DEV low_stock não executada: ${response.statusCode}');
    }
  }

  static Future<void> _triggerDevClientSeed({
    required String baseUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/dev/seed-client-alert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'source': 'cliente-app-startup',
      }),
    );

    if (response.statusCode != 201) {
      debugPrint('[FCM] Seed DEV client não executada: ${response.statusCode}');
    }
  }

}