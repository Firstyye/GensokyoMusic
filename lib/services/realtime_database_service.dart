import 'firebase_emulator_config.dart';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/party_session.dart';
import '../models/song_info.dart';
import 'party_departure_policy.dart';
import 'party_repository.dart';

import 'package:firebase_core/firebase_core.dart';

class RealtimeDatabaseService implements PartyRepository {
  RealtimeDatabaseService({FirebaseDatabase? database, FirebaseAuth? auth})
    : _db =
          database ??
          FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: gensokyoRealtimeDatabaseUrl,
          ),
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUid() =>
      _typedStream(() => _auth.authStateChanges().map((user) => user?.uid));

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
    }
    return user;
  }

  @override
  String reservePartyId() {
    _requireUser();
    try {
      return _pushKey(_db.ref('parties'));
    } on FirebaseException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  String _pushKey(DatabaseReference ref) {
    final key = ref.push().key;
    if (key == null) {
      throw const PartyRepositoryException(PartyFailureCode.unknown);
    }
    return key;
  }

  @override
  Future<void> armDisconnect(String partyId, PartyRole role) => _authenticated(
    (user) => _disconnectRef(partyId, user.uid, role).onDisconnect().remove(),
  );

  @override
  Future<void> disarmDisconnect(String partyId, PartyRole role) =>
      _authenticated(
        (user) =>
            _disconnectRef(partyId, user.uid, role).onDisconnect().cancel(),
      );

  DatabaseReference _disconnectRef(
    String partyId,
    String uid,
    PartyRole role,
  ) => role == PartyRole.host
      ? _db.ref('parties/$partyId')
      : _db.ref('parties/$partyId/participants/$uid');

  @override
  Future<void> createReservedParty(String partyId, SongInfo initialSong) =>
      _authenticated((user) async {
        final ref = _db.ref('parties/$partyId');
        final queueEntryId = _pushKey(ref.child('queue'));
        await ref.set(
          PartyDatabaseCodec.createPayload(
            uid: user.uid,
            name: user.displayName ?? 'Host',
            photoUrl: user.photoURL ?? '',
            song: initialSong,
            queueEntryId: queueEntryId,
            timestamp: ServerValue.timestamp,
          ),
        );
      });

  @override
  Future<bool> isJoinable(String partyId) => _authenticated((_) async {
    final snapshot = await _db.ref('parties/$partyId').get();
    final map = _map(snapshot.value);
    return map != null && PartyMetadata.tryFromMap(map) != null;
  });

  @override
  Future<void> joinParty(String partyId) => _authenticated((user) async {
    // Rules evaluate the current parent atomically with this participant write.
    // Never transact on the root: listeners cannot rewrite it.
    try {
      await _db.ref('parties/$partyId/participants/${user.uid}').set({
        'name': user.displayName ?? user.email?.split('@').first ?? 'Guest',
        'photoUrl': user.photoURL ?? '',
        'isHost': false,
        'joinedAt': ServerValue.timestamp,
      });
    } on FirebaseException catch (error) {
      if (_firebaseCode(error) == 'permission-denied' &&
          !await isJoinable(partyId)) {
        throw const PartyRepositoryException(PartyFailureCode.roomClosed);
      }
      rethrow;
    }
  });

  @override
  Future<void> removeCurrentParticipant(String partyId) => _authenticated(
    (user) => _db.ref('parties/$partyId/participants/${user.uid}').remove(),
  );

  @override
  Future<void> leaveOrTransferParty(String partyId) => _authenticated((
    user,
  ) async {
    final partyRef = _db.ref('parties/$partyId');
    final host = await partyRef.child('hostUid').get();
    if (currentUserUid != user.uid) {
      throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
    }
    if (!host.exists) return;
    if (host.value == user.uid) {
      await _leaveAsHost(partyRef, user.uid);
      return;
    }
    try {
      await partyRef.child('participants/${user.uid}').remove();
    } on FirebaseException catch (error) {
      if (_firebaseCode(error) != 'permission-denied') rethrow;
      final latestHost = await partyRef.child('hostUid').get();
      if (currentUserUid != user.uid) {
        throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
      }
      if (!latestHost.exists) return;
      if (latestHost.value != user.uid) rethrow;
      await _leaveAsHost(partyRef, user.uid);
    }
  });

  Future<void> _leaveAsHost(DatabaseReference partyRef, String uid) async {
    final result = await partyRef.runTransaction((current) {
      if (current == null) return Transaction.success(null);
      final party = _map(current);
      if (party == null) {
        throw const PartyRepositoryException(PartyFailureCode.unknown);
      }
      try {
        return Transaction.success(resolveHostDeparture(party, uid));
      } on StateError catch (error) {
        throw PartyRepositoryException(PartyFailureCode.unknown, cause: error);
      }
    });
    if (!result.committed && result.snapshot.exists) {
      throw const PartyRepositoryException(PartyFailureCode.unknown);
    }
  }

  @override
  Future<void> endParty(String partyId) => _authenticated((user) async {
    final ref = _db.ref('parties/$partyId');
    try {
      final host = await ref.child('hostUid').get();
      if (currentUserUid != user.uid) {
        throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
      }
      if (!host.exists) {
        throw const PartyRepositoryException(PartyFailureCode.roomClosed);
      }
      if (host.value != user.uid) {
        throw const PartyRepositoryException(PartyFailureCode.permissionDenied);
      }
      // The server rechecks ownership if an election races this read.
      await ref.remove();
    } catch (_) {
      // The session defers null metadata throughout End, including host
      // verification. Reconcile every rejection: a genuine deletion during
      // that read (or removal) may produce no second event afterward.
      if (currentUserUid == user.uid) {
        DataSnapshot? current;
        try {
          current = await ref.get();
        } catch (_) {
          // An unavailable confirmation must not replace the original error.
        }
        if (current != null && !current.exists) {
          throw const PartyRepositoryException(PartyFailureCode.roomClosed);
        }
      }
      rethrow;
    }
  });

  @override
  Stream<PartyMetadata?> watchMetadata(String partyId) => _typedStream(() {
    _requireUser();
    return _db.ref('parties/$partyId').onValue.map((event) {
      final map = _map(event.snapshot.value);
      return map == null ? null : PartyMetadata.tryFromObservedMap(map);
    });
  });

  @override
  Stream<PartyPlaybackSnapshot?> watchPlayback(String partyId) =>
      _typedStream(() {
        _requireUser();
        return _db
            .ref('parties/$partyId/state')
            .onValue
            .map((event) => _playback(event.snapshot.value));
      });

  @override
  Stream<List<PartyQueueEntry>> watchQueue(String partyId) => _typedStream(() {
    _requireUser();
    return _db.ref('parties/$partyId/queue').onValue.map((event) {
      final map = _map(event.snapshot.value);
      if (map == null) return <PartyQueueEntry>[];
      final keys = map.keys.toList()..sort();
      return [
        for (final key in keys)
          if (_map(map[key]) case final song?)
            PartyQueueEntry.fromMap(key, song),
      ];
    });
  });

  @override
  Future<PartyPlaybackSnapshot?> readPlayback(String partyId) => _authenticated(
    (_) async =>
        _playback((await _db.ref('parties/$partyId/state').get()).value),
  );

  @override
  Future<void> updatePlayback(String partyId, PartyPlaybackSnapshot state) =>
      _authenticated(
        (_) => _db.ref('parties/$partyId/state').update({
          ...state.toMap(),
          'song': state.song?.toMap(),
          'updatedAt': ServerValue.timestamp,
        }),
      );

  @override
  Future<void> addQueueSong(String partyId, SongInfo song) => _authenticated(
    (_) => _db.ref('parties/$partyId/queue').push().set(song.toMap()),
  );

  @override
  Future<void> removeQueueSong(String partyId, String entryId) =>
      _authenticated(
        (_) => _db.ref('parties/$partyId/queue/$entryId').remove(),
      );

  Future<T> _authenticated<T>(Future<T> Function(User) operation) async {
    final user = _requireUser();
    try {
      return await operation(user);
    } on FirebaseException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  Stream<T> _typedStream<T>(Stream<T> Function() source) {
    try {
      return source().transform(
        StreamTransformer<T, T>.fromHandlers(
          handleError: (Object error, StackTrace stack, EventSink<T> sink) =>
              sink.addError(
                error is FirebaseException ? _mapFirebaseFailure(error) : error,
                stack,
              ),
        ),
      );
    } on FirebaseException catch (error, stack) {
      return Stream<T>.error(_mapFirebaseFailure(error), stack);
    }
  }

  static String _firebaseCode(FirebaseException error) =>
      error.code.toLowerCase().replaceAll('_', '-').split('/').last;

  static PartyRepositoryException _mapFirebaseFailure(FirebaseException error) {
    final code = switch (_firebaseCode(error)) {
      'permission-denied' => PartyFailureCode.permissionDenied,
      'network-error' ||
      'network-request-failed' ||
      'disconnected' ||
      'unavailable' => PartyFailureCode.network,
      'unauthenticated' ||
      'expired-token' ||
      'invalid-token' => PartyFailureCode.unauthenticated,
      'aborted' => PartyFailureCode.roomClosed,
      _ => PartyFailureCode.unknown,
    };
    return PartyRepositoryException(code, cause: error);
  }

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map && value.keys.every((key) => key is String)
      ? Map<String, dynamic>.from(value)
      : null;

  static PartyPlaybackSnapshot? _playback(Object? value) {
    final map = _map(value);
    return map == null ? null : PartyPlaybackSnapshot.fromMap(map);
  }

  // ═══════════════════════════════════════════
  //  PARTY MANAGEMENT
  // ═══════════════════════════════════════════

  // ═══════════════════════════════════════════
  //  PARTICIPANTS MANAGEMENT
  // ═══════════════════════════════════════════

  Stream<DatabaseEvent> getPartyParticipantsStream(String partyId) {
    return _db.ref('parties/$partyId/participants').onValue;
  }

  // ═══════════════════════════════════════════
  //  QUEUE MANAGEMENT
  // ═══════════════════════════════════════════

  /// For reordering, we rewrite the entire queue list to maintain strict order effortlessly
  @override
  Future<void> overwriteQueue(String partyId, List<SongInfo> newQueue) =>
      _authenticated((_) async {
        final ref = _db.ref('parties/$partyId/queue');
        final payload = {
          for (final song in newQueue) _pushKey(ref): song.toMap(),
        };
        await ref.set(payload.isEmpty ? null : payload);
      });

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

  /// One-time read of host's current playback state (used after download)
  Future<Map<String, dynamic>?> getPartyState(String partyId) async {
    final snap = await _db.ref('parties/$partyId/state').get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
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

  Future<void> sendMessage(
    String partyId,
    String message, {
    Map<String, dynamic>? songData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final messageData = <String, dynamic>{
      'uid': user.uid,
      'name': user.displayName ?? user.email?.split('@').first ?? 'Guest',
      'photoUrl': user.photoURL ?? '',
      'message': message,
      'timestamp': ServerValue.timestamp,
    };

    if (songData != null) {
      messageData['song'] = songData;
    }

    await _db.ref('parties/$partyId/chat').push().set(messageData);
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
      debugPrint('RealtimeDatabaseService: private message send failed');
    }
  }

  /// Streams the chat messages for a specific private 1-on-1 chat room.
  Stream<DatabaseEvent> getPrivateChatStream(String chatId) {
    return _db
        .ref('private_chats/$chatId/messages')
        .orderByChild('timestamp')
        .onValue;
  }

  // ═══════════════════════════════════════════
  //  USER PRESENCE
  // ═══════════════════════════════════════════

  /// Updates the user's online status using RTDB's .info/connected
  void updateUserPresence() {
    final user = _auth.currentUser;
    if (user == null) return;

    final myStatusRef = _db.ref('status/${user.uid}');
    _db.ref('.info/connected').onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected) {
        // Automatically switch to offline when client disconnects
        myStatusRef
            .onDisconnect()
            .update({'isOnline': false, 'lastSeen': ServerValue.timestamp})
            .then((_) {
              // Set to online
              myStatusRef.set({
                'isOnline': true,
                'lastSeen': ServerValue.timestamp,
              });
            });
      }
    });
  }

  /// Streams the online presence status of a specific user.
  Stream<bool> getUserPresenceStream(String uid) {
    return _db.ref('status/$uid/isOnline').onValue.map((event) {
      return (event.snapshot.value as bool?) ?? false;
    });
  }
}
