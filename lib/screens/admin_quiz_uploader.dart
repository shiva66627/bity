import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdminQuizUploader extends StatefulWidget {
  const AdminQuizUploader({super.key});

  @override
  State<AdminQuizUploader> createState() => _AdminQuizUploaderState();
}

class _AdminQuizUploaderState extends State<AdminQuizUploader> {
  final _firestore = FirebaseFirestore.instance;

  String? selectedYear;
  String? selectedSubjectId;
  String? selectedChapterId;
  String? selectedQuizId;

  final subjectController = TextEditingController();
  final chapterController = TextEditingController();
  final totalQuestionsController = TextEditingController();

  final questionController = TextEditingController();
  final optionAController = TextEditingController();
  final optionBController = TextEditingController();
  final optionCController = TextEditingController();
  final optionDController = TextEditingController();
  final explanationController = TextEditingController(); // ✅ Added Explanation

  String correctOption = "A";

  int addedQuestions = 0;
  int totalQuestions = 0;

  File? _pickedImage;
  String? _uploadedImageUrl;

  // ✅ For question image
  File? _pickedQuestionImage;
  String? _uploadedQuestionImageUrl;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<void> _pickQuestionImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedQuestionImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("quiz_images")
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Image upload failed: $e")),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Quiz"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Select Year
            DropdownButtonFormField<String>(
              value: selectedYear,
              hint: const Text("Select Year"),
              items: const [
                DropdownMenuItem(value: "1st Year", child: Text("1st Year")),
                DropdownMenuItem(value: "2nd Year", child: Text("2nd Year")),
                DropdownMenuItem(value: "3rd Year", child: Text("3rd Year")),
                DropdownMenuItem(value: "4th Year", child: Text("4th Year")),
              ],
              onChanged: (val) => setState(() => selectedYear = val),
            ),
            const SizedBox(height: 16),

            // ✅ Subject + Image Upload
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: "Subject Name"),
            ),

            const SizedBox(height: 8),
            _pickedImage != null
                ? Image.file(_pickedImage!,
                    height: 100, width: 100, fit: BoxFit.cover)
                : const Text("No image selected"),

            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image, color: Colors.purple),
              label: const Text("Pick Subject Image"),
            ),

            const SizedBox(height: 16),

            // ✅ Chapter + Total Questions
            TextField(
              controller: chapterController,
              decoration: const InputDecoration(labelText: "Chapter Name"),
            ),
            TextField(
              controller: totalQuestionsController,
              decoration: const InputDecoration(labelText: "Total Questions"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveSubjectAndChapter,
              child: const Text("Save Subject & Chapter"),
            ),

            const Divider(height: 40),

            // ✅ Add Questions Section
            if (totalQuestions > 0) _buildQuestionForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Added: $addedQuestions / $totalQuestions",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),

        TextField(
          controller: questionController,
          decoration: const InputDecoration(labelText: "Question"),
        ),
        const SizedBox(height: 8),

        // ✅ Question Image Upload Section
        _pickedQuestionImage != null
            ? Column(
                children: [
                  Image.file(
                    _pickedQuestionImage!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _pickedQuestionImage = null;
                        _uploadedQuestionImageUrl = null;
                      });
                    },
                  )
                ],
              )
            : TextButton.icon(
                onPressed: _pickQuestionImage,
                icon: const Icon(Icons.image, color: Colors.purple),
                label: const Text("Upload Question Image"),
              ),

        const SizedBox(height: 8),

        TextField(
            controller: optionAController,
            decoration: const InputDecoration(labelText: "Option A")),
        TextField(
            controller: optionBController,
            decoration: const InputDecoration(labelText: "Option B")),
        TextField(
            controller: optionCController,
            decoration: const InputDecoration(labelText: "Option C")),
        TextField(
            controller: optionDController,
            decoration: const InputDecoration(labelText: "Option D")),

        // ✅ Explanation field
        TextField(
          controller: explanationController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "Explanation (Optional)",
          ),
        ),

        DropdownButtonFormField<String>(
          value: correctOption,
          items: const [
            DropdownMenuItem(value: "A", child: Text("Correct: A")),
            DropdownMenuItem(value: "B", child: Text("Correct: B")),
            DropdownMenuItem(value: "C", child: Text("Correct: C")),
            DropdownMenuItem(value: "D", child: Text("Correct: D")),
          ],
          onChanged: (val) => setState(() => correctOption = val!),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: addedQuestions >= totalQuestions ? null : _saveQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: addedQuestions == totalQuestions - 1
                ? Colors.green
                : Colors.blue,
          ),
          child: Text(
            addedQuestions == totalQuestions - 1
                ? "Submit Quiz"
                : "Save & Next",
          ),
        ),
      ],
    );
  }

  // ✅ Save Subject & Chapter
  Future<void> _saveSubjectAndChapter() async {
    if (selectedYear == null ||
        subjectController.text.isEmpty ||
        chapterController.text.isEmpty ||
        totalQuestionsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Fill all fields")),
      );
      return;
    }

    totalQuestions = int.tryParse(totalQuestionsController.text) ?? 0;

    if (_pickedImage != null) {
      _uploadedImageUrl = await _uploadImage(_pickedImage!);
    }

    final subjectRef = await _firestore.collection("quizSubjects").add({
      "year": selectedYear,
      "name": subjectController.text.trim(),
      "imageUrl": _uploadedImageUrl ?? "",
      "createdAt": FieldValue.serverTimestamp(),
    });
    selectedSubjectId = subjectRef.id;

    final chapterRef = await _firestore.collection("quizChapters").add({
      "subjectId": selectedSubjectId,
      "name": chapterController.text.trim(),
      "totalQuestions": totalQuestions,
      "createdAt": FieldValue.serverTimestamp(),
    });
    selectedChapterId = chapterRef.id;

    final quizRef = await _firestore.collection("quizPdfs").add({
      "title": "${chapterController.text.trim()} Quiz",
      "chapterId": selectedChapterId,
      "questions": [],
      "totalQuestions": totalQuestions,
      "createdAt": FieldValue.serverTimestamp(),
    });
    selectedQuizId = quizRef.id;

    setState(() {
      addedQuestions = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Subject, Chapter & Quiz created")),
    );
  }

  // ✅ Save Question with explanation
  Future<void> _saveQuestion() async {
    if (selectedQuizId == null || questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Save subject & chapter first")),
      );
      return;
    }

    if (_pickedQuestionImage != null) {
      _uploadedQuestionImageUrl = await _uploadImage(_pickedQuestionImage!);
    }

    final questionData = {
      "question": questionController.text.trim(),
      "imageUrl": _uploadedQuestionImageUrl ?? "",
      "options": {
        "A": optionAController.text.trim(),
        "B": optionBController.text.trim(),
        "C": optionCController.text.trim(),
        "D": optionDController.text.trim(),
      },
      "correctAnswer": correctOption,
      "explanation": explanationController.text.trim(), // ✅ Added here
    };

    await _firestore.collection("quizPdfs").doc(selectedQuizId).update({
      "questions": FieldValue.arrayUnion([questionData])
    });

    // Clear fields
    questionController.clear();
    optionAController.clear();
    optionBController.clear();
    optionCController.clear();
    optionDController.clear();
    explanationController.clear();
    setState(() {
      _pickedQuestionImage = null;
      _uploadedQuestionImageUrl = null;
      addedQuestions++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "✅ Question Added ($addedQuestions / $totalQuestions)")),
    );
  }
}
