import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  void _showPhotoOptions(String uid, FirestoreService db, bool hasExistingPhoto) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppTheme.primaryOrange),
                  title: Text(hasExistingPhoto ? 'Update Profile Picture' : 'Upload Profile Picture'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(uid, db);
                  },
                ),
                if (hasExistingPhoto)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: isDark ? AppTheme.darkTeal : AppTheme.primaryTeal),
                    title: const Text('Remove Profile Picture'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removeProfilePicture(uid, db);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(String uid, FirestoreService db) async {
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
            const SnackBar(content: Text('Profile picture updated', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeProfilePicture(String uid, FirestoreService db) async {
    try {
      await db.updateUserField(uid, {'profilePictureUrl': ''});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture removed', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove picture: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
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
                    SnackBar(content: Text('$title updated', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
      const SnackBar(content: Text('Password reset email sent', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    if (user == null || !_streamInitialized) {
      return const Center(child: Text("Please log in"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // ── Dark/Light mode toggle ───────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                  color: isDark ? Colors.amber : Colors.grey.shade700,
                ),
              ),
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),
        ],
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

          // Theme-aware colors for tiles
          final tileColor = isDark ? AppTheme.darkCard : Colors.grey[50];
          final tileTextColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);
          final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.grey;

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
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF5E6CC),
                          child: _isUploading
                              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
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
                          onTap: () => _showPhotoOptions(user.uid, db, hasValidImage),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryOrange,
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
                Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: tileTextColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.primaryOrange.withValues(alpha: 0.15) : const Color(0xFFFFF0E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Pro Member', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 32),
                
                _buildSectionHeader(Icons.insert_chart_outlined, 'Personal Stats', secondaryTextColor, tileTextColor),
                _buildActionTile('Age', '$age', () => _showEditSheet(user.uid, db, 'personalStats.age', 'Age', age, true), tileColor!, tileTextColor),
                _buildActionTile('Weight', weightStr, () => _showEditSheet(user.uid, db, 'personalStats.weight', 'Weight', weight, true, hintText: 'kg'), tileColor, tileTextColor),
                _buildActionTile('Height', heightStr, () => _showEditSheet(user.uid, db, 'personalStats.height', 'Height', height, true, hintText: 'cm'), tileColor, tileTextColor),

                
                const SizedBox(height: 32),
                _buildSectionHeader(Icons.security, 'Account', secondaryTextColor, tileTextColor),
                _buildInfoTile('Email', email, tileColor, tileTextColor, secondaryTextColor),
                _buildActionTile('Password', '********', () => _resetPassword(email), tileColor, tileTextColor),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                    },
                    icon: Icon(Icons.logout, color: secondaryTextColor),
                    label: Text('Log Out', style: TextStyle(color: tileTextColor.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey[300]!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox();
                    return Text(
                      'v${snap.data!.version}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTeal : AppTheme.primaryTeal),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color iconColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String trailing, Color bgColor, Color textColor, Color trailingColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: textColor)),
          Text(trailing, style: TextStyle(fontWeight: FontWeight.bold, color: trailingColor)),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String trailing, VoidCallback onTap, Color bgColor, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: textColor)),
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
