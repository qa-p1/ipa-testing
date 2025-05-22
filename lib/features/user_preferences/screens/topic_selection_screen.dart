import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mindfeed/core/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindfeed/features/home/screens/home_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// --- TopicItem Class Definition ---
class TopicItem {
  final String name;
  final IconData icon;
  const TopicItem({required this.name, required this.icon});
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicItem && runtimeType == other.runtimeType && name == other.name;
  @override
  int get hashCode => name.hashCode;
}

// --- _initialTopicItems List ---
List<TopicItem> _initialTopicItems = [
  const TopicItem(name: 'Tech', icon: Icons.computer_outlined),
  const TopicItem(name: 'Politics', icon: Icons.gavel_outlined),
  const TopicItem(name: 'Sports', icon: Icons.sports_soccer_outlined),
  const TopicItem(name: 'Health', icon: Icons.monitor_heart_outlined),
  const TopicItem(name: 'Entertainment', icon: Icons.movie_filter_outlined),
  const TopicItem(name: 'Business', icon: Icons.business_center_outlined),
  const TopicItem(name: 'Science', icon: Icons.science_outlined),
  const TopicItem(name: 'World', icon: Icons.public_outlined),
  const TopicItem(name: 'Lifestyle', icon: Icons.spa_outlined),
  const TopicItem(name: 'Education', icon: Icons.school_outlined),
  const TopicItem(name: 'Finance', icon: Icons.attach_money_outlined),
  const TopicItem(name: 'Travel', icon: Icons.flight_takeoff_outlined),
  const TopicItem(name: 'Environment', icon: Icons.eco_outlined),
  const TopicItem(name: 'Space', icon: Icons.rocket_launch_outlined),
  const TopicItem(name: 'Automotive', icon: Icons.directions_car_outlined),
  const TopicItem(name: 'Gaming', icon: Icons.sports_esports_outlined),
  const TopicItem(name: 'Art & Culture', icon: Icons.palette_outlined),
  const TopicItem(name: 'Food', icon: Icons.restaurant_menu_outlined),
  const TopicItem(name: 'Music', icon: Icons.music_note_outlined),
  const TopicItem(name: 'Fashion', icon: Icons.checkroom_outlined),
  const TopicItem(name: 'Books', icon: Icons.menu_book_outlined),
  const TopicItem(name: 'History', icon: Icons.history_edu_outlined),
  const TopicItem(name: 'Photography', icon: Icons.camera_alt_outlined),
  const TopicItem(name: 'Architecture', icon: Icons.architecture_outlined),
  const TopicItem(name: 'Pets', icon: Icons.pets_outlined),
  const TopicItem(name: 'DIY & Crafts', icon: Icons.build_outlined),
  const TopicItem(name: 'Gardening', icon: Icons.local_florist_outlined),
  const TopicItem(name: 'Fitness', icon: Icons.fitness_center_outlined),
];

class TopicSelectionScreen extends StatefulWidget {
  final bool isEditing;
  const TopicSelectionScreen({super.key, this.isEditing = false});

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen> with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final List<TopicItem> _allTopicItemsSorted = List.from(_initialTopicItems);
  final Set<String> _selectedTopicNames = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final int _minTopicsRequired = 3;
  static const int _numRows = 4;

  // Optimized auto-scroll
  late ScrollController _scrollController;
  late AnimationController _scrollAnimationController;
  Timer? _userInteractionTimer;
  bool _userIsInteracting = false;
  
  // Reduced scroll speed and smoother animation
  static const Duration _scrollDuration = Duration(seconds: 20); // Slower, smoother
  static const Duration _pauseDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _allTopicItemsSorted.sort((a, b) => a.name.compareTo(b.name));
    _scrollController = ScrollController();
    
    // Use AnimationController for smoother scrolling
    _scrollAnimationController = AnimationController(
      duration: _scrollDuration,
      vsync: this,
    );
    
