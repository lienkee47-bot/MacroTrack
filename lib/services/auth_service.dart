import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Real-time auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email & password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  // Register with email & password
  Future<User?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      
      if (user != null) {
        // Create a new document for the user with the uid
        await _db.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'proMember': false,
          'createdAt': FieldValue.serverTimestamp(),
          'personalStats': {
            'age': 0,
            'weight': 0,
            'height': 0,
          },
          'preferences': {
            'notifications': true,
            'units': 'Imperial',
          },
          'dailyTargets': {
            'kcal': 2000,
            'protein': 150,
            'carbs': 200,
            'fat': 65,
          }
        });
      }
      return user;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
