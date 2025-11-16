import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController discountCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();
  final TextEditingController expiryCtrl = TextEditingController();

  String discountType = "%"; // "%" or "₹"

  Future<void> _saveCoupon() async {
    final code = codeCtrl.text.trim().toUpperCase();
    final discount = int.tryParse(discountCtrl.text.trim()) ?? 0;
    final description = descriptionCtrl.text.trim();
    final expiryDate = expiryCtrl.text.trim();

    if (code.isEmpty || discount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid coupon details")),
      );
      return;
    }

    // ⭐ SAVE COUPON IN FIRESTORE WITH EXACT DOC ID
    await FirebaseFirestore.instance
        .collection("coupons")
        .doc(code)
        .set({
      "discount": discount,
      "type": discountType,
      "description": description,
      "active": true,
      "expiryDate": expiryDate.isEmpty ? null : expiryDate,
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Coupon $code saved successfully!")),
    );

    codeCtrl.clear();
    discountCtrl.clear();
    descriptionCtrl.clear();
    expiryCtrl.clear();
  }

  Future<void> _deleteCoupon(String docId) async {
    await FirebaseFirestore.instance
        .collection("coupons")
        .doc(docId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Coupon deleted")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Coupons"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // COUPON CODE
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: "Coupon Code (e.g., NEWUSER50)",
              ),
            ),

            const SizedBox(height: 16),

            // DISCOUNT VALUE
            TextField(
              controller: discountCtrl,
              decoration: const InputDecoration(
                labelText: "Discount Value (e.g., 10)",
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // DISCOUNT TYPE
            Row(
              children: [
                ChoiceChip(
                  label: const Text("%"),
                  selected: discountType == "%",
                  onSelected: (_) => setState(() => discountType = "%"),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text("₹"),
                  selected: discountType == "₹",
                  onSelected: (_) => setState(() => discountType = "₹"),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // EXPIRY DATE
            TextField(
              controller: expiryCtrl,
              decoration: const InputDecoration(
                labelText: "Expiry Date (YYYY-MM-DD) — Optional",
              ),
            ),

            const SizedBox(height: 16),

            // DESCRIPTION
            TextField(
              controller: descriptionCtrl,
              decoration: const InputDecoration(
                labelText: "Description (Optional)",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _saveCoupon,
              icon: const Icon(Icons.save),
              label: const Text("Save Coupon"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const Text("Existing Coupons",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("coupons")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text("No coupons yet");
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final code = doc.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          "$code • ${data["discount"]}${data["type"]}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          (data["description"] ?? "") +
                              (data["expiryDate"] != null
                                  ? "\nExpires: ${data["expiryDate"]}"
                                  : ""),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCoupon(doc.id),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
