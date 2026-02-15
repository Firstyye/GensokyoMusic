import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yo/pages/loginscreen.dart';
import '../constant/my_constant.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:mobkit_dashed_border/mobkit_dashed_border.dart';
import '../constant/my_constant.dart';
import '../pages/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/_buildSongMenu.dart';
import '../widgets/_FeatureBanner.dart';
import '../widgets/_buildMiniPlayer.dart';
import '../widgets/_SongCard.dart';
import 'package:yo/data/touhoudb_service.dart';
import 'package:yo/data/customSongsList.dart';
import 'package:yo/data/albumsList.dart';
import 'package:yo/data/toprateSong.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
  const HomeScreen({super.key});
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool isSwitched = true;
  int _selectedIndex = 0;
  final TouhouDBService _service = TouhouDBService();
  late Future<List<customSongList>> _songsFuture;
  late Future<List<Albumslist>> _albumsFuture;
  late Future<List<TopRatedSongList>> _topRatedSongsFuture;
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    _songsFuture = _service.fetchSongs();
    _albumsFuture = _service.fetchAlbum();
    _topRatedSongsFuture = _service.fetchTopRatedSongs();
    isLoading = false;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 3:
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => ProfileScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        shape: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1.0),
        ),
        leadingWidth: 200,
        leading: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                radius: 22,
                child: CircleAvatar(
                  backgroundImage: AssetImage('lib/pages/images/avatar.jpg'),
                  radius: 20,
                ),
              ),
            ),
            SizedBox(width: 5.0),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                      left: 5,
                      right: 5,
                      top: 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 1),
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'MEMBER',
                      style: bodyTextStyle.copyWith(
                        fontSize: 8,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  Text(
                    overflow: TextOverflow.ellipsis,
                    user?.displayName ?? 'Cirno, The Fairy',
                    style: bodyTextStyle.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            radius: 20,
            child: Icon(Icons.search, color: Colors.blue, size: 24.0),
          ),
          SizedBox(width: 16.0),

          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn.instance.signOut();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => LoginScreen()));
            },
            child: CircleAvatar(
              backgroundColor: Colors.grey.withOpacity(0.2),
              radius: 20,
              child: Icon(Icons.exit_to_app, color: dangerColor, size: 24.0),
            ),
          ),
          SizedBox(width: 16.0),
        ],
      ),

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
            child: Stack(
              children: [
                ListView(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Live Parties',
                              style: headerTextStyle.copyWith(fontSize: 20),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.play_circle_fill,
                              color: Colors.red,
                              size: 30,
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: bodyTextStyle.copyWith(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: EdgeInsets.only(top: 20.0, bottom: 20),
                        child: Row(
                          children: [
                            SongCard(
                              title: 'Tomboyish Girl in Love',
                              viewerCount: '128',
                              backgroundImage: 'lib/pages/images/banner.jpg',
                            ),
                            SongCard(
                              title: 'Ghost flight in the sky',
                              viewerCount: '82',
                              backgroundImage:
                                  'lib/pages/images/SongBanner/TOHO_BOSSNOVA8.jpg',
                            ),

                            Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.only(right: 15.0),
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                border: DashedBorder.all(
                                  dashLength: 5,
                                  color: Colors.blueAccent,
                                ),
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blueAccent
                                            .withOpacity(0.2),
                                        radius: 20,
                                        child: Icon(
                                          CupertinoIcons.sparkles,
                                          color: Colors.blueAccent,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Start a Party',
                                    style: bodyTextStyle.copyWith(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  Text(
                                    "(Tap here)",
                                    style: bodyTextStyle.copyWith(
                                      fontSize: 10,
                                      color: Colors.black.withOpacity(0.35),
                                      fontWeight: FontWeight.w100,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Feature Circle",
                          style: headerTextStyle.copyWith(fontSize: 20),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          CupertinoIcons.sparkles,
                          color: Colors.blueAccent,
                          size: 30,
                        ),
                      ],
                    ),
                    FutureBuilder(
                      future: _albumsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Text("Error loading albums");
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text("No albums found");
                        }
                        final albums = snapshot.data!;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: albums.map((album) {
                              return FeatureBanner(
                                titlename: album.name,
                                circlename: album.artist,
                                buttonname: "NEW ALBUM",
                                backgroundimage: album.image,
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    Row(
                      children: [
                        Text(
                          "Top 5 in Gensokyo's Radio",
                          style: headerTextStyle.copyWith(fontSize: 20),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.emoji_events,
                          color: Colors.amberAccent,
                          size: 30,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    FutureBuilder(future: _topRatedSongsFuture, builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text("Error loading songs");
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Text("No songs found");
                      }
                      final songs = snapshot.data!;
                      return Column(
                        children: songs.map((song) {
                          String index = (songs.indexOf(song) + 1).toString();
                          
                          return SongMenu(
                            title: song.name,
                            artist: song.artist,
                            image: song.image,
                            number: index,
                          );
                        }).toList(),
                      );
                    }),
                    Padding(padding: EdgeInsets.only(bottom: 95)),
                  ],
                ),

                Positioned(bottom: 20, left: 0, right: 0, child: MiniPlayer()),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: CurvedNavigationBar(
        height: 75,
        index: _selectedIndex,
        backgroundColor: Colors.transparent,
        color: isSwitched ? Colors.blueAccent : darkThemeColor,
        onTap: _onItemTapped,
        items: [
          Icon(
            Icons.home,
            size: 30,
            color: isSwitched ? Colors.white : bottomNavigationBarIcon,
          ),
          Icon(
            Icons.search,
            size: 30,
            color: isSwitched ? Colors.white : bottomNavigationBarIcon,
          ),
          Icon(
            Icons.play_circle_fill,
            size: 30,
            color: isSwitched ? Colors.white : bottomNavigationBarIcon,
          ),
          Icon(
            Icons.people,
            size: 30,
            color: isSwitched ? Colors.white : bottomNavigationBarIcon,
          ),
        ],
      ),
    );
  }
}
