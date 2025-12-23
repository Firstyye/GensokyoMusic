

import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(height: 20),
            Stack(
              children:[
                CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage("https://avatars.githubusercontent.com/u/43317716?s=400&v=4"),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius:20,
                    backgroundColor: Colors.blue[900],
                    child : Icon(
                      Icons.edit,
                      color: Colors.white,
                      size  :18,
                    )
                  ),
                )
                ] ,
              ),
            SizedBox(height: 10,),
            Text('Cirno', 
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),),
            SizedBox(height: 20,),
            ElevatedButton(
              style : ElevatedButton.styleFrom(
                
                backgroundColor: Colors.blue[100],
                foregroundColor: Colors.blue,
                shape : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)
                )
              ),
              onPressed: (){}, 
              child: Text('Cirno_Gensokyo@gmail.com',
              style: TextStyle(
                color : Colors.blueAccent
              ),) 
              ),
          ],
        ),
      ),
    );
  }
}