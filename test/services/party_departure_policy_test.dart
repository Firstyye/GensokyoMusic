import 'package:flutter_test/flutter_test.dart';
import 'package:yo/services/party_departure_policy.dart';

void main() {
  test('promotes the oldest listener and preserves the party payload', () {
    final party = <String, dynamic>{
      'hostUid': 'host',
      'hostName': 'Host',
      'createdAt': 10,
      'status': 'active',
      'state': <String, dynamic>{
        'isPlaying': true,
        'positionSeconds': 42,
        'updatedAt': 20,
      },
      'queue': <String, dynamic>{
        'first': <String, dynamic>{'id': 'song-1'},
      },
      'chat': <String, dynamic>{
        'message': <String, dynamic>{'text': 'hello'},
      },
      'participants': <String, dynamic>{
        'host': <String, dynamic>{
          'name': 'Host',
          'photoUrl': 'host.png',
          'joinedAt': 1,
          'isHost': true,
        },
        'newer': <String, dynamic>{
          'name': 'Newer Listener',
          'photoUrl': 'newer.png',
          'joinedAt': 3,
          'isHost': false,
        },
        'oldest': <String, dynamic>{
          'name': 'Oldest Listener',
          'photoUrl': 'oldest.png',
          'joinedAt': 2,
          'isHost': false,
        },
      },
    };

    final result = resolveHostDeparture(party, 'host');

    expect(result?['hostUid'], 'oldest');
    expect(result?['hostName'], 'Oldest Listener');
    expect(result?['participants']['host'], isNull);
    expect(result?['participants']['oldest']['isHost'], isTrue);
    expect(result?['participants']['newer']['isHost'], isFalse);
    expect(result?['state'], party['state']);
    expect(result?['queue'], party['queue']);
    expect(result?['chat'], party['chat']);
    expect(party['hostUid'], 'host');
    expect(party['participants']['host']['isHost'], isTrue);
    expect(party['participants']['oldest']['isHost'], isFalse);
  });

  test('breaks equal joinedAt values by participant UID', () {
    final party = <String, dynamic>{
      'hostUid': 'host',
      'participants': <String, dynamic>{
        'host': <String, dynamic>{
          'name': 'Host',
          'joinedAt': 1,
          'isHost': true,
        },
        'z-listener': <String, dynamic>{
          'name': 'Z Listener',
          'joinedAt': 2,
          'isHost': false,
        },
        'a-listener': <String, dynamic>{
          'name': 'A Listener',
          'joinedAt': 2,
          'isHost': false,
        },
      },
    };

    final result = resolveHostDeparture(party, 'host');

    expect(result?['hostUid'], 'a-listener');
  });

  test('deletes the party when the departing host is alone', () {
    final party = <String, dynamic>{
      'hostUid': 'host',
      'participants': <String, dynamic>{
        'host': <String, dynamic>{
          'name': 'Host',
          'joinedAt': 1,
          'isHost': true,
        },
      },
    };

    expect(resolveHostDeparture(party, 'host'), isNull);
  });

  test('rejects departure by a participant who is not the room host', () {
    final party = <String, dynamic>{
      'hostUid': 'host',
      'participants': <String, dynamic>{
        'host': <String, dynamic>{
          'name': 'Host',
          'joinedAt': 1,
          'isHost': true,
        },
        'listener': <String, dynamic>{
          'name': 'Listener',
          'joinedAt': 2,
          'isHost': false,
        },
      },
    };

    expect(
      () => resolveHostDeparture(party, 'listener'),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects malformed participant collections and candidates', () {
    final malformedParties = <Map<String, dynamic>>[
      <String, dynamic>{'hostUid': 'host', 'participants': 'not-a-map'},
      <String, dynamic>{
        'hostUid': 'host',
        'participants': <String, dynamic>{
          'host': <String, dynamic>{
            'name': 'Host',
            'joinedAt': 1,
            'isHost': true,
          },
          'listener': <String, dynamic>{
            'name': '',
            'joinedAt': 2,
            'isHost': false,
          },
        },
      },
      <String, dynamic>{
        'hostUid': 'host',
        'participants': <String, dynamic>{
          'host': <String, dynamic>{
            'name': 'Host',
            'joinedAt': 1,
            'isHost': true,
          },
          'listener': <String, dynamic>{
            'name': 'Listener',
            'joinedAt': 'bad-time',
            'isHost': false,
          },
        },
      },
      <String, dynamic>{
        'hostUid': 'host',
        'participants': <String, dynamic>{
          'host': <String, dynamic>{
            'name': 'Host',
            'joinedAt': 1,
            'isHost': true,
          },
          '': <String, dynamic>{
            'name': 'Listener',
            'joinedAt': 2,
            'isHost': false,
          },
        },
      },
    ];

    for (final party in malformedParties) {
      expect(
        () => resolveHostDeparture(party, 'host'),
        throwsA(isA<StateError>()),
        reason: 'Malformed party should be rejected: $party',
      );
    }
  });
}
