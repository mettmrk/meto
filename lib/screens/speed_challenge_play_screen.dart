import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/competition_model.dart';

class SpeedChallengePlayScreen extends StatefulWidget {
  final Competition competition;
  final String userId;

  const SpeedChallengePlayScreen({
    Key? key,
    required this.competition,
    required this.userId,
  }) : super(key: key);

  @override
  State<SpeedChallengePlayScreen> createState() => _SpeedChallengePlayScreenState();
}

class _SpeedChallengePlayScreenState extends State<SpeedChallengePlayScreen> {
  int _currentQuestionIndex = 0;
  int _secondsLeft = 10;
  Timer? _timer;
  bool _isGameOver = false;
  bool _isFinished = false;
  int? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 10;
      _selectedAnswer = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _onTimeOut();
      }
    });
  }

  void _onTimeOut() {
    _timer?.cancel();
    setState(() => _isGameOver = true);
  }

  void _submitAnswer(int index) {
    if (_isGameOver || _isFinished || _selectedAnswer != null) return;

    _timer?.cancel();
    setState(() => _selectedAnswer = index);

    final correctIndex = widget.competition.questions[_currentQuestionIndex]['answer'];
    
    if (index == correctIndex) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentQuestionIndex + 1 < widget.competition.questions.length) {
          setState(() {
            _currentQuestionIndex++;
          });
          _startTimer();
        } else {
          _onChallengeFinished();
        }
      });
    } else {
      setState(() => _isGameOver = true);
    }
  }

  Future<void> _onChallengeFinished() async {
    setState(() => _isFinished = true);
    try {
      await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competition.id)
          .update({
        'participants': FieldValue.arrayUnion([widget.userId]),
      });
    } catch (e) {
      debugPrint('Error updating participants: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _buildFinishedUI();
    if (_isGameOver) return _buildGameOverUI();

    if (widget.competition.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text('لا توجد أسئلة مضافة لهذا التحدي!', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('العودة', style: GoogleFonts.tajawal()),
              ),
            ],
          ),
        ),
      );
    }

    final question = widget.competition.questions[_currentQuestionIndex];
    final round = (_currentQuestionIndex ~/ 7) + 1;
    final qInRound = (_currentQuestionIndex % 7) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Text(
                      'الجولة $round - السؤال $qInRound',
                      style: GoogleFonts.tajawal(color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _secondsLeft / 10,
                      backgroundColor: Colors.white10,
                      color: _secondsLeft <= 3 ? Colors.red : Colors.greenAccent,
                      strokeWidth: 8,
                    ),
                  ),
                  Text(
                    '$_secondsLeft',
                    style: GoogleFonts.tajawal(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Text(
                question['question'],
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              ...List.generate(3, (index) {
                final option = question['options'][index];
                final isCorrect = index == question['answer'];
                final isSelected = _selectedAnswer == index;

                Color btnColor = Colors.white.withOpacity(0.05);
                if (isSelected) {
                  btnColor = isCorrect ? Colors.green : Colors.red;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _submitAnswer(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.tajawal(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            Text('انتهى التحدي!', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('للأسف لم تنجح في الوصول للنهاية', style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: Text('العودة للمسابقات', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 80),
            const SizedBox(height: 24),
            Text('مبروك!', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('لقد أكملت جميع الجولات بنجاح\nدخلت الآن في سحب الفائزين!', textAlign: TextAlign.center, style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: Text('العودة للمسابقات', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
