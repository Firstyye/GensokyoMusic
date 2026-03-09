import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:yo/data/customSongsList.dart';
import 'package:yo/data/albumsList.dart';
import 'package:yo/data/toprateSong.dart';
import 'package:yo/data/popular_circle.dart';
import '../models/song_info.dart';

class TouhouDBService {
  final String baseUrl = "https://touhoudb.com/api";

  /// Extract the first YouTube pvId from a pvs array, or empty string.
  String _extractYoutubePvId(List<dynamic>? pvs) {
    if (pvs == null || pvs.isEmpty) return '';
    for (final pv in pvs) {
      if (pv['service'] == 'Youtube' && pv['disabled'] != true) {
        return pv['pvId'] ?? '';
      }
    }
    return '';
  }

  Future<List<customSongList>> fetchSongs() async {
    final myID = 3515;

    final response = await http.get(
      Uri.parse(
        "$baseUrl/songLists/$myID/songs?fields=Albums,MainPicture,PVs&maxResults=20",
      ),
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'];

      List<customSongList> songList = await Future.wait(
        items.map((item) async {
          var songData = item['song'];
          String imageUrl = "";

          List<dynamic> albums = songData['albums'] ?? [];

          if (albums.isNotEmpty) {
            int albumId = albums[0]['id'];
            try {
              final albumResponse = await http.get(
                Uri.parse("$baseUrl/albums/$albumId?fields=MainPicture"),
              );
              if (albumResponse.statusCode == 200) {
                var albumData = json.decode(albumResponse.body);
                if (albumData['mainPicture'] != null) {
                  imageUrl = albumData['mainPicture']['urlOriginal'];
                }
              }
            } catch (e) {
              debugPrint("Error fetching album image for ID $albumId: $e");
            }
          }

          if (imageUrl.isEmpty && songData['mainPicture'] != null) {
            imageUrl = songData['mainPicture']['urlOriginal'];
          }

          // Extract YouTube PV ID
          final pvId = _extractYoutubePvId(songData['pvs']);

          return customSongList(
            id: songData['id'] ?? 0,
            name: songData['defaultName'] ?? songData['name'],
            artist: songData['artistString'],
            image: imageUrl,
            pvId: pvId,
          );
        }),
      );

      return songList;
    } else {
      throw Exception("Failed to load songs");
    }
  }

