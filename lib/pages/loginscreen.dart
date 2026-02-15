import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wave/config.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yo/pages/home_screen.dart';
import '../pages/signup.dart';
import 'package:wave/wave.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:quickalert/quickalert.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yo/data/authService.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  bool isSwitch = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  @override
  Widget build(BuildContext context) {
    
    // 1. เพิ่มการ Initialize ใน initState
@override
void initState() {
  super.initState();
  _googleSignIn.initialize();
}

void showSuccess() {
  return DelightToastBar(
          snackbarDuration: Duration(seconds: 4),
          autoDismiss: true,
          builder: (context) => ToastCard(
            color: Colors.green,
            title: Text(
              "Login Successful",
              style: bodyTextStyle.copyWith(color: Colors.white),
            ),

            leading: Icon(
              FontAwesomeIcons.circleCheck,
              color: Colors.white,
              size: 20,
            ),
            trailing: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.swipe_left, size: 20, color: Colors.white),
            ),
          ),
        ).show(context);
}

Future<UserCredential?> signInWithFacebook() async {
    try{
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );
      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);

      await FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
      showSuccess();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );

    }on FirebaseAuthException catch (e) {
      QuickAlert.show(
            context: context,
            confirmBtnTextStyle: bodyTextStyle,
            type: QuickAlertType.error,
            showConfirmBtn: false,
            title: 'Login Failed', 
            text : e.code == "account-exists-with-different-credential"
                ? "An account already exists with the same email address but different sign-in credentials. Please use a different sign-in method."
                : e.message ?? "An error occurred during GitHub sign-in. Please try again.",
            widget: Column(
              children: [
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: Colors.red, 
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
      
      print("Error signing in with Facebook: $e");
      return null;
    }catch (e) {
      print("Unexpected error signing in with Facebook: $e");
      return null;

    }
  }

Future<UserCredential?> signInWithGithub() async{
  try{
    GithubAuthProvider githubProvider = GithubAuthProvider();
    githubProvider.addScope('user:email');
    await FirebaseAuth.instance.signInWithProvider(githubProvider);
    showSuccess();
    await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
    

  }on FirebaseAuthException catch (e) {
    QuickAlert.show(
            context: context,
            confirmBtnTextStyle: bodyTextStyle,
            type: QuickAlertType.error,
            showConfirmBtn: false,
            title: 'Login Failed', 
            text : e.code == "account-exists-with-different-credential"
                ? "An account already exists with the same email address but different sign-in credentials. Please use a different sign-in method."
                : e.message ?? "An error occurred during GitHub sign-in. Please try again.",
            widget: Column(
              children: [
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: Colors.red, 
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
    // print('Firebase Auth Error: ${e.message}');
    
    return null;
  } catch (e) {
    // print('Error: $e');
    return null;
  }
}

Future<UserCredential?> signInWithGoogle() async {
  try {
    
    
    final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

    if (googleUser == null) {
      return null; 
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;


    final credential = GoogleAuthProvider.credential(
      accessToken: null,
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    DelightToastBar(
          snackbarDuration: Duration(seconds: 4),
          autoDismiss: true,
          builder: (context) => ToastCard(
            color: Colors.green,
            title: Text(
              "Login Successful",
              style: bodyTextStyle.copyWith(color: Colors.white),
            ),

            leading: Icon(
              FontAwesomeIcons.circleCheck,
              color: Colors.white,
              size: 20,
            ),
            trailing: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.swipe_left, size: 20, color: Colors.white),
            ),
          ),
        ).show(context);
        
        Duration(seconds: 5);
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
   
    

  } on FirebaseAuthException catch (e) {
    // print('Firebase Auth Error: ${e.message}');
    return null;
  } catch (e) {
    // print('Error: $e');
    return null;
  }
}
    Future<void> signinWithEmailAndPassword() async {
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text,
              password: _passwordController.text,
            );

        Duration(seconds: 2);
        DelightToastBar(
          snackbarDuration: Duration(seconds: 4),
          autoDismiss: true,
          builder: (context) => ToastCard(
            color: Colors.green,
            title: Text(
              "Login Successful",
              style: bodyTextStyle.copyWith(color: Colors.white),
            ),

            leading: Icon(
              FontAwesomeIcons.circleCheck,
              color: Colors.white,
              size: 20,
            ),
            trailing: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.swipe_left, size: 20, color: Colors.white),
            ),
          ),
        ).show(context);
        // print("show toast");
        Duration(seconds: 5);
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        // print('Failed with error code: ${e.code}');
        // print(e.message);
        if (e.code == "invalid-email") {
          QuickAlert.show(
            context: context,
            confirmBtnTextStyle: bodyTextStyle,
            type: QuickAlertType.error,
            showConfirmBtn: false,
            title: 'Login Failed', 
            text : "Invalid email format. Please enter a valid email address.",
            widget: Column(
              children: [
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: Colors.red, 
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
          print("no user found for that email");
        } else if (e.code == 'invalid-credential') {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            showConfirmBtn: false,
            title: 'Login Failed',
            text: 'Wrong password. Please try again.',
            widget: Column(
              children: [
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: Colors.red, 
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
          print("wrong password for that user");
        }
      }
    }

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

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            bottom: -70,
            left: 0,
            right: 0,
            child: WaveWidget(
              config: CustomConfig(
                colors: [
                  Colors.blueAccent,
                  Color.fromARGB(255, 193, 216, 255).withOpacity(0.6),
                ],
                durations: [8000, 6000],
                heightPercentages: [0.65, 0.66],
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

          SingleChildScrollView(
            child: Stack(
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
                          image: AssetImage('assets/images/Register.png'),
                        ),
                      ),
            
                      Text(
                        "Welcome back!",
                        style: headerTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Time to vibe with everyone again.",
                        style: bodyTextStyle.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(height: 20),
                      _BuildTextField(
                        controller: _emailController,
                        labelText: "Email",
                        isObscureText: false,
                        isPassword: false,
                        icon: Icons.email,
                      ),
            
                      _BuildTextField(
                        controller: _passwordController,
                        labelText: "Password",
                        isObscureText: true,
                        isPassword: true,
                        icon: Icons.lock,
                      ),
            
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Switch(
                              value: isSwitch,
                              onChanged: (value) {
                                setState(() {
                                  isSwitch = value;
                                });
                              },
                              activeTrackColor: Colors.blueAccent,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Remember me",
                              style: bodyTextStyle.copyWith(fontSize: 10),
                            ),
                            Spacer(),
                            Text(
                              "Forgot Password?",
                              style: bodyTextStyle.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w100,
                                color: Colors.blueAccent.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
            
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () {
                            signinWithEmailAndPassword();
                          },
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
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SignupScreen(),
                                ),
                              );
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
                   
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LoginButton(
                            onpressed: signInWithGoogle,
                            assetPath: "assets/icons/android_neutral_rd_na.svg",
                            semanticsLabel: 'Google logo',
                          ),
                          _LoginButton(
                            onpressed: signInWithGithub,
                            icon: FontAwesomeIcons.github,
                            iconSize: 24,
                            semanticsLabel: 'Github logo',
                          ),
                          _LoginButton(
                            onpressed: signInWithFacebook,
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
  final VoidCallback? onpressed;
  final String? assetPath;
  final String? semanticsLabel;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor;
  const _LoginButton({
    super.key,
    this.assetPath,
    this.onpressed,
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
          onPressed: onpressed ?? (){},
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
  _BuildTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
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
          floatingLabelStyle: TextStyle(color: Colors.blueAccent),
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
        keyboardType: widget.isObscureText
            ? TextInputType.text
            : TextInputType.emailAddress,
        onChanged: (value) {},
      ),
    );
  }
}
