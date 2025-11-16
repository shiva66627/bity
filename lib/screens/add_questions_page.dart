import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddQuestionsPage extends StatefulWidget {
  final String quizId;

  const AddQuestionsPage({super.key, required this.quizId});

  @override
  State<AddQuestionsPage> createState() => _AddQuestionsPageState();
}

class _AddQuestionsPageState extends State<AddQuestionsPage> {
  final questionController = TextEditingController();
  final optionA = TextEditingController();
  final optionB = TextEditingController();
  final optionC = TextEditingController();
  final optionD = TextEditingController();
  final explanation = TextEditingController();

  List<dynamic> questions = [];
  int? editingIndex;
  bool isLoading = true;

  String correctOption = "A";

  File? pickedImage;
  String? uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadExistingQuestions();
  }

  Future<void> _loadExistingQuestions() async {
    final snap = await FirebaseFirestore.instance
        .collection("quizPdfs")
        .doc(widget.quizId)
        .get();

    questions = (snap.data()?["questions"] ?? []) as List;
    setState(() => isLoading = false);
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref("question_images")
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _resetForm() {
    editingIndex = null;
    questionController.clear();
    optionA.clear();
    optionB.clear();
    optionC.clear();
    optionD.clear();
    explanation.clear();
    correctOption = "A";
    pickedImage = null;
    uploadedImageUrl = null;
    setState(() {});
  }

  Future<void> _saveQuestion() async {
    if (questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("⚠ Enter question")));
      return;
    }

    if (pickedImage != null) {
      uploadedImageUrl = await _uploadImage(pickedImage!);
    }

    final q = {
      "question": questionController.text.trim(),
      "imageUrl": uploadedImageUrl ?? "",
      "options": {
        "A": optionA.text.trim(),
        "B": optionB.text.trim(),
        "C": optionC.text.trim(),
        "D": optionD.text.trim(),
      },
      "correctAnswer": correctOption,
      "explanation": explanation.text.trim(),
    };

    if (editingIndex != null) {
      questions[editingIndex!] = q;
    } else {
      questions.add(q);
    }

    await FirebaseFirestore.instance
        .collection("quizPdfs")
        .doc(widget.quizId)
        .update({"questions": questions});

    _resetForm();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("✔ Saved")));
  }

  void _editQuestion(int index) {
    final q = questions[index];

    editingIndex = index;

    questionController.text = q["question"];
    optionA.text = q["options"]["A"];
    optionB.text = q["options"]["B"];
    optionC.text = q["options"]["C"];
    optionD.text = q["options"]["D"];
    explanation.text = q["explanation"];
    correctOption = q["correctAnswer"];

    uploadedImageUrl = q["imageUrl"];
    pickedImage = null;

    setState(() {});
  }

  void _deleteQuestion(int index) async {
    questions.removeAt(index);

    await FirebaseFirestore.instance
        .collection("quizPdfs")
        .doc(widget.quizId)
        .update({"questions": questions});

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Manage Quiz"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveQuestion,
            child: const Text("Save & Next",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ===================== QUESTIONS LIST =====================
                Container(
                  padding: const EdgeInsets.all(8),
                  height: 250,
                  child: questions.isEmpty
                      ? const Center(child: Text("No questions added"))
                      : ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (context, index) {
                            final q = questions[index];
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(
                                  "${index + 1}. ${q["question"]}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle:
                                    Text("Correct: ${q["correctAnswer"]}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => _editQuestion(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deleteQuestion(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const Divider(),

                // ===================== FORM AREA =====================
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Question",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        TextField(controller: questionController),

                        const SizedBox(height: 12),

                        // IMAGE PICKER
                        if (uploadedImageUrl != null &&
                            uploadedImageUrl!.isNotEmpty)
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(uploadedImageUrl!,
                                    height: 150, fit: BoxFit.cover),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final img = await ImagePicker().pickImage(
                                      source: ImageSource.gallery);
                                  if (img != null) {
                                    setState(() => pickedImage =
                                        File(img.path));
                                  }
                                },
                                child: const Text("Change Image"),
                              )
                            ],
                          )
                        else if (pickedImage != null)
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(pickedImage!,
                                    height: 150, fit: BoxFit.cover),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => pickedImage = null),
                                child: const Text("Remove Image",
                                    style: TextStyle(color: Colors.red)),
                              )
                            ],
                          )
                        else
                          TextButton.icon(
                            onPressed: () async {
                              final img = await ImagePicker()
                                  .pickImage(source: ImageSource.gallery);
                              if (img != null) {
                                setState(
                                    () => pickedImage = File(img.path));
                              }
                            },
                            icon: const Icon(Icons.image),
                            label: const Text("Upload Question Image"),
                          ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: optionA,
                          decoration:
                              const InputDecoration(labelText: "Option A"),
                        ),
                        TextField(
                          controller: optionB,
                          decoration:
                              const InputDecoration(labelText: "Option B"),
                        ),
                        TextField(
                          controller: optionC,
                          decoration:
                              const InputDecoration(labelText: "Option C"),
                        ),
                        TextField(
                          controller: optionD,
                          decoration:
                              const InputDecoration(labelText: "Option D"),
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField(
                          value: correctOption,
                          decoration: const InputDecoration(
                              labelText: "Correct Option"),
                          items: const [
                            DropdownMenuItem(
                                value: "A", child: Text("A")),
                            DropdownMenuItem(
                                value: "B", child: Text("B")),
                            DropdownMenuItem(
                                value: "C", child: Text("C")),
                            DropdownMenuItem(
                                value: "D", child: Text("D")),
                          ],
                          onChanged: (v) => setState(() {
                            correctOption = v!;
                          }),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: explanation,
                          decoration: const InputDecoration(
                              labelText: "Explanation (Optional)"),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),

                // ===================== SUBMIT BUTTON =====================
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Submit",
                        style: TextStyle(fontSize: 18)),
                  ),
                )
              ],
            ),
    );
  }
}
