import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'user_form_page.dart';
import 'dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String message = '';

  Future<void> register() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        message = 'Please fill in all fields';
      });
      return;
    }

    try {
      setState(() {
        loading = true;
        message = '';
      });

      final result =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
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
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out after registration so we can test Login properly.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() {
        message = 'Account created successfully ✅ Now login';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        message = e.message ?? 'Registration failed';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        message = 'Registration failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> login() async {
  final email = emailController.text.trim();
  final password = passwordController.text;

  if (email.isEmpty || password.isEmpty) {
    setState(() {
      message = 'Enter email and password';
    });
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

    final user = FirebaseAuth.instance.currentUser!;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    final profileCompleted =
        data != null && data['profileCompleted'] == true;

    if (!mounted) return;

    if (profileCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const UserFormPage(),
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    setState(() {
      message = e.message ?? 'Login failed';
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      message = 'Login failed: $e';
    });
  } finally {
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }
}

  Future<void> googleLogin() async {
    try {
      setState(() {
        loading = true;
        message = '';
      });

      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'username': result.user!.displayName ?? 'Google User',
        'email': result.user!.email ?? googleUser.email,
        'uid': result.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        message = 'Google login successful ✅';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        message = e.message ?? 'Google login failed';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        message = 'Google login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
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
      appBar: AppBar(
        title: const Text('Early Warning Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
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

            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}