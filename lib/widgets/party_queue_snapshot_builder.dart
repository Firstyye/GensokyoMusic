import 'package:flutter/widgets.dart';

import '../models/party_session.dart';
import '../models/song_info.dart';

typedef PartyQueueSnapshotWidgetBuilder =
    Widget Function(
      BuildContext context,
      List<PartyQueueEntry> entries,
      SongInfo? currentSong,
    );

/// Rebuilds queue content when either the queue or the current song changes.
class PartyQueueSnapshotBuilder extends StatelessWidget {
  const PartyQueueSnapshotBuilder({
    super.key,
    required this.queueStream,
    required this.initialQueue,
    required this.currentSongStream,
    required this.initialSong,
    required this.builder,
  });

  final Stream<List<PartyQueueEntry>> queueStream;
  final List<PartyQueueEntry> initialQueue;
  final Stream<SongInfo?> currentSongStream;
  final SongInfo? initialSong;
  final PartyQueueSnapshotWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PartyQueueEntry>>(
      stream: queueStream,
      initialData: initialQueue,
      builder: (context, queueSnapshot) {
        final entries = queueSnapshot.data ?? const <PartyQueueEntry>[];
        return StreamBuilder<SongInfo?>(
          stream: currentSongStream,
          initialData: initialSong,
          builder: (context, songSnapshot) =>
              builder(context, entries, songSnapshot.data),
        );
      },
    );
  }
}
