import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:just_audio/just_audio.dart';
import '../services/shut_the_box_service.dart';

class ShutTheBoxProvider extends ChangeNotifier {
  final ShutTheBoxService _service = ShutTheBoxService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  String? _roomId;
  String? get roomId => _roomId;

  String _status = 'idle'; // idle, waiting, playing, finished
  String get status => _status;

  int _maxPlayers = 2;
  int get maxPlayers => _maxPlayers;
  
  int _betAmount = 0;
  int get betAmount => _betAmount;
  
  Map<String, dynamic> _players = {};
  Map<String, dynamic> get players => _players;

  // Game State
  Map<String, List<bool>> _tiles = {
    '0': List.generate(10, (_) => false),
    '1': List.generate(10, (_) => false),
    '2': List.generate(10, (_) => false),
    '3': List.generate(10, (_) => false),
  };
  Map<String, List<bool>> get tiles => _tiles;

  int _dice1 = 1;
  int _dice2 = 1;
  int get dice1 => _dice1;
  int get dice2 => _dice2;

  bool _diceRolled = false;
  bool get diceRolled => _diceRolled;

  int _currentPlayerIndex = 0;
  int get currentPlayerIndex => _currentPlayerIndex;

  int _winnerIndex = -1;
  int get winnerIndex => _winnerIndex;
  
  bool _prizeAwarded = false;

  bool _isDiceAnimating = false;
  bool get isDiceAnimating => _isDiceAnimating;

  int _rollCounter = 0;

  Set<int> _selectedTiles = {};
  Set<int> get selectedTiles => _selectedTiles;

  Map<int, String> _activeReactions = {};
  Map<int, String> get activeReactions => _activeReactions;

  StreamSubscription? _roomSubscription;
  Timer? _turnTimer;
  int _remainingTurnSeconds = 20;
  int get remainingTurnSeconds => _remainingTurnSeconds;

  int get localPlayerIndex {
    final uid = _auth.currentUser?.uid;
    if (uid != null && _players.containsKey(uid)) {
      return _players[uid]['index'] ?? -1;
    }
    return -1;
  }

  bool get isMyTurn {
    return status == 'playing' && localPlayerIndex == _currentPlayerIndex;
  }

  Future<void> joinGame(int betAmount, int maxPlayers, {String? name, String? photo}) async {
    try {
      _status = 'joining';
      notifyListeners();

      _roomId = await _service.joinOrCreateRoom(
        betAmount: betAmount,
        maxPlayers: maxPlayers,
        name: name,
        photo: photo,
      );

      _listenToRoom();
    } catch (e) {
      _status = 'error';
      notifyListeners();
      rethrow;
    }
  }

