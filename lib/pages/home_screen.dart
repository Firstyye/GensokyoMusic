import 'package:flutter/material.dart';
import '../constant/my_constant.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../constant/my_constant.dart';
import '../pages/profile_screen.dart';
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
      switch (index){
      case 3:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Icon(Icons.search, color: Colors.blue, size: 24.0),
          SizedBox(width: 16.0),

          Icon(Icons.exit_to_app, color: Colors.blue, size: 24.0),
          SizedBox(width: 16.0),
        ],

        leading: Icon(Icons.menu, color: Colors.blue),
        title: Center(
          child: Text('Home Screen', style: TextStyle(color: Colors.black)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "data",
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.settings, color: const Color.fromARGB(255, 128, 128, 128), size: 48),
            const SizedBox(height: 16),
            Row(
              
              children: [
                Container(
                  alignment: Alignment.center,
                  width: 200,
                  height: 200,
                  color: Colors.red,
                  child: const Text("hello"),
                ),
                Container(
                  width: 200,
                  height: 200,
                  color: Colors.blue,
                  child: const Text("hello"),
                ),
                Container(
                  width: 200,
                  height: 200,
                  color: Colors.green,
                  child: const Text("hello"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.blueAccent,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                  "https://avatars.githubusercontent.com/u/43317716?s=400&v=4",
                ),
              ),
            ),
          ],
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
            Icons.gamepad,
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
