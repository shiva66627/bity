// PAYMENTSCREEN.DART
// -----------------------------------------------------------
// Handles Razorpay Payment + Coupon + Premium Unlock (Normal + Bulk + All Years)
// -----------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentScreen extends StatefulWidget {
  final String planName;
  final int amount; // in paise
  final String selectedYear;          // Example: "3rd Year" or "All Years"
  final List<String> selectedSubjects; // ["ALL"] or ["Anatomy","Physiology"]
  final String validity; // "6 Months" or "1 Year"

  const PaymentScreen({
    super.key,
    required this.planName,
    required this.amount,
    required this.selectedYear,
    required this.selectedSubjects,
    required this.validity,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  bool _processing = false;

  TextEditingController couponCtrl = TextEditingController();
  bool couponApplied = false;
  int discountedAmount = 0;
  String appliedCouponCode = "";

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // =========================================================
  // APPLY COUPON
  // =========================================================
  Future<void> _applyCoupon() async {
    final code = couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      Fluttertoast.showToast(msg: "Enter a coupon code!");
      return;
    }

    final snap =
        await FirebaseFirestore.instance.collection("coupons").doc(code).get();

    if (!snap.exists) {
      Fluttertoast.showToast(msg: "Invalid coupon!");
      return;
    }

    final data = snap.data()!;
    if (!(data["active"] ?? true)) {
      Fluttertoast.showToast(msg: "Coupon disabled!");
      return;
    }

    if (data["expiryDate"] != null &&
        data["expiryDate"].toString().isNotEmpty) {
      final expiry = DateTime.parse(data["expiryDate"]);
      if (DateTime.now().isAfter(expiry)) {
        Fluttertoast.showToast(msg: "Coupon expired!");
        return;
      }
    }

    final int discountValue = data["discount"] ?? 0;
    final String discountType = data["type"] ?? "%";

    int newAmount = widget.amount;

    if (discountType == "%") {
      newAmount = widget.amount - ((widget.amount * discountValue) ~/ 100);
    } else {
      newAmount = widget.amount - (discountValue * 100);
    }

    if (newAmount < 100) newAmount = 100;

    setState(() {
      couponApplied = true;
      discountedAmount = newAmount;
      appliedCouponCode = code;
    });

    Fluttertoast.showToast(
        msg:
            "🎉 Coupon Applied! New Amount ₹${(newAmount / 100).toStringAsFixed(2)}");
  }

  // =========================================================
  // OPEN RAZORPAY CHECKOUT
  // =========================================================
  void _openCheckout() {
    var finalAmount = couponApplied ? discountedAmount : widget.amount;

    final subjectNames = widget.selectedSubjects.join(", ");
    final subjectCount = widget.selectedSubjects.length;

    final dynamicTitle =
        "${widget.selectedYear} - $subjectNames - $subjectCount Subject${subjectCount > 1 ? 's' : ''}";

    var options = {
      'key': 'rzp_live_Rg19MzdYC6BYmI',   // ⭐ ADD YOUR LIVE KEY HERE
      'amount': finalAmount,
      'name': 'MBBS Freaks',
      'description': dynamicTitle,
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        'email': FirebaseAuth.instance.currentUser?.email ?? ''
      },
      'theme': {'color': '#1976D2'},
    };

    try {
      _razorpay.open(options);
      setState(() => _processing = true);
    } catch (e) {
      Fluttertoast.showToast(msg: "⚠️ Error: $e");
      setState(() => _processing = false);
    }
  }

  // =========================================================
  // PAYMENT SUCCESS HANDLER
  // =========================================================
  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    Fluttertoast.showToast(msg: "✅ Payment successful!");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final now = DateTime.now();
    final expiry = now.add(
      widget.validity == "6 Months"
          ? const Duration(days: 180)
          : const Duration(days: 365),
    );

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    // =========================================================
    // ⭐⭐⭐ PREMIUM UNLOCK LOGIC ⭐⭐⭐
    // =========================================================
    if (widget.selectedSubjects.contains("ALL")) {
      // -----------------------------------------------------
      // BULK: ALL YEARS
      // -----------------------------------------------------
      if (widget.selectedYear == "All Years") {
        final yearList = ["1st Year", "2nd Year", "3rd Year", "4th Year"];

        for (final y in yearList) {
          final subsSnap = await FirebaseFirestore.instance
              .collection("notesSubjects")
              .where("year", isEqualTo: y)
              .get();

          final allSubs =
              subsSnap.docs.map((e) => e["name"].toString().trim()).toList();

          await userRef.set({
            "premiumYears": FieldValue.arrayUnion([y]),
            "premiumExpiries": {y: expiry.toIso8601String()},
            "premiumSubjects": {y: allSubs},
          }, SetOptions(merge: true));
        }
      }

      // -----------------------------------------------------
      // BULK: SINGLE YEAR
      // -----------------------------------------------------
      else {
        final subsSnap = await FirebaseFirestore.instance
            .collection("notesSubjects")
            .where("year", isEqualTo: widget.selectedYear)
            .get();

        final allSubs =
            subsSnap.docs.map((e) => e["name"].toString().trim()).toList();

        await userRef.set({
          "premiumYears": FieldValue.arrayUnion([widget.selectedYear]),
          "premiumExpiries": {
            widget.selectedYear: expiry.toIso8601String()
          },
          "premiumSubjects": {widget.selectedYear: allSubs},
        }, SetOptions(merge: true));
      }
    } else {
      // -----------------------------------------------------
      // NORMAL PLAN (only selected subjects)
      // -----------------------------------------------------
      await userRef.set({
        "premiumYears": FieldValue.arrayUnion([widget.selectedYear]),
        "premiumExpiries": {
          widget.selectedYear: expiry.toIso8601String(),
        },
        "premiumSubjects": {
          widget.selectedYear: FieldValue.arrayUnion(
            widget.selectedSubjects.map((s) => s.trim()).toList(),
          )
        }
      }, SetOptions(merge: true));
    }

    // =========================================================
    // SAVE PAYMENT HISTORY (with EMAIL + UID)
    // =========================================================
    await userRef.collection("payments").add({
      "razorpayPaymentId": response.paymentId,
      "planName": widget.planName,
      "amountPaid":
          (couponApplied ? discountedAmount : widget.amount) / 100,
      "year": widget.selectedYear.trim(),
      "subjects": widget.selectedSubjects,
      "validity": widget.validity,
      "paidAt": now,
      "expiresAt": expiry,
      "status": "success",
      "couponApplied": couponApplied ? appliedCouponCode : null,

      "userEmail": user.email ?? "",
      "userId": uid,
    });

    if (!mounted) return;
    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🎉 ${widget.planName} purchased successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =========================================================
  // PAYMENT FAIL
  // =========================================================
  void _handlePaymentError(PaymentFailureResponse response) {
    Fluttertoast.showToast(msg: "❌ Payment failed. Try again.");
    setState(() => _processing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(msg: "Wallet Selected: ${response.walletName}");
  }

  @override
  Widget build(BuildContext context) {
    final finalAmount =
        (couponApplied ? discountedAmount : widget.amount) / 100;

    final subjectNames = widget.selectedSubjects.join(", ");
    final subjectCount = widget.selectedSubjects.length;

    final dynamicTitle =
        "${widget.selectedYear} - $subjectNames - $subjectCount Subject${subjectCount > 1 ? 's' : ''}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Secure Payment"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, color: Colors.blue, size: 70),
            const SizedBox(height: 10),

            Text(
              dynamicTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),
            Text("₹$finalAmount • ${widget.validity}",
                style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 30),

            TextField(
              controller: couponCtrl,
              decoration: InputDecoration(
                labelText: "Enter Coupon",
                suffixIcon: TextButton(
                  child: const Text("Apply"),
                  onPressed: _applyCoupon,
                ),
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: Text(_processing ? "Processing..." : "Pay Now"),
              onPressed: _processing ? null : _openCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
            )
          ],
        ),
      ),
    );
  }
}
