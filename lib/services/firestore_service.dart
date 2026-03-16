import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Food Library (private per user: foods/{uid}/userFoods/)
  Stream<QuerySnapshot> getFoods(String uid) {
    return _db.collection('foods').doc(uid).collection('userFoods').snapshots();
  }

  Future<void> addFood(String uid, String name, num servingSize, String servingUnit, num kcal, num prot, num carb, num fat) {
    return _db.collection('foods').doc(uid).collection('userFoods').add({
      'name': name,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'kcal': kcal,
      'protein': prot,
      'carbs': carb,
      'fat': fat,
    });
  }

  Future<void> updateFood(String uid, String docId, String name, num servingSize, String servingUnit, num kcal, num prot, num carb, num fat) {
    return _db.collection('foods').doc(uid).collection('userFoods').doc(docId).update({
      'name': name,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'kcal': kcal,
      'protein': prot,
      'carbs': carb,
      'fat': fat,
    });
  }

  Future<void> deleteFood(String uid, String docId) {
    return _db.collection('foods').doc(uid).collection('userFoods').doc(docId).delete();
  }

  /// One-time migration: copies root /foods docs into foods/{targetUid}/userFoods/
  /// and deletes the originals. Hardcoded target UID per user request.
  Future<int> migrateRootFoods() async {
    const targetUid = 'L6CriapTlCYRjStlISL81IqEdWf2';
    final rootFoods = await _db.collection('foods').get();
    
    // Filter only actual food documents (skip sub-collection parent docs)
    final docsToMigrate = rootFoods.docs.where((doc) {
      final data = doc.data();
      return data.containsKey('name'); // real food docs have a 'name' field
    }).toList();

    if (docsToMigrate.isEmpty) return 0;

    final batch = _db.batch();
    for (var doc in docsToMigrate) {
      // Copy to private path
      final newRef = _db.collection('foods').doc(targetUid).collection('userFoods').doc();
      batch.set(newRef, doc.data());
      // Delete original
      batch.delete(doc.reference);
    }
    await batch.commit();
    return docsToMigrate.length;
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
  Stream<QuerySnapshot> getDailyLogEntries(String uid, String dateStr) {
    return _db.collection('logs').doc(uid).collection('dailyLogs').doc(dateStr).collection('entries').orderBy('timestamp').snapshots();
  }

  Future<void> addFoodToLog(String uid, String dateStr, String mealType, Map<String, dynamic> entryData) {
    return _db.collection('logs').doc(uid).collection('dailyLogs').doc(dateStr).collection('entries').add(entryData);
  }

  Future<void> updateFoodInLog(String uid, String dateStr, String docId, Map<String, dynamic> entryData) {
    return _db.collection('logs').doc(uid).collection('dailyLogs').doc(dateStr).collection('entries').doc(docId).update(entryData);
  }

  Future<void> deleteFoodFromLog(String uid, String dateStr, String docId) {
    return _db.collection('logs').doc(uid).collection('dailyLogs').doc(dateStr).collection('entries').doc(docId).delete();
  }
}

