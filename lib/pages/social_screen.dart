import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../services/realtime_database_service.dart';
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

  Widget _buildUserTile(Map<String, dynamic> user, {required bool isRequest}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: StreamBuilder<bool>(
        stream: RealtimeDatabaseService().getUserPresenceStream(user['uid']),
        builder: (context, snapshot) {
          final isOnline = snapshot.data ?? false;
          return Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white12,
                backgroundImage:
                    user['photoUrl'] != null &&
                        user['photoUrl'].toString().isNotEmpty
                    ? NetworkImage(user['photoUrl'])
                    : null,
                child:
                    user['photoUrl'] == null ||
                        user['photoUrl'].toString().isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.greenAccent : Colors.grey.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      title: Text(
        user['displayName'] ?? 'Unknown',
        style: bodyTextStyle.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        isRequest ? "Pending Request" : "Tap to chat",
        style: bodyTextStyle.copyWith(
          color: isRequest ? cyanAccent : Colors.white54,
          fontSize: 12,
        ),
      ),
      trailing: isRequest
          ? ElevatedButton(
              onPressed: () async {
                await _firestoreService.addFriend(user['uid']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${user['displayName']} back!'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
              child: const Text("Accept"),
            )
          : null,
      onTap: isRequest
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrivateChatScreen(friendData: user),
                ),
              );
            },
    ).animate().fade().slideX(begin: 0.05);
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
              // ─── SOCIAL CONNECTIONS ───
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreService.getFriendsStream(),
                  builder: (context, friendsSnapshot) {
                    if (friendsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: cyanAccent),
                      );
                    }
                    if (friendsSnapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error loading friends",
                          style: bodyTextStyle.copyWith(color: Colors.red),
                        ),
                      );
                    }

                    final friends = friendsSnapshot.data ?? [];
                    final friendUids = friends
                        .map((f) => f['uid'].toString())
                        .toSet();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _firestoreService.getFollowersStream(),
                      builder: (context, followersSnapshot) {
                        final allFollowers = followersSnapshot.data ?? [];
                        // Filter followers to only those who are NOT yet in the friends list
                        final pendingRequests = allFollowers
                            .where(
                              (f) => !friendUids.contains(f['uid'].toString()),
                            )
                            .toList();

                        if (friends.isEmpty && pendingRequests.isEmpty) {
                          return Center(
                            child: Text(
                              "You don't have any friends yet.\nShare your UID to get started!",
                              style: bodyTextStyle.copyWith(
                                color: Colors.white54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            if (pendingRequests.isNotEmpty) ...[
                              Text(
                                "Friend Requests",
                                style: headerTextStyle.copyWith(
                                  fontSize: 18,
                                  color: cyanAccent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...pendingRequests.map(
                                (req) => _buildUserTile(req, isRequest: true),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (friends.isNotEmpty) ...[
                              Text(
                                "Friends",
                                style: headerTextStyle.copyWith(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...friends.map(
                                (friend) =>
                                    _buildUserTile(friend, isRequest: false),
                              ),
                            ],
                          ],
                        );
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
