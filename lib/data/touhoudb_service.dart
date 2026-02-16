import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yo/data/customSongsList.dart';
import 'package:yo/data/albumsList.dart';
import 'package:yo/data/toprateSong.dart';

class TouhouDBService {
  final String baseUrl = "https://touhoudb.com/api";

  Future<List<customSongList>> fetchSongs() async {
    final myID = 3515; 
    final response = await http.get(
      Uri.parse(
        "$baseUrl/songLists/${myID}/songs?fields=MainPicture&maxResults=20",
      ),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'];
      return items
          .map(
            (song) => customSongList(
              name: song['song']['defaultName'],
              artist: song['song']['artistString'],
              image : song['song']['mainPicture']['urlOriginal'] ?? "",
            ),
          )
          .toList();
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
       // Assuming pvs is a list in the first item
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
          name: albumData['defaultName'] ?? albumData['name'] ?? 'Unknown Album',
          artist: artistName,
          image: imageUrl.isNotEmpty 
              ? imageUrl 
              : "", // ใส่ URL รูป Default ถ้าไม่มีรูป
        );
      }).toList();

    } else {
      throw Exception("Failed to load album");
    }
  }
  Future<List<TopRatedSongList>> fetchTopRatedSongs() async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/songs?sort=RatingScore&maxResults=5&fields=MainPicture",
      ),
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> items = data['items'];
      return items
          .map(
            (song) => TopRatedSongList(
              name: song['defaultName'],
              artist: song['artistString'],
              image : song['mainPicture']['urlThumb'] ?? "",
            ),
          )
          .toList();
    } else {
      throw Exception("Failed to load songs");
    }
  }
}
