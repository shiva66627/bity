import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'premium_users_list_page.dart';

class AdminPremiumUsersPage extends StatefulWidget {
  const AdminPremiumUsersPage({super.key});

  @override
  State<AdminPremiumUsersPage> createState() => _AdminPremiumUsersPageState();
}

class _AdminPremiumUsersPageState extends State<AdminPremiumUsersPage> {
  final TextEditingController emailController = TextEditingController();
  String selectedYear = "1st Year";
  bool isLoading = false;

  int premiumCount = 0, y1 = 0, y2 = 0, y3 = 0, y4 = 0;

  Future<void> _grantPremium() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ User not found")),
        );
      } else {
        final docRef = query.docs.first.reference;
        final data = (await docRef.get()).data() as Map<String, dynamic>;
        final List<String> years = List<String>.from(data['premiumYears'] ?? []);
        if (!years.contains(selectedYear)) {
          years.add(selectedYear);
          await docRef.update({'premiumYears': years});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ $email granted $selectedYear")),
        );
        emailController.clear();
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Premium Users"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allUsers = snapshot.data!.docs;
          final premiumUsers = allUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final List<dynamic> years = data['premiumYears'] ?? [];
            return years.isNotEmpty;
          }).toList();

          // count logic
          premiumCount = premiumUsers.length;
          y1 = y2 = y3 = y4 = 0;
          for (var u in premiumUsers) {
            final list = List<String>.from((u.data() as Map)['premiumYears']);
            if (list.contains("1st Year")) y1++;
            if (list.contains("2nd Year")) y2++;
            if (list.contains("3rd Year")) y3++;
            if (list.contains("4th Year")) y4++;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ EMAIL INPUT
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "User Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // ✅ YEAR DROPDOWN
                DropdownButtonFormField<String>(
                  value: selectedYear,
                  items: const [
                    DropdownMenuItem(value: "1st Year", child: Text("1st Year")),
                    DropdownMenuItem(value: "2nd Year", child: Text("2nd Year")),
                    DropdownMenuItem(value: "3rd Year", child: Text("3rd Year")),
                    DropdownMenuItem(value: "4th Year", child: Text("4th Year")),
                  ],
                  onChanged: (v) => setState(() => selectedYear = v!),
                  decoration: const InputDecoration(
                    labelText: "Select Year",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // ✅ GRANT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: isLoading ? null : _grantPremium,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Grant Premium Access"),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // ✅ YEAR SUMMARY
                Text("Premium Users: $premiumCount",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Year-wise Breakdown:",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("1st Year      : $y1"),
                Text("2nd Year      : $y2"),
                Text("3rd Year      : $y3"),
                Text("4th Year      : $y4"),
                const SizedBox(height: 20),

                // ✅ VIEW BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumUsersListPage()),
                      );
                    },
                    child: const Text("View Current Premium Users"),
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
