import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// General educational chat, separate from the alert explanation model.
/// Conversation history is kept in memory for this chat session only.
class HealthChatService {
  static const _instructions = '''
You are a supportive general health education assistant inside Early Warning.
Answer in the same language as the user, using clear and concise language.
Provide general, evidence-informed health information, not diagnoses.
Never claim to access Apple Watch readings, medical records, or the user's profile.
Do not invent personal measurements or health conditions.
Do not prescribe medication, doses, or advise starting, stopping, or changing medication.
For possible emergencies (e.g., chest pain, stroke symptoms, severe breathing difficulty),
urge immediate local emergency medical assistance.
When symptoms are concerning or persistent, advise a qualified clinician.
Acknowledge uncertainty and ask a clarifying question when necessary.
Do not request identifying or sensitive information unnecessarily.
''';

  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.1-flash-lite',
    systemInstruction: Content.system(_instructions),
    generationConfig: GenerationConfig(temperature: 0.4),
  );

  late final ChatSession _chat = _model.startChat();

  Future<String> ask(String message) async {
    final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return 'Please sign in to use AI Health Chat.';
  }

  final profile = await FirestoreService.instance.getProfile(user.uid);

  if (profile?.aiConsent != true) {
    return 'Please enable AI consent in your health profile before using the chatbot.';
  }

    final response = await _chat.sendMessage(Content.text(message.trim()))
        .timeout(const Duration(seconds: 35));
    final answer = response.text?.trim();
    if (answer == null || answer.isEmpty) {
      throw StateError('No response received from AI');
    }
    return answer;
  }
}
