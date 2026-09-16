import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_page.dart';

class UserFormPage extends StatefulWidget {
  const UserFormPage({super.key});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();

  String gender = 'Female';
  bool loading = false;

  Future<void> saveForm() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (ageController.text.isEmpty ||
        heightController.text.isEmpty ||
        weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() => loading = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'age': int.tryParse(ageController.text),
      'gender': gender,
      'height': double.tryParse(heightController.text),
      'weight': double.tryParse(weightController.text),
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Information'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Female',
                  child: Text('Female'),
                ),
                DropdownMenuItem(
                  value: 'Male',
                  child: Text('Male'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  gender = value;
                }
              },
            ),

            const SizedBox(height: 15),

            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : saveForm,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Save & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}