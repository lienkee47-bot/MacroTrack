import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authenticate.dart';
import 'main_screen.dart';
import '../providers/app_state.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    
    // Return either Authenticate or MainScreen
    if (user == null) {
      return const Authenticate();
    } else {
      // Set the user ID in AppState once they log in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<AppState>(context, listen: false).setUserId(user.uid);
      });
      return const MainScreen();
    }
  }
}
