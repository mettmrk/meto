import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/story_service.dart';
import '../models/index.dart';
import 'chat_screen.dart';
import '../widgets/framed_avatar.dart';
import 'story_view_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChatService chatService = ChatService();
    final UserService userService = UserService();
    final String currentUid = auth.FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white, // Changed to solid white for maximum clarity
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            style: const TextStyle(
              color: Colors.black87, // Solid dark text
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث عن أصدقاء أو رسائل...',
              hintStyle: const TextStyle(
                color: Colors.black38,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.black45,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.black45,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none, // Removes the line
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Active Users List (Horizontal)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8.0),
            child: SizedBox(
              height: 110,
              child: StreamBuilder<List<Story>>(
                stream: StoryService().getStoriesStream(),
                builder: (context, snapshot) {
                  final stories = snapshot.data ?? [];
                  if (stories.isEmpty) {
                    return Center(
                      child: Text(
                        'لا يوجد قصص نشطة الآن',
                        style: const TextStyle(
                          color: Colors.white60, // Visible on primary background
                          fontSize: 12,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: stories.length,
                    itemBuilder: (context, index) {
                      final story = stories[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryViewScreen(
                                stories: stories,
                                username: story.username,
                                userProfileImage: story.userProfileImage,
                                currentUserId: currentUid,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Stack(
                                children: [
                                  story.storyImage != null
                                      ? Image.network(
                                          story.storyImage!,
                                          width: 100,
                                          height: 160,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Theme.of(context).primaryColor,
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      color: Colors.white54,
                                                    ),
                                                  ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.teal.shade700,
                                                Colors.teal.shade400,
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.6),
                                        ],
                                        begin: Alignment.center,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            story.userProfileImage != null &&
                                                story
                                                    .userProfileImage!
                                                    .isNotEmpty
                                            ? NetworkImage(
                                                story.userProfileImage!,
                                              )
                                            : null,
                                        backgroundColor: Colors.grey.shade200,
                                        child: story.userProfileImage == null
                                            ? Icon(
                                                Icons.person,
                                                size: 16,
                                                color: Colors.grey.shade400,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Text(
                                      story.username,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FD), // Slightly off-white for premium feel
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: StreamBuilder<List<Chat>>(
                  stream: chatService.getChatsStream(currentUid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ',
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Filtering Logic
                    final allChats = snapshot.data ?? [];
                    final chats = _searchQuery.isEmpty
                        ? allChats
                        : allChats.where((chat) {
                            final lastMsg = chat.lastMessage.toLowerCase();
                            // Note: Nickname filtering requires the user data,
                            // we'll handle filter in the ListView.builder or by pre-fetching
                            // For simplicity, we filter by last message here if query is present
                            return lastMsg.contains(_searchQuery);
                          }).toList();

                    if (chats.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty
                                  ? Icons.chat_bubble_outline
                                  : Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'ابدأ محادثة جديدة الآن'
                                  : 'لا توجد نتائج لـ "$_searchQuery"',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final otherUserId = chat.participants.firstWhere(
                          (id) => id != currentUid,
                        );
                        final unreadCount = chat.unreadCounts[currentUid] ?? 0;

                        return FutureBuilder<User?>(
                          future: userService.getUser(otherUserId),
                          builder: (context, userSnapshot) {
                            final user = userSnapshot.data;
                            if (user == null) return const SizedBox.shrink();

                            // Filter by username/nickname if searching
                            if (_searchQuery.isNotEmpty) {
                              final nickname = (user.nickname ?? '')
                                  .toLowerCase();
                              final username = user.username.toLowerCase();
                              final lastMsg = chat.lastMessage.toLowerCase();
                              if (!nickname.contains(_searchQuery) &&
                                  !username.contains(_searchQuery) &&
                                  !lastMsg.contains(_searchQuery)) {
                                return const SizedBox.shrink();
                              }
                            }

                            return Dismissible(
                              key: Key(chat.id),
                              background: Container(
                                color: Colors.red.shade50,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                      'حذف المحادثة؟',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: const Text(
                                      'سيتم حذف جميع الرسائل في هذه المحادثة.',
                                    ),
                                    actions: [
                                      TextButton(
                                        child: const Text(
                                          'تراجع',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('حذف'),
                                        onPressed: () {
                                          Navigator.pop(ctx, true);
                                          chatService.deleteChat(chat.id);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                leading: Stack(
                                  children: [
                                    FramedAvatar(
                                      userId: user.uid,
                                      radius: 28,
                                      imageUrl: user.profileImage,
                                      disableFrame: true,
                                    ),
                                    if (user.isOnline)
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  user.nickname ?? user.username,
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    chat.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unreadCount > 0
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTimestamp(chat.lastTimestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: unreadCount > 0
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.shade500,
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        receiverId: user.uid,
                                        receiverName:
                                            user.nickname ?? user.username,
                                        receiverImage: user.profileImage,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (now.day == timestamp.day &&
        now.month == timestamp.month &&
        now.year == timestamp.year) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
    return '${timestamp.day}/${timestamp.month}';
  }
}
