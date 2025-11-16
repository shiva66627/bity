import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BulkOffersPage extends StatefulWidget {
  const BulkOffersPage({super.key});

  @override
  State<BulkOffersPage> createState() => _BulkOffersPageState();
}

class _BulkOffersPageState extends State<BulkOffersPage> {
  final _offerNameController = TextEditingController();
  final _price6mController = TextEditingController();
  final _price1yController = TextEditingController();
  final List<String> _selectedYears = [];

  final List<String> _allYears = [
    "1st Year",
    "2nd Year",
    "3rd Year",
    "4th Year",
  ];

  bool isSaving = false;
  String? _editingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Bulk Offers"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text("Offer Name",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _offerNameController,
              decoration: const InputDecoration(
                hintText: "e.g., Combo Offer (All Years)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            const Text("Select Years",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            Wrap(
              spacing: 8,
              children: _allYears.map((year) {
                final selected = _selectedYears.contains(year);
                return FilterChip(
                  label: Text(year),
                  selected: selected,
                  selectedColor: Colors.deepPurple.shade100,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedYears.add(year);
                      } else {
                        _selectedYears.remove(year);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            const Text("Pricing",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            TextField(
              controller: _price6mController,
              decoration: const InputDecoration(
                labelText: "6 Months Price (₹)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _price1yController,
              decoration: const InputDecoration(
                labelText: "1 Year Price (₹)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: isSaving ? null : _saveOrUpdate,
              icon: const Icon(Icons.save),
              label: Text(_editingId == null
                  ? "Save Bulk Offer"
                  : "Update Offer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(thickness: 1.2),

            // ------------------------
            // ⭐ EXPANSION DROPDOWN HERE
            // ------------------------
            ExpansionTile(
              title: const Text(
                "Existing Bulk Offers",
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("bulkOffers")
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: CircularProgressIndicator()),
                      );
                    }

                    if (!snap.hasData ||
                        snap.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          "No bulk offers created yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Column(
                      children: snap.data!.docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final name = d['name'] ?? 'Unnamed Offer';
                        final years = (d['years'] as List?)
                                ?.join(', ') ??
                            'All Years';
                        final p6 = d['price6m'] ?? 0;
                        final p1 = d['price1y'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(Icons.all_inclusive,
                                color: Colors.deepPurple),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            subtitle: Text(
                              "Years: $years\n₹$p6 (6M) / ₹$p1 (1Y)",
                              style: const TextStyle(
                                  color: Colors.black54),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _editOffer(doc.id, d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteOffer(
                                      doc.id, name),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------------
  Future<void> _saveOrUpdate() async {
    if (_selectedYears.isEmpty ||
        _price6mController.text.isEmpty ||
        _price1yController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⚠️ Please fill all required fields")));
      return;
    }

    setState(() => isSaving = true);

    final p6 = int.tryParse(_price6mController.text) ?? 0;
    final p1 = int.tryParse(_price1yController.text) ?? 0;

    final data = {
      "name": _offerNameController.text.trim().isEmpty
          ? "Bulk Combo (${_selectedYears.join(', ')})"
          : _offerNameController.text.trim(),
      "years": _selectedYears,
      "price6m": p6,
      "price1y": p1,
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      if (_editingId == null) {
        await FirebaseFirestore.instance
            .collection("bulkOffers")
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection("bulkOffers")
            .doc(_editingId)
            .update(data);
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Bulk offer saved!")));
      _resetForm();
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _resetForm() {
    _offerNameController.clear();
    _price6mController.clear();
    _price1yController.clear();
    _selectedYears.clear();
    _editingId = null;
    setState(() {});
  }

  void _editOffer(String id, Map<String, dynamic> d) {
    _offerNameController.text = d['name'] ?? '';
    _price6mController.text = "${d['price6m'] ?? ''}";
    _price1yController.text = "${d['price1y'] ?? ''}";

    _selectedYears
      ..clear()
      ..addAll(List<String>.from(d['years'] ?? []));

    _editingId = id;
    setState(() {});
  }

  Future<void> _deleteOffer(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Bulk Offer"),
        content: Text("Delete '$name'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("bulkOffers")
          .doc(id)
          .delete();
    }
  }
}
