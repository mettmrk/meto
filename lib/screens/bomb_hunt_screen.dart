import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/game_service.dart';
import '../models/game_model.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';
import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:lottie/lottie.dart';

class BombHuntScreen extends StatefulWidget {
  const BombHuntScreen({super.key});

  @override
  State<BombHuntScreen> createState() => _BombHuntScreenState();
}

class _BombHuntScreenState extends State<BombHuntScreen>
    with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _gameId;
  String? _currentUserId;
  String _status = 'جاري الاتصال...';

  StreamSubscription<GameModel?>? _gameSubscription;
  GameModel? _gameModel;

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _boomPlayer = AudioPlayer();
  final AudioPlayer _setupPlayer = AudioPlayer();

  bool _isSetupDone = false;
  bool _isExploding = false;
  bool _isActionActive = false; // لمنع الضغط العشوائي أثناء ظهور النوافذ
  int _myShields = 0;
  int _comboCount = 0; // متتبع للضربات المتتالية (كومبو)

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final List<String> _minefieldPool = [
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'SAFE',
    'MINE',
    'MINE',
    'MINE',
    'MINE',
    'TIME_BOMB',
    'TIME_BOMB',
    'QUESTION',
    'QUESTION',
    'SHIELD', // تم تقليل الدرع إلى 1 فقط لجعلها أكثر تحدياً
    'BOX',
  ];

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: -15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _initializeGame();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await Future.wait([
        _musicPlayer
            .setUrl(
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
            )
            .then((_) {
              _musicPlayer.setLoopMode(LoopMode.all);
              _musicPlayer.setVolume(0.85);
              _musicPlayer.play();
            }),
        _boomPlayer
            .setUrl(
              'https://actions.google.com/sounds/v1/explosions/explosion_large_distant.ogg',
            )
            .then((_) {
              _boomPlayer.setLoopMode(LoopMode.off);
              _boomPlayer.setVolume(1.0);
            }),
      ]);
    } catch (e) {
      debugPrint('Audio Init Error: $e');
    }
  }

  Future<void> _initializeGame() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _status = 'يجب تسجيل الدخول');
      return;
    }
    _currentUserId = user.uid;

    String gameId = await _gameService.findOrCreateGame(
      type: 'bomb_hunt',
      userId: user.uid,
      userName: user.displayName ?? 'لاعب',
    );

    setState(() => _gameId = gameId);
    _gameSubscription = _gameService.streamGame(gameId).listen(_onGameUpdate);
  }

  void _onGameUpdate(GameModel? game) {
    if (game == null || !mounted) return;

    setState(() {
      _gameModel = game;

      if (game.status == 'waiting') {
        _status = 'بانتظار لاعب آخر...';
      } else if (game.status == 'active') {
        bool bothSetup = (game.data['setup'] ?? {}).length == 2;
        if (!bothSetup) {
          _status = 'اضغط لزرع الفخاخ للخصم 🥷';
        } else {
          bool isMyTurn = game.currentTurn == _currentUserId;
          _status = isMyTurn
              ? 'دورك! استمر بالتقدم بحذر 🔥'
              : 'دور الخصم... راقبه يخطئ! 🍿';
        }
      } else if (game.status == 'finished' && !_isExploding) {
        _status = game.winner == _currentUserId
            ? 'أنت البطل! 🏆'
            : (game.winner == 'draw' ? 'تعادل! 🤝' : 'لقد خسرت 💥');
      }
    });

    if (game.status == 'active') {
      bool serverSetupDone =
          (game.data['setup'] ?? {})[_currentUserId] ?? false;
      if (!serverSetupDone && _isSetupDone)
        setState(() => _isSetupDone = false);
    }
  }

  void _setupMinefield() async {
    if (_isSetupDone || _gameModel?.status != 'active') return;

    List<String> gridValues = List.from(_minefieldPool)..shuffle(Random());
    setState(() => _isSetupDone = true);

    Map<String, dynamic> updates = {
      'data.grids.$_currentUserId': gridValues,
      'data.setup.$_currentUserId': true,
    };

    await _gameService.makeMove(_gameId!, updates);
    if (_currentUserId != null) {
      TaskService().incrementTaskProgress(_currentUserId!, TaskType.playBombHunt);
    }
  }

  Future<bool> _showDefuseBombDialog() async {
    int tapsRequired = 10;
    int currentTaps = 0;
    int timeLeft = 3;
    Timer? timer;
    bool isDefused = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (timeLeft > 1) {
                setStateDialog(() => timeLeft--);
              } else {
                t.cancel();
                Navigator.of(context).pop();
              }
            });

            return AlertDialog(
              backgroundColor: Colors.red.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '💣 قنبلة موقوتة! فككها!',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الوقت المتبقي: $timeLeft ث',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'النقرات: $currentTaps / $tapsRequired',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      setStateDialog(() {
                        currentTaps++;
                        if (currentTaps >= tapsRequired) {
                          isDefused = true;
                          timer?.cancel();
                          Navigator.of(context).pop();
                        }
                      });
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'اضغط!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    timer?.cancel();
    return isDefused;
  }

  Future<bool> _showQuestionDialog() async {
    bool answeredCorrectly = false;
    int timeLeft = 10;
    Timer? timer;

    final List<Map<String, dynamic>> questions = [
      {
        'text': 'ما هو أسرع حيوان بري في العالم؟',
        'options': ['الأسد', 'الفهد', 'الغزال', 'الحصان'],
        'answer': 'الفهد',
      },
      {
        'text': 'كم عدد قارات العالم؟',
        'options': ['5', '6', '7', '8'],
        'answer': '7',
      },
      {
        'text': 'ما هو ناتج 12 × 12؟',
        'options': ['144', '124', '142', '164'],
        'answer': '144',
      },
      {
        'text': 'ما هي عاصمة اليابان؟',
        'options': ['بكين', 'طوكيو', 'سيول', 'بانكوك'],
        'answer': 'طوكيو',
      },
      {
        'text': 'أكبر محيط في العالم هو؟',
        'options': ['الأطلسي', 'الهندي', 'الهادي', 'المتجمد الشمالي'],
        'answer': 'الهادي',
      },
      {
        'text': 'من هو مكتشف الجاذبية؟',
        'options': ['أينشتاين', 'نيوتن', 'غاليلو', 'إديسون'],
        'answer': 'نيوتن',
      },
    ];

    final question = questions[Random().nextInt(questions.length)];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (timeLeft > 0) {
                if (mounted) setStateDialog(() => timeLeft--);
              } else {
                t.cancel();
                if (context.mounted) Navigator.of(context).pop();
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تحدي الذكاء 🧠',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: timeLeft <= 3 ? Colors.red : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$timeLeft',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    question['text'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Tajawal',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 25),
                  ...List.generate(question['options'].length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent.withOpacity(
                            0.3,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          if (question['options'][index] ==
                              question['answer']) {
                            answeredCorrectly = true;
                          }
                          timer?.cancel();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          question['options'][index],
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );

    timer?.cancel();
    return answeredCorrectly;
  }

  Future<void> _triggerExplosionEffect() async {
    setState(() => _isExploding = true);
    _shakeController.repeat();
    if (_boomPlayer.playing) await _boomPlayer.stop();
    await _boomPlayer.seek(Duration.zero);
    await _boomPlayer.play();

    await Future.delayed(const Duration(seconds: 2));
    _shakeController.stop();
    if (mounted) setState(() => _isExploding = false);
  }

  void _tapTile(int index) async {
    if (_gameModel?.currentTurn != _currentUserId ||
        _isActionActive ||
        _isExploding)
      return;

    String? oppId = _gameModel!.players.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    if (oppId.isEmpty) return;

    List revealed = _gameModel!.data['revealed']?[oppId] ?? [];
    if (revealed.contains(index)) return;

    setState(() => _isActionActive = true); // إقفال الشاشة مؤقتاً

    List gridValues = _gameModel!.data['grids'][oppId] ?? [];
    String tileType = gridValues[index];

    List updatedRevealed = List.from(revealed)..add(index);
    Map<String, dynamic> updates = {'data.revealed.$oppId': updatedRevealed};

    bool turnEnds = false;
    int pointsModifier = 0;

    switch (tileType) {
      case 'SAFE':
        _comboCount++;
        pointsModifier = _comboCount; // كسب نقاط أكثر كلما زاد الكومبو
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _comboCount > 1
                  ? 'ضربة متتالية! ×$_comboCount 🔥'
                  : 'طريق سليم! كمل ✔️',
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: _comboCount > 1 ? Colors.orange : Colors.green,
          ),
        );
        break;

      case 'MINE':
        _comboCount = 0; // تصفير الكومبو عند الإصابة
        if (_myShields > 0) {
          setState(() => _myShields--);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🛡️ الدرع حماك من اللغم! استمر')),
          );
        } else {
          await _triggerExplosionEffect();
          pointsModifier = -4; // زيادة العقوبة لجعلها أكثر إثارة
          turnEnds = true;
        }
        break;

      case 'TIME_BOMB':
        _comboCount = 0;
        bool defused = await _showDefuseBombDialog();
        if (defused) {
          pointsModifier = 5; // زيادة المكافأة
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('كفو! فككت القنبلة +5 نقاط 💪'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          await _triggerExplosionEffect();
          pointsModifier = -3;
          turnEnds = true;
        }
        break;

      case 'QUESTION':
        _comboCount = 0;
        bool answered = await _showQuestionDialog();
        if (answered) {
          pointsModifier = 7; // زيادة مكافأة السؤال
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('عبقري! +7 نقاط 🎓'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          pointsModifier = -3;
          turnEnds = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('للأسف خطأ! ضاع دورك ❌'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case 'SHIELD':
        setState(() => _myShields++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لقد وجدت درعاً ثميناً! 🛡️'),
            backgroundColor: Colors.blueAccent,
          ),
        );
        break;

      case 'BOX':
        _comboCount = 0;
        // تأثير الصندوق العشوائي: إما مكافأة كبيرة أو لغم مفاجئ
        bool isLucky = Random().nextBool();
        if (isLucky) {
          pointsModifier = 4;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يا حظك! هدية +4 نقاط 🎁'),
              backgroundColor: Colors.pink,
            ),
          );
        } else {
          await _triggerExplosionEffect();
          pointsModifier = -2;
          turnEnds = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فخ بمظهر صندوق! 💀'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        break;
    }

    updates['scores.$_currentUserId'] = FieldValue.increment(pointsModifier);

    if (turnEnds) {
      updates['currentTurn'] = oppId;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('انتهى دورك! الدور للخصم ⏳'),
            backgroundColor: Colors.orange,
          ),
        );
    }

    // إنهاء اللعبة إذا تم فتح كل المربعات
    if (updatedRevealed.length == 20) {
      updates['status'] = 'finished';
      // حساب الفائز
      int myFinalScore =
          (_gameModel!.scores[_currentUserId] ?? 0) + pointsModifier;
      int oppFinalScore = _gameModel!.scores[oppId] ?? 0;
      updates['winner'] = myFinalScore > oppFinalScore
          ? _currentUserId
          : (oppFinalScore > myFinalScore ? oppId : 'draw');
    }

    await _gameService.makeMove(_gameId!, updates);
    if (mounted) setState(() => _isActionActive = false);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _gameSubscription?.cancel();
    _musicPlayer.dispose();
    _clickPlayer.dispose();
    _boomPlayer.dispose();
    _setupPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isWaiting = _gameModel?.status == 'waiting';
    bool isFinished = _gameModel?.status == 'finished';
    bool inSetup =
        _gameModel?.status == 'active' &&
        !((_gameModel?.data['setup'] ?? {})[_currentUserId] ?? false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'حقل الألغام',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '🛡️ $_myShields',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Background Gradient Layer
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A0E1A), // Midnight Space Blue
                      Color(0xFF0F172A), // Slate Navy Dark Blue
                      Color(0xFF050814), // Dark Space Abyss
                    ],
                  ),
                ),
              ),
            ),
            // Dark Overlay for readability
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildScoreBoard(),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: isWaiting
                            ? const CircularProgressIndicator(
                                color: Colors.deepPurpleAccent,
                              )
                            : isFinished && !_isExploding
                            ? _buildResultUI()
                            : AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: inSetup
                                        ? _buildSetupGrid()
                                        : _buildPlayUI(),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isExploding)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.redAccent.withOpacity(0.3),
                    child: Center(
                      child: Lottie.asset(
                        'assets/lottie/explosion.json',
                        repeat: false,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    if (_gameModel == null) return const SizedBox();
    String? oppId = _gameModel!.players.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    int myScore = _gameModel!.scores[_currentUserId] ?? 0;
    int oppScore = oppId.isNotEmpty ? (_gameModel!.scores[oppId] ?? 0) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2D42), Color(0xFF1D3557)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _scoreItem('أنت', myScore, Colors.greenAccent),
          const Icon(
            Icons.flash_on_rounded,
            color: Colors.orangeAccent,
            size: 30,
          ),
          _scoreItem('الخصم', oppScore, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _scoreItem(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Tajawal',
            fontSize: 16,
          ),
        ),
        Text(
          score.toString(),
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSetupGrid() {
    return Column(
      children: [
        const SizedBox(height: 50),
        ElevatedButton.icon(
          onPressed: _setupMinefield,
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text(
            'زرع الألغام للخصم وبدء اللعب',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            backgroundColor: Colors.deepPurpleAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayUI() {
    bool bothSetup = (_gameModel?.data['setup'] ?? {}).length == 2;
    if (!bothSetup) {
      return const Padding(
        padding: EdgeInsets.only(top: 50),
        child: Text(
          "بانتظار الخصم ليقوم بالزرع...",
          style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
        ),
      );
    }

    String? oppId = _gameModel!.players.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    List revealed = _gameModel!.data['revealed']?[oppId] ?? [];
    List gridValues = _gameModel!.data['grids']?[oppId] ?? [];

    return Column(
      children: [
        SizedBox(
          width: 320,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: 20,
            itemBuilder: (ctx, i) {
              bool isRevealed = revealed.contains(i);
              String val = isRevealed
                  ? (gridValues.length > i ? gridValues[i] : '')
                  : '';

              return GestureDetector(
                onTap: () => _tapTile(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isRevealed
                        ? _getTileColor(val)
                        : const Color(0xFF3A506B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isRevealed
                        ? []
                        : const [
                            BoxShadow(
                              color: Colors.black54,
                              offset: Offset(2, 4),
                              blurRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.white10,
                              offset: Offset(-1, -1),
                              blurRadius: 2,
                            ),
                          ],
                  ),
                  child: Center(
                    child: isRevealed
                        ? _getTileIcon(val)
                        : const Icon(
                            Icons.adjust_rounded,
                            color: Colors.white24,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildPlayerIndicator(),
      ],
    );
  }

  Color _getTileColor(String val) {
    switch (val) {
      case 'SAFE':
        return Colors.green.shade700;
      case 'MINE':
        return Colors.red.shade900;
      case 'TIME_BOMB':
        return Colors.orange.shade800;
      case 'QUESTION':
        return Colors.purple.shade700;
      case 'SHIELD':
        return Colors.blue.shade700;
      case 'BOX':
        return Colors.pink.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _getTileIcon(String val) {
    switch (val) {
      case 'SAFE':
        return const Icon(Icons.check_rounded, color: Colors.white, size: 28);
      case 'MINE':
        return const Icon(
          Icons.local_fire_department_rounded,
          color: Colors.white,
          size: 28,
        );
      case 'TIME_BOMB':
        return const Icon(Icons.timer_rounded, color: Colors.white, size: 28);
      case 'QUESTION':
        return const Icon(
          Icons.question_mark_rounded,
          color: Colors.white,
          size: 28,
        );
      case 'SHIELD':
        return const Icon(Icons.shield_rounded, color: Colors.white, size: 28);
      case 'BOX':
        return const Icon(
          Icons.card_giftcard_rounded,
          color: Colors.white,
          size: 28,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildPlayerIndicator() {
    bool isMyTurn = _gameModel?.currentTurn == _currentUserId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.green.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyTurn ? Colors.greenAccent : Colors.white24,
        ),
      ),
      child: Text(
        isMyTurn ? "دورك! استمر بجمع النقاط 🏃‍♂️" : "انتظر خطأ الخصم...",
        style: TextStyle(
          color: isMyTurn ? Colors.greenAccent : Colors.white54,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }

  Widget _buildResultUI() {
    String winner = _gameModel?.winner ?? '';
    bool iWon = winner == _currentUserId;
    bool draw = winner == 'draw';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          draw
              ? Icons.handshake_rounded
              : (iWon ? Icons.emoji_events_rounded : Icons.dangerous_rounded),
          size: 100,
          color: draw
              ? Colors.amber
              : (iWon ? Colors.greenAccent : Colors.redAccent),
        ),
        const SizedBox(height: 20),
        Text(
          draw ? "تعادل!" : (iWon ? "انتصرت!" : "انتهت اللعبة!"),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            child: Text(
              "العودة للقائمة",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