  Future<List<Albumslist>> fetchAlbum() async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/users/7255/albums?purchaseStatuses=Wishlisted&fields=MainPicture,PVs",
      ),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'];

      return items.map((item) {
        final albumData = item['album'];
        final List pvs = albumData['pvs'] ?? [];
        String artistName;

        if (pvs.isNotEmpty) {
          artistName = pvs[0]['author'];
        } else {
          artistName = albumData['artistString'] ?? 'Unknown Artist';
        }
        String imageUrl = "";
        if (albumData['mainPicture'] != null) {
          imageUrl = albumData['mainPicture']['urlOriginal'];
        }

        return Albumslist(
          id: albumData['id'] ?? 0,
          name:
              albumData['defaultName'] ?? albumData['name'] ?? 'Unknown Album',
          artist: artistName,
          image: imageUrl.isNotEmpty ? imageUrl : "",
        );
      }).toList();
    } else {
      throw Exception("Failed to load album");
    }
  }

  Future<List<SongInfo>> getRecommendedSongs({String genre = 'All'}) async {
    final rng = Random();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    if (genre == 'All') {
      final sortOptions = [
        'RatingScore',
        'AdditionDate',
        'PublishDate',
        'FavoritedTimes',
        'Name',
      ];
      final randomSort = sortOptions[rng.nextInt(sortOptions.length)];

      // VocaDB has tens of thousands of songs — use a large offset range
      // for genuine variety. Retry with smaller offset if overshoot.
      int offset = rng.nextInt(2000);
      for (int attempt = 0; attempt < 3; attempt++) {
        final response = await http.get(
          Uri.parse(
            "$baseUrl/songs?sort=$randomSort&start=$offset&maxResults=10&fields=MainPicture,PVs&_cb=$cacheBuster",
          ),
        );
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          List<dynamic> items = data['items'] ?? [];
          List<SongInfo> results = [];
          for (var song in items) {
            final pvId = _extractYoutubePvId(song['pvs']);
            if (pvId.isNotEmpty) {
              results.add(
                SongInfo(
                  youtubeVideoId: pvId,
                  title: song['defaultName'] ?? song['name'] ?? 'Unknown',
                  artist: song['artistString'] ?? 'Unknown Artist',
                  thumbnailUrl:
                      song['mainPicture']?['urlOriginal'] ??
                      song['mainPicture']?['urlThumb'] ??
                      'https://i.ytimg.com/vi/$pvId/hqdefault.jpg',
                ),
              );
            }
          }
          if (results.isNotEmpty) {
            results.shuffle(rng); // Shuffle for extra randomness
            return results;
          }
        }
        // Overshoot → halve offset and retry
        offset = (offset ~/ 2);
      }
      return []; // All retries exhausted
    } else {
      // ── Genre-specific fetch ──
      final Map<String, int> genreTags = {
        'chiptune': 27,
        'drum and bass': 20,
        'EDM': 17,
        'electronic': 12,
        'eurobeat': 14,
        'hardcore techno': 83,
        'house': 22,
        'jazz': 7,
        'metal': 10,
        'orchestra': 80,
        'piano arrangement': 1202,
        'rock': 3,
        'techno': 79,
        'Touhou-style': 338,
        'trance': 13,
      };

      final tagId = genreTags[genre];
      if (tagId == null) return [];

      // Randomize sort to avoid always getting the same top-rated songs
      final genreSorts = ['RatingScore', 'AdditionDate', 'FavoritedTimes'];
      final randomSort = genreSorts[rng.nextInt(genreSorts.length)];

      // Use larger offset (retry with smaller if empty)
      int offset = rng.nextInt(50);
      for (int attempt = 0; attempt < 3; attempt++) {
        final response = await http.get(
          Uri.parse(
            "$baseUrl/songs?tagId[]=$tagId&sort=$randomSort&start=$offset&maxResults=10&fields=MainPicture,PVs&_cb=$cacheBuster",
          ),
        );
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          List<dynamic> items = data['items'] ?? [];
          List<SongInfo> results = [];
          for (var song in items) {
            final pvId = _extractYoutubePvId(song['pvs']);
            if (pvId.isNotEmpty) {
              results.add(
                SongInfo(
                  youtubeVideoId: pvId,
                  title: song['defaultName'] ?? song['name'] ?? 'Unknown',
                  artist: song['artistString'] ?? 'Unknown Artist',
                  thumbnailUrl:
                      song['mainPicture']?['urlOriginal'] ??
                      song['mainPicture']?['urlThumb'] ??
                      'https://i.ytimg.com/vi/$pvId/hqdefault.jpg',
                ),
              );
            }
          }
          if (results.isNotEmpty) {
            results.shuffle(rng);
            return results;
          }
        }
        // Overshoot → halve offset and retry
        offset = (offset ~/ 2);
      }
      return [];
    }
  }

  Future<List<TopRatedSongList>> fetchTopRatedSongs() async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/songs?sort=RatingScore&maxResults=5&fields=MainPicture,PVs",
      ),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'];
      return items
          .map(
            (song) => TopRatedSongList(
              id: song['id'] ?? 0,
              name: song['defaultName'],
              artist: song['artistString'],
              image: song['mainPicture']?['urlThumb'] ?? "",
              pvId: _extractYoutubePvId(song['pvs']),
            ),
          )
          .toList();
    } else {
      throw Exception("Failed to load songs");
    }
  }

  Future<List<SongInfo>> searchSongs(String query) async {
    final url = Uri.parse(
      "$baseUrl/songs?query=${Uri.encodeComponent(query)}&nameMatchMode=Auto&maxResults=15&fields=MainPicture,PVs",
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      List<SongInfo> results = [];
      for (var song in items) {
        final pvId = _extractYoutubePvId(song['pvs']);
        if (pvId.isNotEmpty) {
          results.add(
            SongInfo(
              youtubeVideoId: pvId,
              title: song['defaultName'] ?? song['name'] ?? 'Unknown',
              artist: song['artistString'] ?? 'Unknown Artist',
              thumbnailUrl:
                  song['mainPicture']?['urlThumb'] ??
                  'https://i.ytimg.com/vi/$pvId/hqdefault.jpg',
            ),
          );
        }
      }
      return results;
    } else {
      throw Exception("Failed to search songs");
    }
  }

  Future<List<Albumslist>> searchAlbums(String query) async {
    final url = Uri.parse(
      "$baseUrl/albums?query=${Uri.encodeComponent(query)}&nameMatchMode=Auto&maxResults=15&fields=MainPicture",
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      return items.map((albumUrlData) {
        String imageUrl = "";
        if (albumUrlData['mainPicture'] != null) {
          imageUrl =
              albumUrlData['mainPicture']['urlOriginal'] ??
              albumUrlData['mainPicture']['urlThumb'] ??
              "";
        }
        return Albumslist(
          id: albumUrlData['id'] ?? 0,
          name:
              albumUrlData['defaultName'] ??
              albumUrlData['name'] ??
              'Unknown Album',
          artist: albumUrlData['artistString'] ?? 'Unknown Artist',
          image: imageUrl,
        );
      }).toList();
    } else {
      throw Exception("Failed to search albums");
    }
  }

  Future<List<PopularCircle>> searchArtists(String query) async {
    final url = Uri.parse(
      "$baseUrl/artists?query=${Uri.encodeComponent(query)}&nameMatchMode=Auto&maxResults=15&fields=MainPicture",
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      return items.map((artistData) {
        String imageUrl = "";
        if (artistData['mainPicture'] != null) {
          imageUrl =
              artistData['mainPicture']['urlOriginal'] ??
              artistData['mainPicture']['urlThumb'] ??
              "";
        }
        return PopularCircle(
          id: artistData['id'] ?? 0,
          name:
              artistData['defaultName'] ??
              artistData['name'] ??
              'Unknown Artist',
          imageUrl: imageUrl,
        );
      }).toList();
    } else {
      throw Exception("Failed to search artists");
    }
  }

  Future<List<Albumslist>> getArtistAlbums(
    int artistId, {
    String sort = 'ReleaseDate',
    int maxResults = 10,
  }) async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/albums?artistId[]=$artistId&sort=$sort&maxResults=$maxResults&fields=MainPicture",
      ),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      return items.map((albumUrlData) {
        String imageUrl = "";
        if (albumUrlData['mainPicture'] != null) {
          imageUrl =
              albumUrlData['mainPicture']['urlOriginal'] ??
              albumUrlData['mainPicture']['urlThumb'] ??
              "";
        }
        return Albumslist(
          id: albumUrlData['id'] ?? 0,
          name:
              albumUrlData['defaultName'] ??
              albumUrlData['name'] ??
              'Unknown Album',
          artist: albumUrlData['artistString'] ?? 'Unknown Artist',
          image: imageUrl,
        );
      }).toList();
    } else {
      throw Exception("Failed to load artist albums");
    }
  }

  Future<List<Albumslist>> getTopRatedAlbums() async {
    final rng = Random();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final sortOptions = ['RatingTotal', 'AdditionDate', 'Name'];
    final randomSort = sortOptions[rng.nextInt(sortOptions.length)];

    // Fetch 20 albums to have a pool; filter to those with playable tracks
    int offset = rng.nextInt(500);
    for (int attempt = 0; attempt < 3; attempt++) {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/albums?sort=$randomSort&start=$offset&maxResults=20&fields=MainPicture&_cb=$cacheBuster",
        ),
      );
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        List<dynamic> items = data['items'] ?? [];
        if (items.isNotEmpty) {
          List<Albumslist> validAlbums = [];

          // Check all albums concurrently for playable tracks
          await Future.wait(
            items.map((albumUrlData) async {
              final int albumId = albumUrlData['id'] ?? 0;
              if (albumId == 0) return;
              try {
                final trackRes = await http.get(
                  Uri.parse("$baseUrl/albums/$albumId/tracks?fields=PVs"),
                );
                if (trackRes.statusCode == 200) {
                  var tData = json.decode(trackRes.body);
                  List<dynamic> tItems = tData is List
                      ? tData
                      : (tData['items'] ?? []);
                  for (var track in tItems) {
                    final songData = track['song'];
                    if (songData != null &&
                        _extractYoutubePvId(songData['pvs']).isNotEmpty) {
                      // Has at least 1 playable track → keep this album
                      String imageUrl = "";
                      if (albumUrlData['mainPicture'] != null) {
                        imageUrl =
                            albumUrlData['mainPicture']['urlOriginal'] ??
                            albumUrlData['mainPicture']['urlThumb'];
                      }
                      validAlbums.add(
                        Albumslist(
                          id: albumId,
                          name:
                              albumUrlData['defaultName'] ??
                              albumUrlData['name'] ??
                              'Unknown Album',
                          artist:
                              albumUrlData['artistString'] ?? 'Unknown Artist',
                          image: imageUrl,
                        ),
                      );
                      break; // Found one playable track, no need to check more
                    }
                  }
                }
              } catch (e) {
                debugPrint("Error checking tracks for album $albumId: $e");
              }
            }),
          );

          if (validAlbums.isNotEmpty) {
            validAlbums.shuffle(rng);
            return validAlbums.take(10).toList();
          }
        }
      }
      // Overshoot -> halve the offset and retry
      offset = (offset ~/ 2);
    }
    return [];
  }

  Future<List<PopularCircle>> getPopularCircles() async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/artists?artistTypes=Circle&sort=SongCount&maxResults=15&fields=MainPicture",
      ),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      return items.map((artistData) {
        String imageUrl = "";
        if (artistData['mainPicture'] != null) {
          imageUrl =
              artistData['mainPicture']['urlOriginal'] ??
              artistData['mainPicture']['urlThumb'];
        }
        return PopularCircle(
          id: artistData['id'] ?? 0,
          name:
              artistData['defaultName'] ??
              artistData['name'] ??
              'Unknown Circle',
          imageUrl: imageUrl,
        );
      }).toList();
    } else {
      throw Exception("Failed to load popular circles");
    }
  }

  Future<List<SongInfo>> getAlbumTracks(int albumId) async {
    // Include MainPicture in field just in case, though tracks usually use album art
    final response = await http.get(
      Uri.parse("$baseUrl/albums/$albumId/tracks?fields=PVs,MainPicture"),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      // The API returns a list directly or in an 'items' field depending on the specific endpoint version
      List<dynamic> items = [];
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] != null) {
        items = data['items'];
      }

      List<SongInfo> results = [];
      for (var track in items) {
        final songData = track['song'];
        final trackName = track['name'] ?? 'Unknown Track';

        if (songData != null) {
          final pvId = _extractYoutubePvId(songData['pvs']);

          results.add(
            SongInfo(
              youtubeVideoId: pvId,
              title: songData['defaultName'] ?? songData['name'] ?? trackName,
              artist: songData['artistString'] ?? 'Unknown Artist',
              thumbnailUrl: pvId.isNotEmpty
                  ? 'https://i.ytimg.com/vi/$pvId/hqdefault.jpg'
                  : (songData['mainPicture']?['urlOriginal'] ??
                        songData['mainPicture']?['urlThumb'] ??
                        ''),
            ),
          );
        } else {
          // Add as a non-playable track so the list isn't empty
          results.add(
            SongInfo(
              youtubeVideoId: '',
              title: trackName,
              artist: 'Unknown Artist',
              thumbnailUrl: '',
            ),
          );
        }
      }
      return results;
    } else {
      throw Exception("Failed to load album tracks");
    }
  }
}
