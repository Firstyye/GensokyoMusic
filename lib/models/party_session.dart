import 'song_info.dart';

enum PartySessionPhase { idle, joining, active, leaving, ended, failed }

enum PartyRole { host, listener }

enum PartyFailureCode {
  unauthenticated,
  roomClosed,
  permissionDenied,
  network,
  alreadyBusy,
  unknown,
}

class PartySessionState {
  final PartySessionPhase phase;
  final String? partyId;
  final PartyRole? role;
  final int generation;
  final PartyFailureCode? failure;

  const PartySessionState._({
    required this.phase,
    required this.partyId,
    required this.role,
    required this.generation,
    required this.failure,
  });

  const PartySessionState.idle({int generation = 0})
    : this._(
        phase: PartySessionPhase.idle,
        partyId: null,
        role: null,
        generation: generation,
        failure: null,
      );

  const PartySessionState.joining({required String partyId, int generation = 0})
    : this._(
        phase: PartySessionPhase.joining,
        partyId: partyId,
        role: null,
        generation: generation,
        failure: null,
      );

  const PartySessionState.active({
    required String partyId,
    required PartyRole role,
    required int generation,
    PartyFailureCode? warning,
  }) : this._(
         phase: PartySessionPhase.active,
         partyId: partyId,
         role: role,
         generation: generation,
         failure: warning,
       );

  const PartySessionState.leaving({
    required String partyId,
    required PartyRole role,
    required int generation,
  }) : this._(
         phase: PartySessionPhase.leaving,
         partyId: partyId,
         role: role,
         generation: generation,
         failure: null,
       );

  const PartySessionState.ended({int generation = 0})
    : this._(
        phase: PartySessionPhase.ended,
        partyId: null,
        role: null,
        generation: generation,
        failure: null,
      );

  const PartySessionState.failed({
    required PartyFailureCode failure,
    int generation = 0,
  }) : this._(
         phase: PartySessionPhase.failed,
         partyId: null,
         role: null,
         generation: generation,
         failure: failure,
       );

  bool get isActive => phase == PartySessionPhase.active;

  bool get isHost => isActive && role == PartyRole.host;

  PartyFailureCode? get warning => isActive ? failure : null;
}

class PartyActionResult {
  final PartyFailureCode? failure;

  const PartyActionResult._(this.failure);

  const PartyActionResult.success() : this._(null);

  const PartyActionResult.failure(PartyFailureCode failure) : this._(failure);

  bool get isSuccess => failure == null;
}

class PartyMetadata {
  final String hostUid;
  final String hostName;
  final int createdAt;

  const PartyMetadata({
    required this.hostUid,
    required this.hostName,
    required this.createdAt,
  });

  /// Decodes only party roots that can still accept a participant join.
  ///
  /// The party ID is intentionally supplied by the repository path rather than
  /// duplicated in the Realtime Database payload.
  static PartyMetadata? tryFromMap(Map<String, dynamic> map) =>
      _decode(map, allowDepartedHost: false);

  /// An existing session must survive the short interval between host removal
  /// and the server's election/deletion transaction. Missing membership alone
  /// is not a room-deletion signal; invalid metadata or an invalid *present*
  /// host still is. Join preflights must continue using [tryFromMap].
  static PartyMetadata? tryFromObservedMap(Map<String, dynamic> map) =>
      _decode(map, allowDepartedHost: true);

  static PartyMetadata? _decode(
    Map<String, dynamic> map, {
    required bool allowDepartedHost,
  }) {
    final hostUid = map['hostUid'];
    final hostName = map['hostName'];
    final createdAt = map['createdAt'];
    final participants = map['participants'];
    final hostParticipant = participants is Map ? participants[hostUid] : null;
    if (map['status'] != 'active' ||
        hostUid is! String ||
        hostUid.isEmpty ||
        hostName is! String ||
        createdAt is! num ||
        map['state'] is! Map ||
        (participants != null && participants is! Map)) {
      return null;
    }
    final hostAbsent =
        participants == null ||
        (participants is Map && !participants.containsKey(hostUid));
    if (!(allowDepartedHost && hostAbsent) &&
        (hostParticipant is! Map || hostParticipant['isHost'] != true)) {
      return null;
    }
    return PartyMetadata(
      hostUid: hostUid,
      hostName: hostName,
      createdAt: createdAt.toInt(),
    );
  }
}

class PartyPlaybackSnapshot {
  final bool isPlaying;
  final int positionSeconds;
  final int updatedAt;
  final SongInfo? song;

  const PartyPlaybackSnapshot({
    required this.isPlaying,
    required this.positionSeconds,
    required this.updatedAt,
    this.song,
  });

  factory PartyPlaybackSnapshot.fromMap(Map<String, dynamic> map) {
    final rawSong = map['song'];
    return PartyPlaybackSnapshot(
      isPlaying: map['isPlaying'] is bool ? map['isPlaying'] as bool : false,
      positionSeconds: _intValue(map['positionSeconds']),
      updatedAt: _intValue(map['updatedAt']),
      song: rawSong is Map
          ? SongInfo.fromMap(Map<String, dynamic>.from(rawSong))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isPlaying': isPlaying,
      'positionSeconds': positionSeconds,
      'updatedAt': updatedAt,
      if (song != null) 'song': song!.toMap(),
    };
  }
}

class PartyQueueEntry {
  final String entryId;
  final SongInfo song;

  const PartyQueueEntry({required this.entryId, required this.song});

  factory PartyQueueEntry.fromMap(String entryId, Map<String, dynamic> map) {
    return PartyQueueEntry(entryId: entryId, song: SongInfo.fromMap(map));
  }

  Map<String, dynamic> toMap() => song.toMap();
}

/// Firebase payload construction without depending on the Firebase SDK.
class PartyDatabaseCodec {
  static Map<String, dynamic> createPayload({
    required String uid,
    required String name,
    required String photoUrl,
    required SongInfo song,
    required String queueEntryId,
    required Object timestamp,
  }) => {
    'status': 'active',
    'hostUid': uid,
    'hostName': name,
    'createdAt': timestamp,
    'state': {
      'isPlaying': false,
      'positionSeconds': 0,
      'updatedAt': timestamp,
      'song': song.toMap(),
    },
    'participants': {
      uid: {
        'name': name,
        'photoUrl': photoUrl,
        'joinedAt': timestamp,
        'isHost': true,
      },
    },
    'queue': {queueEntryId: song.toMap()},
  };
}

int _intValue(Object? value) => value is num ? value.toInt() : 0;
