import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';
import '../models/index.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/message_options_sheet.dart';
import '../services/presence_service.dart';
import 'profile_screen.dart';
import '../widgets/framed_avatar.dart';
import 'image_preview_screen.dart';
import 'voice_room_screen.dart';
import '../widgets/telegram_delete_animation.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverImage;
  final bool isSupport;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverImage,
    this.isSupport = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final String _currentUid = auth.FirebaseAuth.instance.currentUser!.uid;
  late String _chatId;

  late Stream<User?> _currentUserStream;
  late Stream<User?> _receiverUserStream;
  late Stream<Chat?> _chatMetadataStream;
  late Stream<List<Message>> _messagesStream;
  StreamSubscription<List<Message>>? _messagesSubscription;

  Timer? _typingTimer;
  bool _isTyping = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordDuration = 0;

  final Map<String, String> _deletingMessageTypes = {};

  @override
  void initState() {
    super.initState();
    _chatId = _chatService.getChatId(_currentUid, widget.receiverId);
    _currentUserStream = _userService.getUserStream(_currentUid);
    _receiverUserStream = _userService.getUserStream(widget.receiverId);
    _messagesStream = _chatService.getMessagesStream(_chatId);
    _chatMetadataStream = _chatService.getChatStream(_chatId);

    _chatService.markAsRead(_chatId, _currentUid);
    PresenceService().setActiveChatId(widget.receiverId);

    _messagesSubscription = _messagesStream.listen((messages) {
      if (messages.isNotEmpty) {
        final lastMessage = messages.first;
        if (lastMessage.senderId != _currentUid && !lastMessage.isRead) {
          _chatService.markAsRead(_chatId, _currentUid);
        }
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatService.setTypingStatus(_chatId, _currentUid, false);
    _chatService.setRecordingStatus(_chatId, _currentUid, false);
    _messageController.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    PresenceService().setActiveChatId(null);
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _onTypingChanged() {
    if (!_isTyping) {
      _isTyping = true;
      _chatService.setTypingStatus(_chatId, _currentUid, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _chatService.setTypingStatus(_chatId, _currentUid, false);
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _typingTimer?.cancel();
    _chatService.setTypingStatus(_chatId, _currentUid, false);
    try {
      await _chatService.sendMessage(
        senderId: _currentUid,
        receiverId: widget.receiverId,
        text: text,
      );
      TaskService().incrementTaskProgress(_currentUid, TaskType.sendMessage);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
    }
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'مسح المحادثة',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هل أنت متأكد من حذف جميع الرسائل؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.clearChatMessages(_chatId);
            },
            child: const Text('مسح الكل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message message) {
    final isMe = message.senderId == _currentUid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageOptionsSheet(
        message: message,
        isMe: isMe,
        onDeleteForMe: () => _deleteForMe(message),
        onDeleteForEveryone: isMe ? () => _deleteForEveryone(message) : null,
        onEdit: (isMe && message.type == 'text')
            ? () => _editMessage(message)
            : null,
      ),
    );
  }

  Future<void> _deleteForMe(Message message) async {
    if (mounted) setState(() => _deletingMessageTypes[message.id] = 'me');
  }

  Future<void> _performDeleteForMe(Message message) async {
    try {
      await _chatService.deleteMessageForMe(
        chatId: _chatId,
        messageId: message.id,
        userId: _currentUid,
      );
    } finally {
      if (mounted) setState(() => _deletingMessageTypes.remove(message.id));
    }
  }

  Future<void> _deleteForEveryone(Message message) async {
    if (mounted) setState(() => _deletingMessageTypes[message.id] = 'everyone');
  }

  Future<void> _performDeleteForEveryone(Message message) async {
    try {
      await _chatService.deleteMessageForEveryone(
        chatId: _chatId,
        messageId: message.id,
      );
    } finally {
      if (mounted) setState(() => _deletingMessageTypes.remove(message.id));
    }
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'تعديل الرسالة',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white10,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _chatService.editMessage(
                  chatId: _chatId,
                  messageId: message.id,
                  newText: controller.text.trim(),
                );
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => setState(() => _recordDuration++),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    String period = hour >= 12 ? 'م' : 'ص';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leadingWidth: 40,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: widget.isSupport
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => ProfileScreen(uid: widget.receiverId),
                  ),
                ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(child: _buildHeaderInfo()),
            ],
          ),
        ),
        actions: [_buildAppBarActions()],
      ),
      body: StreamBuilder<User?>(
        stream: _currentUserStream,
        builder: (context, userSnapshot) {
          final currentUserData = userSnapshot.data;
          return StreamBuilder<User?>(
            stream: _receiverUserStream,
            builder: (context, receiverSnapshot) {
              final receiverUser = receiverSnapshot.data;
              final bool isBlocked =
                  currentUserData?.blockedUsers.contains(widget.receiverId) ??
                  false;

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  image: DecorationImage(
                    image: AssetImage('assets/chat_bg.png'),
                    fit: BoxFit.cover,
                    opacity: 0.05,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _buildMessageList(currentUserData, receiverUser),
                    ),
                    if (isBlocked)
                      _buildBlockedIndicator()
                    else
                      _ChatInputField(
                        controller: _messageController,
                        isRecording: _isRecording,
                        recordDuration: _recordDuration,
                        onStartRecording: _startRecording,
                        onStopRecording: _stopRecording,
                        onCancelRecording: _cancelRecording,
                        onSendMessage: _sendMessage,
                        onTypingChanged: _onTypingChanged,
                        onAttach: _showAttachmentSheet,
                        formatDuration: _formatDuration,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.isSupport) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade900,
        child: const Icon(Icons.support_agent_rounded, color: Colors.teal),
      );
    }
    return Stack(
      children: [
        FramedAvatar(
          userId: widget.receiverId,
          radius: 20,
          imageUrl: widget.receiverImage,
          disableFrame: true,
        ),
        StreamBuilder<User?>(
          stream: _receiverUserStream,
          builder: (context, snapshot) {
            if (snapshot.data?.isOnline ?? false) {
              return Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isSupport ? 'الدعم الفني' : widget.receiverName,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (!widget.isSupport)
          StreamBuilder<User?>(
            stream: _receiverUserStream,
            builder: (context, snapshot) => Text(
              snapshot.data?.formatStatus ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _buildAppBarActions() {
    return StreamBuilder<User?>(
      stream: _currentUserStream,
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        final bool isBlocked =
            currentUser?.blockedUsers.contains(widget.receiverId) ?? false;
        final bool isMuted =
            currentUser?.mutedUsers.contains(widget.receiverId) ?? false;

        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFF1A1A1A),
          onSelected: (val) async {
            if (val == 'block') {
              if (isBlocked)
                await _userService.unblockUser(
                  currentUserId: _currentUid,
                  userToUnblockId: widget.receiverId,
                );
              else
                await _userService.blockUser(
                  currentUserId: _currentUid,
                  userToBlockId: widget.receiverId,
                );
            } else if (val == 'mute') {
              if (isMuted)
                await _userService.unmuteUser(
                  currentUserId: _currentUid,
                  userToUnmuteId: widget.receiverId,
                );
              else
                await _userService.muteUser(
                  currentUserId: _currentUid,
                  userToMuteId: widget.receiverId,
                );
            } else if (val == 'clear')
              _confirmClearChat();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'block',
              child: Text(
                isBlocked ? 'إلغاء الحظر' : 'حظر',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            PopupMenuItem(
              value: 'mute',
              child: Text(
                isMuted ? 'تفعيل التنبيهات' : 'كتم التنبيهات',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Text('مسح المحادثة', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageList(User? currentUser, User? receiverUser) {
    return StreamBuilder<Chat?>(
      stream: _chatMetadataStream,
      builder: (chatCtx, chatSnapshot) {
        final isOtherTyping =
            chatSnapshot.data?.typingStatus[widget.receiverId] ?? false;
        final isOtherRecording =
            chatSnapshot.data?.recordingStatus[widget.receiverId] ?? false;
        final showIndicator = isOtherTyping || isOtherRecording;

        return StreamBuilder<List<Message>>(
          stream: _messagesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final messages = snapshot.data!
                .where(
                  (m) =>
                      !m.isDeletedForEveryone &&
                      !m.isDeletedForMe.contains(_currentUid),
                )
                .toList();

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length + (showIndicator ? 1 : 0),
              itemBuilder: (context, index) {
                if (showIndicator && index == 0) {
                  return _buildStatusIndicator(isOtherRecording, isOtherTyping);
                }

                final messageIndex = showIndicator ? index - 1 : index;
                final m = messages[messageIndex];
                final isMe = m.senderId == _currentUid;

                return TelegramDeleteWrapper(
                  key: ValueKey(m.id),
                  isDeleting: _deletingMessageTypes.containsKey(m.id),
                  onAnimationComplete: () =>
                      _deletingMessageTypes[m.id] == 'everyone'
                      ? _performDeleteForEveryone(m)
                      : _performDeleteForMe(m),
                  child: Align(
                    alignment: isMe
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: GestureDetector(
                      onLongPress: () => _showMessageOptions(m),
                      child: _buildBubble(m, isMe, currentUser),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatusIndicator(bool isRecording, bool isTyping) {
    if (isRecording) {
      return const Align(
        key: ValueKey('recording_indicator'),
        alignment: Alignment.centerLeft,
        child: BlinkingMicIndicator(),
      );
    }
    return _buildTypingIndicator();
  }

  Widget _buildTypingIndicator() {
    return Align(
      key: const ValueKey('typing_indicator'),
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'يكتب الآن...',
          style: TextStyle(color: Colors.tealAccent, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildBubble(Message m, bool isMe, User? currentUser) {
    if (m.type == 'room_invite') return _buildRoomInviteMessage(m, isMe);
    if (m.type == 'image')
      return _buildImageMessage(
        m,
        m.mediaUrl!,
        m.timestamp,
        isMe,
        isRead: m.isRead,
        isDelivered: m.isDelivered,
        status: m.status,
      );
    if (m.type == 'location')
      return _buildLocationMessage(m.mediaUrl!, m.timestamp, isMe);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.only(bottom: 8),
      padding: m.type == 'audio'
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: m.type == 'audio'
            ? Colors.grey.withOpacity(0.12)
            : (isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 4 : 16),
          bottomRight: Radius.circular(isMe ? 16 : 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: m.type == 'audio'
          ? VoiceMessageBubble(
              audioUrl: m.mediaUrl!,
              isMe: isMe,
              duration: m.duration,
              timestamp: m.timestamp,
              status: m.status,
              isRead: m.isRead,
              isDelivered: m.isDelivered,
              profileImage: isMe
                  ? currentUser?.profileImage
                  : widget.receiverImage,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  m.text,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (m.isEdited)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          "تم التعديل",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    Text(
                      _formatTime(m.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        m.isRead ? Icons.done_all : Icons.check,
                        size: 14,
                        color: m.isRead ? Colors.blue : Colors.white60,
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildImageMessage(
    Message m,
    String imageUrl,
    DateTime timestamp,
    bool isMe, {
    bool isRead = false,
    bool isDelivered = false,
    String status = 'sent',
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => ImagePreviewScreen(
                  imageUrl: imageUrl,
                  message: m,
                  chatId: _chatId,
                  isMe: isMe,
                ),
              ),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                width: 260,
                color: Colors.white10,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.tealAccent,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                width: 260,
                color: Colors.white10,
                child: const Icon(Icons.broken_image, color: Colors.white54),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.check,
                    size: 14,
                    color: isRead ? Colors.blue : Colors.white60,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMessage(String url, DateTime timestamp, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkWell(
            onTap: () async {
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'الموقع المباشر',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(timestamp),
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomInviteMessage(Message m, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D2671), Color(0xFFC33764)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'دعوة للانضمام للغرفة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      m.text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => VoiceRoomScreen(roomId: m.mediaUrl!),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'دخول الغرفة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedIndicator() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    color: Colors.red.withOpacity(0.1),
    child: const Center(
      child: Text(
        'لا يمكنك مراسلة هذا المستخدم',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Future<void> _sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      await _chatService.sendImageMessage(
        senderId: _currentUid,
        receiverId: widget.receiverId,
        imageFile: File(image.path),
      );
    }
  }

  Future<void> _sendLocation() async {
    final Position position = await Geolocator.getCurrentPosition();
    await _chatService.sendLocationMessage(
      senderId: _currentUid,
      receiverId: widget.receiverId,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  void _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _chatService.setRecordingStatus(_chatId, _currentUid, true);
      _startTimer();
    }
  }

  void _stopRecording() async {
    final path = await _audioRecorder.stop();
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    _chatService.setRecordingStatus(_chatId, _currentUid, false);
    if (path != null) {
      await _chatService.sendAudioMessage(
        senderId: _currentUid,
        receiverId: widget.receiverId,
        audioPath: path,
        duration: _recordDuration > 0 ? _recordDuration : 1,
      );
    }
  }

  void _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() => _isRecording = false);
    _chatService.setRecordingStatus(_chatId, _currentUid, false);
    _recordTimer?.cancel();
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AttachOption(
              icon: Icons.image,
              label: 'صورة',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(ctx);
                _sendImage();
              },
            ),
            _AttachOption(
              icon: Icons.location_on,
              label: 'الموقع',
              color: Colors.green,
              onTap: () {
                Navigator.pop(ctx);
                _sendLocation();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final int recordDuration;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendMessage;
  final VoidCallback onTypingChanged;
  final VoidCallback onAttach;
  final String Function(int) formatDuration;

  const _ChatInputField({
    required this.controller,
    required this.isRecording,
    required this.recordDuration,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendMessage,
    required this.onTypingChanged,
    required this.onAttach,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: onAttach,
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.tealAccent,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (v) => onTypingChanged(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isRecording
                      ? 'اسحب لليسار للإلغاء...'
                      : 'اكتب رسالتك...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  prefixIcon: isRecording
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mic,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatDuration(recordDuration),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final bool isNotEmpty = value.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: isNotEmpty ? onSendMessage : null,
                  onLongPress: isNotEmpty ? null : onStartRecording,
                  onLongPressUp: isNotEmpty ? null : onStopRecording,
                  onHorizontalDragUpdate: (details) {
                    if (isRecording && details.primaryDelta! < -20) {
                      onCancelRecording();
                    }
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: isRecording ? Colors.red : Colors.teal,
                    child: Icon(
                      isRecording
                          ? Icons.mic
                          : (isNotEmpty ? Icons.send : Icons.mic),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class BlinkingMicIndicator extends StatefulWidget {
  const BlinkingMicIndicator({super.key});

  @override
  State<BlinkingMicIndicator> createState() => _BlinkingMicIndicatorState();
}

class _BlinkingMicIndicatorState extends State<BlinkingMicIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mic,
              color: Colors.redAccent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'يسجل بصمة الآن...',
              style: TextStyle(
                color: Colors.redAccent.shade100,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
