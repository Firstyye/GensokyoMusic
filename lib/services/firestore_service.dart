import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song_info.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
