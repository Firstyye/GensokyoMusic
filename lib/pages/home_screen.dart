import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_icons/cupertino_icons.dart';
import '../constant/my_constant.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:mobkit_dashed_border/mobkit_dashed_border.dart';
import '../constant/my_constant.dart';
import '../pages/profile_screen.dart';


import '../widgets/_buildSongMenu.dart';
import '../widgets/_FeatureBanner.dart';
import '../widgets/_buildMiniPlayer.dart';
import '../widgets/_SongCard.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
  const HomeScreen({super.key});
}

class _HomeScreenState extends State<HomeScreen> {
  bool isSwitched = true;
  int _selectedIndex = 0;

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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE STRONGEST',
                    style: bodyTextStyle.copyWith(
                      fontSize: 8,
                      color: Colors.blueAccent
                      ),
                  ),
                  Text(
                    'Cirno, The Fairy',
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

          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            radius: 20,
            child: Icon(Icons.exit_to_app, color: dangerColor, size: 24.0),
          ),
          SizedBox(width: 16.0),
        ],
      ),

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
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
                              backgroundImage: 'lib/pages/images/SongBanner/TOHO_BOSSNOVA8.jpg',
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FeatureBanner(
                            titlename:
                                "Chou Saikyou! Saishuu Kichiku Imouto Flandre S",
                            circlename: "COOL&CREATE",
                          ),
                          FeatureBanner(
                            titlename:
                                "Touhou Hits Covers -Ska Punk Flavor-",
                            circlename: "IOSYS",
                            backgroundimage: 'lib/pages/images/SongBanner/SkaPunkFlavor.jpg',
                          ),
                          FeatureBanner(
                            titlename:
                                "Santa Prisma",
                            circlename: "	魂音泉, (TINY PLANETS)",
                            backgroundimage: "lib/pages/images/SongBanner/SantaPrisma.jpg",
                          ),
                          
                        ],
                      ),
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
                    SongMenu(
                      number: "1",
                      title: "Koi no Hyoketsu Otenba Yukemuri Cirno Onsen", 
                      artist: "IOSYS",
                      image: 'lib/pages/images/SongBanner/1383.jpg',
                    ),
                    SongMenu(
                      number: "2",
                      title: "Sanae-san", 
                      artist: "RD-Sounds feat. めらみぽっぷ",
                      image: 'lib/pages/images/SongBanner/sanae_san.jpg',
                    ),
                    SongMenu(
                      number: "3",
                      title: "Cirno's Perfect Math Class", 
                      artist: "IOSYS",
                      image: 'lib/pages/images/SongBanner/Cirno.jpg',
                    ),
                    SongMenu(
                      number: "4",
                      title: "クオリア", 
                      artist: "IOSYS",
                      image: "lib/pages/images/SongBanner/ROCKIN'ON.jpg",
                    ),
                    SongMenu(
                      number: "5",
                      title: "Narcissus no Sayonara, Goodbye to Narcissus", 
                      artist: "ShibayanRecords",
                      image: 'lib/pages/images/SongBanner/TOHO_BOSSNOVA2.jpg',
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 80)),
                  ],
                ),
                
                Positioned(bottom: 5, left: 0, right: 0, child: MiniPlayer()),
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
