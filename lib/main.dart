// تعريف القنوات للإشعارات (Silent by default as per user request)
import 'dart:async' as meto_async;
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mmmm/screens/add_post_screen.dart';
import 'package:mmmm/screens/add_story_screen.dart';
import 'package:mmmm/screens/agency_request_screen.dart';
import 'package:mmmm/screens/agents_screen.dart';
import 'package:mmmm/screens/comments_screen.dart';
import 'package:mmmm/screens/edit_profile_screen.dart';
import 'package:mmmm/screens/login_screen.dart';
import 'package:mmmm/screens/ludo_screen.dart';
import 'package:mmmm/screens/main_screen.dart';
import 'package:mmmm/screens/notification_screen.dart';
import 'package:mmmm/screens/post_search_screen.dart';
import 'package:mmmm/screens/privacy_policy_screen.dart';
import 'package:mmmm/screens/profile_screen.dart';
import 'package:mmmm/screens/settings_screen.dart';
import 'package:mmmm/screens/signup_screen.dart';
import 'package:mmmm/screens/splash_screen.dart';
import 'package:mmmm/screens/support_screen.dart';
import 'package:mmmm/screens/terms_of_use_screen.dart';
import 'package:mmmm/screens/voice_room_screen.dart';
import 'package:mmmm/screens/wallet_screen.dart';
import 'package:mmmm/services/notification_service.dart' as ns;
import 'package:mmmm/services/post_service.dart';
import 'package:mmmm/services/preload_service.dart';
import 'package:mmmm/services/presence_service.dart';
import 'package:mmmm/services/user_service.dart';
import 'package:mmmm/services/voice_room_service.dart';
import 'package:mmmm/providers/shut_the_box_provider.dart';
import 'package:mmmm/widgets/block_wrapper.dart';
import 'package:mmmm/widgets/minimized_room_widget.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'meto_notifications_v4',
  'إشعارات النظام',
  description: 'هذه القناة مخصصة لإشعارات تطبيق ميتو العامة.',
  importance: Importance.high, // Show pop-ups
  playSound: true, // Play sound
  sound: RawResourceAndroidNotificationSound('meto'),
);

const AndroidNotificationChannel messagesChannel = AndroidNotificationChannel(
  'meto_messages_v4',
  'رسائل ومحادثات',
  description: 'إشعارات الرسائل والدردشة.',
  importance: Importance.high, // Show pop-ups
  playSound: true, // Play sound
  sound: RawResourceAndroidNotificationSound('msg'),
);

