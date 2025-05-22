import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'users';

  Future<void> saveUserInterests(String userId, List<String> interests) async {
    try {
      await _firestore.collection(_collectionPath).doc(userId).update({
        'selectedTopics': interests,
        'interestsSetAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving user interests: $e");
      rethrow;
    }
  }

  Future<List<String>> getUserInterests(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionPath).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        List<dynamic>? topics = (doc.data() as Map<String, dynamic>)['selectedTopics'];
        return topics?.cast<String>() ?? [];
      }
      return [];
    } catch (e) {
      print("Error fetching user interests: $e");
      return [];
    }
  }
  
  Future<bool> checkIfUserHasSetInterests(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionPath).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic>? topics = data['selectedTopics'];
        // Consider interests set if the field exists and is not empty, 
        // or if a specific marker like 'interestsSetAt' exists.
        return topics != null && topics.isNotEmpty;
      }
      return false;
    } catch (e) {
      print("Error checking user interests: $e");
      return false; // Default to false on error, prompting for selection
    }
  }
}