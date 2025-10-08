import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isResettingPassword = false;
  bool _obscurePassword = true; // 👁️ Password toggle state

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email address")),
      );
      return;
    }

    setState(() => _isResettingPassword = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Password Reset Email Sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Check your email inbox or spam folder for the reset link.'),
              const SizedBox(height: 8),
              Text(_emailController.text.trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _loginUser() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          // ✅ Navigate to HomePage and clear back stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User data not found in Firestore")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed. Please try again.";
      if (e.code == 'user-not-found') message = "No user found with this email.";
      if (e.code == 'wrong-password') message = "Invalid credentials.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("MBBSFreaks",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700)),
              const SizedBox(height: 6),
              const Text(
                "Your Medical Journey Starts Here",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset("assets/loggos.jpeg", height: 300),
              ),
              const SizedBox(height: 32),

              // 📧 Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email),
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔐 Password with Eye Toggle
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isResettingPassword ? null : _resetPassword,
                  child: _isResettingPassword
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.blue),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔵 Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Login",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // 📝 Signup
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/signup'),
                child: const Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 🧑‍💼 Admin Login
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/admin_login'),
                child: const Text(
                  "Admin Login",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
