import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _updateUserData(userCredential.user!);
      }
      return userCredential.user;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      return null;
    }
  }

  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user != null) {
        // Send verification email
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          // The UI will inform the user.
        }
        await _updateUserData(user, isNewUser: true); // Create Firestore doc
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print("Error during Email/Password Sign-Up: ${e.message}");
      rethrow; 
    }
  }

  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // AuthWrapper will handle email verification check.
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error during Email/Password Sign-In: ${e.message}");
      rethrow;
    }
  }

  Future<void> _updateUserData(User user, {bool isNewUser = false}) async {
    DocumentReference userRef = _firestore.collection('users').doc(user.uid);
    
    if (isNewUser || !(await userRef.get()).exists) {
      return userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'selectedTopics': [], 
      }, SetOptions(merge: true));
    }
  }
  
  Future<void> ensureUserDataExists(User user) async {
    DocumentReference userRef = _firestore.collection('users').doc(user.uid);
    DocumentSnapshot userDoc = await userRef.get();

    if (!userDoc.exists) {
      await _updateUserData(user, isNewUser: true);
    }
  }

  Future<void> resendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } catch (e) {
        print("Error resending verification email: $e");
        rethrow;
      }
    } else if (user == null) {
      throw Exception("No user logged in to resend verification email.");
    } else if (user.emailVerified) {
      throw Exception("Email is already verified.");
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}