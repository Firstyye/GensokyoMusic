import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:yo/data/customSongsList.dart';
import 'package:yo/data/albumsList.dart';
import 'package:yo/data/toprateSong.dart';

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
}
