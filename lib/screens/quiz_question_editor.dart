import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class QuizEditor extends StatefulWidget {
  final String quizId;
  final String chapterName;

  const QuizEditor({
    super.key,
    required this.quizId,
    required this.chapterName,
  });

  @override
  State<QuizEditor> createState() => _QuizEditorState();
}

class _QuizEditorState extends State<QuizEditor> {
  int selectedQno = 1;
  int totalQuestions = 0;

  bool loading = false;

  Map<String, dynamic>? current;

  final qC = TextEditingController();
  final aC = TextEditingController();
  final bC = TextEditingController();
  final cC = TextEditingController();
  final dC = TextEditingController();
  final expC = TextEditingController();

  String correct = "A";

  File? pickedImage;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _loadTotal();
    _loadQuestion(1);
  }

  Future<void> _loadTotal() async {
    final snap = await FirebaseFirestore.instance
        .collection("quizQuestions")
        .where("quizId", isEqualTo: widget.quizId)
        .get();

    setState(() => totalQuestions = snap.docs.length);
  }

  Future<void> _loadQuestion(int qno) async {
    setState(() => loading = true);

    final snap = await FirebaseFirestore.instance
        .collection("quizQuestions")
        .where("quizId", isEqualTo: widget.quizId)
        .where("qno", isEqualTo: qno)
        .get();

    if (snap.docs.isEmpty) {
      _clearUI();
      current = null;
    } else {
      final data = snap.docs.first.data();
      current = data;

      qC.text = data["question"];
      aC.text = data["options"]["A"];
      bC.text = data["options"]["B"];
      cC.text = data["options"]["C"];
      dC.text = data["options"]["D"];
      expC.text = data["explanation"];
      imageUrl = data["imageUrl"];
      correct = data["correct"];
    }

    setState(() => loading = false);
  }

  void _clearUI() {
    qC.clear();
    aC.clear();
    bC.clear();
    cC.clear();
    dC.clear();
    expC.clear();
    correct = "A";
    imageUrl = null;
    pickedImage = null;
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref("quiz_images")
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (qC.text.trim().isEmpty) {
      _toast("Enter question");
      return;
    }

    setState(() => loading = true);

    // upload image if new picked
    if (pickedImage != null) {
      imageUrl = await _uploadImage(pickedImage!);
    }

    final questionData = {
      "quizId": widget.quizId,
      "qno": selectedQno,
      "question": qC.text.trim(),
      "options": {
        "A": aC.text.trim(),
        "B": bC.text.trim(),
        "C": cC.text.trim(),
        "D": dC.text.trim(),
      },
      "correct": correct,
      "explanation": expC.text.trim(),
      "imageUrl": imageUrl ?? "",
      "updatedAt": FieldValue.serverTimestamp(),
    };

    final snap = await FirebaseFirestore.instance
        .collection("quizQuestions")
        .where("quizId", isEqualTo: widget.quizId)
        .where("qno", isEqualTo: selectedQno)
        .get();

    if (snap.docs.isEmpty) {
      await FirebaseFirestore.instance
          .collection("quizQuestions")
          .add(questionData);
    } else {
      await snap.docs.first.reference.update(questionData);
    }

    await _loadTotal();

    setState(() => loading = false);

    _toast("Saved ✔");
  }

  Future<void> _delete() async {
    final snap = await FirebaseFirestore.instance
        .collection("quizQuestions")
        .where("quizId", isEqualTo: widget.quizId)
        .where("qno", isEqualTo: selectedQno)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.delete();
      _toast("Deleted");
    }

    await _loadTotal();
    _clearUI();
    setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: Text("Manage Quiz - ${widget.chapterName}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // **********************
                  //   JUMP TO QUESTION UI
                  // **********************
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3))
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Q.No:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),

                        SizedBox(
                          width: 70,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(hintText: "1"),
                            onSubmitted: (v) {
                              final no = int.tryParse(v.trim()) ?? 1;
                              selectedQno = no;
                              _loadQuestion(no);
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        ElevatedButton(
                          onPressed: () => _loadQuestion(selectedQno),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple),
                          child: const Text("Load"),
                        ),

                        const Spacer(),

                        Chip(
                          label: Text("Total: $totalQuestions"),
                          backgroundColor: Colors.purple.shade100,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // **********************
                  //   QUESTION EDITOR
                  // **********************
                  _buildInput("Question", qC),

                  const SizedBox(height: 10),

                  // IMAGE BLOCK
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(imageUrl!,
                              height: 150, fit: BoxFit.cover),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => imageUrl = null),
                          child: const Text("Remove Image",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  else if (pickedImage != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(pickedImage!,
                              height: 150, fit: BoxFit.cover),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => pickedImage = null),
                          child: const Text("Remove Image",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  else
                    TextButton.icon(
                      icon: const Icon(Icons.image, color: Colors.purple),
                      label: const Text("Upload Question Image"),
                      onPressed: () async {
                        final picked = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setState(() => pickedImage = File(picked.path));
                        }
                      },
                    ),

                  const SizedBox(height: 20),

                  _buildInput("Option A", aC),
                  _buildInput("Option B", bC),
                  _buildInput("Option C", cC),
                  _buildInput("Option D", dC),

                  const SizedBox(height: 15),

                  DropdownButtonFormField(
                    value: correct,
                    decoration: const InputDecoration(
                        labelText: "Correct Answer"),
                    items: ["A", "B", "C", "D"]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => correct = v!),
                  ),

                  const SizedBox(height: 20),

                  _buildInput("Explanation (Optional)", expC, maxLines: 2),

                  const SizedBox(height: 30),
                ],
              ),
            ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (current != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: _delete,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red),
                  child: const Text("Delete",
                      style: TextStyle(fontSize: 18)),
                ),
              ),
            if (current != null) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text("Submit",
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController c,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
