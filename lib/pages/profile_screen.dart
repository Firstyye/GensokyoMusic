import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yo/pages/loginscreen.dart';
import '../constant/my_constant.dart';
import '../widgets/_buildMenuItem.dart';
import '../pages/home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool isSwitched = true;
  int _selectedIndex = 3;
  String _getUserEmail() {

    if (user?.email != null && user!.email!.isNotEmpty) {
      return user!.email!;
    }

 
    if (user?.providerData != null) {
      for (var profile in user!.providerData) {
        if (profile.email != null && profile.email!.isNotEmpty) {
          return profile.email!;
        }
      }
    }

    
    return 'Cirno_Gensokyo@gmail.com';
  }
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => HomeScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get screen width to make dynamic decisions if needed
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isSwitched ? backgroundColor : darkModeBackgroundColor,

      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: isSwitched ? backgroundColor : darkModeBackgroundColor,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            radius: 20,
            child: Icon(
              Icons.arrow_back_ios_outlined,
              color: isSwitched ? Colors.blueAccent : darkThemeColor,
              size: 24,
            ),
          ),
        ),
        title: Text(
          'Profile',
          style: bodyTextStyle.copyWith(
            color: isSwitched ? Colors.black : darkThemeTextColor,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.withOpacity(0.2),
              radius: 20,
              child: Icon(
                Icons.notifications_active_rounded,
                color: isSwitched ? Colors.blueAccent : darkThemeColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),

      // 2. Wrap in SingleChildScrollView to prevent overflow on small screens
      body: SingleChildScrollView(
        child: Center(
          // 3. ConstrainedBox ensures it doesn't get too wide on tablets/web
          // but shrinks to fit on mobile.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Profile Picture Stack
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 160,
                        child: GestureDetector(
                          onTap: () {
                            print("Show Banner");
                            showDialog(
                              context: context,
                              builder: (context) => GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(5),

                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: isSwitched
                                          ? backgroundColor
                                          : darkThemeColor,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        'lib/pages/images/banner.jpg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              image: DecorationImage(
                                image: AssetImage(
                                  'lib/pages/images/banner.jpg',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 10,
                        left: 10,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: () {
                            // showDialog(context: context, builder: (context) => Dialog(
                            //   backgroundColor: backgroundColor,
                            //   shape: RoundedRectangleBorder(
                            //     borderRadius: BorderRadius.circular(10),
                            //   ),
                            //   child: Padding(
                            //     padding: const EdgeInsets.all(8.0),
                            //     child: Column(
                            //       crossAxisAlignment: CrossAxisAlignment.center,
                            //       mainAxisSize: MainAxisSize.min,
                            //       mainAxisAlignment: MainAxisAlignment.center,
                            //       children: [
                            //         Text('Change Banner', style: bodyTextStyle.copyWith(
                            //           color: const Color.fromARGB(255, 0, 0, 0),
                            //           fontSize: screenWidth >= 600 ? 16 : screenWidth < 600 && screenWidth >= 400 ? 12 : 10,
                            //         ),),

                            //       ],
                            //       ),
                            //   ),
                            // ));
                          },

                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.palette_outlined,
                                  color: isSwitched
                                      ? Colors.blueAccent
                                      : darkThemeColor,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Edit Banner",
                                  style: bodyTextStyle.copyWith(
                                    color: Colors.white,
                                    fontSize: screenWidth >= 600
                                        ? 16
                                        : screenWidth < 600 &&
                                              screenWidth >= 400
                                        ? 12
                                        : 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 0,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 110,
                              backgroundColor: isSwitched
                                  ? Colors.blueAccent
                                  : darkThemeColor,
                              child: CircleAvatar(
                                radius: 105,
                                backgroundColor: isSwitched
                                    ? backgroundColor
                                    : darkModeBackgroundColor,
                                child: CircleAvatar(
                                  radius: 100,
                                  backgroundImage: AssetImage(
                                    'lib/pages/images/avatar.jpg',
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: isSwitched
                                    ? lightBackgroundColor
                                    : darkThemeColor,
                                child: Icon(
                                  Icons.edit,
                                  color: isSwitched
                                      ? Colors.white
                                      : Colors.black,
                                  size: 30,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  user?.displayName ?? 'Cirno, The Fairy',
                  style: headerTextStyle.copyWith(
                    color: isSwitched ? Colors.black : darkThemeTextColor,
                    fontSize: 30,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 24,
                      color: isSwitched ? Colors.black : darkThemeTextColor,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Joined since : 5 January 2023',
                      style: bodyTextStyle.copyWith(
                        color: isSwitched ? Colors.black : darkThemeTextColor,
                        fontWeight: FontWeight.w100,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Email Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shadowColor: Colors.transparent,
                    side: BorderSide(
                      color: isSwitched
                          ? Color.fromRGBO(45, 146, 208, 1)
                          : darkThemeColor,
                    ),
                    backgroundColor: isSwitched
                        ? const Color.fromARGB(255, 214, 235, 255)
                        : darkElevatedButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _getUserEmail(),
                      style: bodyTextStyle.copyWith(
                        color: isSwitched
                            ? const Color.fromRGBO(45, 146, 208, 1)
                            : darkElevatedButtonTextColor,
                        // Make font smaller on very small screens if needed
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text("Settings"),
                      // Divider(color: Colors.blueAccent),
                      // Top Item (Rounded Top)
                      MenuItemWidget(
                        icon: Icons.edit,
                        text: "Edit Profile",
                        isTop: true,
                        isSwitched: isSwitched,
                      ),

                      // Middle Items (No Rounded Corners)
                      MenuItemWidget(
                        icon: Icons.lock,
                        text: "Add Pin",
                        isSwitched: isSwitched,
                      ),
                      MenuItemWidget(
                        icon: Icons.settings,
                        text: "Settings",
                        isSwitched: isSwitched,
                      ),

                      MenuItemWidget(
                        icon: Icons.group_add_sharp,
                        text: "Invite a friend",
                        isSwitched: isSwitched,
                      ),
                      MenuItemWidget(
                        icon: Icons.help,
                        text: "Help & Support",
                        isSwitched: isSwitched,
                      ),
                      MenuItemWidget(
                        icon: isSwitched ? Icons.light_mode : Icons.dark_mode,
                        text: "Change Theme",
                        isChangeTheme: true,
                        isSwitched: isSwitched,
                        onThemeChanged: (value) {
                          setState(() {
                            isSwitched = value;
                          });
                        },
                      ),

                      // Bottom Item (Rounded Bottom + Logout Color)\
                      MenuItemWidget(
                        icon: Icons.logout,
                        text: "Logout",
                        isBottom: true,
                        isDestructive: true,
                        isSwitched: isSwitched,
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          await GoogleSignIn.instance.signOut();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Extra space at bottom for scrolling
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
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
