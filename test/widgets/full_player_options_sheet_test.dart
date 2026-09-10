import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/models/song_relations.dart';
import 'package:yo/widgets/full_player_options_sheet.dart';

const song = SongInfo(
  title: 'Song',
  artist: 'Artist',
  thumbnailUrl: '',
  youtubeVideoId: 'video',
);

void main() {
  testWidgets('options remain scrollable without overflowing a short screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullPlayerOptionsSheet(
            isFavorite: false,
            initialSong: song,
            songStream: const Stream.empty(),
            loadRelations: (_) async => SongRelations.empty,
            onToggleFavorite: () {},
            onAddToPlaylist: () {},
            onRelatedSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('related_album_action')),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Go to Album'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
