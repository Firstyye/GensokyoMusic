enum SongRelationKind { artist, circle, album }

class SongRelationTarget {
  final int id;
  final SongRelationKind kind;
  final String name;
  final String imageUrl;
  final String subtitle;

  const SongRelationTarget({
    required this.id,
    required this.kind,
    required this.name,
    this.imageUrl = '',
    this.subtitle = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongRelationTarget &&
          id == other.id &&
          kind == other.kind &&
          name == other.name &&
          imageUrl == other.imageUrl &&
          subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(id, kind, name, imageUrl, subtitle);
}

class SongRelations {
  final List<SongRelationTarget> artists;
  final List<SongRelationTarget> circles;
  final List<SongRelationTarget> albums;

  const SongRelations({
    this.artists = const [],
    this.circles = const [],
    this.albums = const [],
  });

  static const empty = SongRelations();

  factory SongRelations.fromTouhouDbSong(Map<String, dynamic> song) {
    final artists = <SongRelationTarget>[];
    final circles = <SongRelationTarget>[];
    final seenArtists = <int>{};
    final seenCircles = <int>{};
    final rawArtists = song['artists'];

    if (rawArtists is List) {
      for (final rawRelation in rawArtists) {
        if (rawRelation is! Map) continue;
        final relation = Map<String, dynamic>.from(rawRelation);
        final rawArtist = relation['artist'];
        if (rawArtist is! Map) continue;
        final artist = Map<String, dynamic>.from(rawArtist);
        final id = artist['id'];
        final name = artist['name'];
        if (id is! int || id <= 0 || name is! String || name.trim().isEmpty) {
          continue;
        }

        final categories = relation['categories']?.toString() ?? '';
        final artistType = artist['artistType']?.toString() ?? '';
        if (categories
                .split(',')
                .map((value) => value.trim())
                .contains('Subject') ||
            artistType == 'Character') {
          continue;
        }

        final kind = artistType == 'Circle' || categories == 'Circle'
            ? SongRelationKind.circle
            : SongRelationKind.artist;
        final seen = kind == SongRelationKind.circle
            ? seenCircles
            : seenArtists;
        if (!seen.add(id)) continue;

        final picture = artist['mainPicture'];
        final imageUrl = picture is Map
            ? (picture['urlThumb'] ?? picture['urlOriginal'] ?? '').toString()
            : '';
        final target = SongRelationTarget(
          id: id,
          kind: kind,
          name: name.trim(),
          imageUrl: imageUrl,
          subtitle: artistType,
        );
        if (kind == SongRelationKind.circle) {
          circles.add(target);
        } else {
          artists.add(target);
        }
      }
    }

    final albums = <SongRelationTarget>[];
    final seenAlbums = <int>{};
    final rawAlbums = song['albums'];
    if (rawAlbums is List) {
      for (final rawAlbum in rawAlbums) {
        if (rawAlbum is! Map) continue;
        final album = Map<String, dynamic>.from(rawAlbum);
        final id = album['id'];
        final name = album['name'];
        if (id is! int || id <= 0 || name is! String || name.trim().isEmpty) {
          continue;
        }
        if (!seenAlbums.add(id)) continue;

        final picture = album['mainPicture'];
        final imageUrl = picture is Map
            ? (picture['urlThumb'] ?? picture['urlOriginal'] ?? '').toString()
            : '';
        albums.add(
          SongRelationTarget(
            id: id,
            kind: SongRelationKind.album,
            name: name.trim(),
            imageUrl: imageUrl,
            subtitle: (album['artistString'] ?? '').toString(),
          ),
        );
      }
    }

    return SongRelations(
      artists: List.unmodifiable(artists),
      circles: List.unmodifiable(circles),
      albums: List.unmodifiable(albums),
    );
  }
}
