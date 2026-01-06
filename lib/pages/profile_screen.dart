

import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

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
            style: headerTextStyle,
           ),
            SizedBox(height: 20,),
            ElevatedButton(
              style : ElevatedButton.styleFrom(
                
                backgroundColor: lightBackgroundColor,
                foregroundColor: const Color.fromARGB(255, 205, 224, 255),
                shape : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.blueAccent)
                )
              ),
              onPressed: (){}, 
              child: Text('Cirno_Gensokyo@gmail.com',
              style: bodyTextStyle,) 
              ),
              SizedBox(height: 30,),
              Padding(
                padding: const EdgeInsets.fromLTRB(25,25,25,5),
                child: Container(
                  width: double.infinity,
                  height: 40,
                  color: darkBackgroundColor,
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
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
                child: Container(
                  width: double.infinity,
                  height: 40,
                  color: darkBackgroundColor,
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
              )
          ],
        ),
      ),
    );
  }
}