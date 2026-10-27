import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class FCMService {
  static const String _serviceAccountJson = '''
{
  "type": "service_account",
  "project_id": "meto-9e010",
  "private_key_id": "0589c2fde6fa5d277378b364d505259ebbcde0c5",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDXh/47LfkCcBe+\\nK9/UOgqiHP4ORcL/rnq+4vBBOYc2U5wADgvjIHyzqEfUXtoR8u0Bx+FxvpTUi97V\\n182hw4hjmTgRulDqtiVqReY+V+EnVY5nYfScBM9KmE6ZfS3ZK7CBTroGajqHrQZJ\\nyvcyqu/BS5oH2R0F7lwr6DcoQfQWmZtubDGktdDPpog8LhGh0UwMx8kghFGLuXK4\\nk7du+oP5w+SBr1uM5XqSHSsr2rOHDNhwXrvcV6rYqxFhrrt5peDXNPVnVCwiDRuu\\n3hU7fLYZLpt3UtQ9SziX0Yu8vbAh8i4cdmHduOUlkdwMbF0Ke0lX33Vc1BN7/ZHn\\ng5kD76rdAgMBAAECggEABZTyxf2ypBEFqbnk07OfjsOVyenWfrlzBHbkPze/eKb9\\nycnorCAfGN9c4cFpHIDj0JNFBUHwBHjw3hEFUXvJEE5ieqG5B/o3GC4bJCD42Etw\\nxqPfTdSnnQTIqhu+cGWRNWHghOl009Gz1QtNcw/dsLU+snodCc9XIE/BVJqFjmR0\\n2tZ+SA12p/B7Rf8zs4cIOz4GrXTDy+mQWciIWc/nfz+ochZpDGeOxzxfV0872Cvu\\nOYcRDhIr97QTxkNMj+Dkux7Iuhi81nqwaeHKlXTmANFw5qRR2c5QSFDd3N+RXLor\\nu5YZGi2fMpSnM//EdfRgZIIf005z98+4pfMXPJGREQKBgQDrF+NE+NNqXcwnBUf3\\n5Ar6Z97GeF7XSayWYRe9gwUB9RZLskDh2FcO79LjZhnD5ElvYu8F7/5BEz8uP3gN\\n+sEwPjbPr8ggH99rJkItIX1Zj2fjLMGplg7tMEs97dfSjhvrlXWPiLrSKzE9Ge4y\\nhuiOE87JkGUww2SVHQ2RU2HhhQKBgQDqssGzyPDZLqM8cuHsP4/fSmPoJaDxo1+N\\nGGnDp6DP7qrG+jjNKKmXrqb4bOMK0xaCECHrmQ6aqs9au3QzZbhHc1EK/wdpEBnc\\n/hdbioTpGHpd8tFhGcHu4mLw4Kw61F7PCWmlHefjKwAqErdYUOKpKrtGuDSBsppX\\ntyb+B363eQKBgGyvPHh0eHjiKDGZ9W2a1aBySMGEgIQTIWDcPjd0zOncvpP8Mpa2\\nh3j2Uo6icyLm9TQzjsE19FttZHYjDYOY+5ssB/b4ExMW6RkGNO3cX7D55VNXK6kV\\nII1zGDXnMTG8VRgSnqje00+6fCb9R+vABt84NQ9mXAGxM1zkc5NN8yBpAoGBANAU\\nXBgBd0eWSbM2R4clc3EMizcu5VpW9kgp9Ns6qyCvAUoYXnPGMVYBypdGMqVOMQ5v\\nLyOqN4B5IA3ZVFSdQpxWaOvO38sOM1/zBtJqJRxkT1ksBuaH56DbpczZ5NjjoIr+\\nVWPG9+g4H5Utss/iJpLFB/TTK/oxVxWdlDx0eKxBAoGBANe9CWD5PguWGC6bW5aF\\nXpj41cqcxUEd73lsQJG+Bz0bVVACYh/GOBmxzhq+teDlpoT7qWuCoDLilMm9iVi5\\nnIgEbIcwFWODUWD4JWVpYFoj5qDywcUxxTk3c9E8QY3ZFs5PwD0He4CYy+q8kKZI\\nSJWnjYUhqopmq1yPK9fjiI1X\\n-----END PRIVATE KEY-----\\n",
  "client_email": "firebase-adminsdk-fbsvc@meto-9e010.iam.gserviceaccount.com",
  "client_id": "105437529402525041293",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40meto-9e010.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
''';

  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;

  static Future<String> _getAccessToken() async {
    try {
      if (_cachedAccessToken != null &&
          _tokenExpiry != null &&
          _tokenExpiry!.isAfter(DateTime.now())) {
        return _cachedAccessToken!;
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(
        _serviceAccountJson,
      );
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);

      _cachedAccessToken = client.credentials.accessToken.data;
      // Set expiry to 5 minutes before actual expiry to be safe
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));

      client.close();
      return _cachedAccessToken!;
    } catch (e) {
      print('Error getting FCM access token: $e');
      rethrow;
    }
  }

  static Future<void> sendNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (deviceToken.isEmpty) return;

    try {
      final accessToken = await _getAccessToken();
      final projectId = jsonDecode(_serviceAccountJson)['project_id'];
      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final type = data?['type']?.toString();

      // Check for gift notification first (type index 4)
      final isGiftNotification = type == '4';

      // Then check for chat messages (type index 2, or 'chat'/'message' strings)
      final isChatMessage =
          !isGiftNotification &&
          (type == 'chat' || type == 'message' || type == '2');

      final selectedSound = isGiftNotification
          ? 'gift'
          : isChatMessage
          ? 'msg'
          : 'meto';
      final selectedChannelId = isGiftNotification
          ? 'meto_gifts_v4'
          : isChatMessage
          ? 'meto_messages_v4'
          : 'meto_notifications_v4';

      final message = {
        'message': {
          'token': deviceToken,
          'notification': {'title': title, 'body': body},
          'data':
              data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
          'android': {
            'priority': 'high',
            'ttl': '0s', // Immediate delivery
            'notification': {
              'sound': selectedSound,
              'channel_id': selectedChannelId,
              'tag': DateTime.now().millisecondsSinceEpoch
                  .toString(), // Prevent collapsing
            },
          },
          'apns': {
            'headers': {
              'apns-priority': '10', // High priority for iOS
              'apns-push-type': 'alert',
            },
            'payload': {
              'aps': {
                'sound': isGiftNotification
                    ? 'gift.wav'
                    : isChatMessage
                    ? 'msg.wav'
                    : 'meto.wav',
                'badge': 1,
                'content-available': 1,
              },
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode != 200) {
        print(
          'Error sending FCM notification: ${response.statusCode} - ${response.body}',
        );
      } else {
        print('FCM notification sent successfully');
      }
    } catch (e) {
      print('Exception in sendNotification: $e');
    }
  }

  static Future<void> sendGlobalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      final projectId = jsonDecode(_serviceAccountJson)['project_id'];
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final message = {
        'message': {
          'topic': 'all',
          'notification': {'title': title, 'body': body},
          'data': data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
          'android': {
            'priority': 'high',
            'ttl': '0s',
            'notification': {
              'sound': 'meto',
              'channel_id': 'meto_notifications_v4',
            },
          },
          'apns': {
            'headers': {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            'payload': {
              'aps': {
                'sound': 'meto.wav',
                'badge': 1,
                'content-available': 1,
              },
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode != 200) {
        print('Error sending FCM global notification: ${response.statusCode} - ${response.body}');
      } else {
        print('FCM global notification sent successfully');
      }
    } catch (e) {
      print('Exception in sendGlobalNotification: $e');
    }
  }
}
