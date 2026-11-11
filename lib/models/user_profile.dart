import 'package:cloud_firestore/cloud_firestore.dart';

/// Stored at users/{uid}. Keeps the fields the app already writes
/// (username, email, age, gender, height, weight, profileCompleted, ...)
/// and adds optional risk-factor answers used as context for the AI.
class UserProfile {
  final String uid;
  final String username;
  final String email;
  final int? age;
  final String? gender;
  final double? height; // cm
  final double? weight; // kg
  final bool familyHistoryDiabetes;
  final bool familyHistoryHypertension;
  final bool smoker;
  final String language; // 'en' or 'ar' — language for AI explanations
  final bool profileCompleted;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.familyHistoryDiabetes = false,
    this.familyHistoryHypertension = false,
    this.smoker = false,
    this.language = 'en',
    this.profileCompleted = false,
  });

  double? get bmi => (height != null && weight != null && height! > 0)
      ? weight! / ((height! / 100) * (height! / 100))
      : null;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) =>
      UserProfile(
        uid: uid,
        username: m['username'] as String? ?? '',
        email: m['email'] as String? ?? '',
        age: (m['age'] as num?)?.toInt(),
        gender: m['gender'] as String?,
        height: (m['height'] as num?)?.toDouble(),
        weight: (m['weight'] as num?)?.toDouble(),
        familyHistoryDiabetes: m['familyHistoryDiabetes'] as bool? ?? false,
        familyHistoryHypertension:
            m['familyHistoryHypertension'] as bool? ?? false,
        smoker: m['smoker'] as bool? ?? false,
        language: m['language'] as String? ?? 'en',
        profileCompleted: m['profileCompleted'] as bool? ?? false,
      );

  Map<String, dynamic> toUpdateMap() => {
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'familyHistoryDiabetes': familyHistoryDiabetes,
        'familyHistoryHypertension': familyHistoryHypertension,
        'smoker': smoker,
        'language': language,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
