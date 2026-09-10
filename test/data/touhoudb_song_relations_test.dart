import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yo/data/touhoudb_service.dart';

void main() {
  test(
    'looks up a song by its exact YouTube PV id and parses relations',
    () async {
      late Uri requestedUri;
      final service = TouhouDBService(
        getRequest: (uri) async {
          requestedUri = uri;
          return http.Response(
            jsonEncode({
              'artists': [
                {
                  'categories': 'Circle',
                  'artist': {
                    'id': 7,
                    'name': 'Sound Circle',
                    'artistType': 'Circle',
                  },
                },
              ],
              'albums': [
                {
                  'id': 8,
                  'name': 'Sound Album',
                  'artistString': 'Sound Circle',
                },
              ],
            }),
            200,
          );
        },
      );

      final relations = await service.getSongRelationsByYoutubeVideoId('yt/id');

      expect(requestedUri.path, '/api/songs/byPv');
      expect(requestedUri.queryParameters, {
        'pvService': 'Youtube',
        'pvId': 'yt/id',
        'fields': 'Albums,Artists,MainPicture',
      });
      expect(relations.circles.single.name, 'Sound Circle');
      expect(relations.albums.single.name, 'Sound Album');
    },
  );

  test('missing TouhouDB song keeps every relation unavailable', () async {
    final service = TouhouDBService(
      getRequest: (_) async => http.Response('', 404),
    );

    final relations = await service.getSongRelationsByYoutubeVideoId('missing');

    expect(relations.artists, isEmpty);
    expect(relations.circles, isEmpty);
    expect(relations.albums, isEmpty);
  });
}
