import 'dart:math';

import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hello! Ready to get started?",
              style: headerTextStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "Please sign in with your emain",
              style: bodyTextStyle.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w100,
                color: Colors.grey.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 20),
            _BuildTextField(
              controller: _emailController,
              hintText: "Email",
              isObscureText: false,
              icon: Icons.email,
            ),

            _BuildTextField(
              controller: _passwordController,
              hintText: "Password",
              isObscureText: true,
              icon: Icons.lock,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(
                "Login",
                style: bodyTextStyle.copyWith(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account?",
                
                  style: headerTextStyle.copyWith(
                    fontSize: 10,
                    color: Colors.grey.withOpacity(0.9),
                  ),
                ),
                Text(" Sign Up ",
                  style: headerTextStyle.copyWith(
                    fontSize: 10,
                    color: Colors.blueAccent,
                  ),),
                Text("Here", 
                style: headerTextStyle.copyWith(
                    fontSize: 10,
                    color: Colors.grey.withOpacity(0.9),
                  ),)
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: Text(
                "Login With Google",

                style: bodyTextStyle.copyWith(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              icon: Icon(Icons.login, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isObscureText;
  final IconData icon;
  _BuildTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.isObscureText,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        obscureText: isObscureText,
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(icon),

          labelText: hintText,
          labelStyle: bodyTextStyle.copyWith(
            fontSize: 12,
            color: Colors.grey.withOpacity(0.9),
          ),
        ),
        keyboardType: isObscureText
            ? TextInputType.text
            : TextInputType.emailAddress,
        onChanged: (value) {},
      ),
    );
  }
}
