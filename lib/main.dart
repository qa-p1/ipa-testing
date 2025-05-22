import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// No need for Provider for this setup yet

import 'package:mindfeed/firebase_options.dart';
import 'package:mindfeed/core/theme/app_theme.dart';
import 'package:mindfeed/core/services/auth_service.dart';
import 'package:mindfeed/core/services/user_service.dart';

import 'package:mindfeed/features/splash/screens/splash_screen.dart';
import 'package:mindfeed/features/auth/screens/login_screen.dart';
import 'package:mindfeed/features/auth/screens/verify_email_screen.dart'; // Import VerifyEmailScreen
import 'package:mindfeed/features/user_preferences/screens/topic_selection_screen.dart';
import 'package:mindfeed/features/home/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
     return MaterialApp(
      title: 'MindFeed',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const InitialScreenHandler(), 
    );
  }
}

class InitialScreenHandler extends StatefulWidget {
  const InitialScreenHandler({super.key});

  @override
  State<InitialScreenHandler> createState() => _InitialScreenHandlerState();
}

class _InitialScreenHandlerState extends State<InitialScreenHandler> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }
    return const AuthWrapper();
  }
}


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final UserService userService = UserService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          bool isEmailPasswordUser = user.providerData.any((userInfo) => userInfo.providerId == 'password');
          
          // This check is still important for users who open the app and are already
          // logged in via email/password but haven't verified yet (e.g., closed app after signup).
          if (isEmailPasswordUser && !user.emailVerified) {
            print("[AuthWrapper] User is email/pass but NOT verified. Navigating to VerifyEmailScreen.");
            return VerifyEmailScreen(user: user);
          }

          // User is logged in AND ( (is Google user) OR (is email/pass AND verified) )
          // This FutureBuilder handles ensuring user data and checking interests for these verified users.
          return FutureBuilder<void>(
            // Adding a key here can help if you suspect ensureUserDataExists needs to re-run
            // more explicitly if user object changes identity but uid is same.
            // key: ValueKey(user.uid + "_ensureData"), 
            future: authService.ensureUserDataExists(user),
            builder: (context, ensureDocSnapshot) {
              if (ensureDocSnapshot.connectionState == ConnectionState.waiting) {
                 return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Ensuring user data...")));
              }
              if (ensureDocSnapshot.hasError) {
                print("[AuthWrapper] Error ensuring user data: ${ensureDocSnapshot.error}. Navigating to LoginScreen.");
                // Potentially show an error snackbar before navigating
                // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error setting up account. Please try logging in again.")));
                return const LoginScreen(); 
              }

              // After ensuring data, check for interests
              return FutureBuilder<bool>(
                // key: ValueKey(user.uid + "_checkInterests_${user.emailVerified}"),
                future: userService.checkIfUserHasSetInterests(user.uid),
                builder: (context, interestSnapshot) {
                  if (interestSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Checking interests...")));
                  }
                  
                  print("[AuthWrapper] User ${user.uid} - Interest check result: ${interestSnapshot.data}, Error: ${interestSnapshot.error}");

                  if (interestSnapshot.hasError) {
                    print("[AuthWrapper] Error checking interests: ${interestSnapshot.error}. Navigating to TopicSelectionScreen as fallback.");
                    return const TopicSelectionScreen();
                  }

                  if (interestSnapshot.hasData && interestSnapshot.data == true) {
                    print("[AuthWrapper] User ${user.uid} has set interests. Navigating to BlankScreen.");
                    return const HomeScreen(); 
                  } else {
                    print("[AuthWrapper] User ${user.uid} has NOT set interests. Navigating to TopicSelectionScreen.");
                    return const TopicSelectionScreen();
                  }
                },
              );
            }
          );
        } else {
          // User is not logged in
          print("[AuthWrapper] No user logged in. Navigating to LoginScreen.");
          return const LoginScreen();
        }
      },
    );
  }
}