  void _listenToRoom() {
    if (_roomId == null) return;

    _roomSubscription?.cancel();
    _roomSubscription = _service.streamRoom(_roomId!).listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        String newStatus = data['status'] ?? 'waiting';
        bool statusChangedToPlaying = _status != 'playing' && newStatus == 'playing';
        _status = newStatus;
        
        _maxPlayers = data['maxPlayers'] ?? 2;
        _betAmount = data['betAmount'] ?? 0;
        
        if (data['players'] != null) {
          _players = Map<String, dynamic>.from(data['players']);
        }

        bool turnChanged = false;

        if (data['state'] != null) {
          final state = Map<String, dynamic>.from(data['state']);
          
          if (state['tiles'] != null) {
            final tilesData = state['tiles'];
            if (tilesData is List) {
              for (int i = 0; i < tilesData.length; i++) {
                if (tilesData[i] != null) {
                  _tiles[i.toString()] = List<bool>.from(tilesData[i]);
                }
              }
            } else if (tilesData is Map) {
              tilesData.forEach((key, value) {
                _tiles[key.toString()] = List<bool>.from(value);
              });
            }
          }

          _dice1 = state['dice1'] ?? 1;
          _dice2 = state['dice2'] ?? 1;
          _diceRolled = state['diceRolled'] ?? false;
          
          int newPlayerIndex = state['currentPlayerIndex'] ?? 0;
          if (_currentPlayerIndex != newPlayerIndex) {
            _currentPlayerIndex = newPlayerIndex;
            turnChanged = true;
          }
          
          _winnerIndex = state['winnerIndex'] ?? -1;
          
          if (_winnerIndex == localPlayerIndex && !_prizeAwarded && _roomId != null) {
            _prizeAwarded = true;
            _service.awardWinner(_roomId!, _winnerIndex);
          }
          
          int newRollCounter = state['rollCounter'] ?? 0;
          if (newRollCounter > _rollCounter) {
            _rollCounter = newRollCounter;
            if (!isMyTurn) {
              _playSound('assets/sounds/dice.mp3');
              _isDiceAnimating = true;
              Future.delayed(const Duration(seconds: 1), () {
                _isDiceAnimating = false;
                notifyListeners();
              });
            }
          } else {
            _isDiceAnimating = state['isDiceAnimating'] ?? false;
          }

          if (state['reactions'] != null) {
            final reactionsData = state['reactions'];
            
            void processReaction(int pIdx, dynamic value) {
              if (value is Map && value['id'] != null) {
                String id = value['id'];
                int ts = value['timestamp'] ?? 0;
                // Only show if newer than 5 seconds to avoid old reactions on rejoin
                if (DateTime.now().millisecondsSinceEpoch - ts < 5000) {
                  // Only update if it's a new reaction timestamp to re-trigger
                  String uniqueId = '${id}_$ts';
                  if (_activeReactions[pIdx] != uniqueId) {
                    _activeReactions[pIdx] = uniqueId;
                  }
                } else {
                  _activeReactions.remove(pIdx);
                }
              }
            }

            if (reactionsData is List) {
              for (int i = 0; i < reactionsData.length; i++) {
                if (reactionsData[i] != null) {
                  processReaction(i, reactionsData[i]);
                }
              }
            } else if (reactionsData is Map) {
              reactionsData.forEach((key, value) {
                processReaction(int.parse(key.toString()), value);
              });
            }
          }
        }

        if (statusChangedToPlaying || turnChanged) {
          _startTurnTimer();
        }

        // Count active players (not left)
        int activePlayersCount = _players.values.where((p) => p['left'] != true).length;

        // If playing and opponents left (only 1 player remaining), the remaining player wins
        if (_status == 'playing' && activePlayersCount <= 1 && _winnerIndex == -1) {
          int remainingPlayerIndex = -1;
          for (var p in _players.values) {
            if (p['left'] != true) {
              remainingPlayerIndex = p['index'] ?? -1;
              break;
            }
          }
          
          if (remainingPlayerIndex != -1) {
            _winnerIndex = remainingPlayerIndex;
            _status = 'finished';
            
            // Only the actual winner (remaining player) should update the server and award the prize
            if (remainingPlayerIndex == localPlayerIndex) {
              _service.updateGameState(_roomId!, {
                'status': 'finished',
                'state/winnerIndex': remainingPlayerIndex,
              });
              
              if (!_prizeAwarded && _roomId != null) {
                _prizeAwarded = true;
                _service.awardWinner(_roomId!, _winnerIndex);
              }
            }
          }
        }

        notifyListeners();
      } else {
        // Room deleted or left
        _status = 'closed';
        notifyListeners();
      }
    });
  }

  Future<void> sendReaction(String stickerId) async {
    if (_roomId == null) return;
    await _service.updateGameState(_roomId!, {
      'state/reactions/$localPlayerIndex': {
        'id': stickerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    });
  }

  void clearReaction(int playerIndex) {
    _activeReactions.remove(playerIndex);
    notifyListeners();
  }

  Future<void> rollDice() async {
    if (!isMyTurn || _diceRolled || _status != 'playing' || _isDiceAnimating) return;

    _playSound('assets/sounds/dice.mp3');
    _isDiceAnimating = true;
    _diceRolled = true;
    _rollCounter++;
    _dice1 = Random().nextInt(6) + 1;
    _dice2 = Random().nextInt(6) + 1;
    _selectedTiles.clear();
    
    // Broadcast immediately so opponents see the animation
    await _service.updateGameState(_roomId!, {
      'state/dice1': _dice1,
      'state/dice2': _dice2,
      'state/diceRolled': true,
      'state/isDiceAnimating': true,
      'state/rollCounter': _rollCounter,
    });
    
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));
    _isDiceAnimating = false;
    
    await _service.updateGameState(_roomId!, {
      'state/isDiceAnimating': false,
    });

    int target = _dice1 + _dice2;

    if (!_hasValidMove(target)) {
      // Wait 2 seconds so opponents can see the dice
      await Future.delayed(const Duration(seconds: 2));

      // Pass turn
      _diceRolled = false;
      int nextPlayer;
      if (_maxPlayers == 2) {
        nextPlayer = _currentPlayerIndex == 0 ? 2 : 0;
      } else {
        nextPlayer = (_currentPlayerIndex + 1) % 4;
      }

      await _service.updateGameState(_roomId!, {
        'state/diceRolled': false,
        'state/currentPlayerIndex': nextPlayer,
      });
    }
  }

  bool _hasValidMove(int target) {
    List<int> openTiles = [];
    String pKey = localPlayerIndex.toString();
    for (int i = 0; i < 10; i++) {
      if (!_tiles[pKey]![i]) {
        openTiles.add(i + 1);
      }
    }
    return _isSubsetSum(openTiles, openTiles.length, target);
  }

  bool _isSubsetSum(List<int> set, int n, int sum) {
    if (sum == 0) return true;
    if (n == 0 && sum != 0) return false;
    if (set[n - 1] > sum) return _isSubsetSum(set, n - 1, sum);
    return _isSubsetSum(set, n - 1, sum) || _isSubsetSum(set, n - 1, sum - set[n - 1]);
  }

  void toggleTile(int tileIndex) {
    if (!isMyTurn || !_diceRolled || _isDiceAnimating) return;
    
    String pKey = localPlayerIndex.toString();
    if (_tiles[pKey]![tileIndex]) return;

    if (_selectedTiles.contains(tileIndex)) {
      _selectedTiles.remove(tileIndex);
    } else {
      _selectedTiles.add(tileIndex);
    }
    notifyListeners();
  }

  Future<void> confirmSelection(void Function(String) showErrorMsg) async {
    if (!isMyTurn || !_diceRolled) return;

    int selectedSum = 0;
    for (int index in _selectedTiles) {
      selectedSum += (index + 1);
    }

    int target = _dice1 + _dice2;

    if (selectedSum == target) {
      _playSound('assets/sounds/dominorme.mp3');
      String pKey = localPlayerIndex.toString();
      
      // Update local state first
      for (int index in _selectedTiles) {
        _tiles[pKey]![index] = true;
      }
      
      bool allShut = !_tiles[pKey]!.contains(false);
      
      int nextPlayer = _currentPlayerIndex;
      if (!allShut) {
        if (_maxPlayers == 2) {
          nextPlayer = _currentPlayerIndex == 0 ? 2 : 0;
        } else {
          nextPlayer = (_currentPlayerIndex + 1) % 4;
        }
      }

      await _service.updateGameState(_roomId!, {
        'state/tiles/$pKey': _tiles[pKey],
        'state/diceRolled': false,
        'state/currentPlayerIndex': nextPlayer,
        if (allShut) 'state/winnerIndex': localPlayerIndex,
        if (allShut) 'status': 'finished',
      });
      
      _selectedTiles.clear();
      _diceRolled = false;

    } else {
      showErrorMsg('مجموع الأرقام المحددة لا يساوي مجموع النرد!');
    }
  }

  Future<void> leaveGame() async {
    if (_roomId != null) {
      await _service.leaveRoom(_roomId!);
      _roomSubscription?.cancel();
    }
    _status = 'idle';
    _roomId = null;
    notifyListeners();
  }

  Future<void> passTurn() async {
    if (!isMyTurn) return;

    int nextPlayer;
    if (_maxPlayers == 2) {
      nextPlayer = _currentPlayerIndex == 0 ? 2 : 0;
    } else {
      nextPlayer = (_currentPlayerIndex + 1) % 4;
    }

    _selectedTiles.clear();

    await _service.updateGameState(_roomId!, {
      'state/diceRolled': false,
      'state/currentPlayerIndex': nextPlayer,
    });
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    _remainingTurnSeconds = 20;
    
    if (_status != 'playing') return;

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTurnSeconds > 0) {
        _remainingTurnSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        if (isMyTurn) {
          passTurn();
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _turnTimer?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }
}
