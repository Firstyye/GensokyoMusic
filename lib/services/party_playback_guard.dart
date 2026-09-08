/// Identifies one source load within one acknowledged party session.
class PartyPlaybackTicket {
  const PartyPlaybackTicket({
    required this.generation,
    required this.partyId,
    required this.videoId,
    required this.loadToken,
  });
  final int generation;
  final String partyId;
  final String videoId;
  final int loadToken;
}

class PartyPlaybackGuard {
  int _loadToken = 0;
  int _lastUpdatedAt = -1;

  PartyPlaybackTicket beginLoad({
    required int generation,
    required String partyId,
    required String videoId,
  }) => PartyPlaybackTicket(
    generation: generation,
    partyId: partyId,
    videoId: videoId,
    loadToken: ++_loadToken,
  );

  bool accepts(
    PartyPlaybackTicket ticket, {
    required int generation,
    required String? partyId,
    required String? videoId,
  }) =>
      ticket.loadToken == _loadToken &&
      ticket.generation == generation &&
      ticket.partyId == partyId &&
      ticket.videoId == videoId;

  bool acceptTimestamp(int timestamp) {
    if (timestamp < _lastUpdatedAt) return false;
    _lastUpdatedAt = timestamp;
    return true;
  }

  void invalidate() {
    ++_loadToken;
    _lastUpdatedAt = -1;
  }
}

/// Each caller observes its own failure without poisoning subsequent commits.
class PartyPlaybackCommitQueue {
  Future<void> _tail = Future<void>.value();
  Future<void> run(Future<void> Function() commit) {
    final result = _tail.then((_) => commit());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
