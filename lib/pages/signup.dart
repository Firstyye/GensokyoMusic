import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yo/pages/main_layout.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:yo/pages/loginscreen.dart';
import '../components/static_bg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/introscreen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool isSwitch = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmpasswordController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  double _passwordStrength = 0.0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      _checkPasswordStrength(_passwordController.text);
    });
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmpasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      if (password.isEmpty) {
        _passwordStrength = 0.0;
        _strengthLabel = '';
        _strengthColor = Colors.transparent;
      } else if (password.length < 6) {
        _passwordStrength = 0.33;
        _strengthLabel = 'Weak';
        _strengthColor = Colors.redAccent;
      } else if (password.length < 8 || !password.contains(RegExp(r'[0-9]'))) {
        _passwordStrength = 0.66;
        _strengthLabel = 'Medium';
        _strengthColor = Colors.orangeAccent;
      } else {
        _passwordStrength = 1.0;
        _strengthLabel = 'Strong';
        _strengthColor = Colors.greenAccent;
      }
    });
  }

  Future<void> _handleLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('seen') ?? false;

    if (!mounted) return;

    if (seen) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const IntroScreen()),
      );
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

  Future<User?> signInWithTwitter() async {
    try {
      final TwitterAuthProvider twitterProvider = TwitterAuthProvider();
      await FirebaseAuth.instance.signInWithProvider(twitterProvider);

      showGlassToast("Login Successful", isError: false);
      _handleLoginSuccess();
    } on FirebaseAuthException catch (e) {
      showGlassToast("Twitter Login Failed: \n${e.message ?? 'Unknown error'}");
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
          FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);

      await FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
      showGlassToast("Login Successful", isError: false);
      _handleLoginSuccess();
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
      showGlassToast("Google Login Failed: \n${e.message ?? 'Unknown error'}");
      return null;
    } catch (e) {
      showGlassToast("Google Error: $e");
      return null;
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    if (_usernameController.text.trim().isEmpty) {
      showGlassToast("Please enter a username.");
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      showGlassToast("Please enter an email address.");
      return;
    }
    if (_passwordController.text.isEmpty ||
        _confirmpasswordController.text.isEmpty) {
      showGlassToast("Please fill out both password fields.");
      return;
    }
    if (_passwordController.text != _confirmpasswordController.text) {
      showGlassToast("Passwords do not match.");
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      showGlassToast("Register Successful", isError: false);

      FirebaseAuth.instance.currentUser!.updateDisplayName(
        _usernameController.text.trim(),
      );
      FirebaseAuth.instance.signOut();

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == "weak-password") {
        showGlassToast(
          "Your password is too weak. Please use at least 6 characters.",
        );
      } else if (e.code == "email-already-in-use") {
        showGlassToast("An account already exists for that email.");
      } else if (e.code == "invalid-email") {
        showGlassToast("Invalid email format. Please try again.");
      } else {
        showGlassToast(e.message ?? "An error occurred during registration.");
      }
    } catch (e) {
      showGlassToast("An unexpected error occurred.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: StaticBackground(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: viewInsets.bottom,
                left: 24.0,
                right: 24.0,
                top: 40.0,
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
                        child: FractionallySizedBox(
                          widthFactor: 0.9,
                          child: Image(
                            image: const AssetImage('assets/images/CirnoLogin.png'),
                            fit: BoxFit.contain, // Maintain aspect ratio within bounds
                          ),
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
                          color: darkThemeColor,
                        ),
                      ),
                      SizedBox(height: 30),
                      _BuildTextField(
                        controller: _usernameController,
                        labelText: "Username",
                        isObscureText: false,
                        isPassword: false,
                        icon: Icons.person_outline,
                      ),
                      _BuildTextField(
                        controller: _emailController,
                        labelText: "Email",
                        isObscureText: false,
                        isPassword: false,
                        typeText: false,
                        icon: Icons.email_outlined,
                      ),
                      _BuildTextField(
                        controller: _passwordController,
                        labelText: "Password",
                        isObscureText: true,
                        isPassword: true,
                        icon: Icons.lock_outline,
                      ),

                      _BuildTextField(
                        controller: _confirmpasswordController,
                        labelText: "Confirm Password",
                        isObscureText: true,
                        isPassword: true,
                        icon: Icons.lock_reset_outlined,
                      ),

                      // Password Strength Indicator
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: _passwordController.text.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Password Strength",
                                          style: bodyTextStyle.copyWith(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        AnimatedOpacity(
                                          opacity: _passwordStrength > 0
                                              ? 1.0
                                              : 0.0,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: Text(
                                            _strengthLabel,
                                            style: bodyTextStyle.copyWith(
                                              fontSize: 10,
                                              color: _strengthColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Stack(
                                      children: [
                                        Container(
                                          height: 4,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          height: 4,
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.7 *
                                              _passwordStrength,
                                          decoration: BoxDecoration(
                                            color: _strengthColor,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
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
                              createUserWithEmailAndPassword();
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
                              "SIGN UP",
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
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account?",

                            style: headerTextStyle.copyWith(
                              fontSize: 10,
                              color: darkThemeColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              " Login ",
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
                            assetPath: "assets/icons/android_neutral_rd_na.svg",
                            semanticsLabel: 'Google logo',
                            onTap: signInWithGoogle,
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            icon: FontAwesomeIcons.github,
                            iconSize: 28,
                            semanticsLabel: 'Github logo',
                            onTap: signInWithGithub,
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            icon: FontAwesomeIcons.facebook,
                            iconSize: 28,
                            iconColor: Colors.blue[700],
                            semanticsLabel: 'Facebook logo',
                            onTap: signInWithFacebook,
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            icon: FontAwesomeIcons.twitter,
                            iconSize: 28,
                            iconColor: cyanAccent,
                            semanticsLabel: 'Twitter logo',
                            onTap: signInWithTwitter,
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
  final String? assetPath;
  final String? semanticsLabel;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _LoginButton({
    super.key,
    this.assetPath,
    this.semanticsLabel,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.onTap,
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
          onTap: onTap,
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
  final bool isObscureText;
  final bool isPassword;
  final IconData icon;
  final bool isHidden;
  final bool typeText;
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
  late bool _isObscure;
  late bool _isHidden;

  @override
  void initState() {
    super.initState();
    _isObscure = widget.isObscureText;
    _isHidden = widget.isHidden;
  }

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
          obscureText: _isObscure,
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
                        _isObscure = !_isObscure;
                        _isHidden = !_isHidden;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(
                        _isHidden
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
              color: Colors.grey.withValues(alpha: 0.7),
            ),
            hintText: widget.hintText,
            hintStyle: bodyTextStyle.copyWith(
              fontSize: 14,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
          ),
          keyboardType: widget.typeText
              ? TextInputType.text
              : TextInputType.emailAddress,
          onChanged: (value) {},
        ),
      ),
    );
  }
}
