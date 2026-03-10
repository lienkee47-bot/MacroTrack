import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Food Library
  Stream<QuerySnapshot> getFoods() {
    return _db.collection('foods').snapshots();
  }

  Future<void> addFood(String name, num servingSize, String servingUnit, num kcal, num prot, num carb, num fat) {
    return _db.collection('foods').add({
      'name': name,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'kcal': kcal,
      'protein': prot,
      'carbs': carb,
      'fat': fat,
    });
  }

  Future<void> updateFood(String docId, String name, num servingSize, String servingUnit, num kcal, num prot, num carb, num fat) {
    return _db.collection('foods').doc(docId).update({
      'name': name,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'kcal': kcal,
      'protein': prot,
      'carbs': carb,
      'fat': fat,
    });
  }

  Future<void> deleteFood(String docId) {
    return _db.collection('foods').doc(docId).delete();
  }

  // Daily Targets & User Profiles
  Stream<DocumentSnapshot> getUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Backwards compatibility
  Stream<DocumentSnapshot> getUserTargets(String uid) => getUserProfile(uid);

  Future<void> updateUserTargets(String uid, num kcal, num prot, num carb, num fat) {
    return _db.collection('users').doc(uid).set({
      'dailyTargets': {
        'kcal': kcal,
        'protein': prot,
        'carbs': carb,
        'fat': fat,
      }
    }, SetOptions(merge: true));
  }
  
  Future<void> updateUserField(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).update(data);
  }

  Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_pics').child('$uid.jpg');
      final bytes = await imageFile.readAsBytes();
      
      final uploadTask = ref.putData(
        bytes, 
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload task failed: ${snapshot.state}');
      }
      
      final url = await snapshot.ref.getDownloadURL();
      await updateUserField(uid, {'profilePictureUrl': url});
      return url;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        throw Exception('Storage bucket not initialized. Please click "Get Started" in your Firebase Console under Storage, then try again!');
      }
      throw Exception(e.message ?? 'Firebase Storage error');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  // Logs
  Stream<DocumentSnapshot> getDailyLog(String uid, String dateStr) {
    return _db.collection('logs').doc(uid).collection('dailyLogs').doc(dateStr).snapshots();
  }

  Future<void> addFoodToLog(String uid, String dateStr, String mealType, Map<String, dynamic> foodItem) {
    return _db.collection('logs').doc(uid).collection('dailyLogs').doc(dateStr).set({
      mealType: FieldValue.arrayUnion([foodItem])
    }, SetOptions(merge: true));
  }
}

