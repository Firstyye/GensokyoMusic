import 'package:flutter/material.dart';

import '../models/song_info.dart';
import '../models/song_relations.dart';
import 'related_music_menu_section.dart';

typedef SongRelationsLoader = Future<SongRelations> Function(String videoId);

class RelatedMusicMenuLoader extends StatelessWidget {
  const RelatedMusicMenuLoader({
    super.key,
    required this.initialSong,
    required this.songStream,
    required this.loadRelations,
    required this.onSelected,
  });

  final SongInfo initialSong;
  final Stream<SongInfo?> songStream;
  final SongRelationsLoader loadRelations;
  final ValueChanged<SongRelationTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SongInfo?>(
      stream: songStream,
      initialData: initialSong,
      builder: (context, songSnapshot) {
        final song = songSnapshot.data ?? initialSong;
        final videoId = song.youtubeVideoId.trim();
        final future = videoId.isEmpty
            ? Future.value(SongRelations.empty)
            : loadRelations(videoId);

        return FutureBuilder<SongRelations>(
          key: ValueKey(videoId),
          future: future,
          builder: (context, relationsSnapshot) {
            return RelatedMusicMenuSection(
              relations: relationsSnapshot.data ?? SongRelations.empty,
              isLoading:
                  relationsSnapshot.connectionState != ConnectionState.done,
              onSelected: onSelected,
            );
          },
        );
      },
    );
  }
}
