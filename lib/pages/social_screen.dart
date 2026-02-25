import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import 'private_chat_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _searchedUser;
  bool _isSearching = false;

  void _copyUidToClipboard() {
    if (currentUser != null) {
      Clipboard.setData(ClipboardData(text: currentUser!.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your UID copied to clipboard!'),
          backgroundColor: cyanAccent.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _searchUser() async {
    final uid = _searchController.text.trim();
    if (uid.isEmpty) return;

    // Prevent adding oneself
    if (uid == currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't add yourself as a friend.")),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchedUser = null;
    });

    final userData = await _firestoreService.searchUserByUid(uid);

    setState(() {
      _isSearching = false;
      _searchedUser = userData;
    });

    if (userData == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not found.')));
    }
  }

  Future<void> _addFriend() async {
    if (_searchedUser == null) return;

    final friendUid = _searchedUser!['uid'];
    final success = await _firestoreService.addFriend(friendUid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Friend added successfully!'
                : 'Failed to add friend or already added.',
          ),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
      if (success) {
        setState(() {
          _searchedUser = null;
          _searchController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Friends & Chat",
          style: headerTextStyle.copyWith(color: Colors.white, fontSize: 24),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── MY UID SECTION ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: darkThemeSecondaryColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cyanAccent.withValues(alpha: 0.2),
                      backgroundImage: currentUser?.photoURL != null
                          ? NetworkImage(currentUser!.photoURL!)
                          : null,
                      child: currentUser?.photoURL == null
                          ? Icon(Icons.person, color: cyanAccent)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Your ID",
                            style: bodyTextStyle.copyWith(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            currentUser?.uid ?? 'Not logged in',
                            style: bodyTextStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: cyanAccent),
                      onPressed: _copyUidToClipboard,
                      tooltip: "Copy UID",
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.1),

              const SizedBox(height: 24),

              // ─── SEARCH UID SECTION ───
              Text(
                "Add Friend",
                style: headerTextStyle.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: bodyTextStyle.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter friend's UID...",
                        hintStyle: bodyTextStyle.copyWith(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _searchUser(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cyanAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSearching
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.search, color: Colors.black),
                      onPressed: _searchUser,
                    ),
                  ),
                ],
              ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

              // ─── SEARCH RESULT ───
              if (_searchedUser != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cyanAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            _searchedUser!['photoUrl'] != null &&
                                _searchedUser!['photoUrl'].toString().isNotEmpty
                            ? NetworkImage(_searchedUser!['photoUrl'])
                            : null,
                        child:
                            _searchedUser!['photoUrl'] == null ||
                                _searchedUser!['photoUrl'].toString().isEmpty
                            ? Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _searchedUser!['displayName'] ?? 'Unknown',
                          style: bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _addFriend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
              ],

              const SizedBox(height: 32),

              // ─── FRIENDS LIST ───
              Text(
                "Friends",
                style: headerTextStyle.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreService.getFriendsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: cyanAccent),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error loading friends",
                          style: bodyTextStyle.copyWith(color: Colors.red),
                        ),
                      );
                    }

                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return Center(
                        child: Text(
                          "You don't have any friends yet.\nShare your UID to get started!",
                          style: bodyTextStyle.copyWith(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.white12,
                                backgroundImage:
                                    friend['photoUrl'] != null &&
                                        friend['photoUrl'].toString().isNotEmpty
                                    ? NetworkImage(friend['photoUrl'])
                                    : null,
                                child:
                                    friend['photoUrl'] == null ||
                                        friend['photoUrl'].toString().isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              title: Text(
                                friend['displayName'] ?? 'Unknown',
                                style: bodyTextStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Tap to chat",
                                style: bodyTextStyle.copyWith(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PrivateChatScreen(friendData: friend),
                                  ),
                                );
                              },
                            )
                            .animate()
                            .fade(delay: (200 + index * 50).ms)
                            .slideX(begin: 0.05);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
