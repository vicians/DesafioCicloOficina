import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseMessagingService {
  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();

    if (token != null) {
      print("Firebase conectado"); // TODO: Remover print
    }
}

}