    _loadCurrentUserInterests();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollAnimationController.dispose();
    _userInteractionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUserInterests() async {
    if (!mounted) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final interests = await _userService.getUserInterests(user.uid);
      if (mounted) {
        setState(() {
          _selectedTopicNames.clear();
          _selectedTopicNames.addAll(interests);
          _isLoading = false;
        });
        _startAutoScrollAfterDelay();
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _startAutoScrollAfterDelay() {
    // Start auto-scroll after a short delay to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_userIsInteracting) {
        _startSmoothAutoScroll();
      }
    });
  }

  void _startSmoothAutoScroll() {
    if (!_scrollController.hasClients || _userIsInteracting) return;
    
    _scrollAnimationController.reset();
    
    // Calculate scroll distance based on content
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) return;
    
    final animation = Tween<double>(
      begin: 0,
      end: maxScrollExtent * 0.7, // Scroll to 70% of content
    ).animate(CurvedAnimation(
      parent: _scrollAnimationController,
      curve: Curves.linear,
    ));
    
    animation.addListener(() {
      if (_scrollController.hasClients && !_userIsInteracting) {
        _scrollController.jumpTo(animation.value);
      }
    });
    
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_userIsInteracting) {
        // Pause then restart
        Future.delayed(_pauseDuration, () {
          if (mounted && !_userIsInteracting) {
            _startSmoothAutoScroll();
          }
        });
      }
    });
    
    _scrollAnimationController.forward();
  }

  void _pauseAutoScroll() {
    _userIsInteracting = true;
    _scrollAnimationController.stop();
    _userInteractionTimer?.cancel();
    
    // Resume after user stops interacting
    _userInteractionTimer = Timer(_pauseDuration, () {
      if (mounted) {
        _userIsInteracting = false;
        _startSmoothAutoScroll();
      }
    });
  }

  void _toggleTopic(String topicName) {
    _pauseAutoScroll();
    setState(() {
      if (_selectedTopicNames.contains(topicName)) {
        _selectedTopicNames.remove(topicName);
      } else {
        _selectedTopicNames.add(topicName);
      }
    });
  }

  Future<void> _saveInterests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.'))
        );
      }
      return;
    }

    if (!widget.isEditing && _selectedTopicNames.length < _minTopicsRequired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least $_minTopicsRequired topics.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      await _userService.saveUserInterests(user.uid, _selectedTopicNames.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Interests updated!' : 'Welcome!'),
            backgroundColor: Colors.green[700],
          ),
        );
        
        if (widget.isEditing) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: widget.isEditing ? AppBar(
        title: const Text('Manage Your Interests'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ) : null,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: SpinKitFadingCircle(color: theme.colorScheme.primary)
              )
            : Padding(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  bottom: 24.0,
                  top: widget.isEditing ? 0 : 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: widget.isEditing ? 20 : 40),
                    Text(
                      'What are you into right now?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose at least $_minTopicsRequired topics to personalize your feed.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[400]
                      ),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: _OptimizedTopicsGrid(
                        topics: _allTopicItemsSorted,
                        selectedTopics: _selectedTopicNames,
                        onTopicToggle: _toggleTopic,
                        scrollController: _scrollController,
                        onUserInteraction: _pauseAutoScroll,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _isSaving
                        ? SpinKitFadingCircle(color: Colors.blue[600])
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _saveInterests,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              child: Text(
                                widget.isEditing ? 'Update Interests' : 'Get Started'
                              ),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

// Optimized topics grid widget
class _OptimizedTopicsGrid extends StatelessWidget {
  final List<TopicItem> topics;
  final Set<String> selectedTopics;
  final Function(String) onTopicToggle;
  final ScrollController scrollController;
  final VoidCallback onUserInteraction;

  const _OptimizedTopicsGrid({
    required this.topics,
    required this.selectedTopics,
    required this.onTopicToggle,
    required this.scrollController,
    required this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onPanDown: (_) => onUserInteraction(),
      onTap: onUserInteraction,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: _buildTopicsLayout(theme),
      ),
    );
  }

  Widget _buildTopicsLayout(ThemeData theme) {
    const numRows = 4;
    final rows = <List<TopicItem>>[];
    
    // Organize topics into rows
    for (int i = 0; i < numRows; i++) {
      rows.add([]);
    }
    
    for (int i = 0; i < topics.length; i++) {
      rows[i % numRows].add(topics[i]);
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((rowTopics) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: rowTopics.map((topic) =>
              Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: _OptimizedTopicChip(
                  topic: topic,
                  isSelected: selectedTopics.contains(topic.name),
                  onToggle: () => onTopicToggle(topic.name),
                  theme: theme,
                ),
              ),
            ).toList(),
          ),
        ),
      ).toList(),
    );
  }
}

// Optimized topic chip widget
class _OptimizedTopicChip extends StatelessWidget {
  final TopicItem topic;
  final bool isSelected;
  final VoidCallback onToggle;
  final ThemeData theme;

  const _OptimizedTopicChip({
    required this.topic,
    required this.isSelected,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    
    return FilterChip(
      avatar: Icon(
        topic.icon,
        size: 18,
        color: isSelected
            ? theme.colorScheme.onPrimary
            : (isDark ? Colors.white70 : Colors.black54),
      ),
      label: Text(topic.name),
      selected: isSelected,
      onSelected: (_) => onToggle(),
      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : (isDark ? Colors.white : Colors.black87),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(
          color: isSelected 
              ? theme.colorScheme.primary 
              : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
          width: 1.0,
        ),
      ),
    );
  }
}