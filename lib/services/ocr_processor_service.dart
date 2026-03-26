import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/food_model.dart';

class OcrProcessorService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// The main entry point to scan a label using the new backend pipeline.
  static Future<FoodModel> extractFromImage(String imagePath) async {
    final String scanId = DateTime.now().millisecondsSinceEpoch.toString();
    final File imageFile = File(imagePath);

    try {
      // 1. Upload the image to the 'ocr_pics' folder
      final Reference storageRef = _storage.ref().child('ocr_pics/$scanId.jpg');
      await storageRef.putFile(imageFile);
      
      // Get the gs:// path (Internal Firebase path used by the extension)
      final String gsPath = 'gs://${storageRef.bucket}/${storageRef.fullPath}';

      // 2. Trigger the Gemini extension by creating a Firestore document
      final DocumentReference docRef = _db.collection('foodScans').doc(scanId);
      await docRef.set({
        'image_url': gsPath,
        'status': 'processing',
      });

      // 3. Listen for the 'extracted_data' field to be populated
      // We use a timeout to ensure the app doesn't wait forever if the network fails
      return await docRef.snapshots()
          .map((snap) => _parseExtensionResult(snap))
          .where((food) => food != null)
          .cast<FoodModel>()
          .first
          .timeout(const Duration(seconds: 30));
          
    } catch (e) {
      throw Exception('Failed to process label: $e');
    }
  }

  /// Helper to parse the JSON string returned by the Gemini extension
  static FoodModel? _parseExtensionResult(DocumentSnapshot snap) {
    if (!snap.exists) return null;
    
    final data = snap.data() as Map<String, dynamic>;
    
    // Check if the extension has finished and written the result
    if (data.containsKey('extracted_data')) {
      String rawJson = data['extracted_data'];
      
      // Strip markdown code blocks if the AI accidentally included them
      rawJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final Map<String, dynamic> decoded = jsonDecode(rawJson);
      
      return FoodModel(
        name: decoded['name'] ?? 'Unknown Food',
        servingSize: num.tryParse(decoded['servingSize']?.toString() ?? '100') ?? 100,
        servingUnit: 'g', // You can refine this to parse the unit from servingSize if needed
        kcal: (decoded['calories'] as num).toDouble(),
        protein: (decoded['protein'] as num).toDouble(),
        carbs: (decoded['carbs'] as num).toDouble(),
        fat: (decoded['fat'] as num).toDouble(),
      );
    }
    
    return null;
  }
}