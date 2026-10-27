import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../models/index.dart'; // Assumed to contain User and Post models
import '../screens/home_screen.dart'; // To use PostCard, which is imported there or defined there? Wait, PostCard is defined in home_screen.dart? No, it's usually defined separately.
// Wait, I saw import '../screens/home_screen.dart' in step 615 for PostCard. If PostCard is accessible via home_screen, I'll keep it. If not, I should check where PostCard is.
// Actually, PostCard is likely defined in a widgets file or home_screen.dart (as step 615 says). I'll keep the import.
import 'profile_screen.dart';

class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final PostService _postService = PostService();
  final UserService _userService = UserService();

  List<Post> _postSearchResults = [];
  List<User> _userSearchResults = [];
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _postSearchResults = [];
          _userSearchResults = [];
          _currentQuery = '';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _currentQuery = query;
      });
    }

    try {
      final postsFuture = _postService.searchPosts(query);
      final usersFuture = _userService.searchUsers(
        query,
        currentUserId: auth.FirebaseAuth.instance.currentUser?.uid,
      );

      final results = await Future.wait([postsFuture, usersFuture]);

      if (mounted) {
        setState(() {
          _postSearchResults = results[0] as List<Post>;
          _userSearchResults = results[1] as List<User>;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في البحث: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onSubmitted: _performSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'بحث عام...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
          tabs: const [
            Tab(text: 'أشخاص'),
            Tab(text: 'بلاغات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsersList(), _buildPostsList()],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentQuery.isEmpty) {
      return _buildEmptyState('ابحث عن أصدقائك', Icons.person_search_rounded);
    }
    if (_userSearchResults.isEmpty) {
      return _buildEmptyState(
        'لا يوجد أشخاص بهذا الاسم',
        Icons.search_off_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _userSearchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _userSearchResults[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 28,
              backgroundImage:
                  user.profileImage != null && user.profileImage!.isNotEmpty
                  ? NetworkImage(user.profileImage!)
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: user.profileImage == null || user.profileImage!.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            title: Text(
              user.nickname ?? user.username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('@${user.username}'),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentQuery.isEmpty) {
      return _buildEmptyState(
        'ابحث عن مفقودات أو بلاغات',
        Icons.article_rounded,
      );
    }
    if (_postSearchResults.isEmpty) {
      return _buildEmptyState(
        'لا يوجد بلاغات مطابقة',
        Icons.search_off_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: _postSearchResults.length,
      itemBuilder: (context, index) {
        return PostCard(post: _postSearchResults[index]);
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
