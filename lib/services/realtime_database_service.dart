import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song_info.dart';

import 'package:firebase_core/firebase_core.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://flutterauth-d67b9-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════
  //  PARTY MANAGEMENT
  // ═══════════════════════════════════════════

  /// Creates a new party room and returns the room code.
  Future<String?> createParty({SongInfo? initialSong}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final partyRef = _db.ref('parties').push(); // Generate unique key
    final roomId = partyRef.key;
    if (roomId == null) return null;

    final initialData = {
      'hostUid': user.uid,
      'hostName': user.displayName ?? 'Host',
      'createdAt': ServerValue.timestamp,
      'state': {
        'isPlaying': false,
        'positionSeconds': 0,
        'song': initialSong?.toMap(),
      },
      'participants': {
        user.uid: {
          'name': user.displayName ?? 'Host',
          'photoUrl': user.photoURL ?? '',
          'isHost': true,
          'joinedAt': ServerValue.timestamp,
        },
      },
    };

    await partyRef.set(initialData);

    // If an initial song is provided, add it to the queue
    if (initialSong != null) {
      await partyRef.child('queue').push().set(initialSong.toMap());
    }

    return roomId;
  }

  /// Closes the party room and deletes all data/chat
  Future<void> closeParty(String partyId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.ref('parties/$partyId').remove();
  }

  /// Check if party exists before joining
  Future<bool> checkPartyExists(String partyId) async {
    final snapshot = await _db.ref('parties/$partyId').get();
    return snapshot.exists;
  }

  // ═══════════════════════════════════════════
  //  PARTICIPANTS MANAGEMENT
  // ═══════════════════════════════════════════

  Future<void> joinPartyUser(String partyId, {bool isHost = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.ref('parties/$partyId/participants/${user.uid}').set({
      'name': user.displayName ?? user.email?.split('@').first ?? 'Guest',
      'photoUrl': user.photoURL ?? '',
      'isHost': isHost,
      'joinedAt': ServerValue.timestamp,
    });
  }

  /// Removes user from party. If user is host, transfers host status or closes party.
  Future<void> leavePartyUser(String partyId, bool wasHost) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final partyRef = _db.ref('parties/$partyId');

    // Remove the user from participants
    await partyRef.child('participants/${user.uid}').remove();

    if (wasHost) {
      // Find the next oldest user to promote
      final participantsSnap = await partyRef.child('participants').get();
      if (!participantsSnap.exists || participantsSnap.value == null) {
        // Room is empty, delete it entirely
        await closeParty(partyId);
        return;
      }

      final participantsMap = Map<dynamic, dynamic>.from(
        participantsSnap.value as Map,
      );
      if (participantsMap.isEmpty) {
        await closeParty(partyId);
        return;
      }

      // Find user with earliest joinedAt
      String? nextHostUid;
      int earliestTime = double.maxFinite.toInt();
      String nextHostName = 'Host';

      participantsMap.forEach((uid, data) {
        final pData = Map<String, dynamic>.from(data);
        final joinedAt = pData['joinedAt'] ?? 0;
        if (joinedAt < earliestTime) {
          earliestTime = joinedAt;
          nextHostUid = uid.toString();
          nextHostName = pData['name'] ?? 'Host';
        }
      });

      if (nextHostUid != null) {
        // Promote the next user
        await partyRef.child('participants/$nextHostUid/isHost').set(true);
        await partyRef.update({
          'hostUid': nextHostUid,
          'hostName': nextHostName,
        });
      }
    }
  }

  Stream<DatabaseEvent> getPartyParticipantsStream(String partyId) {
    return _db.ref('parties/$partyId/participants').onValue;
  }

  // ═══════════════════════════════════════════
  //  QUEUE MANAGEMENT
  // ═══════════════════════════════════════════

  Future<void> addSongToQueue(String partyId, SongInfo song) async {
    await _db.ref('parties/$partyId/queue').push().set(song.toMap());
  }

  Future<void> removeSongFromQueue(String partyId, String pushId) async {
    await _db.ref('parties/$partyId/queue/$pushId').remove();
  }

  /// For reordering, we rewrite the entire queue list to maintain strict order effortlessly
  Future<void> overwriteQueue(String partyId, List<SongInfo> newQueue) async {
    final ref = _db.ref('parties/$partyId/queue');
    await ref.remove(); // Clear old queue

    for (final song in newQueue) {
      await ref.push().set(song.toMap());
    }
  }

  Stream<DatabaseEvent> getPartyQueueStream(String partyId) {
    return _db.ref('parties/$partyId/queue').onValue;
  }

  // ═══════════════════════════════════════════
  //  PLAYBACK SYNCHRONIZATION
  // ═══════════════════════════════════════════

  /// Host updates the party playback state
  Future<void> updatePartyState({
    required String partyId,
    required SongInfo? song,
    required bool isPlaying,
    required int positionSeconds,
  }) async {
    await _db.ref('parties/$partyId/state').update({
      'isPlaying': isPlaying,
      'positionSeconds': positionSeconds,
      'song': song?.toMap(),
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Listeners subscribe to this stream to mirror host's playback
  Stream<DatabaseEvent> getPartyStream(String partyId) {
    return _db.ref('parties/$partyId/state').onValue;
  }

  /// Listeners subscribe to check if the party dies or metadata changes
  Stream<DatabaseEvent> getPartyMetadataStream(String partyId) {
    return _db.ref('parties/$partyId').onValue;
  }

  // ═══════════════════════════════════════════
  //  LIVE CHAT
  // ═══════════════════════════════════════════

  /// Watch all open parties globally (For HomeScreen)
  Stream<DatabaseEvent> getActivePartiesStream() {
    return _db.ref('parties').onValue;
  }

  Future<void> sendMessage(String partyId, String message) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.ref('parties/$partyId/chat').push().set({
      'uid': user.uid,
      'name': user.displayName ?? user.email?.split('@').first ?? 'Guest',
      'photoUrl': user.photoURL ?? '',
      'message': message,
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<DatabaseEvent> getChatStream(String partyId) {
    // Only fetch the last 50 messages to keep UI light
    return _db
        .ref('parties/$partyId/chat')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue;
  }

  // ═══════════════════════════════════════════
  //  PRIVATE CHAT MANAGEMENT
  // ═══════════════════════════════════════════

  /// Generates a consistent chat ID between two users by sorting their UIDs alphabetically.
  String getPrivateChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return "${uids[0]}_${uids[1]}";
  }

  /// Sends a private message to a specific chat ID. Supports optional song attachment.
  Future<void> sendPrivateMessage(
    String chatId,
    String message, {
    Map<String, dynamic>? songData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final messageData = {
      'text': message,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown',
      'senderPhotoUrl': user.photoURL ?? '',
      'timestamp': ServerValue.timestamp,
    };

    if (songData != null) {
      messageData['song'] = songData;
    }

    try {
      await _db.ref('private_chats/$chatId/messages').push().set(messageData);

      // Update last message timestamp for indexing/sorting
      await _db.ref('private_chats/$chatId/metadata').set({
        'lastMessageAt': ServerValue.timestamp,
      });
    } catch (e) {
      print(
        'RealtimeDatabaseService ERROR: Failed to send private message: $e',
      );
    }
  }

  /// Streams the chat messages for a specific private 1-on-1 chat room.
  Stream<DatabaseEvent> getPrivateChatStream(String chatId) {
    return _db
        .ref('private_chats/$chatId/messages')
        .orderByChild('timestamp')
        .onValue;
  }
}
