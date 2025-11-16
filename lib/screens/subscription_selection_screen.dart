import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_screen.dart';

class SubscriptionSelectionScreen extends StatefulWidget {
  final String selectedYear;
  const SubscriptionSelectionScreen({super.key, required this.selectedYear});

  @override
  State<SubscriptionSelectionScreen> createState() =>
      _SubscriptionSelectionScreenState();
}

class _SubscriptionSelectionScreenState
    extends State<SubscriptionSelectionScreen> {
  String? validity; // "6m" or "1y"

  bool _loading = true;
  String? _errorMsg;

  List<String> allSubjects = [];
  List<String> selectedSubjects = [];

  /// key = number of subjects, value = { 'price6m': int, 'price1y': int }
  Map<int, Map<String, int>> pricingByCount = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // Load subjects
      final subjectsSnap = await FirebaseFirestore.instance
          .collection("notesSubjects")
          .where("year", isEqualTo: widget.selectedYear)
          .get();

      final List<String> subjects =
          subjectsSnap.docs.map((d) => d["name"].toString()).toList();

      // Load pricing slabs
      final pricingDoc = await FirebaseFirestore.instance
          .collection("subscriptionPricing")
          .doc(widget.selectedYear)
          .get();

      Map<int, Map<String, int>> slabsMap = {};

      if (pricingDoc.exists) {
        final data = pricingDoc.data()!;
        final List slabs = (data["slabs"] as List?) ?? [];
        for (final s in slabs) {
          if (s is Map<String, dynamic>) {
            final int count = int.tryParse(s["count"].toString()) ?? 0;
            final int price6m = int.tryParse(s["price6m"].toString()) ?? 0;
            final int price1y = int.tryParse(s["price1y"].toString()) ?? 0;

            if (count > 0) {
              slabsMap[count] = {
                "price6m": price6m,
                "price1y": price1y,
              };
            }
          }
        }
      }

      setState(() {
        allSubjects = subjects;
        selectedSubjects.clear();
        pricingByCount = slabsMap;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = "Failed to load data: $e";
        _loading = false;
      });
    }
  }

  // ⭐ Calculate price
  int _calculateAmount() {
    if (validity == null) return 0;

    // ⭐ If ALL selected → use largest slab
    if (selectedSubjects.contains("ALL")) {
      if (pricingByCount.isEmpty) return 0;

      final largestSlab =
          pricingByCount.keys.reduce((a, b) => a > b ? a : b);

      final slab = pricingByCount[largestSlab]!;
      return validity == "6m" ? slab["price6m"]! : slab["price1y"]!;
    }

    // Normal selection
    final count = selectedSubjects.length;
    if (count == 0) return 0;

    final slab = pricingByCount[count];
    if (slab == null) return 0;

    return validity == "6m" ? slab["price6m"]! : slab["price1y"]!;
  }

  @override
  Widget build(BuildContext context) {
    final amount = _calculateAmount();

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.selectedYear} Subscription"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg != null
                ? Center(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : allSubjects.isEmpty
                    ? const Center(
                        child: Text(
                          "No subjects found for this year yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // VALIDITY
                          const Text(
                            "Select Validity",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text("6 Months"),
                                selected: validity == "6m",
                                onSelected: (_) {
                                  setState(() => validity = "6m");
                                },
                                selectedColor: Colors.blue.shade100,
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text("1 Year"),
                                selected: validity == "1y",
                                onSelected: (_) {
                                  setState(() => validity = "1y");
                                },
                                selectedColor: Colors.blue.shade100,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // SUBJECTS TITLE
                          const Text(
                            "Select Subjects",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text("Choose specific subjects OR select all",
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),

                          // ⭐ BULK ALL CHECKBOX
                          CheckboxListTile(
                            title: const Text(
                              "Unlock ALL subjects in this year (Bulk Offer)",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            value: selectedSubjects.contains("ALL"),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selectedSubjects = ["ALL"];
                                } else {
                                  selectedSubjects.clear();
                                }
                              });
                            },
                          ),

                          Expanded(
                            child: ListView.builder(
                              itemCount: allSubjects.length,
                              itemBuilder: (context, index) {
                                final subject = allSubjects[index];
                                final isSelected =
                                    selectedSubjects.contains(subject);

                                return CheckboxListTile(
                                  title: Text(subject),
                                  value: selectedSubjects.contains("ALL")
                                      ? true
                                      : isSelected,
                                  onChanged: selectedSubjects.contains("ALL")
                                      ? null
                                      : (v) {
                                          setState(() {
                                            if (v == true) {
                                              selectedSubjects.add(subject);
                                            } else {
                                              selectedSubjects
                                                  .remove(subject);
                                            }
                                          });
                                        },
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          if (selectedSubjects.isNotEmpty)
                            Text(
                              "Selected: ${selectedSubjects.contains("ALL") ? "ALL subjects" : selectedSubjects.length.toString()}",
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),

                          const SizedBox(height: 8),

                          if (amount > 0 && validity != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Total Payable:",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text("₹$amount",
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue)),
                                ],
                              ),
                            )
                          else
                            const Text(
                              "Select validity + subjects to see price.",
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),

                          const SizedBox(height: 15),

                          ElevatedButton.icon(
                            onPressed: (amount == 0 ||
                                    validity == null ||
                                    selectedSubjects.isEmpty)
                                ? null
                                : () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentScreen(
                                          planName:
                                              "${widget.selectedYear} - ${selectedSubjects.contains("ALL") ? "ALL Subjects" : "${selectedSubjects.length} Subjects"}",
                                          amount: amount * 100,
                                          selectedYear: widget.selectedYear,
                                          selectedSubjects:
                                              List.of(selectedSubjects),
                                          validity: validity == "6m"
                                              ? "6 Months"
                                              : "1 Year",
                                        ),
                                      ),
                                    );

                                    if (result == true && mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  },
                            icon: const Icon(Icons.payment),
                            label: Text(amount > 0
                                ? "Proceed to Pay ₹$amount"
                                : "Proceed to Pay"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
