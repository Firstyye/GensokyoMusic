import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yo/pages/home_screen.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:quickalert/quickalert.dart';
import 'package:yo/pages/loginscreen.dart';
import '../components/animated_bg.dart';

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

  Future<void> createUserWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      DelightToastBar(
        snackbarDuration: Duration(seconds: 4),
        autoDismiss: true,
        builder: (context) => ToastCard(
          color: Colors.green,
          title: Text(
            "Register Successful",
            style: bodyTextStyle.copyWith(color: Colors.white),
          ),

          leading: Icon(
            FontAwesomeIcons.circleCheck,
            color: Colors.white,
            size: 20,
          ),
        ),
      ).show(context);
      FirebaseAuth.instance.currentUser!.updateDisplayName(
        _usernameController.text,
      );
      FirebaseAuth.instance.signOut();
      await Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen()));
    } on FirebaseAuthException catch (e) {
      if (e.code == "weak-password") {
        QuickAlert.show(
          context: context,
          confirmBtnTextStyle: bodyTextStyle,
          type: QuickAlertType.error,
          title: 'Register Failed',
          text: 'Password is too weak',
          showConfirmBtn: false,
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
        print("weak password");
      } else if (e.code == "email-already-in-use") {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          confirmBtnTextStyle: bodyTextStyle,
          title: 'Register Failed',
          text: 'Email is already in use',
          showConfirmBtn: false,
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
        print("email already in use");
      }
    } catch (e) {
      print(e);
    }
  }

  void _showMyDialog(String txtMsg) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Expanded(
          child: AlertDialog(
            backgroundColor: Colors.blueAccent.shade100,
            title: const Text('Register Failed'),
            content: Text(txtMsg),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, 'Cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'OK'),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: AnimatedBackground(
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
                        child: Flexible(
                          child: FractionallySizedBox(
                            widthFactor: 0.9,
                            child: Image(
                              image: AssetImage('assets/images/CirnoLogin.png'),
                              fit: BoxFit
                                  .contain, // Maintain aspect ratio within bounds
                            ),
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
                          color: Colors.grey.withOpacity(0.9),
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
                              if (_usernameController.text.isEmpty) {
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Register Failed',
                                  text: 'Invalid Username',
                                  showConfirmBtn: false,
                                  widget: Column(
                                    children: [
                                      const SizedBox(height: 20),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                print("Invalid Username");
                              } else if (_emailController.text.isEmpty) {
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Register Failed',
                                  text: 'Invalid Email',
                                  showConfirmBtn: false,
                                  widget: Column(
                                    children: [
                                      const SizedBox(height: 20),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                print("Invalid Email");
                              } else if (_passwordController.text !=
                                      _confirmpasswordController.text ||
                                  _passwordController.text.isEmpty) {
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Register Failed',
                                  text: 'Password does not match',
                                  showConfirmBtn: false,
                                  widget: Column(
                                    children: [
                                      const SizedBox(height: 20),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                print("password does not match");
                                return;
                              }
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
                              color: Colors.grey.withOpacity(0.9),
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
                          SizedBox(width: 15),
                          _LoginButton(
                            icon: FontAwesomeIcons.github,
                            iconSize: 28,
                            semanticsLabel: 'Github logo',
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
                            icon: FontAwesomeIcons.facebook,
                            iconSize: 28,
                            iconColor: Colors.blue[700],
                            semanticsLabel: 'Facebook logo',
                          ),
                          SizedBox(width: 15),
                          _LoginButton(
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
          onTap: () {},
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
          keyboardType: widget.typeText
              ? TextInputType.text
              : TextInputType.emailAddress,
          onChanged: (value) {},
        ),
      ),
    );
  }
}
