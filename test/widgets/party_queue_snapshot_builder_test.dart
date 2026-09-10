import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/widgets/party_queue_snapshot_builder.dart';

const songA = SongInfo(
  title: 'A',
  artist: 'Artist',
  thumbnailUrl: '',
  youtubeVideoId: 'a',
);
const songB = SongInfo(
  title: 'B',
  artist: 'Artist',
  thumbnailUrl: '',
  youtubeVideoId: 'b',
);
const queue = [
  PartyQueueEntry(entryId: 'entry-a', song: songA),
  PartyQueueEntry(entryId: 'entry-b', song: songB),
];

void main() {
  testWidgets('current song rebuilds queue selection without a queue event', (
    tester,
  ) async {
    final queues = StreamController<List<PartyQueueEntry>>.broadcast(
      sync: true,
    );
    final songs = StreamController<SongInfo?>.broadcast(sync: true);
    addTearDown(queues.close);
    addTearDown(songs.close);

    await tester.pumpWidget(
      MaterialApp(
        home: PartyQueueSnapshotBuilder(
          queueStream: queues.stream,
          initialQueue: queue,
          currentSongStream: songs.stream,
          initialSong: songA,
          builder: (context, entries, currentSong) =>
              Text('${entries.length}:${currentSong?.youtubeVideoId}'),
        ),
      ),
    );
    expect(find.text('2:a'), findsOneWidget);

    songs.add(songB);
    await tester.pump();

    expect(find.text('2:b'), findsOneWidget);
    expect(find.text('2:a'), findsNothing);

    queues.add(queue);
    await tester.pump();

    expect(find.text('2:b'), findsOneWidget);
    expect(find.text('2:a'), findsNothing);
  });
}
