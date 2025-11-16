// ALL_OFFERS_PAGE.DART
// Fully working: Year-wise → Subject selection + Bulk offers → Payment screen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subscription_selection_screen.dart';
import 'payment_screen.dart';

class AllOffersPage extends StatefulWidget {
  const AllOffersPage({super.key});

  @override
  State<AllOffersPage> createState() => _AllOffersPageState();
}

class _AllOffersPageState extends State<AllOffersPage> {
  final years = ["1st Year", "2nd Year", "3rd Year", "4th Year"];
  final Map<String, bool> expanded = {};

  @override
  void initState() {
    super.initState();
    for (var y in years) {
      expanded[y] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("All Offers"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Choose Your Year",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ...years.map((y) => _yearCard(y)).toList(),

            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Bulk Offers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildBulkOffersList(),
          ],
        ),
      ),
    );
  }

  // ------------------------ YEAR CARD ------------------------
  Widget _yearCard(String year) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
          year,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        initiallyExpanded: expanded[year] ?? false,
        onExpansionChanged: (val) => setState(() => expanded[year] = val),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionSelectionScreen(
                      selectedYear: year,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book,
                          color: Colors.blueAccent),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Select Subjects",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Choose subjects & select validity on next screen",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 18, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------ BULK OFFERS LIST ------------------------
  Widget _buildBulkOffersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bulkOffers")
          .orderBy("name")
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Text("No bulk offers found",
              style: TextStyle(color: Colors.grey));
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final name = data["name"] ?? "Bulk Offer";
            final yearsIncluded =
                (data["years"] as List<dynamic>?)
                        ?.join(", ") ??
                    "All Years";

            final price6m = data["price6m"] ?? 0;
            final price1y = data["price1y"] ?? 0;

            return GestureDetector(
              onTap: () {
                _showValidityPicker(
                  name: name,
                  price6m: price6m,
                  price1y: price1y,
                );
              },
              child: Card(
                color: Colors.amber.shade50,
                elevation: 2,
                margin:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.all_inclusive,
                          color: Colors.deepPurple, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text("Years: $yearsIncluded",
                                style: const TextStyle(
                                    color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text(
                              "₹$price6m (6M)  |  ₹$price1y (1Y)",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 18, color: Colors.purple),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ------------------------ VALIDITY PICKER ------------------------
  void _showValidityPicker({
    required String name,
    required int price6m,
    required int price1y,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Validity",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800)),
              const SizedBox(height: 20),

              // 6 MONTHS
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.blue),
                title: const Text("6 Months"),
                trailing: Text("₹$price6m",
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        planName: "$name (6 Months)",
                        amount: price6m * 100,
                        selectedYear: "All Years",
                        selectedSubjects: ["ALL"],
                        validity: "6 Months",
                      ),
                    ),
                  );
                },
              ),

              const Divider(),

              // 1 YEAR
              ListTile(
                leading: const Icon(Icons.calendar_today,
                    color: Colors.green),
                title: const Text("1 Year"),
                trailing: Text("₹$price1y",
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        planName: "$name (1 Year)",
                        amount: price1y * 100,
                        selectedYear: "All Years",
                        selectedSubjects: ["ALL"],
                        validity: "1 Year",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
