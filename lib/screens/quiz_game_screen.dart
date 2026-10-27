import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/game_service.dart';
import '../models/game_model.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/voice_room_service.dart';

class QuizGameScreen extends StatefulWidget {
  const QuizGameScreen({super.key});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  final GameService _gameService = GameService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _gameId;
  String? _currentUserId;
  String _status = 'جاري الاتصال...';

  StreamSubscription<GameModel?>? _gameSubscription;
  GameModel? _gameModel;

  // Local State
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;
  int _myScore = 0;
  int _opponentScore = 0;

  // Hardcoded Questions (MVP)
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'ما هي عاصمة السعودية؟',
      'options': ['جدة', 'الرياض', 'مكة', 'الدمام'],
      'answer': 1,
    },
    {
      'question': 'كم عدد قارات العالم؟',
      'options': ['5', '6', '7', '8'],
      'answer': 2,
    },
    {
      'question': 'من هو مخترع المصباح الكهربائي؟',
      'options': ['تيسلا', 'أينشتاين', 'إديسون', 'نيوتن'],
      'answer': 2,
    },
    {
      'question': 'ما هو أسرع حيوان بري؟',
      'options': ['الأسد', 'الفهد', 'النمر', 'الغزال'],
      'answer': 1,
    },
    {
      'question': 'في أي عام تأسست شركة جوجل؟',
      'options': ['1995', '1998', '2000', '2004'],
      'answer': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeGame();

    // تلقائياً الخروج من الغرفة الصوتية عند الدخول للعبة
    Future.microtask(() {
      if (mounted) {
        final voiceRoomService = Provider.of<VoiceRoomService>(
          context,
          listen: false,
        );
        if (voiceRoomService.isJoined) {
          voiceRoomService.leaveRoom();
          debugPrint('Auto-exited voice room because Quiz started');
        }
      }
    });
  }

  Future<void> _initializeGame() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _status = 'يجب تسجيل الدخول');
      return;
    }
    _currentUserId = user.uid;

    String gameId = await _gameService.findOrCreateGame(
      type: 'quiz',
      userId: user.uid,
      userName: user.displayName ?? 'Player',
    );

    setState(() {
      _gameId = gameId;
    });

    _gameSubscription = _gameService.streamGame(gameId).listen(_onGameUpdate);
  }

  void _onGameUpdate(GameModel? game) {
    if (game == null) return;
    if (!mounted) return;

    setState(() {
      _gameModel = game;

      if (game.status == 'waiting') {
        _status = 'بانتظار لاعب آخر...';
      } else if (game.status == 'active') {
        _status = 'المباراة جارية';
        int serverIndex = game.data['currentQuestionIndex'] ?? 0;
        if (serverIndex != _currentQuestionIndex) {
          _currentQuestionIndex = serverIndex;
          _hasAnswered = false;
          _selectedAnswerIndex = null;
        }

        // Sync Scores
        Map<String, dynamic> scores = game.scores;
        _myScore = scores[_currentUserId] ?? 0;

        String? oppId = game.players.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );
        if (oppId.isNotEmpty) {
          _opponentScore = scores[oppId] ?? 0;
        }

        // Check if we moved to next question, reset local selection
        // We know we moved if new index > old known index,
        // BUT for MVP let's just use _hasAnswered logic based on current question index
        // If the server index is ahead of our last answered index?
        // Simpler: Just check if *I* accepted the answer for *this* question.

        // Actually, we need to know if we already answered THIS specific question index
        // We can track locally `_lastAnsweredQuestionIndex`.
      } else if (game.status == 'finished') {
        String result = '';
        if (game.winner == _currentUserId) {
          result = 'مبروك! فزت 🎉';
        } else if (game.winner == 'draw') {
          result = 'تعادل!';
        } else {
          result = 'للأسف خسرت 😢';
        }
        _status = 'انتهت اللعبة\n$result';
      }
    });

    // Reset local answer state if question changed
    if (_gameModel != null &&
        _gameModel!.data['currentQuestionIndex'] != null) {
      // Logic handled in build via state check or here
    }
  }

  void _submitAnswer(int answerIdx) async {
    if (_hasAnswered || _gameModel?.status != 'active') return;

    setState(() {
      _selectedAnswerIndex = answerIdx;
      _hasAnswered = true;
    });

    bool isCorrect = answerIdx == _questions[_currentQuestionIndex]['answer'];

    if (isCorrect) {
      // Optimistic update
      _myScore += 10;
    }

    // Update Server
    // We need to:
    // 1. Update my score (if correct)
    // 2. Mark that I answered this question
    // 3. If BOTH answered, increment currentQuestionIndex

    // This requires atomic updates or a smart transaction.
    // For MVP/No-Code-Server:
    // We will just update our score.
    // AND we check if the opponent has answered THIS question index.
    // Ideally we store answers in `data.answers`.

    // Read fresh first? We rely on stream.
    Map<String, dynamic> answersMap = Map.from(
      _gameModel!.data['answers'] ?? {},
    );
    Map<String, dynamic> myAnswers = Map.from(answersMap[_currentUserId] ?? {});
    myAnswers['$_currentQuestionIndex'] = answerIdx;
    answersMap[_currentUserId!] = myAnswers;

    Map<String, dynamic> updates = {'data.answers': answersMap};

    if (isCorrect) {
      updates['scores.$_currentUserId'] = FieldValue.increment(10);
    }

    await _gameService.makeMove(_gameId!, updates);

    // Check if we should advance to next question
    // Valid if opponent also has an answer for this index
    String? oppId = _gameModel!.players.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    if (oppId.isNotEmpty) {
      Map<String, dynamic> oppAnswers = Map.from(answersMap[oppId] ?? {});
      if (oppAnswers.containsKey('$_currentQuestionIndex')) {
        // Both answered!
        // Advance Question
        // Wait a simplified delay then advance
        await Future.delayed(const Duration(seconds: 1));

        int nextIdx = _currentQuestionIndex + 1;
        if (nextIdx >= _questions.length) {
          // Game Over
          // Calculate Winner (Local check might be racey but okay for MVP)

          // Quick fix: assume scores in _gameModel are effectively current
          // (minus our just submitted one if not synced yet)

          await _gameService.makeMove(_gameId!, {
            'status': 'finished',
            'winner': _determineWinner(),
          });
        } else {
          await _gameService.makeMove(_gameId!, {
            'data.currentQuestionIndex': nextIdx,
          });
        }
      }
    }

    // Reset local state if we advanced?
    // The stream listener should handle the UI reset when it sees the new index.
  }

  String _determineWinner() {
    // This logic runs before score update is fully confirmed in stream,
    // so use local _myScore vs _opponentScore
    if (_myScore > _opponentScore) return _currentUserId!;
    if (_opponentScore > _myScore) {
      String? oppId = _gameModel!.players.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      return oppId;
    }
    return 'draw';
  }

  @override
  void didUpdateWidget(QuizGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safety
    if (_currentQuestionIndex >= _questions.length) {
      // Already handled by finished status usually, but prevent index error
      if (_status != 'انتهت اللعبة') _status = 'جاري إنهاء اللعبة...';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        title: const Text(
          'مسابقة ثقافية',
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score Board
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildScoreCard('أنت', _myScore, Colors.green),
                  const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  _buildScoreCard('الخصم', _opponentScore, Colors.orange),
                ],
              ),
            ),

            const Divider(color: Colors.white24),

            Expanded(
              child: (_gameModel?.status != 'active')
                  ? Center(
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    )
                  : (_currentQuestionIndex < _questions.length)
                  ? _buildQuestionUI()
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 25,
          child: Text(
            score.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
        ),
      ],
    );
  }

  Widget _buildQuestionUI() {
    final qData = _questions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'السؤال ${_currentQuestionIndex + 1} / ${_questions.length}',
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            qData['question'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 40),
          ...List.generate(4, (index) {
            String option = qData['options'][index];
            bool isSelected = _selectedAnswerIndex == index;
            bool isCorrect = (index == qData['answer']);

            // Only show correct/wrong AFTER answering
            Color btnColor = Colors.white;
            if (_hasAnswered) {
              if (isSelected) {
                btnColor = isCorrect ? Colors.green : Colors.red;
              } else if (isCorrect) {
                // Show correct answer anyway?
                btnColor = Colors.green.withValues(alpha: 0.7);
              } else {
                btnColor = Colors.grey;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _hasAnswered ? null : () => _submitAnswer(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: (_hasAnswered && (isSelected || isCorrect))
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 18,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          if (_hasAnswered)
            const Text(
              'بانتظار الخصم...',
              style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
            ),
        ],
      ),
    );
  }
}
