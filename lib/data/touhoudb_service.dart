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
    if (genre == 'All') {
      final randomOffset = Random().nextInt(100); // Variety from top 100
      final response = await http.get(
        Uri.parse(
          "$baseUrl/songs?sort=RatingScore&start=$randomOffset&maxResults=10&fields=MainPicture,PVs",
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
                    song['mainPicture']?['urlThumb'] ??
                    'https://i.ytimg.com/vi/$pvId/hqdefault.jpg',
              ),
            );
          }
        }
        return results;
      }
      throw Exception("Failed to load recommended songs");
    } else {
      // Fetch by Tag for better accuracy in Genre
      final randomOffset = Random().nextInt(50); // Variety within top results
      final response = await http.get(
        Uri.parse(
          "$baseUrl/songs?tagName=${Uri.encodeComponent(genre)}&sort=RatingScore&start=$randomOffset&maxResults=10&fields=MainPicture,PVs",
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
                    song['mainPicture']?['urlThumb'] ??
                    'https://i.ytimg.com/vi/$pvId/hqdefault.jpg',
              ),
            );
          }
        }
        return results;
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
      "$baseUrl/songs?query=${Uri.encodeComponent(query)}&maxResults=15&fields=MainPicture,PVs",
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

  Future<List<Albumslist>> getTopRatedAlbums() async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/albums?sort=RatingTotal&maxResults=10&fields=MainPicture",
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
              albumUrlData['mainPicture']['urlThumb'];
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
      throw Exception("Failed to load top rated albums");
    }
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
    final response = await http.get(
      Uri.parse("$baseUrl/albums/$albumId/tracks?fields=PVs"),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      List<SongInfo> results = [];
      for (var track in items) {
        final songData = track['song'];
        if (songData != null) {
          final pvId = _extractYoutubePvId(songData['pvs']);

          results.add(
            SongInfo(
              youtubeVideoId: pvId,
              title: songData['defaultName'] ?? songData['name'] ?? 'Unknown',
              artist: songData['artistString'] ?? 'Unknown Artist',
              thumbnailUrl: pvId.isNotEmpty
                  ? 'https://i.ytimg.com/vi/$pvId/hqdefault.jpg'
                  : '',
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
