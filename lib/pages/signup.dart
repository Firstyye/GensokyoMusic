import 'package:flutter/material.dart';
import 'package:wave/config.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yo/pages/loginscreen.dart';
import 'package:wave/wave.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool isSwitch = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmpasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height / 4.25);
    var firstControlPoint = Offset(size.width / 4, size.height / 3);
    var firstEndPoint = Offset(size.width / 2, size.height / 3 - 60);
    var secondControlPoint = Offset(
      size.width - (size.width / 4),
      size.height / 4 - 65,
    );
    var secondEndPoint = Offset(size.width, size.height / 3 - 40);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height / 3);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  getBottomClip(Size size) {
    var path = Path();
    // เริ่มต้นที่มุมซ้ายล่าง
    path.moveTo(0, size.height);
    // ลากขึ้นไปจุดเริ่มโค้ง (ขยับความสูงตรง size.height * 0.85)
    path.lineTo(0, size.height * 0.45);

    var firstControlPoint = Offset(size.width * 0.25, size.height * 0.75);
    var firstEndPoint = Offset(size.width * 0.5, size.height * 0.88);

    var secondControlPoint = Offset(size.width * 0.75, size.height);
    var secondEndPoint = Offset(size.width, size.height * 0.45);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            bottom: -70,
            left: 0,
            right: 0,
            child: WaveWidget(config:
             CustomConfig(
              colors : [Colors.blueAccent,const Color.fromARGB(255, 193, 216, 255).withOpacity(0.6)],
              durations: [8000,7000], 
              heightPercentages: [0.65,0.66]
              ),
              backgroundColor: Colors.transparent,
              size: Size(2000, 500),
              ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 500),
              painter: _ClipPainter(
                getClip(Size(MediaQuery.of(context).size.width, 1000)),
                color: const Color.fromARGB(255, 131, 176, 255),
              ),
            ),
          ),
            

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 300),
              painter: _ClipPainter(
                getClip(Size(MediaQuery.of(context).size.width, 800)),
                color: Colors.blueAccent,
              ),
            ),
          ),

          
         
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
                        height: 300,
                        image: AssetImage('assets/images/CirnoLogin.png'),
                      ),
                    ),

                    Text(
                      "Ready to get started?",
                      style: headerTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Create an account to start your musical journey now!",
                      textAlign: TextAlign.center,
                      style: bodyTextStyle.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w100,
                        color: Colors.grey.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 20),
                    _BuildTextField(
                      controller: _usernameController,
                      labelText: "Username",
                      isObscureText: false,
                      isPassword: false,
                      icon: Icons.person,
                    ),
                    _BuildTextField(
                      controller: _emailController,
                      labelText: "Email",
                      isObscureText: false,
                      isPassword: false,
                      typeText: false,
                      icon: Icons.email,
                    ),

                    _BuildTextField(
                      controller: _passwordController,
                      labelText: "Password",
                      isObscureText: true,
                      isPassword: true,
                      icon: Icons.lock,
                    ),
                    _BuildTextField(
                      controller: _confirmpasswordController,
                      labelText: "Confirm Password",
                      isObscureText: true,
                      isPassword: true,
                      icon: Icons.lock,
                    ),

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
                          "SIGN UP",
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
                          "Already have an account?",

                          style: headerTextStyle.copyWith(
                            fontSize: 10,
                            color: Colors.grey.withOpacity(0.9),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            " Login ",
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
                    )
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

class _ClipPainter extends CustomPainter {
  final Path path;
  final Color color; // เพิ่มตัวแปรสีตรงนี้

  _ClipPainter(
    this.path, {
    this.color = Colors.blue,
  }); // รับค่าสีผ่าน constructor

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = color); // ใช้สีที่ส่งมา
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginButton extends StatelessWidget {
  final String? assetPath;
  final String? semanticsLabel;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor;
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
        padding: const EdgeInsets.only(right: 8.0, left: 8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.only(left: 10, right: 10),
            minimumSize: Size(75, 75),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),

            foregroundColor: Colors.black,
          ),
          onPressed: () {},
          child: icon != null
              ? Icon(icon, size: iconSize, color: iconColor)
              : SvgPicture.asset(
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
  final String labelText;
  final String? hintText;
  bool isObscureText;
  bool isPassword;
  final IconData icon;
  bool isHidden;
  bool typeText;
  _BuildTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    required this.isObscureText,
    required this.icon,
    required this.isPassword,
    this.isHidden = true,
    this.typeText = true,
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
          floatingLabelStyle: TextStyle(
            color: Colors.blueAccent,),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.blueAccent, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(widget.icon),
          suffixIcon: widget.isPassword
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      widget.isObscureText = !widget.isObscureText;
                      widget.isHidden = !widget.isHidden;
                    });
                  },
                  child: Icon(
                    widget.isHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                )
              : null,
          labelText: widget.labelText,
          labelStyle: bodyTextStyle.copyWith(
            fontSize: 12,
            color: Colors.grey.withOpacity(0.9),
          ),
          hintText: widget.hintText,
          hintStyle: bodyTextStyle.copyWith(
            fontSize: 12,
            color: Colors.grey.withOpacity(0.9),
          ),
        ),
        keyboardType: widget.typeText
            ? TextInputType.text
            : TextInputType.emailAddress,
        onChanged: (value) {},
      ),
    );
  }
}