const AndroidNotificationChannel giftsChannel = AndroidNotificationChannel(
  'meto_gifts_v4',
  'إشعارات الهدايا',
  description: 'إشعارات استلام الهدايا.',
  importance: Importance.high, // Show pop-ups
  playSound: true, // Play sound
  sound: RawResourceAndroidNotificationSound('gift'),
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
meto_async.Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // عرض الإشعار المحلي عند إغلاق التطبيق تماماً (terminated state)
  // FCM يعرض الإشعارات تلقائياً إذا كان هناك notification payload
  // لكن إذا كانت data-only messages، نحتاج إلى عرضها يدوياً هنا
  if (message.notification == null && message.data.isNotEmpty) {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    await plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // إنشاء قنوات الإشعارات
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.createNotificationChannel(messagesChannel);
      await androidPlugin.createNotificationChannel(giftsChannel);
    }

    final type = message.data['type']?.toString();
    final isGiftNotification = type == '4';
    final isChatMessage =
        !isGiftNotification &&
        (type == 'chat' || type == 'message' || type == '2');

    final selectedChannelId = isGiftNotification
        ? 'meto_gifts_v4'
        : isChatMessage
        ? 'meto_messages_v4'
        : 'meto_notifications_v4';
    final selectedChannelName = isGiftNotification
        ? 'إشعارات الهدايا'
        : isChatMessage
        ? 'رسائل ومحادثات'
        : 'إشعارات النظام';

    final title = message.data['title'] ?? message.data['senderName'] ?? 'ميتو';
    final body = message.data['body'] ?? message.data['text'] ?? '';

    if (body.isNotEmpty) {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            selectedChannelId,
            selectedChannelName,
            icon: '@drawable/ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('@drawable/shaar'),
            color: const Color(0xFF0A2E1A),
            priority: Priority.high,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global Notifiers for Theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(
  const Color(0xFF009688),
);

meto_async.Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize timezone asynchronously to avoid blocking runApp
  meto_async.Future(() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Failed to get local timezone: $e");
    }
  });

  // تفعيل App Check للوضع الحقيقي (Play Integrity) لتجنب توقف التطبيق (ANR)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  // Load saved theme
  try {
    final prefs = await SharedPreferences.getInstance();

    // Load Dark Mode
    final isDarkMode = prefs.getBool('isDarkMode');
    if (isDarkMode != null) {
      themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    } else {
      themeNotifier.value = ThemeMode.light;
    }

    // Load Primary Color
    final colorValue = prefs.getInt('primaryColor');
    if (colorValue != null) {
      primaryColorNotifier.value = Color(colorValue);
    }
  } catch (e) {
    themeNotifier.value = ThemeMode.light;
  }

  // إعداد اللغة العربية للوقت
  timeago.setLocaleMessages('ar', timeago.ArMessages());

  // إعداد Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // إنشاء قنوات الإشعارات في الخلفية لتسريع تشغيل التطبيق
  meto_async.Future(() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.createNotificationChannel(messagesChannel);
      await androidPlugin.createNotificationChannel(giftsChannel);
    }
  });

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // Show popup in foreground
    badge: true,
    sound: true, // Play sound
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VoiceRoomService()),
        ChangeNotifierProvider(create: (_) => ShutTheBoxProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final ns.NotificationService _notificationService = ns.NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupInteractedMessage();
    _initLocalNotifications();
    _listenToSessionChanges();

    // Preload gifts in background
    PreloadService().preloadGiftAnimations();

    // تعيين المستخدم كنشط عند فتح التطبيق
    _setUserOnline();

    // الاستماع للرسائل في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final senderId = message.data['senderId'];
        if (senderId != null) {
          final userService = UserService();
          final userDoc = await userService.getUser(currentUser.uid);
          if (userDoc != null && userDoc.mutedUsers.contains(senderId)) {
            return;
          }

          if (PresenceService().activeChatId == senderId) {
            return;
          }

          final voiceRoomService = Provider.of<VoiceRoomService>(
            context,
            listen: false,
          );
          if (voiceRoomService.isJoined) {
            final type = message.data['type']?.toString();
            final messageType = message.data['messageType']?.toString();
            if (type == '9' || messageType == 'room_invite') return;
            final isChatMessage =
                type == 'chat' ||
                type == 'message' ||
                type == '2' ||
                type == '4';
            if (isChatMessage) return;
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final bool notificationsEnabled =
            prefs.getBool('notificationsEnabled') ?? true;
        if (!notificationsEnabled) return;
      }

      RemoteNotification? notification = message.notification;
      String? title =
          notification?.title ??
          message.data['title'] ??
          message.data['senderName'];
      String? body =
          notification?.body ?? message.data['body'] ?? message.data['text'];

      if (title != null && body != null) {
        final int notificationId =
            DateTime.now().microsecondsSinceEpoch % 1000000;
        final type = message.data['type']?.toString();
        final isGiftNotification = type == '4';
        final isChatMessage =
            !isGiftNotification &&
            (type == 'chat' || type == 'message' || type == '2');
        final selectedChannelId = isGiftNotification
            ? giftsChannel.id
            : isChatMessage
            ? messagesChannel.id
            : channel.id;

        flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              selectedChannelId,
              isGiftNotification
                  ? giftsChannel.name
                  : isChatMessage
                  ? messagesChannel.name
                  : channel.name,
              channelDescription: isGiftNotification
                  ? giftsChannel.description
                  : isChatMessage
                  ? messagesChannel.description
                  : channel.description,
              icon: '@drawable/ic_notification',
              largeIcon: const DrawableResourceAndroidBitmap('@drawable/shaar'),
              color: const Color(0xFF0A2E1A),
              priority: Priority.high,
              importance: Importance.high,
              enableVibration: true,
              playSound: true,
              ticker: 'ticker',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;

  void _listenToSessionChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      _sessionSubscription?.cancel();
      if (user != null) {
        _sessionSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) async {
              if (snapshot.exists) {
                final data = snapshot.data();
                if (data != null && data.containsKey('sessionId')) {
                  final remoteSessionId = data['sessionId'] as String?;
                  final prefs = await SharedPreferences.getInstance();
                  final localSessionId = prefs.getString('sessionId');

                  if (remoteSessionId != null &&
                      localSessionId != null &&
                      remoteSessionId != localSessionId) {
                    await FirebaseAuth.instance.signOut();
                    await prefs.remove('sessionId');
                    if (navigatorKey.currentState != null) {
                      navigatorKey.currentState!.pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                      ScaffoldMessenger.of(
                        navigatorKey.currentContext!,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text('تم تسجيل الدخول من جهاز آخر'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              } else {
                final userMetadata =
                    FirebaseAuth.instance.currentUser?.metadata;
                final creationTime = userMetadata?.creationTime;
                if (creationTime != null &&
                    DateTime.now().difference(creationTime).inSeconds < 10)
                  return;

                await FirebaseAuth.instance.signOut();
                if (navigatorKey.currentState != null) {
                  navigatorKey.currentState!.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                  ScaffoldMessenger.of(
                    navigatorKey.currentContext!,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف حسابك أو تعطيله من النظام'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _setUserOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setUserOffline();
        break;
    }
  }

  void _setUserOnline() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _userService.setUserOnline(user.uid);
  }

  void _setUserOffline() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _userService.setUserOffline(user.uid);
  }

  meto_async.Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            _navigateToScreen(jsonDecode(details.payload!));
          } catch (e) {}
        }
      },
    );
    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) await androidImpl.requestNotificationsPermission();
  }

  meto_async.Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) _handleMessage(initialMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) => _navigateToScreen(message.data);

  void _navigateToScreen(Map<String, dynamic> data) async {
    final typeIndex = int.tryParse(data['type'].toString()) ?? -1;
    final senderId = data['senderId'];
    final postId = data['postId'];
    if (navigatorKey.currentState == null) return;

    if (typeIndex == 0) {
      if (senderId != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (context) => ProfileScreen(uid: senderId)),
        );
      }
    } else if (typeIndex == 1 || typeIndex == 2 || typeIndex == 3) {
      if (postId != null) {
        try {
          final post = await PostService().getPost(postId);
          if (post != null) {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) => CommentsScreen(post: post),
              ),
            );
          }
        } catch (e) {}
      }
    } else if (typeIndex == 5) {
      final roomId = data['roomId'] ?? data['postId'];
      if (roomId != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => LudoScreen(roomId: roomId.toString()),
          ),
        );
      }
    } else if (data['type'] == 'support_update' || typeIndex == 7) {
      navigatorKey.currentState!.pushNamed('/support');
    } else if (data['type'] == 'agency_update' || typeIndex == 8) {
      navigatorKey.currentState!.pushNamed('/agency-request');
    } else if (typeIndex == 9) {
      final roomId = data['roomId'] ?? data['postId'];
      if (roomId != null) {
        final voiceService = Provider.of<VoiceRoomService>(
          navigatorKey.currentContext!,
          listen: false,
        );
        if (voiceService.isJoined &&
            voiceService.currentRoomId == roomId.toString())
          return;
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => VoiceRoomScreen(
              roomId: roomId.toString(),
              initialRoomData: data,
            ),
          ),
        );
      }
    }
    final notificationId = data['notificationId'];
    if (notificationId != null)
      await _notificationService.markAsRead(notificationId.toString());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: primaryColorNotifier,
          builder: (context, primaryColor, _) {
            final secondaryColor = primaryColor.withValues(alpha: 0.8);
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'MeTo',
              debugShowCheckedModeBanner: false,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                useMaterial3: true,
                textTheme: GoogleFonts.tajawalTextTheme(),
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  primary: primaryColor,
                  secondary: secondaryColor,
                  surface: Colors.white,
                  background: const Color(0xFFF5F7FB),
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(0xFFF5F7FB),
                appBarTheme: AppBarTheme(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  titleTextStyle: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  backgroundColor: primaryColor,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white70,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  primary: primaryColor,
                  secondary: secondaryColor,
                  surface: const Color(0xFF1E1E1E),
                  background: const Color(0xFF121212),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: AppBarTheme(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  titleTextStyle: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  backgroundColor: primaryColor,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white70,
                ),
                textTheme: GoogleFonts.tajawalTextTheme(
                  const TextTheme(
                    bodyLarge: TextStyle(color: Colors.white),
                    bodyMedium: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              themeMode: currentMode,
              home: const SplashScreenHandler(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/signup': (context) => const SignUpScreen(),
                '/home': (context) => const MainScreen(),
                '/addPost': (context) => const AddPostScreen(),
                '/addStory': (context) => const AddStoryScreen(),
                '/editProfile': (context) => const EditProfileScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/search': (context) => const UnifiedSearchScreen(),
                '/notifications': (context) => const NotificationScreen(),
                '/agents': (context) => const AgentsScreen(),
                '/agency-request': (context) => const AgencyRequestScreen(),
                '/wallet': (context) => WalletScreen(
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                ),
                '/voice-room': (context) {
                  final args =
                      ModalRoute.of(context)!.settings.arguments
                          as Map<String, dynamic>;
                  return VoiceRoomScreen(
                    roomId: args['roomId'],
                    initialRoomData: args['initialRoomData'] ?? args,
                  );
                },
                '/privacy-policy': (context) => const PrivacyPolicyScreen(),
                '/terms-of-use': (context) => const TermsOfUseScreen(),
                '/support': (context) => const SupportScreen(),
              },
              builder: (context, child) {
                return ResponsiveBreakpoints.builder(
                  child: Builder(
                    builder: (context) {
                      return Container(
                        color: Colors.black,
                        child: MaxWidthBox(
                          maxWidth: 1200,
                          child: ResponsiveScaledBox(
                            // 390 هو عرض الشاشة القياسي للهواتف المتوسطة، سنقوم بتكبير/تصغير كل شيء بناءً عليه
                            width: ResponsiveValue<double>(
                              context,
                              defaultValue: 390,
                              conditionalValues: [
                                Condition.equals(name: MOBILE, value: 390),
                                Condition.between(
                                  start: 800,
                                  end: 1100,
                                  value: 800,
                                ),
                                Condition.between(
                                  start: 1000,
                                  end: 1200,
                                  value: 1000,
                                ),
                              ],
                            ).value,
                            child: BlockWrapper(
                              child: Stack(
                                children: [
                                  if (child != null) child,
                                  const MinimizedRoomWidget(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  breakpoints: [
                    const Breakpoint(start: 0, end: 450, name: MOBILE),
                    const Breakpoint(start: 451, end: 800, name: TABLET),
                    const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                    const Breakpoint(
                      start: 1921,
                      end: double.infinity,
                      name: '4K',
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class SplashScreenHandler extends StatefulWidget {
  const SplashScreenHandler({super.key});
  @override
  State<SplashScreenHandler> createState() => _SplashScreenHandlerState();
}

class _SplashScreenHandlerState extends State<SplashScreenHandler> {
  bool _isSplashVisible = true;
  @override
  Widget build(BuildContext context) {
    if (_isSplashVisible) {
      return SplashScreen(
        onInitializationComplete: () {
          if (mounted) setState(() => _isSplashVisible = false);
        },
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ValueListenableBuilder<Color>(
            valueListenable: primaryColorNotifier,
            builder: (context, color, _) => Scaffold(
              body: Center(child: CircularProgressIndicator(color: color)),
            ),
          );
        }
        if (snapshot.hasData) {
          UserService().updateFCMToken(snapshot.data!.uid);
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
