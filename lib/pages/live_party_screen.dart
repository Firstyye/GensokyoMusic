import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/add_song_search_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/_buildMiniPlayer.dart';
import '../widgets/custom_page_route.dart';
import 'full_player_screen.dart';

class LivePartyScreen extends StatefulWidget {
  final String partyId;
  final bool isHost; // Initial host state

  const LivePartyScreen({
    super.key,
    required this.partyId,
    required this.isHost,
  });

  @override
  State<LivePartyScreen> createState() => _LivePartyScreenState();
}

class _LivePartyScreenState extends State<LivePartyScreen> {
  final RealtimeDatabaseService _dbService = RealtimeDatabaseService();
  final AudioPlayerService _audioService = AudioPlayerService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Stream<DatabaseEvent> _chatStream;
  late Stream<DatabaseEvent> _metadataStream;
  late Stream<DatabaseEvent> _queueStream;

  bool _isCurrentlyHost = false;

  @override
  void initState() {
    super.initState();
    _isCurrentlyHost = widget.isHost;

    _chatStream = _dbService.getChatStream(widget.partyId).asBroadcastStream();
    _metadataStream = _dbService
        .getPartyMetadataStream(widget.partyId)
        .asBroadcastStream();
    _queueStream = _dbService
        .getPartyQueueStream(widget.partyId)
        .asBroadcastStream();

    // Listen to metadata to see if the host closes the party or transfers host
    _metadataStream.listen((event) {
      if (!event.snapshot.exists && mounted && !_isCurrentlyHost) {
        // Party deleted — clean up audio service state so HomeScreen banner disappears
        _audioService.leaveParty();
        if (Navigator.canPop(context)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The host closed the party.')),
          );
          Navigator.pop(context);
        }
      } else if (event.snapshot.exists && mounted) {
        final meta = Map<String, dynamic>.from(event.snapshot.value as Map);
        final myUid = FirebaseAuth.instance.currentUser?.uid;

        // If host changes to me
        if (meta['hostUid'] == myUid && !_isCurrentlyHost) {
          setState(() {
            _isCurrentlyHost = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are now the Host!')),
          );
        }
      }
    });
  }

  void _sendMessage({SongInfo? song}) {
    final msg = _msgController.text.trim();
    if (msg.isEmpty && song == null) return;

    _dbService.sendMessage(widget.partyId, msg, songData: song?.toMap());
    _msgController.clear();
  }

