import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        return null; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
     
    }on FirebaseAuthException catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }
  Future<UserCredential?> signInWithGithub() async{
    try {
      final GithubAuthProvider githubProvider = GithubAuthProvider();
      final UserCredential userCredential =
          await _auth.signInWithProvider(githubProvider);
      return userCredential;
    }on FirebaseAuthException catch (e) {
      print("Error signing in with GitHub: $e");
      return null;
    }catch (e) {
      print("Unexpected error signing in with GitHub: $e");
      return null;
    }

  }
  Future<UserCredential?> signInWithFacebook() async {
    try{
      final LoginResult loginResult = await FacebookAuth.instance.login();
      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);

      return FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);

    }on FirebaseAuthException catch (e) {
      
      print("Error signing in with Facebook: $e");
      return null;
    }catch (e) {
      print("Unexpected error signing in with Facebook: $e");
      return null;

    }
  }
  
  Future<User?> signInWithTwitter() async {
    try {
      final TwitterAuthProvider twitterProvider = TwitterAuthProvider();
      final UserCredential userCredential =
          await _auth.signInWithProvider(twitterProvider);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in with Twitter: $e");
      return null;
    } catch (e) {
      print("Unexpected error signing in with Twitter: $e");
      return null;
    }
  }

}