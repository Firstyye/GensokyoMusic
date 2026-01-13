import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isSwitched = true;
  int _selectedIndex = 3;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get screen width to make dynamic decisions if needed
    double screenWidth = MediaQuery.of(context).size.width;
    

    return Scaffold(
      backgroundColor: isSwitched ? backgroundColor : darkModeBackgroundColor,

      appBar: AppBar(
        // shape: Border(bottom: BorderSide(color: Colors.blueAccent, width: 2.5)),
        scrolledUnderElevation: 0.0,
        backgroundColor: isSwitched ? backgroundColor : darkModeBackgroundColor,
        leading: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Icon(
            Icons.arrow_back_ios_outlined,
            color:  isSwitched ? Colors.blueAccent : darkThemeColor,
            size: 24,
          ),
        ),
        title: Text(
          'Profile',
          style: bodyTextStyle.copyWith(color: isSwitched ? Colors.black : darkThemeTextColor, fontSize: 24),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Icon(
              Icons.notifications_active_rounded,
              color:  isSwitched ? Colors.blueAccent : darkThemeColor,
              size: 24,
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
                            showDialog(context: context, builder: (context) => GestureDetector(
                              onTap: (){
                                Navigator.of(context).pop();
                              },
                              child: Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child : Container(
                                    padding: EdgeInsets.all(5),

                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: isSwitched ? backgroundColor : darkThemeColor,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        'lib/pages/images/banner.jpg',
                                        fit: BoxFit.contain,
                                      ),
                                    ) 
                                  )
                              
                              
                              ),
                            ));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              
                              color: Colors.blueAccent,
                              image: DecorationImage(
                                image: AssetImage(
                                  'lib/pages/images/banner.jpg',
                                 
                                ),
                                fit : BoxFit.cover
                              )
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
                          onPressed: (){
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
                                
                                Icon(Icons.palette_outlined, color: isSwitched ? Colors.blueAccent : darkThemeColor,),
                                SizedBox(width: 5,),
                                Text("Edit Banner" , style : bodyTextStyle.copyWith(
                                  color: Colors.white,
                                  fontSize: screenWidth >= 600 ? 16 : screenWidth < 600 && screenWidth >= 400 ? 12 : 10,
                                  ))
                              ],
                            ),
                          ),
                        )),

                      Positioned(
                        bottom: 0,
                        child: Stack(
                          
                          children: [
                            CircleAvatar(
                              radius: 110,
                              backgroundColor: isSwitched ? Colors.blueAccent : darkThemeColor,
                              child: CircleAvatar(
                                radius: 105,
                                backgroundColor: isSwitched ? backgroundColor : darkModeBackgroundColor,
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
                                backgroundColor: isSwitched ? lightBackgroundColor : darkThemeColor,
                                child: Icon(
                                  Icons.edit,
                                  color: isSwitched ? Colors.white : Colors.black,
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
                  'Cirno, The Fairy',
                  style: headerTextStyle.copyWith(
                    color: isSwitched ? Colors.black : darkThemeTextColor,
                    fontSize: 30),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, size: 24, color: isSwitched ? Colors.black : darkThemeTextColor,),
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
                      color: isSwitched ? Color.fromRGBO(45, 146, 208, 1) : darkThemeColor ,
                    ),
                    backgroundColor: isSwitched ? const Color.fromARGB(255, 214, 235, 255) : darkElevatedButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: 
                    Text(
                      'Cirno_Gensokyo@gmail.com',
                      style: bodyTextStyle.copyWith(
                        color: isSwitched ? const Color.fromRGBO(45, 146, 208, 1) : darkElevatedButtonTextColor,
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
                      _buildMenuItem(
                        icon: Icons.edit,
                        text: "Edit Profile",
                        isTop: true,
                      ),

                      // Middle Items (No Rounded Corners)
                      _buildMenuItem(icon: Icons.lock, text: "Add Pin"),
                      _buildMenuItem(icon: Icons.settings, text: "Settings"),
                      
                      _buildMenuItem(
                        icon: Icons.group_add_sharp,
                        text: "Invite a friend",
                      ),
                      _buildMenuItem(icon: Icons.help, text: "Help & Support"),
                      _buildMenuItem(
                        icon: isSwitched ? Icons.light_mode : Icons.dark_mode, 
                        text: "Change Theme",
                        isChangeTheme: true
                        ),

                      

                      // Bottom Item (Rounded Bottom + Logout Color)\
                      _buildMenuItem(
                        icon: Icons.logout,
                        text: "Logout",
                        isBottom: true,
                        isDestructive: true,
                        onTap: () {
                          // Handle Logout
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
        items:  [
          Icon(Icons.home, size: 30, color: isSwitched ? Colors.white : bottomNavigationBarIcon),
          Icon(Icons.search, size: 30, color: isSwitched ? Colors.white : bottomNavigationBarIcon),
          Icon(Icons.calendar_month, size: 30, color: isSwitched ? Colors.white : bottomNavigationBarIcon),
          Icon(Icons.people, size: 30, color: isSwitched ? Colors.white : bottomNavigationBarIcon),
        ],
      ),
    );
  }

  // --- REUSABLE WIDGET FUNCTION ---
  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    bool isTop = false,
    bool isBottom = false,
    bool isDestructive = false,
    bool isChangeTheme = false,
    VoidCallback? onTap,
  }) {
    // Determine colors based on whether it is a "Destructive" (Logout) action
    final Color iconColor = isDestructive ? dangerColor : lightBackgroundColor;
    final Color iconDarkColor = isDestructive ? dangerDarkColor : darkThemeColor;


    final Color textColor = isDestructive
        ? dangerColor
        : Colors.black; // Assuming black for default text
    final Color darkTextColor = isDestructive ? dangerDarkColor : darkThemeTextColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Allow width to stretch to the parent Constraint (up to 600px)
        width: double.infinity,
        height: 50, // Slightly taller for better touch targets
        margin: const EdgeInsets.only(bottom: 2), // Small gap between items
        decoration: BoxDecoration(
          color: isDestructive ? (isSwitched ?  dangerTransparentColor : dangerTransparentDarkColor) : (isSwitched ? lightThemeBackgroundColor : darkThemeSecondaryColor),
          borderRadius: BorderRadius.vertical(
            top: isTop ? const Radius.circular(12) : Radius.zero,
            bottom: isBottom ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child:  Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: isSwitched ? iconColor : iconDarkColor, size: 24),
                  const SizedBox(width: 15),
                  Text(text, style: bodyTextStyle.copyWith(color: isSwitched ? textColor : darkTextColor)),
                ],
              ),
              if (!isDestructive)
                isChangeTheme ? Switch(
                  value: isSwitched,
                  onChanged: (value) {
                    setState(() {
                      isSwitched = value;
                    });
                  },
                  activeThumbColor: Colors.blueAccent,
                  inactiveThumbColor: darkThemeColor,
                  inactiveTrackColor: darkElevatedButtonColor,
                  trackOutlineColor: WidgetStatePropertyAll(  
                    isSwitched ? Colors.blueAccent : darkThemeColor,
                  ),
                ) : 
                Icon( 
                  Icons.arrow_forward,
                  color: isSwitched ? lightBackgroundColor : darkThemeColor,
                  size: 24,
                ),
              
              
            ],
          ),
        ),
      ),
    );
  }
}
