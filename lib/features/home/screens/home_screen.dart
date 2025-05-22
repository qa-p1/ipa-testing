import 'package:flutter/material.dart';
// import 'package:mindfeed/core/services/auth_service.dart'; // Keep if needed for other home features
import 'package:mindfeed/features/settings/screens/settings_screen.dart'; // New import

class HomeScreen extends StatelessWidget { // Renamed class
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindFeed'), // Changed title slightly
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined), // Changed icon to settings
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dynamic_feed_outlined, size: 100, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
            const SizedBox(height: 20),
            Text(
              'Your AI News Feed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Tailored articles, summarized by AI, coming soon!',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}