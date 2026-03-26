import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/food_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class OcrProcessorService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// The main entry point to scan a label using the new backend pipeline.
  static Future<FoodModel> extractFromImage(String imagePath) async {
    final String scanId = DateTime.now().millisecondsSinceEpoch.toString();
  
    try {
      // 1. PRE-PROCESSING: Compress and Resize
      // This reduces a 15MB file to ~500KB while keeping text sharp
      final String targetPath = p.join((await getTemporaryDirectory()).path, '${scanId}_compressed.jpg');
    
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imagePath, 
        targetPath,
        quality: 80,         // Balance between file size and text clarity
        minWidth: 1080,      // Forces the image into a standard HD width
        minHeight: 1920,     // Ensures vertical labels remain high-res
        keepExif: false,     // CRITICAL: Strips EXIF so rotation is "baked in"
      );

      if (compressedXFile == null) throw Exception("Image compression failed");
      final File fileToUpload = File(compressedXFile.path);

      // 2. UPLOAD: Use the new, smaller file
      final Reference storageRef = _storage.ref().child('ocr_pics/$scanId.jpg');
      await storageRef.putFile(fileToUpload); //
    
      final String gsPath = 'gs://${storageRef.bucket}/${storageRef.fullPath}';

      // 3. TRIGGER & LISTEN: (Rest of your existing Firestore logic)
      final DocumentReference docRef = _db.collection('foodScans').doc(scanId);
      await docRef.set({
        'image_url': gsPath,
        'status': 'processing',
      });

      return await docRef.snapshots()
          .map((snap) => _parseExtensionResult(snap))
          .where((food) => food != null)
          .cast<FoodModel>()
          .first
          .timeout(const Duration(seconds: 30)); //
        
    } catch (e) {
      throw Exception('Resolution pre-processing failed: $e');
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