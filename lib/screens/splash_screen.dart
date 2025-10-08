// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// No need to import the page classes if using named routing.

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2)); // small splash delay

    try {
      // ✅ Correctly waits for the Firebase user session to resolve
      final user = await FirebaseAuth.instance.authStateChanges().first;

      if (!mounted) return;

      if (user == null) {
        // 🚪 FIX: Navigate to LoginPage using NAMED ROUTE
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
        return;
      }

      // ✅ User session exists, check Firestore role
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['role'] == 'admin') {
        // 🔑 FIX: Logged in as admin -> go to AdminDashboard using NAMED ROUTE
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/admin_dashboard',
          (route) => false,
        );
      } else {
        // 👤 Normal user -> go to HomePage using NAMED ROUTE
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
      }
    } catch (e) {
      // If something goes wrong -> send to login page using named route
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/loggos.jpeg", height: 120),
            const SizedBox(height: 20),
            const Text(
              "MBBSFreaks",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Colors.purple,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}