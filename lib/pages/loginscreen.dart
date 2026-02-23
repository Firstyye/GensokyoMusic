import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:yo/pages/home_screen.dart';
import '../pages/signup.dart';
import '../pages/forgetpass.dart';
import '../pages/introscreen.dart';
import '../components/animated_bg.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:quickalert/quickalert.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yo/data/authService.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _handleLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('seen') ?? false;

    if (!mounted) return;

    if (seen) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => IntroScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. เพิ่มการ Initialize ใน initState
    @override
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

    Future<User?> signInWithTwitter() async {
      try {
        final TwitterAuthProvider twitterProvider = TwitterAuthProvider();
        await FirebaseAuth.instance.signInWithProvider(twitterProvider);

        showSuccess();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        QuickAlert.show(
          context: context,
          confirmBtnTextStyle: bodyTextStyle,
          type: QuickAlertType.error,
          showConfirmBtn: false,
          title: 'Login Failed',
          text: "error code: ${e.code}\n${e.message}",
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
        print("Error signing in with Twitter: $e");
        return null;
      } catch (e) {
        print("Unexpected error signing in with Twitter: $e");
        return null;
      }
    }

    Future<UserCredential?> signInWithFacebook() async {
      try {
        final LoginResult loginResult = await FacebookAuth.instance.login(
          permissions: ['public_profile', 'email'],
        );
        final OAuthCredential facebookAuthCredential =
            FacebookAuthProvider.credential(
              loginResult.accessToken!.tokenString,
            );

        await FirebaseAuth.instance.signInWithCredential(
          facebookAuthCredential,
        );
        showSuccess();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        QuickAlert.show(
          context: context,
          confirmBtnTextStyle: bodyTextStyle,
          type: QuickAlertType.error,
          showConfirmBtn: false,
          title: 'Login Failed',
          text: e.code == "account-exists-with-different-credential"
              ? "An account already exists with the same email address but different sign-in credentials. Please use a different sign-in method."
              : e.message ??
                    "An error occurred during GitHub sign-in. Please try again.",
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
      } catch (e) {
        print("Unexpected error signing in with Facebook: $e");
        return null;
      }
    }

    Future<UserCredential?> signInWithGithub() async {
      try {
        GithubAuthProvider githubProvider = GithubAuthProvider();
        githubProvider.addScope('user:email');
        await FirebaseAuth.instance.signInWithProvider(githubProvider);
        showSuccess();
        _handleLoginSuccess();
      } on FirebaseAuthException catch (e) {
        QuickAlert.show(
          context: context,
          confirmBtnTextStyle: bodyTextStyle,
          type: QuickAlertType.error,
          showConfirmBtn: false,
          title: 'Login Failed',
          text: e.code == "account-exists-with-different-credential"
              ? "An account already exists with the same email address but different sign-in credentials. Please use a different sign-in method."
              : e.message ??
                    "An error occurred during GitHub sign-in. Please try again.",
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
        _googleSignIn.initialize();
        final GoogleSignInAccount? googleUser = await _googleSignIn
            .authenticate();
        if (googleUser == null) {
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
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
        _handleLoginSuccess();
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
        _handleLoginSuccess();
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
            text: "Invalid email format. Please enter a valid email address.",
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65), // Frosted glass effect
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Image(
                          width: 280,
                          height: 240,
                          image: AssetImage('assets/images/Register.png'),
                        ),
                      ),
                      SizedBox(height: 10),

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
                      SizedBox(height: 30),
                      _BuildTextField(
                        controller: _emailController,
                        labelText: "Email",
                        isObscureText: false,
                        isPassword: false,
                        icon: Icons.email_outlined,
                      ),

                      _BuildTextField(
                        controller: _passwordController,
                        labelText: "Password",
                        isObscureText: true,
                        isPassword: true,
                        icon: Icons.lock_outline,
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
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ForgetPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                "Forgot Password?",
                                style: bodyTextStyle.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w100,
                                  color: Colors.blueAccent.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 15.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: LinearGradient(
                              colors: [Colors.blueAccent, Colors.lightBlue],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.4),
                                spreadRadius: 1,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              signinWithEmailAndPassword();
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              backgroundColor:
                                  Colors.transparent, // Let gradient show
                              shadowColor:
                                  Colors.transparent, // Disable default shadow
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              "LOGIN",
                              style: bodyTextStyle.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
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
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LoginButton(
                            onpressed: signInWithGoogle,
                            assetPath: "assets/icons/android_neutral_rd_na.svg",
                            semanticsLabel: 'Google logo',
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            onpressed: signInWithGithub,
                            icon: FontAwesomeIcons.github,
                            iconSize: 28,
                            semanticsLabel: 'Github logo',
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            onpressed: signInWithFacebook,
                            icon: FontAwesomeIcons.facebook,
                            iconSize: 28,
                            iconColor: Colors.blue[700],
                            semanticsLabel: 'Facebook logo',
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            onpressed: signInWithTwitter,
                            icon: FontAwesomeIcons.twitter,
                            iconSize: 28,
                            iconColor: Colors.lightBlue,
                            semanticsLabel: 'Twitter logo',
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: CircleBorder(),
          onTap: onpressed ?? () {},
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: iconSize, color: iconColor)
                : SvgPicture.asset(
                    'assets/icons/android_neutral_rd_na.svg',
                    semanticsLabel: semanticsLabel ?? 'Google logo',
                    width: 32,
                    height: 32,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          obscureText: widget.isObscureText,
          controller: widget.controller,
          style: bodyTextStyle.copyWith(fontSize: 14),
          decoration: InputDecoration(
            floatingLabelStyle: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.blueAccent.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            fillColor: Colors.white,
            filled: true,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(
                widget.icon,
                color: Colors.blueAccent.withOpacity(0.8),
              ),
            ),
            suffixIcon: widget.isPassword
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        widget.isObscureText = !widget.isObscureText;
                        widget.isHidden = !widget.isHidden;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(
                        widget.isHidden
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                : null,
            labelText: widget.labelText,
            labelStyle: bodyTextStyle.copyWith(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.7),
            ),
            hintText: widget.hintText,
            hintStyle: bodyTextStyle.copyWith(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
          ),
          keyboardType: widget.isObscureText
              ? TextInputType.text
              : TextInputType.emailAddress,
          onChanged: (value) {},
        ),
      ),
    );
  }
}
