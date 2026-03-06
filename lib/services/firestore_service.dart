import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Food Library
  Stream<QuerySnapshot> getFoods() {
    return _db.collection('foods').snapshots();
  }

  Future<void> addFood(String name, num kcal, num prot, num carb, num fat) {
    return _db.collection('foods').add({
      'name': name,
      'kcal': kcal,
      'protein': prot,
      'carbs': carb,
      'fat': fat,
    });
  }

  // Daily Targets
  Stream<DocumentSnapshot> getUserTargets(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

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
