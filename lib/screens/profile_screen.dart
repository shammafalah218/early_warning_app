import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/firestore_service.dart';

/// Replaces the existing "User Information" screen. Same fields, plus
/// optional risk-factor questions used as context for the AI explanation.
class ProfileScreen extends StatefulWidget {
  final UserProfile? existing;
  const ProfileScreen({super.key, this.existing});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _age = TextEditingController(text: widget.existing?.age?.toString() ?? '');
  late final _height = TextEditingController(text: widget.existing?.height?.toStringAsFixed(0) ?? '');
  late final _weight = TextEditingController(text: widget.existing?.weight?.toString() ?? '');
  late String _gender = widget.existing?.gender ?? 'Female';
  late bool _fhDiabetes = widget.existing?.familyHistoryDiabetes ?? false;
  late bool _fhHypertension = widget.existing?.familyHistoryHypertension ?? false;
  late bool _smoker = widget.existing?.smoker ?? false;
  late String _language = widget.existing?.language ?? 'en';
  bool _saving = false;

  String? _range(String? v, num min, num max) {
    final x = num.tryParse(v ?? '');
    if (x == null) return 'Required';
    if (x < min || x > max) return 'Enter a value between $min and $max';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser!;
    final p = UserProfile(
      uid: user.uid,
      username: widget.existing?.username ?? '',
      email: user.email ?? '',
      age: int.parse(_age.text),
      gender: _gender,
      height: double.parse(_height.text),
      weight: double.parse(_weight.text),
      familyHistoryDiabetes: _fhDiabetes,
      familyHistoryHypertension: _fhHypertension,
      smoker: _smoker,
      language: _language,
    );
    await FirestoreService.instance.saveProfile(p);
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Information')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
              controller: _age,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              validator: (v) => _range(v, 10, 110)),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
            ],
            onChanged: (v) => setState(() => _gender = v!),
          ),
          TextFormField(
              controller: _height,
              decoration: const InputDecoration(labelText: 'Height (cm)'),
              keyboardType: TextInputType.number,
              validator: (v) => _range(v, 100, 230)),
          TextFormField(
              controller: _weight,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _range(v, 25, 300)),
          const SizedBox(height: 24),
          Text('Risk factors (optional)', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
              title: const Text('Parent or sibling with diabetes'),
              value: _fhDiabetes,
              onChanged: (v) => setState(() => _fhDiabetes = v)),
          SwitchListTile(
              title: const Text('Parent or sibling with high blood pressure'),
              value: _fhHypertension,
              onChanged: (v) => setState(() => _fhHypertension = v)),
          SwitchListTile(
              title: const Text('I smoke'),
              value: _smoker,
              onChanged: (v) => setState(() => _smoker = v)),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Language for AI explanations'),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
            ],
            onChanged: (v) => setState(() => _language = v!),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save & Continue'),
          ),
        ]),
      ),
    );
  }
}
