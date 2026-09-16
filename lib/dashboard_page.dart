import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello ${data['username'] ?? 'User'}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    subtitle: Text(
                      'Age: ${data['age'] ?? '-'} | '
                      'Height: ${data['height'] ?? '-'} cm | '
                      'Weight: ${data['weight'] ?? '-'} kg',
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                const Card(
                  child: ListTile(
                    leading: Icon(Icons.favorite),
                    title: Text('Heart Rate'),
                    subtitle: Text('Apple Watch data will appear here'),
                    trailing: Text('-- BPM'),
                  ),
                ),

                const SizedBox(height: 15),

                const Card(
                  child: ListTile(
                    leading: Icon(Icons.directions_walk),
                    title: Text('Steps'),
                    subtitle: Text('Apple Watch data will appear here'),
                    trailing: Text('--'),
                  ),
                ),

                const SizedBox(height: 15),

                const Card(
                  child: ListTile(
                    leading: Icon(Icons.warning_amber),
                    title: Text('Early Warning Status'),
                    subtitle: Text(
                      'No abnormal pattern detected',
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Apple Health connection will be enabled on iPhone',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.watch),
                    label: const Text('Connect Apple Watch'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}