import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'add_questions_page.dart';

class AdminQuizUploader extends StatefulWidget {
  final String? existingQuizId;
  final String? existingChapterId;
  final String? existingChapterName;

  const AdminQuizUploader({
    super.key,
    this.existingQuizId,
    this.existingChapterId,
    this.existingChapterName,
  });

  @override
  State<AdminQuizUploader> createState() => _AdminQuizUploaderState();
}

class _AdminQuizUploaderState extends State<AdminQuizUploader> {
  final _firestore = FirebaseFirestore.instance;

  String? selectedYear;
  String? selectedSubjectId;
  bool addingNewSubject = false;

  final subjectController = TextEditingController();
  final chapterController = TextEditingController();

  File? _pickedImage;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    subjectController.dispose();
    chapterController.dispose();
    super.dispose();
  }

  // 🚀 IMAGE PICKER
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadSubjectImage(File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref("quiz_subject_images")
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ EDIT MODE DETECTED
    if (widget.existingQuizId != null) {
      return AddQuestionsPage(quizId: widget.existingQuizId!);
    }

    // ⭐ NORMAL CREATE MODE
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Quiz"),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------------- YEAR ----------------
            DropdownButtonFormField<String>(
              value: selectedYear,
              hint: const Text("Select Year"),
              items: const [
                DropdownMenuItem(value: "1st Year", child: Text("1st Year")),
                DropdownMenuItem(value: "2nd Year", child: Text("2nd Year")),
                DropdownMenuItem(value: "3rd Year", child: Text("3rd Year")),
                DropdownMenuItem(value: "4th Year", child: Text("4th Year")),
              ],
              onChanged: (val) {
                setState(() {
                  selectedYear = val;
                  selectedSubjectId = null;
                  subjectController.clear();
                  addingNewSubject = false;
                });
              },
            ),

            const SizedBox(height: 20),

            if (selectedYear != null) _buildSubjectSelector(),

            const SizedBox(height: 20),

            TextField(
              controller: chapterController,
              decoration: const InputDecoration(
                labelText: "Chapter Name",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveSubjectAndChapter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
              child: const Text("Save & Add Questions"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- SUBJECT DROPDOWN ----------------
  Widget _buildSubjectSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Subject", style: TextStyle(fontSize: 16)),

        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection("quizSubjects")
              .where("year", isEqualTo: selectedYear)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const CircularProgressIndicator();

            final docs = snap.data!.docs;

            return DropdownButtonFormField<String>(
              value: addingNewSubject ? "new" : selectedSubjectId,
              hint: const Text("Select Subject"),
              items: [
                ...docs.map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d["name"]),
                  ),
                ),
                const DropdownMenuItem(
                    value: "new", child: Text("➕ Add New Subject")),
              ],
              onChanged: (val) {
                setState(() {
                  _pickedImage = null;
                  _uploadedImageUrl = null;

                  if (val == "new") {
                    addingNewSubject = true;
                    selectedSubjectId = null;
                    subjectController.clear();
                  } else {
                    addingNewSubject = false;
                    selectedSubjectId = val;

                    final data = docs.firstWhere((d) => d.id == val).data()
                        as Map<String, dynamic>;
                    subjectController.text = data["name"];
                    _uploadedImageUrl = data["imageUrl"];
                  }
                });
              },
            );
          },
        ),

        const SizedBox(height: 14),

        TextField(
          controller: subjectController,
          decoration: const InputDecoration(labelText: "Subject Name"),
          readOnly: !addingNewSubject,
        ),

        const SizedBox(height: 12),

        if (addingNewSubject) _buildImagePicker(),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        _pickedImage != null
            ? Image.file(_pickedImage!, height: 120, fit: BoxFit.cover)
            : const Text("No image selected"),

        TextButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image, color: Colors.purple),
          label: const Text("Pick Subject Image"),
        ),
      ],
    );
  }

  // ---------------- SAVE & CREATE NEW QUIZ ----------------
  Future<void> _saveSubjectAndChapter() async {
    if (selectedYear == null ||
        subjectController.text.isEmpty ||
        chapterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Fill all fields")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // ✔ CREATE NEW SUBJECT
      if (addingNewSubject) {
        if (_pickedImage != null) {
          _uploadedImageUrl = await _uploadSubjectImage(_pickedImage!);
        }

        final subRef =
            await _firestore.collection("quizSubjects").add({
          "name": subjectController.text.trim(),
          "year": selectedYear,
          "imageUrl": _uploadedImageUrl ?? "",
          "createdAt": FieldValue.serverTimestamp(),
        });

        selectedSubjectId = subRef.id;
      }

      // ✔ CREATE CHAPTER
      final chapRef = await _firestore.collection("quizChapters").add({
        "subjectId": selectedSubjectId,
        "name": chapterController.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
      });

      // ✔ CREATE QUIZ
      final quizRef = await _firestore.collection("quizPdfs").add({
        "title": "${chapterController.text.trim()} Quiz",
        "chapterId": chapRef.id,
        "questions": [],
        "createdAt": FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddQuestionsPage(quizId: quizRef.id),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
