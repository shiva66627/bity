import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'premium_user_details_page.dart';
import 'package:intl/intl.dart';

class PremiumUsersListPage extends StatefulWidget {
  const PremiumUsersListPage({super.key});

  @override
  State<PremiumUsersListPage> createState() => _PremiumUsersListPageState();
}

class _PremiumUsersListPageState extends State<PremiumUsersListPage> {
  final TextEditingController searchCtrl = TextEditingController();
  String selectedYear = "All";
  DateTime? selectedDate;

  final List<String> yearOptions = ["All", "1st Year", "2nd Year", "3rd Year", "4th Year"];

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  bool _matchesDate(Timestamp timestamp) {
    if (selectedDate == null) return true;
    final createdAt = timestamp.toDate();
    return createdAt.year == selectedDate!.year &&
        createdAt.month == selectedDate!.month &&
        createdAt.day == selectedDate!.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Premium Users"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allUsers = snapshot.data!.docs;

          // Step 1: Premium only
          final premiumUsers = allUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final List<String> years = List<String>.from(data['premiumYears'] ?? []);
            return years.isNotEmpty;
          }).toList();

          // Step 2: Year Filter
          final yearFiltered = selectedYear == "All"
              ? premiumUsers
              : premiumUsers.where((doc) {
                  final years = List<String>.from((doc.data() as Map)['premiumYears']);
                  return years.contains(selectedYear);
                }).toList();

          // Step 3: Date Filter
          final dateFiltered = selectedDate == null
              ? yearFiltered
              : yearFiltered.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = data['createdAt'] as Timestamp?;
                  return createdAt != null && _matchesDate(createdAt);
                }).toList();

          // Step 4: Search Filter
          final query = searchCtrl.text.trim().toLowerCase();
          final finalList = query.isEmpty
              ? dateFiltered
              : dateFiltered.where((doc) {
                  final email = (doc.data() as Map)['email'].toString().toLowerCase();
                  return email.contains(query);
                }).toList();

          int count = finalList.length;

          return Column(
            children: [
              // 🔹 Filter Row (Year + Date)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                child: Row(
                  children: [
                    const Text("Filter: "),
                    DropdownButton<String>(
                      value: selectedYear,
                      items: yearOptions.map((y) {
                        return DropdownMenuItem(value: y, child: Text(y));
                      }).toList(),
                      onChanged: (v) => setState(() => selectedYear = v!),
                    ),
                    const Spacer(),
                    selectedDate == null
                        ? IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _pickDate,
                          )
                        : Row(
                            children: [
                              Text(DateFormat("dd MMM yyyy").format(selectedDate!)),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => selectedDate = null),
                              ),
                            ],
                          ),
                  ],
                ),
              ),

              // 🔹 Search Bar
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search email",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtrl.clear();
                        setState(() {});
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              // 🔹 Count (Shown ONLY when date is selected)
              if (selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Showing: $count users on ${DateFormat("dd MMM yyyy").format(selectedDate!)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 🔹 List
              Expanded(
                child: ListView.builder(
                  itemCount: finalList.length,
                  itemBuilder: (_, index) {
                    final doc = finalList[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final email = data['email'];
                    final years = List<String>.from(data['premiumYears']);

                    return ListTile(
                      title: Text(email),
                      subtitle: Text("Premium for: ${years.join(", ")}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PremiumUserDetailsPage(userId: doc.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
