import 'package:flutter/material.dart';

import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../models/song_relations.dart';
import 'related_music_menu_loader.dart';

class FullPlayerOptionsSheet extends StatelessWidget {
  const FullPlayerOptionsSheet({
    super.key,
    required this.isFavorite,
    required this.initialSong,
    required this.songStream,
    required this.loadRelations,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onRelatedSelected,
  });

  final bool isFavorite;
  final SongInfo initialSong;
  final Stream<SongInfo?> songStream;
  final SongRelationsLoader loadRelations;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;
  final ValueChanged<SongRelationTarget> onRelatedSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? Colors.redAccent : Colors.white70,
              ),
              title: Text(
                isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                style: bodyTextStyle.copyWith(color: Colors.white),
              ),
              onTap: onToggleFavorite,
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: Colors.white70,
              ),
              title: Text(
                'Add to Playlist',
                style: bodyTextStyle.copyWith(color: Colors.white),
              ),
              onTap: onAddToPlaylist,
            ),
            const Divider(color: Colors.white12, height: 1),
            RelatedMusicMenuLoader(
              initialSong: initialSong,
              songStream: songStream,
              loadRelations: loadRelations,
              onSelected: onRelatedSelected,
            ),
          ],
        ),
      ),
    );
  }
}
