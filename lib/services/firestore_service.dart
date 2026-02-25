import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song_info.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Users & Friends ───

  /// Saves or updates the user's data in Firestore.
  Future<void> saveUserToFirestore(User user) async {
    try {
      final docRef = _db.collection('users').doc(user.uid);
      await docRef.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'Unknown DJ',
        'photoUrl': user.photoURL ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('FirestoreService: User data saved for ${user.uid}');
    } catch (e) {
      print('FirestoreService ERROR: Failed to save user: $e');
    }
  }

  /// Searches for a user by their UID. Returns user data or null.
  Future<Map<String, dynamic>?> searchUserByUid(String uid) async {
    try {
      final docSnap = await _db.collection('users').doc(uid).get();
      if (docSnap.exists) {
        return docSnap.data();
      }
    } catch (e) {
      print('FirestoreService ERROR: Failed to search user: $e');
    }
    return null;
  }

  /// Adds a friend for the current user.
  Future<bool> addFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid == friendUid) return false;

    try {
      // First verify the friend actually exists
      final friendDoc = await _db.collection('users').doc(friendUid).get();
      if (!friendDoc.exists) return false;

      // Add to user's friends list subcollection
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .doc(friendUid)
          .set({'uid': friendUid, 'addedAt': FieldValue.serverTimestamp()});

      // Add to friend's followers list subcollection (Incoming Request)
      await _db
          .collection('users')
          .doc(friendUid)
          .collection('followers')
          .doc(user.uid)
          .set({'uid': user.uid, 'addedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      print('FirestoreService ERROR: Failed to add friend: $e');
      return false;
    }
  }

  /// Removes a friend and severs the mutual connection completely.
  Future<bool> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid == friendUid) return false;

    try {
      // Remove from our friends list
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .doc(friendUid)
          .delete();
      // Remove our pending request to them if it exists
      await _db
          .collection('users')
          .doc(friendUid)
          .collection('followers')
          .doc(user.uid)
          .delete();

      // Also remove us from THEIR friends list (mutual sever)
      await _db
          .collection('users')
          .doc(friendUid)
          .collection('friends')
          .doc(user.uid)
          .delete();
      // Remove their pending request to us if it exists
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('followers')
          .doc(friendUid)
          .delete();

      return true;
    } catch (e) {
      print('FirestoreService ERROR: Failed to remove friend: $e');
      return false;
    }
  }

  /// Returns a stream of the current user's friends.
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> friends = [];
          for (var doc in snapshot.docs) {
            final friendUid = doc.id;
            final friendData = await searchUserByUid(friendUid);
            if (friendData != null) {
              friends.add(friendData);
            }
          }
          return friends;
        });
  }

  /// Returns a stream of users who have added the current user (Followers/Incoming Requests).
  Stream<List<Map<String, dynamic>>> getFollowersStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('followers')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> followers = [];
          for (var doc in snapshot.docs) {
            final followerUid = doc.id;
            final followerData = await searchUserByUid(followerUid);
            if (followerData != null) {
              followers.add(followerData);
            }
          }
          return followers;
        });
  }

  // ─── Favorites ───

  /// Gets the collection reference for the current user's favorites
  CollectionReference<Map<String, dynamic>>? get _favoritesRef {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _db.collection('favorites').doc(user.uid).collection('songs');
  }

  /// Toggles a song's favorite status in Firestore.
  /// Returns [true] if it was added, [false] if it was removed.
  Future<bool> toggleFavorite(SongInfo song) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print(
          'FirestoreService: Cannot toggle favorite. User is null (not logged in).',
        );
        return false;
      }
      print(
        'FirestoreService: Toggling favorite for user: ${user.uid}, song: ${song.title}',
      );

      final ref = _favoritesRef;
      if (ref == null) return false;

      final docRef = ref.doc(song.youtubeVideoId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        // Remove favorite
        await docRef.delete();
        print('FirestoreService: Successfully removed favorite.');
        return false;
      } else {
        // Add favorite
        await docRef.set({
          'title': song.title,
          'artist': song.artist,
          'thumbnailUrl': song.thumbnailUrl,
          'youtubeVideoId': song.youtubeVideoId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('FirestoreService: Successfully added favorite.');
        return true;
      }
    } catch (e) {
      print('FirestoreService ERROR: Failed to toggle favorite: $e');
      return false; // Safely return false if something crashes
    }
  }

  /// Returns a stream indicating whether the song is currently a favorite.
  Stream<bool> isFavoriteStream(String videoId) {
    final ref = _favoritesRef;
    if (ref == null) return Stream.value(false);

    return ref.doc(videoId).snapshots().map((snap) => snap.exists);
  }

  /// Returns a stream of all favorite songs for a specific user.
  Stream<List<SongInfo>> getFavoriteSongsStream([String? uid]) {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null) return Stream.value([]);

    final ref = _db.collection('favorites').doc(targetUid).collection('songs');
    return ref.orderBy('addedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SongInfo(
          title: data['title'] ?? '',
          artist: data['artist'] ?? '',
          thumbnailUrl: data['thumbnailUrl'] ?? '',
          youtubeVideoId: data['youtubeVideoId'] ?? doc.id,
        );
      }).toList();
    });
  }

  // ─── Playlists ───

  CollectionReference<Map<String, dynamic>> get _playlistsRef {
    return _db.collection('playlists');
  }

  Future<void> createPlaylist(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _playlistsRef.add({
      'name': name,
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns a stream of playlists for a specific user.
  Stream<List<Map<String, dynamic>>> getPlaylistsStream([String? uid]) {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null) return Stream.value([]);

    return _playlistsRef
        .where('ownerUid', isEqualTo: targetUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          // Sort in memory to avoid requiring a composite index in Firestore
          list.sort((a, b) {
            final t1 = a['createdAt'] as Timestamp?;
            final t2 = b['createdAt'] as Timestamp?;
            if (t1 == null || t2 == null) return 0;
            return t2.compareTo(t1);
          });
          return list;
        });
  }

  Future<void> addSongToPlaylist(String playlistId, SongInfo song) async {
    await _playlistsRef
        .doc(playlistId)
        .collection('songs')
        .doc(song.youtubeVideoId)
        .set({
          'title': song.title,
          'artist': song.artist,
          'thumbnailUrl': song.thumbnailUrl,
          'youtubeVideoId': song.youtubeVideoId,
          'addedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Returns a stream of songs for a specific playlist.
  Stream<List<SongInfo>> getPlaylistSongsStream(String playlistId) {
    return _playlistsRef
        .doc(playlistId)
        .collection('songs')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return SongInfo(
              title: data['title'] ?? '',
              artist: data['artist'] ?? '',
              thumbnailUrl: data['thumbnailUrl'] ?? '',
              youtubeVideoId: data['youtubeVideoId'] ?? doc.id,
            );
          }).toList();
        });
  }
}
