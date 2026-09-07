import 'song_info.dart';

enum PartySessionPhase { idle, joining, active, leaving, ended, failed }

enum PartyRole { host, listener }

enum PartyFailureCode {
  roomClosed,
  notFound,
  notJoinable,
  unauthenticated,
  permissionDenied,
  network,
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

  const PartySessionState.joining({
    required String partyId,
    int generation = 0,
  }) : this._(
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
  }) : this._(
          phase: PartySessionPhase.active,
          partyId: partyId,
          role: role,
          generation: generation,
          failure: null,
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
}

class PartyActionResult {
  final PartyFailureCode? failure;

  const PartyActionResult._(this.failure);

  const PartyActionResult.success() : this._(null);

  const PartyActionResult.failure(PartyFailureCode failure) : this._(failure);

  bool get isSuccess => failure == null;
}

class PartyMetadata {
  final String partyId;
  final String hostUid;
  final bool isJoinable;
  final int generation;
  final int createdAt;

  const PartyMetadata({
    required this.partyId,
    required this.hostUid,
    required this.isJoinable,
    required this.generation,
    this.createdAt = 0,
  });

  factory PartyMetadata.fromMap(String partyId, Map<String, dynamic> map) {
    return PartyMetadata(
      partyId: partyId,
      hostUid: _stringValue(map['hostUid']),
      isJoinable: map['isJoinable'] is bool ? map['isJoinable'] as bool : false,
      generation: _intValue(map['generation']),
      createdAt: _intValue(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostUid': hostUid,
      'isJoinable': isJoinable,
      'generation': generation,
      'createdAt': createdAt,
    };
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
  final String addedByUid;
  final int addedAt;

  const PartyQueueEntry({
    required this.entryId,
    required this.song,
    required this.addedByUid,
    required this.addedAt,
  });

  factory PartyQueueEntry.fromMap(String entryId, Map<String, dynamic> map) {
    final rawSong = map['song'];
    return PartyQueueEntry(
      entryId: entryId,
      song: SongInfo.fromMap(
        rawSong is Map ? Map<String, dynamic>.from(rawSong) : const {},
      ),
      addedByUid: _stringValue(map['addedByUid']),
      addedAt: _intValue(map['addedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'song': song.toMap(),
      'addedByUid': addedByUid,
      'addedAt': addedAt,
    };
  }
}

int _intValue(Object? value) => value is num ? value.toInt() : 0;

String _stringValue(Object? value) => value is String ? value : '';
