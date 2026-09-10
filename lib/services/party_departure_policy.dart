Map<String, dynamic>? resolveHostDeparture(
  Map<String, dynamic> party,
  String departingUid,
) {
  final hostUid = party['hostUid'];
  if (hostUid is! String ||
      hostUid.isEmpty ||
      departingUid.isEmpty ||
      hostUid != departingUid) {
    throw StateError('Only the current host can transfer the party.');
  }
  final rawParticipants = party['participants'];
  if (rawParticipants is! Map) {
    throw StateError('Party participants are malformed.');
  }
  final participants = <String, dynamic>{};
  for (final entry in rawParticipants.entries) {
    final uid = entry.key;
    final participant = entry.value;
    if (uid is! String ||
        uid.isEmpty ||
        participant is! Map ||
        participant['name'] is! String ||
        (participant['name'] as String).isEmpty ||
        participant['joinedAt'] is! num) {
      throw StateError('Party participant is malformed.');
    }
    participants[uid] = participant;
  }
  final departingParticipant = participants[departingUid];
  if (departingParticipant is! Map || departingParticipant['isHost'] != true) {
    throw StateError('The departing host participant is malformed.');
  }
  participants.remove(departingUid);
  if (participants.isEmpty) {
    return null;
  }

  final candidates = participants.entries.toList()
    ..sort((left, right) {
      final leftJoinedAt = (left.value as Map)['joinedAt'] as num;
      final rightJoinedAt = (right.value as Map)['joinedAt'] as num;
      final joinedAtComparison = leftJoinedAt.compareTo(rightJoinedAt);
      return joinedAtComparison != 0
          ? joinedAtComparison
          : left.key.compareTo(right.key);
    });
  final promotedUid = candidates.first.key;
  final promoted = candidates.first.value as Map;
  final normalizedParticipants = <String, dynamic>{
    for (final entry in participants.entries)
      entry.key: <String, dynamic>{
        ...Map<String, dynamic>.from(entry.value as Map),
        'isHost': entry.key == promotedUid,
      },
  };

  return <String, dynamic>{
    ...party,
    'hostUid': promotedUid,
    'hostName': promoted['name'],
    'participants': normalizedParticipants,
  };
}
