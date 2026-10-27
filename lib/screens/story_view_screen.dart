import 'package:flutter/material.dart';
import 'dart:async';
import '../models/index.dart'; // Add model index for User
import '../models/task_model.dart';
import '../services/story_service.dart';
import '../services/user_service.dart'; // Add UserService
import '../services/task_service.dart';
import '../widgets/framed_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewScreen extends StatefulWidget {
  final List<Story> stories;
  final String username;
  final String? userProfileImage;
  final String currentUserId;
  final int initialIndex;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.username,
    required this.currentUserId,
    this.userProfileImage,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  int _currentIndex = 0;
  double _progress = 0.0;
  Timer? _timer;
  final int _storyDurationSeconds = 5;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _startTimer();
    _markAsViewed();
  }

  void _markAsViewed() {
    if (widget.stories.isNotEmpty) {
      final story = widget.stories[_currentIndex];
      if (story.userId != widget.currentUserId &&
          !story.viewedBy.contains(widget.currentUserId)) {
        StoryService().viewStory(
          storyId: story.id,
          userId: widget.currentUserId,
        );
        // مهمة: مشاهدة قصة
        TaskService().incrementTaskProgress(
          widget.currentUserId,
          TaskType.watchStory,
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _progress = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.05 / _storyDurationSeconds;
          if (_progress >= 1.0) {
            _nextStory();
          }
        });
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _startTimer();
        _markAsViewed();
      });
    } else {
      if (!_isPopping) {
        _isPopping = true;
        _timer?.cancel();
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _startTimer();
        _markAsViewed();
      });
    } else {
      // Re-start current story if at first index
      _startTimer();
    }
  }

  void _deleteStory() {
    final story = widget.stories[_currentIndex];
    _timer?.cancel();
    final navigator = Navigator.of(
      context,
    ); // Capture navigator before async gap

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القصة'),
        content: const Text('هل أنت متأكد من حذف هذه القصة؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await StoryService().deleteStory(story.id);

              if (mounted) {
                if (widget.stories.length > 1) {
                  setState(() {
                    widget.stories.removeAt(_currentIndex);
                    if (_currentIndex >= widget.stories.length) {
                      _currentIndex = widget.stories.length - 1;
                    }
                    _startTimer();
                  });
                } else {
                  if (!_isPopping) {
                    _isPopping = true;
                    navigator.pop(); // Safe pop using captured navigator
                  }
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showViewers() {
    _timer?.cancel();
    final story = widget.stories[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المشاهدات (${story.viewedBy.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            if (story.viewedBy.isEmpty)
              const Center(
                child: Text(
                  'لا توجد مشاهدات بعد',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: story.viewedBy.length,
                  itemBuilder: (context, index) {
                    final viewerId = story.viewedBy[index];
                    return FutureBuilder<User?>(
                      future: UserService().getUser(viewerId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade800,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                            title: Container(
                              width: 80,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        }
                        final user = snapshot.data;
                        return ListTile(
                          leading: FramedAvatar(
                            userId: viewerId,
                            imageUrl: user?.profileImage,
                            radius: 20,
                            useProfileFrameFallback: false,
                          ),
                          title: Text(
                            user?.nickname ?? user?.username ?? 'مستخدم',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ).then((_) => _startTimer());
  }

  void _react(String emoji) async {
    final story = widget.stories[_currentIndex];
    await StoryService().reactToStory(
      storyId: story.id,
      userId: widget.currentUserId,
      emoji: emoji,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم التفاعل بـ $emoji'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Safety check for index
    final index = _currentIndex.clamp(0, widget.stories.length - 1);
    final currentStory = widget.stories[index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - Image or Video placeholder
          GestureDetector(
            onTapDown: (details) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 3) {
                _previousStory();
              } else if (details.globalPosition.dx > 2 * width / 3) {
                _nextStory();
              }
            },
            onLongPressStart: (_) => _timer?.cancel(),
            onLongPressEnd: (_) => _startTimer(),
            child: Center(
              child: currentStory.storyImage != null
                  ? Image.network(
                      currentStory.storyImage!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
            ),
          ),

          // Top Info & Progress Bars
          SafeArea(
            child: Column(
              children: [
                // Progress Bars
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: List.generate(
                      widget.stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: index == _currentIndex
                                ? _progress
                                : (index < _currentIndex ? 1.0 : 0.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // User Info Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      FramedAvatar(
                        radius: 18,
                        imageUrl: widget.userProfileImage,
                        userId: currentStory.userId,
                        useProfileFrameFallback: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              timeago.format(
                                currentStory.createdAt,
                                locale: 'ar',
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (currentStory.userId == widget.currentUserId)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          onPressed: _deleteStory,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar (Viewers or Reactions)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SafeArea(
              child: currentStory.userId == widget.currentUserId
                  ? Center(
                      child: GestureDetector(
                        onTap: _showViewers,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                            ),
                            Text(
                              '${currentStory.viewedBy.length} مشاهدة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                          return GestureDetector(
                            onTap: () => _react(emoji),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
