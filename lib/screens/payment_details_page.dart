import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const PaymentDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final subjects = (data['subjects'] as List?)?.join(', ') ?? 'N/A';

    final paidAt =
        (data['paidAt'] != null) ? (data['paidAt']).toDate() : null;
    final expiresAt =
        (data['expiresAt'] != null) ? (data['expiresAt']).toDate() : null;

    final paidDate = paidAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)
        : 'N/A';
    final expireDate = expiresAt != null
        ? DateFormat('dd MMM yyyy').format(expiresAt)
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Details"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Delete this payment and remove access",
            onPressed: () async {
              await _confirmAndDelete(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Center(
              child:
                  Icon(Icons.receipt_long, color: Colors.redAccent, size: 70),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                data['planName'] ?? 'Plan Details',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Divider(height: 30, thickness: 1),

            // =============================
            // USER DETAILS (NEW)
            // =============================
            _infoRow("User Name", data['userName'] ?? 'N/A'),
            _infoRow("User Email", data['userEmail'] ?? 'N/A'),
            _infoRow("Phone", data['userPhone'] ?? 'N/A'),
            _infoRow("User ID", data['userId'] ?? 'N/A'),

            // =============================
            // PLAN DETAILS
            // =============================
            _infoRow("Year", data['year'] ?? 'N/A'),
            _infoRow("Subjects", subjects),
            _infoRow("Amount Paid", "₹${data['amountPaid'] ?? 0}"),
            _infoRow("Validity", data['validity'] ?? 'N/A'),

            _infoRow("Paid On", paidDate),
            _infoRow("Expires On", expireDate),

            _infoRow("Razorpay ID", data['razorpayPaymentId'] ?? 'N/A'),
            _infoRow("Status", data['status'] ?? 'success'),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text("Back to History"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 14),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ======================================================
  // Confirm delete and revoke access
  // ======================================================
  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Payment & Revoke Access"),
        content: const Text(
            "Are you sure you want to delete this payment and remove the user's premium access for this year?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
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

    try {
      final year = data['year'];
      final userId = data['userId'];

      // 1️⃣ Delete payment record
      if (data.containsKey('reference') && data['reference'] != null) {
        final ref = data['reference'] as DocumentReference;
        await ref.delete();
      }

      // 2️⃣ Remove access from user profile
      if (userId != null && userId.toString().isNotEmpty) {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(userId);

        final updates = <String, dynamic>{
          'premiumYears': FieldValue.arrayRemove([year]),
          'premiumExpiries.$year': FieldValue.delete(),
          'premiumSubjects.$year': FieldValue.delete(),
        };

        await userRef.update(updates);
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "✅ Payment deleted and user's access revoked successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Error deleting: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ======================================================
  // Row widget
  // ======================================================
  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$title:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
