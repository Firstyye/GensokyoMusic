import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:yo/constant/my_constant.dart';
import '../components/static_bg.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
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

  Future<void> sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showGlassToast("Please enter your email address.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      showGlassToast("Password reset link sent to your email!", isError: false);

      // Go back to login screen after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == "invalid-email") {
        showGlassToast("Invalid email format. Please try again.");
      } else if (e.code == "user-not-found") {
        showGlassToast("No user found for that email.");
      } else {
        showGlassToast("Failed: ${e.message ?? 'An unknown error occurred.'}");
      }
    } catch (e) {
      showGlassToast("An unexpected error occurred.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: cyanAccent),
              onPressed: () {
                Navigator.of(context).pop();
              },
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            );
          },
        ),
      ),
      body: StaticBackground(
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
                        child: FractionallySizedBox(
                          widthFactor: 0.9,
                          child: Image(
                            image: const AssetImage('assets/images/forgetpass.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),

                      Text(
                        "Reset Password",
                        style: headerTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Enter the email associated with your account\nand we'll send an email with instructions\nto reset your password.",
                        textAlign: TextAlign.center,
                        style: bodyTextStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: darkThemeColor,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 40),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 10.0,
                        ),
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
                            controller: _emailController,
                            style: bodyTextStyle.copyWith(fontSize: 14),
                            decoration: InputDecoration(
                              floatingLabelStyle: TextStyle(
                                color: cyanAccent,
                                fontWeight: FontWeight.bold,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 20,
                              ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: Icon(
                                  Icons.email_outlined,
                                  color: cyanAccent.withValues(alpha: 0.8),
                                ),
                              ),
                              labelText: "Email",
                              labelStyle: bodyTextStyle.copyWith(
                                fontSize: 14,
                                color: Colors.grey.withOpacity(0.7),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 25.0,
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
                              sendPasswordResetEmail();
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
                              "SEND RESET LINK",
                              style: bodyTextStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),
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
