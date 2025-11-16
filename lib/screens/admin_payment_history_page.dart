import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'payment_details_page.dart';

class AdminPaymentHistoryPage extends StatefulWidget {
  const AdminPaymentHistoryPage({super.key});

  @override
  State<AdminPaymentHistoryPage> createState() =>
      _AdminPaymentHistoryPageState();
}

class _AdminPaymentHistoryPageState extends State<AdminPaymentHistoryPage> {
  String _searchQuery = "";
  DateTime? _selectedDate;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Payment History"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Delete all failed / ₹0 payments",
            onPressed: _deleting ? null : _deleteFailedPayments,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Filter by Date",
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024, 1, 1),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: "Clear Filter",
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by user, year, or plan name...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // 🔽 List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('payments')
                  .orderBy('paidAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                      child: Text("No payment records found.",
                          style: TextStyle(color: Colors.grey)));
                }

                // 🔹 Filter
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      (data['planName'] ?? '').toString().toLowerCase();
                  final year =
                      (data['year'] ?? '').toString().toLowerCase();
                  final subjects =
                      (data['subjects'] ?? []).join(', ').toLowerCase();
                  final userEmail =
                      (data['userEmail'] ?? '').toString().toLowerCase();

                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery.toLowerCase()) ||
                      year.contains(_searchQuery.toLowerCase()) ||
                      subjects.contains(_searchQuery.toLowerCase()) ||
                      userEmail.contains(_searchQuery.toLowerCase());

                  bool matchesDate = true;
                  if (_selectedDate != null && data['paidAt'] != null) {
                    final paid = (data['paidAt'] as Timestamp).toDate();
                    matchesDate = paid.year == _selectedDate!.year &&
                        paid.month == _selectedDate!.month &&
                        paid.day == _selectedDate!.day;
                  }

                  return matchesSearch && matchesDate;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text("No matching payments found.",
                          style: TextStyle(color: Colors.grey)));
                }

                // 🔹 Payment Cards
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    data['reference'] = doc.reference;

                    final planName = data['planName'] ?? "Unknown Plan";
                    final userEmail = data['userEmail'] ?? "N/A";
                    final year = data['year'] ?? "N/A";
                    final validity = data['validity'] ?? "";
                    final amount = data['amountPaid'] ?? 0;
                    final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
                    final paidDate = paidAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)
                        : 'N/A';

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(
                          Icons.payment,
                          color: (amount == 0 || data['status'] == 'failed')
                              ? Colors.red
                              : Colors.green,
                        ),
                        title: Text(
                          planName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          "$year • ₹$amount • $validity\n$userEmail\n$paidDate",
                          style: const TextStyle(height: 1.5),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentDetailsPage(data: data),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Delete all failed or ₹0 payments
  Future<void> _deleteFailedPayments() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Failed / ₹0 Payments"),
        content: const Text(
          "Are you sure you want to delete all failed or ₹0 payment records? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('payments')
          .get();

      int deletedCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amountPaid'] ?? 0);
        final status = data['status'] ?? '';

        if (amount == 0 || status == 'failed') {
          await doc.reference.delete();
          deletedCount++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("✅ Deleted $deletedCount failed/₹0 payment records."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Error deleting records: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    setState(() => _deleting = false);
  }
}
