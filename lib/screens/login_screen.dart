import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'animated_health_background.dart';

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
    const purple = Color(0xFF6938C6);
    const darkPurple = Color(0xFF27134F);
    InputDecoration fieldDecoration(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF796B8D)),
          prefixIcon: Icon(icon, color: purple),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: Color(0xFFE6D8F6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: purple, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      body: Stack(children: [
        const Positioned.fill(child: AnimatedHealthBackground()),
        SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9569E6), purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: const [BoxShadow(
                          color: Color(0x446938C6), blurRadius: 22, offset: Offset(0, 9)),
                        ],
                      ),
                      child: const Icon(Icons.favorite_border_rounded,
                          color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text('EARLY WARNING',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, letterSpacing: 2.4,
                          color: purple, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800,
                          color: darkPurple)),
                  const SizedBox(height: 9),
                  const Text('Your health journey starts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF82758F))),
                  const SizedBox(height: 32),
                  TextField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: fieldDecoration('Username (for Create Account)', Icons.person_outline),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: fieldDecoration('Email address', Icons.mail_outline),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: fieldDecoration('Password', Icons.lock_outline),
                  ),
                  const SizedBox(height: 26),
                  if (loading)
                    const Center(child: CircularProgressIndicator(color: purple))
                  else ...[
                    FilledButton(
                      onPressed: login,
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        minimumSize: const Size.fromHeight(53),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      ),
                      child: const Text('Log in',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: register,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: purple,
                        side: const BorderSide(color: Color(0xFFCBB3EF), width: 1.5),
                        minimumSize: const Size.fromHeight(53),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      ),
                      child: const Text('Create account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 20),
                    const Row(children: [
                      Expanded(child: Divider(color: Color(0xFFE2D6F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('or', style: TextStyle(color: Color(0xFF94869F))),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2D6F0))),
                    ]),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: googleLogin,
                      icon: const Icon(Icons.account_circle_outlined, color: purple),
                      label: const Text('Continue with Google',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: darkPurple,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE6D8F6)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      ),
                    ),
                  ],
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 19),
                    Text(message, textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF9A3460))),
                  ],
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
      ]),
    );
  }
}
