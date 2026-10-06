import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Login / sign-up screen.
/// No Navigator calls here: AuthGate in main.dart routes automatically
/// (login -> profile screen or dashboard).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static bool _googleReady = false;

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String message = '';

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  Future<void> register() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => message = 'Please fill in all fields');
      return;
    }

    try {
      setState(() {
        loading = true;
        message = '';
      });

      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'username': username,
        'email': email,
        'uid': result.user!.uid,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // No signOut and no Navigator: AuthGate opens the profile screen.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => message = e.message ?? 'Registration failed');
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => message = 'Enter email and password');
      return;
    }

    try {
      setState(() {
        loading = true;
        message = '';
      });

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // AuthGate handles what happens next.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => message = e.message ?? 'Login failed');
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> googleLogin() async {
    try {
      setState(() {
        loading = true;
        message = '';
      });

      await _ensureGoogleReady();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user!;

      // Create the profile document only the first time, so an existing
      // profile (and its profileCompleted flag) is never overwritten.
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'username': user.displayName ?? 'Google User',
          'email': user.email ?? googleUser.email,
          'uid': user.uid,
          'profileCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // AuthGate handles what happens next.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => message = e.message ?? 'Google login failed');
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Google login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Early Warning Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (for Create Account)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            if (loading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: register,
                  child: const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: login,
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: googleLogin,
                  child: const Text('Continue with Google'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
