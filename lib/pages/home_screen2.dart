import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

class HomeScreen2 extends StatefulWidget {
  @override
  State<HomeScreen2> createState() => _HomeScreenState();
  const HomeScreen2({super.key});
}


class _HomeScreenState extends State<HomeScreen2> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  final screens = [
    Center(child:Text("Home")),
    Center(child:Text("Search")),
    Center(child:Text("Profile"))  
  ];


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
            Icon(Icons.settings, color: Colors.blue, size: 48),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
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
        backgroundColor: Colors.white,
        color: Colors.blueAccent,
        items: [
        Icon(Icons.home, size: 30),
        Icon(Icons.search, size: 30),
        Icon(Icons.person, size: 30),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
        ),
    );
  }
}
