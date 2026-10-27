// ignore_for_file: avoid_print

/// خدمة بسيطة لتتبع حالة المستخدم داخل التطبيق (مثل المحادثة النشطة)
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  // تتبع معرف المستخدم الذي تتم محادثته حالياً
  String? _activeChatId;

  String? get activeChatId => _activeChatId;

  void setActiveChatId(String? uid) {
    _activeChatId = uid;
    print('Active chat set to: $uid');
  }
}
