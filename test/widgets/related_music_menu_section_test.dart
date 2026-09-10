import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/song_relations.dart';
import 'package:yo/widgets/related_music_menu_section.dart';

const artistA = SongRelationTarget(
  id: 1,
  kind: SongRelationKind.artist,
  name: 'Artist A',
);
const circleA = SongRelationTarget(
  id: 2,
  kind: SongRelationKind.circle,
  name: 'Circle A',
);
const circleB = SongRelationTarget(
  id: 3,
  kind: SongRelationKind.circle,
  name: 'Circle B',
);

Widget subject({
  SongRelations relations = SongRelations.empty,
  bool isLoading = false,
  required ValueChanged<SongRelationTarget> onSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: RelatedMusicMenuSection(
        relations: relations,
        isLoading: isLoading,
        onSelected: onSelected,
      ),
    ),
  );
}

void main() {
  testWidgets('a single related artist opens directly', (tester) async {
    final selected = <SongRelationTarget>[];
    await tester.pumpWidget(
      subject(
        relations: const SongRelations(artists: [artistA]),
        onSelected: selected.add,
      ),
    );

    await tester.tap(find.byKey(const Key('related_artist_action')));
    await tester.pump();

    expect(selected, [artistA]);
    expect(find.text('Choose Artist'), findsNothing);
  });

  testWidgets('multiple related circles open a picker containing every circle', (
    tester,
  ) async {
    final selected = <SongRelationTarget>[];
    await tester.pumpWidget(
      subject(
        relations: const SongRelations(circles: [circleA, circleB]),
        onSelected: selected.add,
      ),
    );

    await tester.tap(find.byKey(const Key('related_circle_action')));
    await tester.pumpAndSettle();

    expect(find.text('Choose Circle'), findsOneWidget);
    expect(find.text('Circle A'), findsOneWidget);
    expect(find.text('Circle B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('related_target_circle_3')));
    await tester.pumpAndSettle();
    expect(selected, [circleB]);
  });

  testWidgets('unavailable relations stay visible and cannot be tapped', (
    tester,
  ) async {
    final selected = <SongRelationTarget>[];
    await tester.pumpWidget(subject(onSelected: selected.add));

    expect(find.text('Go to Artist'), findsOneWidget);
    expect(find.text('Go to Circle'), findsOneWidget);
    expect(find.text('Go to Album'), findsOneWidget);

    for (final key in [
      'related_artist_action',
      'related_circle_action',
      'related_album_action',
    ]) {
      final tile = tester.widget<ListTile>(find.byKey(Key(key)));
      expect(tile.enabled, isFalse);
      await tester.tap(find.byKey(Key(key)));
    }
    expect(selected, isEmpty);
  });
}