  void _showAddSongSheet() {
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

  void _playSongFromChat(Map<dynamic, dynamic> songMap) {
    final song = SongInfo(
      title: songMap['title'] ?? 'Unknown',
      artist: songMap['artist'] ?? 'Unknown',
      youtubeVideoId: songMap['youtubeVideoId'] ?? '',
      thumbnailUrl: songMap['thumbnailUrl'] ?? '',
    );
    _audioService.playFromYoutubeId(song.youtubeVideoId, song);
    Navigator.push(
      context,
      SlideFadeRoute(page: FullPlayerScreen(initialSong: song)),
    );
  }

  void _leaveParty(bool endPartyForAll) {
    _audioService.leaveParty(isEndParty: endPartyForAll);
    Navigator.pop(context);
  }

  void _showParticipantsMenu() {
    // Create a fresh stream each time so the StreamBuilder gets the current
    // value immediately (broadcast streams don't replay the last event).
    final freshParticipantsStream = _dbService.getPartyParticipantsStream(
      widget.partyId,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: darkModeBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<DatabaseEvent>(
          stream: freshParticipantsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              );
            }

            final Map<dynamic, dynamic> pMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            final participants = pMap.entries
                .map((e) => Map<String, dynamic>.from(e.value))
                .toList();
            participants.sort(
              (a, b) => (a['joinedAt'] ?? 0).compareTo(b['joinedAt'] ?? 0),
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Party Members (${participants.length})",
                    style: headerTextStyle.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final isHost = p['isHost'] ?? false;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: darkThemeSecondaryColor,
                          child: p['photoUrl'] != ''
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: p['photoUrl'],
                                    memCacheWidth: 80,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          p['name'] ?? 'User',
                          style: bodyTextStyle.copyWith(color: Colors.white),
                        ),
                        trailing: isHost
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: cyanAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "HOST",
                                  style: interTextStyle.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "LISTENER",
                                  style: interTextStyle.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: darkModeBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            _isCurrentlyHost
                ? 'Host: Room ${widget.partyId}'
                : 'Guest: Room ${widget.partyId}',
            style: interTextStyle.copyWith(fontSize: 18, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people_alt_rounded, color: Colors.white),
              onPressed: _showParticipantsMenu,
            ),
            IconButton(
              icon: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.redAccent,
              ),
              onPressed: () => _showLeaveConfirm(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Current Song Header
            _buildNowPlayingHeader(),

            // Tabs
            TabBar(
              indicatorColor: cyanAccent,
              labelColor: cyanAccent,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.chat_bubble_outline), text: "Chat"),
                Tab(icon: Icon(Icons.queue_music_rounded), text: "Queue"),
              ],
            ),
            const Divider(color: Colors.white24, height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // Chat Tab
                  KeepAliveWrapper(
                    child: Column(
                      children: [
                        Expanded(child: _buildChatFeed()),
                        _buildChatInput(),
                      ],
                    ),
                  ),

                  // Queue Tab
                  KeepAliveWrapper(child: _buildQueueTab()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }

  Widget _buildNowPlayingHeader() {
    return StreamBuilder<SongInfo?>(
      stream: _audioService.currentSongStream,
      builder: (context, snapshot) {
        final song = snapshot.data ?? _audioService.currentSong;
        if (song == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Text(
              _isCurrentlyHost
                  ? 'Play a song from the Queue!'
                  : 'Waiting for host to play a song...',
              style: bodyTextStyle.copyWith(color: Colors.white54),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  width: 60,
                  height: 60,
                  memCacheWidth: 120, // 60 * 2
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  errorWidget: (context, _, __) => Container(
                    width: 60,
                    height: 60,
                    color: darkThemeSecondaryColor,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOW PLAYING',
                      style: bodyTextStyle.copyWith(
                        color: cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: interTextStyle.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyTextStyle.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              StreamBuilder<PlayerState>(
                stream: _audioService.playerStateStream,
                builder: (context, psSnapshot) {
                  final isPlaying = _audioService.isPlaying;
                  return Icon(
                    isPlaying
                        ? Icons.multitrack_audio_rounded
                        : Icons.pause_rounded,
                    color: cyanAccent,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatFeed() {
    return StreamBuilder<DatabaseEvent>(
      stream: _chatStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Text(
              "No messages yet. Say hi!",
              style: bodyTextStyle.copyWith(color: Colors.white24),
            ),
          );
        }

        final Map<dynamic, dynamic> messagesMap =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        // Sort by timestamp
        final msgs = messagesMap.entries
            .map((e) => Map<String, dynamic>.from(e.value))
            .toList();
        msgs.sort(
          (a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0),
        );

        // Auto-scroll to bottom after rendering
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        final myUid = FirebaseAuth.instance.currentUser?.uid;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: msgs.length,
          itemBuilder: (context, index) {
            final msg = msgs[index];
            final isMe = msg['uid'] == myUid;
            final hasSong = msg['song'] != null;
            final text = msg['message']?.toString() ?? '';

            Widget bubbleContent;
            if (hasSong) {
              final song = Map<String, dynamic>.from(msg['song']);
              bubbleContent = Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        text,
                        style: bodyTextStyle.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _playSongFromChat(song),
                    child: Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: darkThemeSecondaryColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cyanAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: (song['thumbnailUrl'] ?? '').isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song['thumbnailUrl'],
                                    height: 120,
                                    memCacheWidth: 440,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      height: 120,
                                      color: Colors.white10,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      height: 120,
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  )
                                : Container(
                                    height: 120,
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: cyanAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song['title'] ?? 'Unknown',
                                        style: bodyTextStyle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        song['artist'] ?? 'Unknown',
                                        style: bodyTextStyle.copyWith(
                                          color: Colors.white54,
                                          fontSize: 11,
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
            } else {
              bubbleContent = Text(
                text,
                style: bodyTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              );
            }

            Widget bubble = Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: hasSong
                  ? const EdgeInsets.all(8)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? cyanAccent.withValues(alpha: 0.2)
                    : darkThemeSecondaryColor,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(20),
                  bottomLeft: !isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(20),
                ),
                border: isMe
                    ? Border.all(color: cyanAccent.withValues(alpha: 0.5))
                    : null,
              ),
              child: bubbleContent,
            );

            if (isMe) {
              return Align(alignment: Alignment.centerRight, child: bubble);
            } else {
              final senderPhotoUrl = msg['photoUrl']?.toString() ?? '';
              final senderName = msg['name'] ?? 'User';
              final timestamp = msg['timestamp'];
              String timeStr = '';
              if (timestamp is int) {
                timeStr = ' • ${_formatTimestamp(timestamp)}';
              }

              return Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
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
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              bottom: 2,
                              top: 8,
                            ),
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
          },
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 24),
      decoration: BoxDecoration(
        color: darkThemeSecondaryColor,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cyanAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.music_note_rounded, color: Colors.black),
              onPressed: _showAddSongSheet,
              tooltip: 'Attach a song',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _msgController,
              style: bodyTextStyle.copyWith(color: Colors.white),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: bodyTextStyle.copyWith(color: Colors.white54),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: cyanAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.black),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _queueStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Text(
              "Queue is empty.",
              style: bodyTextStyle.copyWith(color: Colors.white54),
            ),
          );
        }

        final Map<dynamic, dynamic> qMap =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        // Sort keys to maintain chronological push id order
        final sortedKeys = qMap.keys.toList()..sort();

        // Build the queue display items
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(
            0,
            8,
            0,
            80,
          ), // Add bottom padding for FAB
          itemCount: sortedKeys.length,
          buildDefaultDragHandles: _isCurrentlyHost, // Only host can reorder
          onReorder: (oldIndex, newIndex) {
            if (!_isCurrentlyHost) return;
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final key = sortedKeys.removeAt(oldIndex);
              sortedKeys.insert(newIndex, key);

              // Map keys back to Songs and overwrite RTDB
              List<SongInfo> newQueue = sortedKeys.map((k) {
                return SongInfo.fromMap(Map<String, dynamic>.from(qMap[k]));
              }).toList();

              _dbService.overwriteQueue(widget.partyId, newQueue);
            });
          },
          itemBuilder: (context, index) {
            final key = sortedKeys[index];
            final songData = Map<String, dynamic>.from(qMap[key]);
            final song = SongInfo.fromMap(songData);

            final isPlaying =
                _audioService.currentSong?.youtubeVideoId ==
                song.youtubeVideoId;

            return ListTile(
              key: ValueKey(key),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  width: 40,
                  height: 40,
                  memCacheWidth: 80, // 40 * 2
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 40,
                    height: 40,
                    color: darkThemeSecondaryColor,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              title: Text(
                song.title,
                style: bodyTextStyle.copyWith(
                  color: isPlaying ? cyanAccent : Colors.white,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                style: bodyTextStyle.copyWith(
                  color: isPlaying
                      ? cyanAccent.withValues(alpha: 0.7)
                      : Colors.white54,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _isCurrentlyHost
                  ? IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        _dbService.removeSongFromQueue(
                          widget.partyId,
                          key.toString(),
                        );
                      },
                    )
                  : null,
              onTap: _isCurrentlyHost
                  ? () {
                      // Host overrides and plays this song immediately
                      _audioService.skipToQueueItem(index);
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildQueueTab() {
    return Stack(
      children: [
        _buildQueueList(),
        if (_isCurrentlyHost)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _showAddSongModal,
              backgroundColor: cyanAccent,
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: Text(
                'Add Song',
                style: interTextStyle.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddSongModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: darkModeBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AddSongSearchSheet(
          onSongSelected: (song) {
            _dbService.addSongToQueue(widget.partyId, song);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added ${song.title} to queue')),
            );
          },
        );
      },
    );
  }

  void _showLeaveConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkThemeSecondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Party Options',
          style: interTextStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          _isCurrentlyHost
              ? 'You are the Host. Leaving will transfer host status to the oldest listener. Ending the party will close the room for everyone.'
              : 'Are you sure you want to leave the party?',
          style: bodyTextStyle.copyWith(color: Colors.white70),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: bodyTextStyle.copyWith(color: Colors.white54),
            ),
          ),
          if (_isCurrentlyHost)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _leaveParty(true); // End for all
              },
              child: Text(
                'End Party',
                style: bodyTextStyle.copyWith(color: Colors.white),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCurrentlyHost
                  ? Colors.orange
                  : Colors.redAccent,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _leaveParty(false); // Leave smoothly
            },
            child: Text(
              'Leave',
              style: bodyTextStyle.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// A generic wrapper to keep TabBarView children alive when switching tabs
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
