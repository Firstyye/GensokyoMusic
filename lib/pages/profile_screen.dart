
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 3;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(height: 70),
            Stack(
              children:[
                CircleAvatar(
                  radius: 105,
                  backgroundColor: Colors.blueAccent,
                  child: CircleAvatar(
                  radius: 100,
                  backgroundImage: NetworkImage("https://avatars.githubusercontent.com/u/43317716?s=400&v=4"),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius:30,
                    backgroundColor: lightBackgroundColor,
                    child : Icon(
                      Icons.edit,
                      color: Colors.white,
                      size  :30,
                    )
                  ),
                )
                ] ,
              ),
            SizedBox(height: 20,),
            Text('Cirno, The Fairy', 
            style: headerTextStyle.copyWith(
              fontSize: 30
            ),
           ),
            SizedBox(height: 20,),
            ElevatedButton(
              style : ElevatedButton.styleFrom(
                
                side: BorderSide(color: Color.fromRGBO(45, 146, 208, 1)),
                backgroundColor: const Color.fromARGB(255, 214, 235, 255),
                foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                shape : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  
    
                )
              ),
              onPressed: (){}, 
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Cirno_Gensokyo@gmail.com', 
                style: bodyTextStyle.copyWith(
                  color: Color.fromRGBO(45, 146, 208, 1),
                
                ),),
              ), 
              ),
              SizedBox(height: 30,),
              Padding(
                padding: const EdgeInsets.fromLTRB(25,25,25,5),
                child: Container(
                  width: 600,
                  height: 40,
                  
                  decoration: BoxDecoration(
                    color: darkBackgroundColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12)
                    )
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.edit, color: lightBackgroundColor, size: 24,),
                      ),
                      Text("Edit Profile", style: bodyTextStyle,),
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_forward, color: lightBackgroundColor, size: 24,),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 5),
                child: Container(
                  width: 600,
                  height: 40,
                  decoration: BoxDecoration(
                    color: darkBackgroundColor,
                    
                  
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.lock, color: lightBackgroundColor, size: 24,),
                      ),
                      Text("Add Pin", style: bodyTextStyle,),
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_forward, color: lightBackgroundColor, size: 24,),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 5),
                child: Container(
                  width: 600,
                  height: 40,
                  decoration: BoxDecoration(
                    color: darkBackgroundColor,
                    
                    
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.settings, color: lightBackgroundColor, size: 24,),
                      ),
                      Text("Settings", style: bodyTextStyle,),
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_forward, color: lightBackgroundColor, size: 24,),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 5),
                child: Container(
                  width: 600,
                  height: 40,
                  decoration: BoxDecoration(
                    color: darkBackgroundColor,
                    
                    
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.group_add_sharp, color: lightBackgroundColor, size: 24,),
                      ),
                      Text("Invite a friend", style: bodyTextStyle,),
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_forward, color: lightBackgroundColor, size: 24,),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 5),
                
                child: GestureDetector(
                  onTap: (){
                  
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 600,
                    height: 40,
                    decoration: BoxDecoration(
                      color: darkBackgroundColor,
                      
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.logout, color: dangerColor, size: 24,),
                        ),
                        Text("Logout", style: bodyTextStyle.copyWith(
                          color : dangerColor,
                        ),),
                        Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                         
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        height: 75,
        index: _selectedIndex,
        backgroundColor: backgroundColor,
        color: Colors.blueAccent,
        onTap: _onItemTapped,
        items: [
          Icon(Icons.home, size: 30, color: Colors.white),
          Icon(Icons.search, size: 30, color: Colors.white ),
          Icon(Icons.calendar_month, size: 30, color: Colors.white),
          Icon(Icons.people, size: 30, color: Colors.white)
        ]
        )
    );
  }
}