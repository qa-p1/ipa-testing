import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindfeed/core/services/auth_service.dart';
import 'package:mindfeed/core/services/user_service.dart'; // Import UserService
import 'package:mindfeed/features/user_preferences/screens/topic_selection_screen.dart'; // Import next screens
import 'package:mindfeed/features/home/screens/home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user;
  const VerifyEmailScreen({super.key, required this.user});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService(); // Instantiate UserService
  bool _isSendingVerification = false;
  bool _isCheckingStatus = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Automatically navigate if already verified when screen loads (e.g., deep link scenario)
    if (widget.user.emailVerified) {
      _navigateToNextScreen(widget.user);
      return; // Don't start timer if already verified
    }

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Use a fresh instance of the user for reload
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) { // User might have signed out
        timer.cancel();
        // AuthWrapper will handle navigation to login
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      await currentUser.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser; // Get the reloaded user

      if (refreshedUser != null && refreshedUser.emailVerified) {
        timer.cancel();
        if (mounted) {
          print("[VerifyEmailScreen] Email verified by timer. Navigating...");
          _navigateToNextScreen(refreshedUser);
        }
      }
    });
  }

  Future<void> _navigateToNextScreen(User verifiedUser) async {
    if (!mounted) return;

    // Ensure Firestore document exists (important if this screen is reached very quickly)
    // This is a good place for it to ensure user data is ready before topic check
    await _authService.ensureUserDataExists(verifiedUser);

    bool hasSetInterests = await _userService.checkIfUserHasSetInterests(verifiedUser.uid);
    
    if (mounted) {
      if (hasSetInterests) {
        print("[VerifyEmailScreen] User has interests. Navigating to BlankScreen.");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      } else {
        print("[VerifyEmailScreen] User has NO interests. Navigating to TopicSelectionScreen.");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TopicSelectionScreen()),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    if (!mounted) return;
    setState(() => _isSendingVerification = true);
    try {
      await _authService.resendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${widget.user.email}.'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending email: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingVerification = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (!mounted) return;
    setState(() => _isCheckingStatus = true);
    
    // Use a fresh instance of the user for reload
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) { // User might have signed out
       if (mounted) setState(() => _isCheckingStatus = false);
       // AuthWrapper will handle navigation to login
       if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
       return;
    }

    await currentUser.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser; // Get reloaded user

    if (mounted) {
      if (refreshedUser != null && refreshedUser.emailVerified) {
        _timer?.cancel(); // Stop periodic checks as we are manually proceeding
        print("[VerifyEmailScreen] Email verified by manual check. Navigating...");
        await _navigateToNextScreen(refreshedUser); // Await this if it involves async ops
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email not verified yet. Please check your inbox or resend.'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
      if (mounted) { // Check again as _navigateToNextScreen might unmount
         setState(() => _isCheckingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            // ... (rest of the UI remains the same)
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'A verification link has been sent to:',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.user.email ?? 'your email address',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please check your inbox (and spam/junk folder) and click the link to complete your registration.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _isSendingVerification
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Resend Verification Email'),
                      onPressed: _resendVerificationEmail,
                    ),
              const SizedBox(height: 16),
              _isCheckingStatus
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text("I've Verified / Refresh Status"),
                      onPressed: _checkVerificationStatus,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
              const SizedBox(height: 24),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout & Go to Login'),
                onPressed: () async {
                  _timer?.cancel();
                  await _authService.signOut();
                  // AuthWrapper will navigate to LoginScreen
                  if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}