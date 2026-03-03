import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../services/realtime_database_service.dart';
import '../services/audio_player_service.dart';
import '../models/song_info.dart';
import 'full_player_screen.dart';
import '../widgets/add_song_search_sheet.dart';
import 'profile_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/_buildMiniPlayer.dart';
import '../widgets/custom_page_route.dart';

class PrivateChatScreen extends StatefulWidget {
  final Map<String, dynamic> friendData;

  const PrivateChatScreen({super.key, required this.friendData});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final RealtimeDatabaseService _rtdbService = RealtimeDatabaseService();
  final AudioPlayerService _audioService = AudioPlayerService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late String chatId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      chatId = _rtdbService.getPrivateChatId(
        currentUser!.uid,
        widget.friendData['uid'],
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({SongInfo? song}) {
    final text = _messageController.text.trim();
    if (text.isEmpty && song == null) return;

    _rtdbService.sendPrivateMessage(chatId, text, songData: song?.toMap());
    _messageController.clear();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAddSongSheet() {
    // Reusing the AddSongSearchSheet from Live Party
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return AddSongSearchSheet(
            scrollController: controller,
            onSongSelected: (song) {
              Navigator.pop(context);
              _sendMessage(song: song);
            },
          );
        },
      ),
    );
  }

  void _playSongFromChat(Map<dynamic, dynamic> songMap) async {
    final song = SongInfo.fromMap(Map<String, dynamic>.from(songMap));

    // Play immediately
    final result = await _audioService.playFromYoutubeId(
      song.youtubeVideoId,
      song,
    );
    if (result == PlayResult.blockedAsListener && mounted) {
      showListenerBlockedDialog(context);
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        SlideFadeRoute(page: FullPlayerScreen(initialSong: song)),
      );
    }
  }

  String _formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(dt);
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$min';

    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return timeStr; // Today
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
      return 'Yesterday, $timeStr';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day/$month/$year, $timeStr';
    }
  }

  Widget _buildMessageBubble(Map<dynamic, dynamic> msgMap, bool isMe) {
    final hasSong = msgMap['song'] != null;
    final text = msgMap['text']?.toString() ?? '';
    final senderName = widget.friendData['displayName'] ?? 'User';
    final senderPhotoUrl = widget.friendData['photoUrl']?.toString() ?? '';
    final timestamp = msgMap['timestamp'];
    String timeStr = '';
    if (timestamp is int) {
      timeStr = ' • ${_formatTimestamp(timestamp)}';
    }

    Widget bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      padding: hasSong
          ? const EdgeInsets.all(0)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? (hasSong ? Colors.transparent : cyanAccent.withValues(alpha: 0.9))
            : (hasSong ? Colors.transparent : Colors.grey[800]),
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: isMe
              ? const Radius.circular(0)
              : const Radius.circular(20),
          bottomLeft: !isMe
              ? const Radius.circular(0)
              : const Radius.circular(20),
        ),
      ),
      child: hasSong
          ? _buildSongCardBubble(
              Map<String, dynamic>.from(msgMap['song']),
              text,
              isMe,
            )
          : Text(
              text,
              style: bodyTextStyle.copyWith(
                color: isMe ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
    );

    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: darkThemeSecondaryColor,
                child: senderPhotoUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: senderPhotoUrl,
                          memCacheWidth: 42,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(strokeWidth: 2),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 2, top: 8),
                    child: Text(
                      '$senderName$timeStr',
                      style: bodyTextStyle.copyWith(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  bubble,
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSongCardBubble(
    Map<String, dynamic> song,
    String text,
    bool isMe,
  ) {
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isMe
                  ? cyanAccent.withValues(alpha: 0.9)
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: isMe
                    ? const Radius.circular(0)
                    : const Radius.circular(20),
                bottomLeft: !isMe
                    ? const Radius.circular(0)
                    : const Radius.circular(20),
              ),
            ),
            child: Text(
              text,
              style: bodyTextStyle.copyWith(
                color: isMe ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        GestureDetector(
          onTap: () => _playSongFromChat(song),
          child: Container(
            width: 240,
            decoration: BoxDecoration(
              color: darkThemeSecondaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cyanAccent.withValues(alpha: 0.4)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: song['thumbnailUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: song['thumbnailUrl'],
                          height: 135,
                          memCacheWidth: 480, // Optimize memory for ~240w box
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 135,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 135,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          height: 135,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cyanAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song['title'] ?? 'Unknown Song',
                              style: bodyTextStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song['artist'] ?? 'Unknown Artist',
                              style: bodyTextStyle.copyWith(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1426), // Deep blue background
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: darkThemeSecondaryColor,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Makes back button white
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: darkThemeSecondaryColor,
              child:
                  widget.friendData['photoUrl'] != null &&
                      widget.friendData['photoUrl'].toString().isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.friendData['photoUrl'],
                        memCacheWidth: 54,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(strokeWidth: 2),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.person, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.friendData['displayName'] ?? 'User',
                style: headerTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'View Profile',
            onPressed: () {
              Navigator.push(
                context,
                SlideFadeRoute(
                  page: ProfileScreen(
                    userId: widget.friendData['uid'],
                    userName: widget.friendData['displayName'],
                    userPhotoUrl: widget.friendData['photoUrl'],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_remove, color: Colors.redAccent),
            tooltip: 'Remove Friend',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: Text(
                    'Remove Friend',
                    style: headerTextStyle.copyWith(color: Colors.white),
                  ),
                  content: Text(
                    'Are you sure you want to remove ${widget.friendData['displayName']}?',
                    style: bodyTextStyle.copyWith(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: bodyTextStyle.copyWith(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Remove',
                        style: bodyTextStyle.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirestoreService().removeFriend(widget.friendData['uid']);
                if (mounted) {
                  Navigator.pop(context); // Go back to social screen
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _rtdbService.getPrivateChatStream(chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: cyanAccent),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return Center(
                    child: Text(
                      "No messages yet.\nBreak the ice! ❄️",
                      style: bodyTextStyle.copyWith(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final messagesMap = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );
                final messagesList = messagesMap.entries
                    .map((e) => e.value)
                    .toList();

                // Sort by timestamp
                messagesList.sort((a, b) {
                  final tA = a['timestamp'] ?? 0;
                  final tB = b['timestamp'] ?? 0;
                  return tA.compareTo(tB);
                });

                // Auto-scroll to bottom strictly on new data point
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messagesList.length,
                  itemBuilder: (context, index) {
                    final msg = Map<dynamic, dynamic>.from(
                      messagesList[index] as Map,
                    );
                    final isMe = msg['senderId'] == currentUser!.uid;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Global MiniPlayer stacked above the chat input
          const MiniPlayer(),

          // Message Input Field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: darkThemeSecondaryColor,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle, color: cyanAccent, size: 28),
                    onPressed: _showAddSongSheet,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: bodyTextStyle.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Message...",
                        hintStyle: bodyTextStyle.copyWith(
                          color: Colors.white38,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white12,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cyanAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
