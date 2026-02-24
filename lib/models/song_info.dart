/// Lightweight model holding metadata for the currently playing song.
/// Used by AudioPlayerService to broadcast song info to the UI.
class SongInfo {
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String youtubeVideoId;

  const SongInfo({
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.youtubeVideoId,
  });

  /// Convenience factory for creating a SongInfo from a map (e.g. Firestore doc).
  factory SongInfo.fromMap(Map<String, dynamic> map) {
    return SongInfo(
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      youtubeVideoId: map['youtubeVideoId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'youtubeVideoId': youtubeVideoId,
    };
  }
}
