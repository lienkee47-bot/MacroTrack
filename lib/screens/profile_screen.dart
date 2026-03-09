import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  late Stream<DocumentSnapshot> _profileStream;
  bool _streamInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      final user = Provider.of<User?>(context);
      final db = Provider.of<FirestoreService>(context, listen: false);
      if (user != null) {
        _profileStream = db.getUserProfile(user.uid);
        _streamInitialized = true;
      }
    }
  }

  Future<void> _pickImage(String uid, FirestoreService db) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);
      
      try {
        final url = await db.uploadProfileImage(uid, File(pickedFile.path));
        if (!mounted) return;
        setState(() => _isUploading = false);
        
        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated'), backgroundColor: Color(0xFF006666)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditSheet(String uid, FirestoreService db, String fieldName, String title, dynamic currentValue, bool isNumeric, {String? hintText}) {
    TextEditingController controller = TextEditingController(text: currentValue.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Update $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                decoration: InputDecoration(
                  labelText: title,
                  hintText: hintText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final val = controller.text;
                  dynamic finalVal = isNumeric ? double.tryParse(val) ?? 0 : val;
                  db.updateUserField(uid, {fieldName: finalVal});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title updated'), backgroundColor: const Color(0xFF006666)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6700),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ), // Updated padding
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  void _resetPassword(String email) {
    AuthService().sendPasswordReset(email);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent'), backgroundColor: Color(0xFF006666)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);

    if (user == null || !_streamInitialized) {
      return const Center(child: Text("Please log in"));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text("No Data"));
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? user.displayName ?? 'User';
          final email = user.email ?? 'No email';
          final photoUrl = data['profilePictureUrl'] ?? data['photoUrl'];
          
          final stats = data['personalStats'] as Map<String, dynamic>? ?? {};
          final num ageRaw = stats['age'] ?? 0;
          final int age = ageRaw.toInt();
          
          final num weightRaw = stats['weight'] ?? 0;
          final double weight = weightRaw.toDouble();
          
          final num heightRaw = stats['height'] ?? 0;
          final double height = heightRaw.toDouble();
          
          String weightStr = '${weight.toStringAsFixed(1)} kg';
          String heightStr = '${height.toStringAsFixed(1)} cm';

          final bool hasValidImage = photoUrl != null && photoUrl.toString().trim().isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      ClipOval(
                        child: Container(
                          width: 100,
                          height: 100,
                          color: const Color(0xFFF5E6CC),
                          child: _isUploading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6700)))
                              : hasValidImage
                                  ? Image.network(
                                      photoUrl.toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                    )
                                  : const Icon(Icons.person, size: 60, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _pickImage(user.uid, db),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6700),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Pro Member', style: TextStyle(color: Color(0xFFFF6700), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 32),
                
                _buildSectionHeader(Icons.insert_chart_outlined, 'Personal Stats'),
                _buildActionTile('Age', '$age', () => _showEditSheet(user.uid, db, 'personalStats.age', 'Age', age, true)),
                _buildActionTile('Weight', weightStr, () => _showEditSheet(user.uid, db, 'personalStats.weight', 'Weight', weight, true, hintText: 'kg')),
                _buildActionTile('Height', heightStr, () => _showEditSheet(user.uid, db, 'personalStats.height', 'Height', height, true, hintText: 'cm')),

                
                const SizedBox(height: 32),
                _buildSectionHeader(Icons.security, 'Account'),
                _buildInfoTile('Email', email),
                _buildActionTile('Password', '********', () => _resetPassword(email)),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.grey),
                    label: const Text('Log Out', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black87)),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String trailing, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.black87)),
            Row(
              children: [
                Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
