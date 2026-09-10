import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/song_relations.dart';

void main() {
  test('separates music artists from circles and omits subject characters', () {
    final relations = SongRelations.fromTouhouDbSong({
      'artists': [
        {
          'categories': 'Producer',
          'artist': {
            'id': 10,
            'name': 'Producer A',
            'artistType': 'Producer',
            'mainPicture': {'urlThumb': 'producer.jpg'},
          },
        },
        {
          'categories': 'Circle',
          'artist': {'id': 20, 'name': 'Circle A', 'artistType': 'Circle'},
        },
        {
          'categories': 'Subject',
          'artist': {
            'id': 30,
            'name': 'Character A',
            'artistType': 'Character',
          },
        },
        {
          'categories': 'Producer',
          'artist': {
            'id': 10,
            'name': 'Producer A duplicate',
            'artistType': 'Producer',
          },
        },
      ],
      'albums': [
        {
          'id': 40,
          'name': 'Album A',
          'artistString': 'Circle A',
          'mainPicture': {'urlOriginal': 'album.jpg'},
        },
        {'id': 40, 'name': 'Album A duplicate'},
      ],
    });

    expect(relations.artists.map((target) => target.name), ['Producer A']);
    expect(relations.artists.single.imageUrl, 'producer.jpg');
    expect(relations.circles.map((target) => target.name), ['Circle A']);
    expect(relations.albums.map((target) => target.name), ['Album A']);
    expect(relations.albums.single.subtitle, 'Circle A');
    expect(relations.albums.single.imageUrl, 'album.jpg');
  });

  test('malformed and absent relationship data produces disabled groups', () {
    final relations = SongRelations.fromTouhouDbSong({
      'artists': [
        {
          'categories': 'Producer',
          'artist': {'id': 0, 'name': ''},
        },
        'bad artist',
      ],
      'albums': 'bad albums',
    });

    expect(relations.artists, isEmpty);
    expect(relations.circles, isEmpty);
    expect(relations.albums, isEmpty);
  });
}
