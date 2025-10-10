import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPremiumUsersPage extends StatefulWidget {
  const AdminPremiumUsersPage({super.key});

  @override
  State<AdminPremiumUsersPage> createState() => _AdminPremiumUsersPageState();
}

class _AdminPremiumUsersPageState extends State<AdminPremiumUsersPage> {
  final TextEditingController emailController = TextEditingController();
  String selectedYear = "1st Year";
  bool isLoading = false;

  final List<String> years = [
    "1st Year",
    "2nd Year",
    "3rd Year",
    "4th Year",
  ];

  Future<void> _grantAccess() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => isLoading = true);

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      final docRef = FirebaseFirestore.instance.collection('users').doc(docId);

      final docSnap = await docRef.get();
      final currentYears =
          List<String>.from(docSnap.data()?['premiumYears'] ?? []);

      if (!currentYears.contains(selectedYear)) {
        currentYears.add(selectedYear);
      }

      await docRef.update({'premiumYears': currentYears});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ $email granted premium for $selectedYear")),
      );
      emailController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ User not found")),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> _revokeAccess(String docId, String year) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(docId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final List<String> currentYears =
        List<String>.from(docSnap.data()?['premiumYears'] ?? []);
    currentYears.remove(year);

    await docRef.update({'premiumYears': currentYears});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Premium Users"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "User Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            /// 🔸 Select Year
            DropdownButtonFormField<String>(
              value: selectedYear,
              items: years
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) => setState(() => selectedYear = val!),
              decoration: const InputDecoration(
                labelText: "Select Year",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: isLoading ? null : _grantAccess,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Grant Premium Access"),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Current Premium Users",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('premiumYears', isNotEqualTo: null)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No premium users yet"));
                  }

                  final users = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final data = users[index].data() as Map<String, dynamic>;
                      final email = data['email'] ?? 'Unknown';
                      final docId = users[index].id;
                      final List<String> premiumYears =
                          List<String>.from(data['premiumYears'] ?? []);

                      return Card(
                        child: ExpansionTile(
                          title: Text(email),
                          subtitle: Text(
                            premiumYears.isEmpty
                                ? "No premium years"
                                : "Premium for: ${premiumYears.join(', ')}",
                            style: const TextStyle(fontSize: 13),
                          ),
                          children: premiumYears.map((year) {
                            return ListTile(
                              title: Text(year),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                onPressed: () => _revokeAccess(docId, year),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
