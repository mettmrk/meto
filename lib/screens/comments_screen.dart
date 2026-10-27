import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/index.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'profile_screen.dart';
import '../widgets/framed_avatar.dart';

class CommentsScreen extends StatefulWidget {
  final Post post;

  const CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final PostService _postService = PostService();
  final UserService _userService = UserService();

  final String currentUserId = auth.FirebaseAuth.instance.currentUser!.uid;
  User? _currentUserData;

  Comment? replyingTo;
  Comment? editingComment; // التعليق الجاري تعديله

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _userService.getUser(currentUserId);
      if (mounted) {
        setState(() {
          _currentUserData = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _onEditComment(Comment comment) {
    setState(() {
      editingComment = comment;
      _commentController.text = comment.content;
      replyingTo = null;
    });
  }

  void _onDeleteComment(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف التعليق'),
        content: const Text('هل أنت متأكد من حذف هذا التعليق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _postService.deleteComment(comment.id, widget.post.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف التعليق')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('التعليقات'),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _postService.getCommentsStream(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }
                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد تعليقات بعد\nكن أول من يعلق!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final parentComments = comments
                    .where((c) => c.parentId == null)
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
                  itemCount: parentComments.length,
                  itemBuilder: (context, index) {
                    final comment = parentComments[index];
                    final replies = comments
                        .where((c) => c.parentId == comment.id)
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CommentItem(
                          comment: comment,
                          onReply: () {
                            setState(() {
                              replyingTo = comment;
                              editingComment = null;
                              _commentController.clear();
                            });
                          },
                          onEdit: () => _onEditComment(comment),
                          onDelete: () => _onDeleteComment(comment),
                          postService: _postService,
                          currentUserId: currentUserId,
                        ),
                        if (replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 16,
                            ), // Less indent for cleaner look
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: replies.map((reply) {
                                  return _CommentItem(
                                    comment: reply,
                                    isReply: true,
                                    onReply: () {
                                      setState(() {
                                        replyingTo = reply;
                                        editingComment = null;
                                        _commentController.clear();
                                      });
                                    },
                                    onEdit: () => _onEditComment(reply),
                                    onDelete: () => _onDeleteComment(reply),
                                    postService: _postService,
                                    currentUserId: currentUserId,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.only(bottom: 16, top: 16, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null || editingComment != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      editingComment != null
                          ? Icons.edit_rounded
                          : Icons.reply_rounded,
                      size: 16,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editingComment != null
                              ? 'تعديل تعليقك'
                              : 'الرد على ${replyingTo!.username}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        if (replyingTo != null)
                          Text(
                            replyingTo!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        replyingTo = null;
                        editingComment = null;
                        _commentController.clear();
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              FramedAvatar(
                imageUrl: _currentUserData?.profileImage,
                radius: 20,
                userId: currentUserId,
                borderColor: Colors.teal.shade100,
                borderWidth: 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقاً...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: Colors.teal,
                        onPressed: _submitComment,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    if (_currentUserData == null) {
      await _loadUserData();
    }

    final content = _commentController.text.trim();

    if (editingComment != null) {
      try {
        await _postService.updateComment(editingComment!.id, content);
        setState(() {
          editingComment = null;
          _commentController.clear();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ في التحديث: $e')));
        }
      }
      return;
    }

    final parentId = replyingTo?.parentId ?? replyingTo?.id;
    final parentCommentOwnerId = replyingTo?.userId;
    final replyToName = replyingTo?.username;
    final displayName =
        _currentUserData?.nickname ?? _currentUserData?.username ?? 'مستخدم';
    final displayPhoto = _currentUserData?.profileImage;

    _commentController.clear();
    setState(() {
      replyingTo = null;
    });

    try {
      await _postService.addComment(
        postId: widget.post.id,
        postOwnerId: widget.post.userId,
        userId: currentUserId,
        username: displayName,
        userProfileImage: displayPhoto,
        content: content,
        parentId: parentId,
        parentCommentOwnerId: parentCommentOwnerId,
        replyTo: replyToName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل إرسال التعليق: $e')));
      }
    }
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final PostService postService;
  final String currentUserId;

  const _CommentItem({
    required this.comment,
    this.isReply = false,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.postService,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = comment.likedBy.contains(currentUserId);
    final isOwner = comment.userId == currentUserId;

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 12 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(uid: comment.userId),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReply ? Colors.grey.shade300 : Colors.teal.shade200,
                  width: 1.5,
                ),
              ),
              child: FramedAvatar(
                imageUrl: comment.userProfileImage,
                radius: isReply ? 14 : 18,
                userId: comment.userId,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: Radius.circular(isReply ? 16 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            comment.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            timeago.format(comment.createdAt, locale: 'ar'),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      if (comment.replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: Text(
                            '@${comment.replyTo}',
                            style: TextStyle(
                              color: Colors.teal.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => postService.toggleCommentLike(
                          comment.id,
                          currentUserId,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: isLiked ? Colors.red : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              comment.likesCount > 0
                                  ? '${comment.likesCount}'
                                  : 'إعجاب',
                              style: TextStyle(
                                color: isLiked ? Colors.red : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: onReply,
                        child: Text(
                          'رد',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: onEdit,
                          child: Text(
                            'تعديل',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: onDelete,
                          child: Text(
                            'حذف',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
