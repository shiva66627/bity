import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final String pdfTitle;
  final int amount; // amount in paise (₹1 = 100)
  final VoidCallback? onPaymentSuccess;

  const PaymentScreen({
    super.key,
    required this.pdfTitle,
    required this.amount,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // ✅ Your real UPI ID (PhonePe / GPay / Paytm)
  final String _upiId = "shivakumarsomavarapu@ybl";

  Future<void> _openUPIApp() async {
    final rupees = widget.amount ~/ 100; // convert paise to rupees

    final Uri upiUrl = Uri.parse(
      "upi://pay?pa=$_upiId&pn=MBBS%20Freaks&am=$rupees&cu=INR&tn=${Uri.encodeComponent(widget.pdfTitle)}",
    );

    if (await canLaunchUrl(upiUrl)) {
      await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Could not open UPI app")),
      );
    }
  }

  void _showPaymentDoneDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Payment Confirmation"),
        content: const Text(
          "After completing the payment in PhonePe / GPay / Paytm, tap below to continue.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              if (widget.onPaymentSuccess != null) {
                widget.onPaymentSuccess!();
              }
              Navigator.pop(context); // go back to previous screen
            },
            child: const Text("I have paid"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountInRupees = widget.amount ~/ 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay with UPI"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Text(
              widget.pdfTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Amount: ₹$amountInRupees",
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 40),

            // ✅ Pay using UPI button
            ElevatedButton.icon(
              onPressed: () async {
                await _openUPIApp();
                _showPaymentDoneDialog();
              },
              icon: const Icon(Icons.payment),
              label: const Text("Pay using PhonePe / UPI"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "This will open PhonePe, GPay or Paytm directly.\nAfter payment, tap “I have paid” to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
