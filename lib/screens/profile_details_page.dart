// PROFILEDETAILS PAGE

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import 'edit_profile.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  String name = "";
  String college = "";
  String email = "";
  String phone = "";
  String planName = "Not Purchased";
  String planStart = "Not Purchased";
  String planEnd = "Not Purchased";
  String profileUrl = "";

  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchUser().then((_) => fetchLatestPaymentPlan());
  }

  // ------------------------------------------------------------------
  // FETCH USER BASIC DATA
  // ------------------------------------------------------------------
  Future<void> fetchUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (!doc.exists) return;

    final data = doc.data()!;
    setState(() {
      name = data["fullName"] ?? "";
      college = data["college"] ?? "";
      email = data["email"] ?? "";
      phone = data["phone"] ?? "";
      profileUrl = data["profileUrl"] ?? "";
      loading = false;
    });
  }

  // ------------------------------------------------------------------
  // FETCH LATEST PAYMENT + AUTO EXPIRE HANDLING
  Future<void> fetchLatestPaymentPlan() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("payments")
        .orderBy("paidAt", descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      setState(() {
        planName = "Not Purchased";
        planStart = "Not Purchased";
        planEnd = "Not Purchased";
      });
      return;
    }

    final data = snap.docs.first.data();
    final paidAt = data["paidAt"]?.toDate();
    final expiresAt = data["expiresAt"]?.toDate();

    final year = data["year"];
    final subjects = List<String>.from(data["subjects"] ?? []);

    // ---------- EXPIRY CHECK ----------
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      setState(() {
        planName = "Not Purchased";
        planStart = "Not Purchased";
        planEnd = "Not Purchased";
      });
      return;
    }

    // ---------- SUBJECT NAME BUILD ----------
    String subjectDisplay = "";
    int subjectCount = 0;

    if (subjects.contains("ALL")) {
      // Bulk: fetch all subjects of this year
      final sSnap = await FirebaseFirestore.instance
          .collection("notesSubjects")
          .where("year", isEqualTo: year)
          .get();

      final all = sSnap.docs.map((d) => d["name"].toString()).toList();

      subjectCount = all.length;
      subjectDisplay = "ALL Subjects ($subjectCount)";
    } else {
      subjectCount = subjects.length;
      subjectDisplay = subjects.join(", ");
    }

    // ---------- SET UI ----------
    setState(() {
      planName = "$year – $subjectDisplay (${subjectCount} Subject${subjectCount > 1 ? 's' : ''})";

      planStart = paidAt != null
          ? DateFormat("dd MMM yyyy").format(paidAt)
          : "Not Purchased";

      planEnd = expiresAt != null
          ? DateFormat("dd MMM yyyy").format(expiresAt)
          : "Not Purchased";
    });
  } catch (e) {
    print("Error: $e");
  }
}

  // ------------------------------------------------------------------
  // UPLOAD PROFILE PHOTO
  // ------------------------------------------------------------------
  Future<void> _pickAndUploadImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    File file = File(picked.path);

    final ref = FirebaseStorage.instance
        .ref()
        .child("profilePhotos")
        .child("$uid.jpg");

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .update({"profileUrl": url});

    setState(() => profileUrl = url);
  }

  // ------------------------------------------------------------------
  // Editable Info Row
  // ------------------------------------------------------------------
  Widget _editableInfo(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value.isEmpty ? "Not added" : value,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],
          ),
        ),

        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfilePage(
                  currentName: name,
                  currentCollege: college,
                  currentEmail: email,
                  currentPhone: phone,
                ),
              ),
            ).then((_) => fetchUser());
          },
        )
      ],
    );
  }

  // ------------------------------------------------------------------
  // Plain Info Row
  // ------------------------------------------------------------------
  Widget _plainInfo(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
      ],
    );
  }

  // ------------------------------------------------------------------
  // BUILD UI
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Details"),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Photo
                  Center(
                    child: GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: profileUrl.isNotEmpty
                            ? NetworkImage(profileUrl)
                            : null,
                        child: profileUrl.isEmpty
                            ? const Icon(Icons.person,
                                size: 60, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Tap to change photo",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Editable fields
                  _editableInfo("Name", name),
                  _editableInfo("College", college),
                  _editableInfo("Email", email),
                  _editableInfo("Phone", phone),

                  const Divider(),
                  const SizedBox(height: 10),

                  const Text("Plan Details",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  _plainInfo("Plan Name", planName),
                  _plainInfo("Start Date", planStart),
                  _plainInfo("End Date", planEnd),
                ],
              ),
            ),
    );
  }
}
