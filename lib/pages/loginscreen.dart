import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:yo/pages/main_layout.dart';
import '../pages/signup.dart';
import '../pages/forgetpass.dart';
import '../pages/introscreen.dart';
import '../components/animated_bg.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yo/data/authService.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/firestore_service.dart';
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
  bool _googleInitialized = false;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    } catch (e) {
      debugPrint('Google Sign-In init error: $e');
    }
  }

  Future<void> _handleLoginSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirestoreService().saveUserToFirestore(user);
    }

    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('seen') ?? false;

    if (!mounted) return;

    if (seen) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => IntroScreen()));
    }
  }

  void showGlassToast(String message, {bool isError = true}) {
    DelightToastBar(
      snackbarDuration: const Duration(seconds: 2),
      autoDismiss: true,
      builder: (context) => ToastCard(
        color: isError
            ? Colors.redAccent.withValues(alpha: 0.9)
            : Colors.green.withValues(alpha: 0.9),
        title: Text(
          message,
          style: bodyTextStyle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Icon(
          isError
              ? FontAwesomeIcons.circleExclamation
              : FontAwesomeIcons.circleCheck,
          color: Colors.white,
          size: 20,
        ),
      ),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    Future<User?> signInWithTwitter() async {
      try {
        final TwitterAuthProvider twitterProvider = TwitterAuthProvider();
        await FirebaseAuth.instance.signInWithProvider(twitterProvider);

        showGlassToast("Login Successful", isError: false);
        await _handleLoginSuccess();
      } on FirebaseAuthException catch (e) {
        showGlassToast(
          "Twitter Login Failed: \n${e.message ?? 'Unknown error'}",
        );
        return null;
      } catch (e) {
        showGlassToast("Unexpected error occurred.");
        return null;
      }
      return null;
    }

    Future<UserCredential?> signInWithFacebook() async {
      try {
        final LoginResult loginResult = await FacebookAuth.instance.login(
          permissions: ['public_profile', 'email'],
        );

        if (loginResult.status == LoginStatus.cancelled) {
          showGlassToast("Facebook login cancelled.");
          return null;
        }

        final OAuthCredential facebookAuthCredential =
            FacebookAuthProvider.credential(
              loginResult.accessToken!.tokenString,
            );

        await FirebaseAuth.instance.signInWithCredential(
          facebookAuthCredential,
        );
        showGlassToast("Login Successful", isError: false);
        await _handleLoginSuccess();
      } on FirebaseAuthException catch (e) {
        final message = e.code == "account-exists-with-different-credential"
            ? "An account already exists with the same email but different sign-in credentials."
            : e.message ?? "An error occurred during Facebook sign-in.";
        showGlassToast("Facebook Login Failed: \n$message");
        return null;
      } catch (e) {
        showGlassToast("Unexpected error occurred.");
        return null;
      }
      return null;
    }

    Future<UserCredential?> signInWithGithub() async {
      try {
        GithubAuthProvider githubProvider = GithubAuthProvider();
        githubProvider.addScope('user:email');
        await FirebaseAuth.instance.signInWithProvider(githubProvider);
        showGlassToast("Login Successful", isError: false);
        _handleLoginSuccess();
      } on FirebaseAuthException catch (e) {
        final message = e.code == "account-exists-with-different-credential"
            ? "An account already exists with the same email but different sign-in credentials."
            : e.message ?? "An error occurred during GitHub sign-in.";
        showGlassToast("GitHub Login Failed: \n$message");
        return null;
      } catch (e) {
        showGlassToast("Unexpected error occurred.");
        return null;
      }
      return null;
    }

    Future<UserCredential?> signInWithGoogle() async {
      try {
        if (!_googleInitialized) {
          await _googleSignIn.initialize();
          _googleInitialized = true;
        }

        // Use a Completer to bridge the stream-based v7 API
        final completer = Completer<GoogleSignInAccount?>();
        late StreamSubscription<GoogleSignInAuthenticationEvent> sub;

        sub = _googleSignIn.authenticationEvents.listen(
          (event) {
            if (!completer.isCompleted) {
              switch (event) {
                case GoogleSignInAuthenticationEventSignIn():
                  completer.complete(event.user);
                case GoogleSignInAuthenticationEventSignOut():
                  completer.complete(null);
              }
            }
            sub.cancel();
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
            sub.cancel();
          },
        );

        // authenticate() returns void in v7; result comes via stream
        await _googleSignIn.authenticate();

        final GoogleSignInAccount? googleUser = await completer.future.timeout(
          const Duration(seconds: 60),
        );

        if (googleUser == null) {
          showGlassToast("Google login cancelled.");
          return null;
        }

        // Get the idToken from the user's authentication
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);

        showGlassToast("Login Successful", isError: false);
        await Future.delayed(const Duration(seconds: 2));
        _handleLoginSuccess();
        return userCredential;
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          showGlassToast("Google login cancelled.");
        } else {
          showGlassToast("Google Error: ${e.description}");
        }
        return null;
      } on FirebaseAuthException catch (e) {
        showGlassToast(
          "Google Login Failed: \n${e.message ?? 'Unknown error'}",
        );
        return null;
      } catch (e) {
        showGlassToast("Google Error: $e");
        return null;
      }
    }

    Future<void> signinWithEmailAndPassword() async {
      if (_emailController.text.trim().isEmpty) {
        showGlassToast("Please enter your email.");
        return;
      }
      if (_passwordController.text.trim().isEmpty) {
        showGlassToast("Please enter your password.");
        return;
      }

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        showGlassToast("Login Successful", isError: false);
        await Future.delayed(const Duration(seconds: 2));
        _handleLoginSuccess();
      } on FirebaseAuthException catch (e) {
        if (e.code == "invalid-email") {
          showGlassToast("Invalid email format. Please try again.");
        } else if (e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'user-not-found') {
          showGlassToast("Incorrect email or password.");
        } else if (e.code == 'user-disabled') {
          showGlassToast("This account has been disabled.");
        } else if (e.code == 'too-many-requests') {
          showGlassToast("Too many attempts. Please try again later.");
        } else {
          showGlassToast(e.message ?? "An error occurred during login.");
        }
      } catch (e) {
        showGlassToast("An unexpected error occurred.");
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
                  color: darkThemeSecondaryColor.withValues(
                    alpha: 0.8,
                  ), // Frosted glass dark effect
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cyanAccent.withValues(alpha: 0.05),
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
                          color: darkThemeColor,
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
                              activeTrackColor: cyanAccent,
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
                                  color: cyanAccent.withValues(alpha: 0.9),
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
                              colors: [
                                cyanAccent,
                                cyanAccent.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cyanAccent.withValues(alpha: 0.4),
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
                              color: darkThemeColor,
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
                                color: cyanAccent,
                              ),
                            ),
                          ),
                          Text(
                            "Here",
                            style: headerTextStyle.copyWith(
                              fontSize: 10,
                              color: darkThemeColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              endIndent: 10,
                              color: darkThemeColor.withValues(alpha: 0.2),
                            ),
                          ),
                          Text(
                            "OR CONTINUE WITH",
                            style: headerTextStyle.copyWith(
                              fontSize: 10,
                              color: darkThemeColor,
                            ),
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              indent: 10,
                              color: darkThemeColor.withValues(alpha: 0.2),
                            ),
                          ),
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
                            iconColor: cyanAccent,
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
        color: Colors.white.withValues(alpha: 0.15), // Brighter background
        boxShadow: [
          BoxShadow(
            color: cyanAccent.withValues(alpha: 0.15),
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
          color: darkThemeSecondaryColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: cyanAccent.withValues(alpha: 0.08),
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
              color: cyanAccent,
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
                color: cyanAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            fillColor: darkThemeSecondaryColor,
            filled: true,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(
                widget.icon,
                color: cyanAccent.withValues(alpha: 0.8),
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
