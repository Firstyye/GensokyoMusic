import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/models/song_relations.dart';
import 'package:yo/widgets/related_music_menu_loader.dart';

const songA = SongInfo(
  title: 'Song A',
  artist: 'Artist A',
  thumbnailUrl: '',
  youtubeVideoId: 'video-a',
);
const songB = SongInfo(
  title: 'Song B',
  artist: 'Artist B',
  thumbnailUrl: '',
  youtubeVideoId: 'video-b',
);
const relatedArtistB = SongRelationTarget(
  id: 22,
  kind: SongRelationKind.artist,
  name: 'Related Artist B',
);

void main() {
  testWidgets('a song change ignores a stale relation lookup', (tester) async {
    final songChanges = StreamController<SongInfo?>.broadcast();
    final lookupA = Completer<SongRelations>();
    final lookupB = Completer<SongRelations>();
    final selected = <SongRelationTarget>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelatedMusicMenuLoader(
            initialSong: songA,
            songStream: songChanges.stream,
            loadRelations: (videoId) => switch (videoId) {
              'video-a' => lookupA.future,
              'video-b' => lookupB.future,
              _ => Future.value(SongRelations.empty),
            },
            onSelected: selected.add,
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('related_artist_action')))
          .enabled,
      isFalse,
    );

    songChanges.add(songB);
    await tester.pump();
    lookupA.complete(
      const SongRelations(
        artists: [
          SongRelationTarget(
            id: 11,
            kind: SongRelationKind.artist,
            name: 'Stale Artist A',
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('related_artist_action')))
          .enabled,
      isFalse,
    );

    lookupB.complete(const SongRelations(artists: [relatedArtistB]));
    await tester.pump();
    await tester.tap(find.byKey(const Key('related_artist_action')));
    expect(selected, [relatedArtistB]);

    await songChanges.close();
  });
}
