import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  // TODO: Replace with a valid Gemini API Key
  static String _apiKey = "YOUR_GEMINI_API_KEY";

  static bool get hasKey =>
      _apiKey != "YOUR_GEMINI_API_KEY" && _apiKey.isNotEmpty;

  static void setApiKey(String key) {
    _apiKey = key;
  }

  static GenerativeModel? _model;

  static GenerativeModel _getModel() {
    _model ??= GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    return _model!;
  }

  /// الحصول على رد ذكي من البوت بناءً على الموقف
  static Future<String?> getBotResponse({
    required String botName,
    required String personality,
    required String event,
    required String context,
  }) async {
    if (!hasKey) return null;

    try {
      final prompt =
          """
      أنت لاعب ذكاء اصطناعي (بوت) في لعبة لودو (Ludo) عراقية مشهورة. 
      اسمك: $botName.
      شخصيتك في اللعب: $personality.
      الموقف الحالي: $event.
      سياق اللعبة: $context.

      المطلوب:
      اكتب تعليقاً قصيراً جداً، مضحكاً، وواقعياً باللهجة العراقية العامية (دارجة) كأنك لاعب حقيقي يدردش في الغرفة.
      - الرد يجب أن يكون جملة واحدة قصيرة أو بضع كلمات فقط.
      - استخدم الإيموجي المناسب للعراقيين (مثل 😂، 🔥، 😎، 😜، 😒).
      - لا تستخدم الفصحى نهائياً.
      - كن خفيف الظل وابقَ في شخصيتك (إذا كنت هجومي فكن متنمراً قليلاً، وإذا كنت مدافعاً فكن حذراً أو معتذراً).
      - لا تذكر أنك ذكاء اصطناعي.
      """;

      final content = [Content.text(prompt)];
      final response = await _getModel().generateContent(content);
      return response.text?.trim();
    } catch (e) {
      debugPrint("AIService Error: $e");
      return null;
    }
  }

  /// الحصول على رد مباشر لمسج من المستخدم
  static Future<String?> getChatResponse({
    required String botName,
    required String personality,
    required String userMessage,
    required String context,
  }) async {
    if (!hasKey) return null;

    try {
      final prompt =
          """
      أنت لاعب عراقي (بوت) في لودو اسمك $botName وشخصيتك $personality.
      المستخدم أرسل لك هذه الرسالة: "$userMessage".
      سياق اللعبة الحالي: $context.

      المطلوب:
      رد عليه بذكاء وخفة دم عراقية (دارجة حصراً).
      - كن قصيراً ومباشراً.
      - تفاعل مع كلامه (إذا مدحك، إذا استهزأ بك، إذا سألك).
      - استخدم إيموجيات عراقية ملائمة.
      - لا تتحدث كـ AI، أنت لاعب حقيقي.
      """;

      final content = [Content.text(prompt)];
      final response = await _getModel().generateContent(content);
      return response.text?.trim();
    } catch (e) {
      debugPrint("AIService Error: $e");
      return null;
    }
  }
}
