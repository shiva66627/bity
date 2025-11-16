import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bulk_offers_page.dart';
import 'coupons_page.dart';

class SetPremiumsPage extends StatefulWidget {
  const SetPremiumsPage({super.key});

  @override
  State<SetPremiumsPage> createState() => _SetPremiumsPageState();
}

// Helper model for each slab row
class _PriceRow {
  final TextEditingController price6Ctrl;
  final TextEditingController price1Ctrl;

  _PriceRow({String price6 = "0", String price1 = "0"})
      : price6Ctrl = TextEditingController(text: price6),
        price1Ctrl = TextEditingController(text: price1);

  void dispose() {
    price6Ctrl.dispose();
    price1Ctrl.dispose();
  }
}

class _SetPremiumsPageState extends State<SetPremiumsPage> {
  String? selectedYear;
  final years = ["1st Year", "2nd Year", "3rd Year", "4th Year"];

  List<_PriceRow> _rows = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _initDefaultRows() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows = [
      _PriceRow(price6: "0", price1: "0"),
    ];
  }

  Future<void> _loadPricingForYear(String year) async {
    // Clear old controllers
    for (final r in _rows) {
      r.dispose();
    }
    _rows = [];

    final doc = await FirebaseFirestore.instance
        .collection("subscriptionPricing")
        .doc(year)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final List slabs = (data["slabs"] as List?) ?? [];
      if (slabs.isNotEmpty) {
        for (final s in slabs) {
          if (s is Map<String, dynamic>) {
            final price6 =
                (s["price6m"] ?? 0).toString(); // store as string in TextField
            final price1 = (s["price1y"] ?? 0).toString();
            _rows.add(_PriceRow(price6: price6, price1: price1));
          }
        }
      } else {
        _initDefaultRows();
      }
    } else {
      _initDefaultRows();
    }

    setState(() {});
  }

  Future<void> _savePricing() async {
    if (selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please select a year first")),
      );
      return;
    }

    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least 1 slab")),
      );
      return;
    }

    final List<Map<String, dynamic>> slabs = [];

    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final count = i + 1; // 1 subject, 2 subjects, 3 subjects...

      final int price6 = int.tryParse(row.price6Ctrl.text.trim()) ?? 0;
      final int price1 = int.tryParse(row.price1Ctrl.text.trim()) ?? 0;

      slabs.add({
        "count": count,
        "price6m": price6,
        "price1y": price1,
      });
    }

    await FirebaseFirestore.instance
        .collection("subscriptionPricing")
        .doc(selectedYear!)
        .set({
      "year": selectedYear,
      "slabs": slabs,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Pricing saved successfully!")),
    );
  }

  void _addSlab() {
    setState(() {
      _rows.add(_PriceRow(price6: "0", price1: "0"));
    });
  }

  void _removeLastSlab() {
    if (_rows.isNotEmpty) {
      setState(() {
        _rows.last.dispose();
        _rows.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Premium Subject Pricing"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _savePricing,
        backgroundColor: Colors.amber,
        child: const Icon(Icons.save),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text("Select Year",
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedYear,
              hint: const Text("Choose Year"),
              isExpanded: true,
              items: years
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  selectedYear = v;
                });
                if (v != null) {
                  await _loadPricingForYear(v);
                }
              },
            ),
            const SizedBox(height: 20),

            const Text(
              "Set pricing based on number of subjects",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Example:\n"
              "1 subject → ₹10 (6m), ₹20 (1y)\n"
              "2 subjects → ₹20 (6m), ₹40 (1y)\n"
              "3 subjects → ₹78 (6m), ₹100 (1y)\n"
              "etc...",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            if (selectedYear == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "Please select a year to configure pricing.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Slabs",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _addSlab,
                        icon: const Icon(Icons.add),
                        tooltip: "Add Slab",
                      ),
                      IconButton(
                        onPressed: _removeLastSlab,
                        icon: const Icon(Icons.remove),
                        tooltip: "Remove Last Slab",
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_rows.isEmpty)
                const Text(
                  "No slabs yet. Tap + to add.",
                  style: TextStyle(color: Colors.grey),
                )
              else
                Column(
                  children: List.generate(_rows.length, (index) {
                    final row = _rows[index];
                    final subjectCount = index + 1;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$subjectCount Subject${subjectCount > 1 ? 's' : ''}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row.price6Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "6 Months Price (₹)",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: row.price1Ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "1 Year Price (₹)",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ],

            const SizedBox(height: 30),
            const Divider(),

            // ⭐ Existing Admin Buttons (unchanged)
            const Text("Other Premium Settings",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BulkOffersPage()),
                );
              },
              icon: const Icon(Icons.all_inclusive),
              label: const Text("Manage Bulk Offers"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CouponsPage()),
                );
              },
              icon: const Icon(Icons.discount_outlined, color: Colors.white),
              label: const Text("Manage Coupons"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
