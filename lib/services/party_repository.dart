import '../models/party_session.dart';
import '../models/song_info.dart';

abstract interface class PartyRepository {
  String? get currentUserUid;

  Stream<String?> watchAuthUid();

  String reservePartyId();

  Future<void> armDisconnect(String partyId, PartyRole role);

  Future<void> disarmDisconnect(String partyId, PartyRole role);

  Future<void> createReservedParty(String partyId, SongInfo initialSong);

  Future<bool> isJoinable(String partyId);

  Future<void> joinParty(String partyId);

  Future<void> removeCurrentParticipant(String partyId);

  Future<void> leaveOrTransferParty(String partyId);

  Future<void> endParty(String partyId);

  Stream<PartyMetadata?> watchMetadata(String partyId);

  Stream<PartyPlaybackSnapshot?> watchPlayback(String partyId);

  Stream<List<PartyQueueEntry>> watchQueue(String partyId);

  Future<PartyPlaybackSnapshot?> readPlayback(String partyId);

  Future<void> updatePlayback(String partyId, PartyPlaybackSnapshot state);

  Future<void> addQueueSong(String partyId, SongInfo song);

  Future<void> removeQueueSong(String partyId, String entryId);

  Future<void> overwriteQueue(String partyId, List<SongInfo> songs);
}

class PartyRepositoryException implements Exception {
  final PartyFailureCode code;
  final Object? cause;

  const PartyRepositoryException(this.code, {this.cause});

  @override
  String toString() => 'PartyRepositoryException($code)';
}
