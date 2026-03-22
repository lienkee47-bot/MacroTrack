import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum RegistrationMethod { barcode, ocr, manual }

/// Modal bottom sheet that lets the user pick one of the 3 registration methods.
class RegistrationMethodSelector extends StatelessWidget {
  final void Function(RegistrationMethod method) onSelected;

  const RegistrationMethodSelector({super.key, required this.onSelected});

  /// Show the selector as a modal bottom sheet and return the chosen method.
  static Future<RegistrationMethod?> show(BuildContext context) {
    return showModalBottomSheet<RegistrationMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrationMethodSelector(
        onSelected: (method) => Navigator.pop(context, method),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add New Food',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how you want to add a food item',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          _MethodTile(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Barcode / QR Scanner',
            subtitle: 'Scan a product barcode or QR code.',
            color: AppTheme.primaryTeal,
            isDark: isDark,
            onTap: () => onSelected(RegistrationMethod.barcode),
          ),
          const SizedBox(height: 12),
          _MethodTile(
            icon: Icons.document_scanner_rounded,
            title: 'Image to Text',
            subtitle: 'Snap or upload a photo of the nutrition label.',
            color: const Color(0xFF5C6BC0), // indigo accent
            isDark: isDark,
            onTap: () => onSelected(RegistrationMethod.ocr),
          ),
          const SizedBox(height: 12),
          _MethodTile(
            icon: Icons.edit_note_rounded,
            title: 'Manual Entry',
            subtitle: 'Type in the macros yourself.',
            color: AppTheme.primaryOrange,
            isDark: isDark,
            onTap: () => onSelected(RegistrationMethod.manual),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppTheme.darkCard : Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
