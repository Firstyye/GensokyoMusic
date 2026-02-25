import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../data/touhoudb_service.dart';

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
  late Stream<DatabaseEvent> _participantsStream;
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
    _participantsStream = _dbService
        .getPartyParticipantsStream(widget.partyId)
        .asBroadcastStream();
    _queueStream = _dbService
        .getPartyQueueStream(widget.partyId)
        .asBroadcastStream();

    // Listen to metadata to see if the host closes the party or transfers host
    _metadataStream.listen((event) {
      if (!event.snapshot.exists && mounted && !_isCurrentlyHost) {
        // Party deleted
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

  void _sendMessage() {
    final msg = _msgController.text.trim();
    if (msg.isEmpty) return;

    _dbService.sendMessage(widget.partyId, msg);
    _msgController.clear();
  }

  void _leaveParty(bool endPartyForAll) {
    _audioService.leaveParty(isEndParty: endPartyForAll);
    Navigator.pop(context);
  }

  void _showParticipantsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkModeBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<DatabaseEvent>(
          stream: _participantsStream,
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
                          backgroundImage: p['photoUrl'] != ''
                              ? NetworkImage(p['photoUrl'])
                              : null,
                          child: p['photoUrl'] == ''
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
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
                                  style: GoogleFonts.inter(
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
                                  style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
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
                child: Image.network(
                  song.thumbnailUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(
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
                      style: GoogleFonts.inter(
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

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) ...[
                      Text(
                        msg['name'] ?? 'User',
                        style: bodyTextStyle.copyWith(
                          color: cyanAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      msg['message'] ?? '',
                      style: bodyTextStyle.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
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
                child: Image.network(
                  song.thumbnailUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
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
                style: GoogleFonts.inter(
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
        return _AddSongSearchSheet(
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
          style: GoogleFonts.inter(
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

// Bottom sheet for searching and adding songs to the queue
class _AddSongSearchSheet extends StatefulWidget {
  final Function(SongInfo) onSongSelected;

  const _AddSongSearchSheet({required this.onSongSelected});

  @override
  State<_AddSongSearchSheet> createState() => _AddSongSearchSheetState();
}

class _AddSongSearchSheetState extends State<_AddSongSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TouhouDBService _touhouDB = TouhouDBService();
  final FirestoreService _firestoreService = FirestoreService();

  List<SongInfo> _searchResults = [];
  bool _isLoading = false;

  int _selectedTab = 0; // 0=Search, 1=Favorites, 2=Playlists
  String? _selectedPlaylistId;
  String? _selectedPlaylistName;

  void _searchSongs(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await _touhouDB.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedTab = index;
            _selectedPlaylistId = null;
            _selectedPlaylistName = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? cyanAccent : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cyanAccent
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cyanAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTab == 0) {
      // Source 0: Search
      return Container(
        key: const ValueKey('SearchTab'),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              onChanged: _searchSongs,
              decoration: InputDecoration(
                hintText: 'Search Touhou songs...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: darkThemeSecondaryColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                ),
              )
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.thumbnailUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onSongSelected(song),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "No results found.",
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      // Source 1: Favorites
      return Container(
        key: const ValueKey('FavoritesTab'),
        child: StreamBuilder<List<SongInfo>>(
          stream: _firestoreService.getFavoriteSongsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              );
            }
            final songs = snapshot.data ?? [];
            if (songs.isEmpty) {
              return const Center(
                child: Text(
                  "You don't have any favorite songs yet.",
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.thumbnailUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    song.title,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => widget.onSongSelected(song),
                );
              },
            );
          },
        ),
      );
    } else {
      // Source 2: Playlists
      return Container(
        key: ValueKey('PlaylistsTab_$_selectedPlaylistId'),
        child: _selectedPlaylistId == null
            // 2A: List all Playlists
            ? StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreService.getPlaylistsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                    );
                  }
                  final playlists = snapshot.data ?? [];
                  if (playlists.isEmpty) {
                    return const Center(
                      child: Text(
                        "You don't have any playlists yet.",
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: darkThemeSecondaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.queue_music,
                            color: Colors.white54,
                          ),
                        ),
                        title: Text(
                          playlist['name'] ?? 'Untitled Playlist',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPlaylistId = playlist['id'];
                            _selectedPlaylistName = playlist['name'];
                          });
                        },
                      );
                    },
                  );
                },
              )
            // 2B: Songs inside the selected Playlist
            : Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.cyanAccent,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedPlaylistId = null;
                            _selectedPlaylistName = null;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          _selectedPlaylistName ?? "Playlist",
                          style: bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: StreamBuilder<List<SongInfo>>(
                      stream: _firestoreService.getPlaylistSongsStream(
                        _selectedPlaylistId!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                            ),
                          );
                        }
                        final songs = snapshot.data ?? [];
                        if (songs.isEmpty) {
                          return const Center(
                            child: Text(
                              "This playlist is empty.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  song.thumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                song.title,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist,
                                style: const TextStyle(color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => widget.onSongSelected(song),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 16,
        right: 16,
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Row of Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('Search', 0),
                const SizedBox(width: 8),
                _buildTabButton('Favorites', 1),
                const SizedBox(width: 8),
                _buildTabButton('Playlists', 2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animated Content Area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: child,
                  ),
                );
              },
              child: _buildSelectedTabContent(),
            ),
          ),
        ],
      ),
    );
  }
}
