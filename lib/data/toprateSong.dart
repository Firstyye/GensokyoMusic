class TopRatedSongList {
  final int id;
  final String name;
  final String artist;
  final String image;
  final String pvId; // YouTube Video ID (empty if none)

  TopRatedSongList({
    required this.id,
    required this.name,
    required this.artist,
    required this.image,
    this.pvId = '',
  });
}
