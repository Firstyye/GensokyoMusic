import 'dart:math';

import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      body: Stack(
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SafeArea(
                      child: Image(
                        width: 350,
                        image: AssetImage('assets/images/CirnoLogin.png'),
                        ),
                    ),

                    Text(
                      "Hello! Ready to get started?",
                      style: headerTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Please sign in with your email",
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
                      isPassword: false,
                      icon: Icons.email,
                    ),

                    _BuildTextField(
                      controller: _passwordController,
                      hintText: "Password",
                      isObscureText: true,
                      isPassword: true,
                      icon: Icons.lock,
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),

                        child: Text(
                          "LOGIN",
                          style: bodyTextStyle.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
                        GestureDetector(
                          onTap: () {
                            print("Pressed");
                          },
                          child: Text(
                            " Sign Up ",
                            style: headerTextStyle.copyWith(
                              fontSize: 10,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        Text(
                          "Here",
                          style: headerTextStyle.copyWith(
                            fontSize: 10,
                            color: Colors.grey.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 1, endIndent: 10)),
                        Text(
                          "OR CONTINUE WITH",
                          style: headerTextStyle.copyWith(
                            fontSize: 10,
                            color: Colors.grey.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 20),
                        Expanded(child: Divider(thickness: 1, indent: 10)),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LoginButton(
                          assetPath: "assets/icons/android_neutral_rd_na.svg",
                          semanticsLabel: 'Google logo',
                        ),
                        _LoginButton(
                          icon: FontAwesomeIcons.github,
                          iconSize: 24,
                          semanticsLabel: 'Github logo',
                        ),
                        _LoginButton(
                          icon: FontAwesomeIcons.facebook,
                          iconSize: 24,
                          iconColor: Colors.blue[700],
                          semanticsLabel: 'Facebook logo',
                        ),
                        _LoginButton(
                          icon: FontAwesomeIcons.twitter,
                          iconSize: 24,
                          iconColor: Colors.blue,
                          semanticsLabel: 'Twitter logo',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String? assetPath;
  final String? semanticsLabel;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor ;
  const _LoginButton({
    super.key, 
    this.assetPath, 
    this.semanticsLabel,
    this.icon,
    this.iconSize,
    this.iconColor,
    });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.only(left: 10, right: 10),
            minimumSize: Size(75, 75),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        
            foregroundColor: Colors.black,
          ),
          onPressed: () {},
          child: icon != null ? Icon(icon, size: iconSize, color: iconColor) : SvgPicture.asset(
            'assets/icons/android_neutral_rd_na.svg',
            semanticsLabel: semanticsLabel ?? 'Google logo',
            width: 50,
            height: 50,
          ),
        ),
      ),
    );
  }
}

class _BuildTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  bool isObscureText;
  bool isPassword;
  final IconData icon;
  bool isHidden;
  _BuildTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.isObscureText,
    required this.icon,
    required this.isPassword,
    this.isHidden = true,
  });

  @override
  State<_BuildTextField> createState() => _BuildTextFieldState();
}

class _BuildTextFieldState extends State<_BuildTextField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        obscureText: widget.isObscureText,
        controller: widget.controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(widget.icon),
          suffixIcon: widget.isPassword ? GestureDetector(
            onTap: (){
              setState(() {
                widget.isObscureText = !widget.isObscureText;
                widget.isHidden = !widget.isHidden;
              });
            },
            child: Icon( widget.isHidden ? Icons.visibility_off : Icons.visibility)) : null,
          labelText: widget.hintText,
          labelStyle: bodyTextStyle.copyWith(
            fontSize: 12,
            color: Colors.grey.withOpacity(0.9),
          ),
        ),
        keyboardType: widget.isObscureText
            ? TextInputType.text
            : TextInputType.emailAddress,
        onChanged: (value) {},
      ),
    );
  }
}
