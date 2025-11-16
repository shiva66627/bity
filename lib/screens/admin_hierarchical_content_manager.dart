import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart'; // Firebase Storage helper
import 'package:mbbsfreaks/screens/admin_quiz_uploader.dart';


class AdminHierarchicalContentManager extends StatefulWidget {
  final String category; // "notes", "pyqs", "question_banks", "quiz"
  const AdminHierarchicalContentManager({super.key, required this.category});

  @override
  State<AdminHierarchicalContentManager> createState() =>
      _AdminHierarchicalContentManagerState();
}

class _AdminHierarchicalContentManagerState
    extends State<AdminHierarchicalContentManager> {
  String? selectedYear;
  String? selectedSubjectId;
  String? selectedChapterId;

  final List<String> years = ["1st Year", "2nd Year", "3rd Year", "4th Year"];

  late final String subjectsCollection;
  late final String chaptersCollection;
  late final String pdfsCollection;

  @override
  void initState() {
    super.initState();

    final collections = {
      "notes": {
        "subjects": "notesSubjects",
        "chapters": "notesChapters",
        "pdfs": "notesPdfs"
      },
      "pyqs": {
        "subjects": "pyqsSubjects",
        "chapters": "pyqsChapters",
        "pdfs": "pyqsPdfs"
      },
      "question_banks": {
        "subjects": "qbSubjects",
        "chapters": "qbChapters",
        "pdfs": "qbPdfs"
      },
      "quiz": {
        "subjects": "quizSubjects",
        "chapters": "quizChapters",
        "pdfs": "quizPdfs"
      },
    };

    subjectsCollection = collections[widget.category]!["subjects"]!;
    chaptersCollection = collections[widget.category]!["chapters"]!;
    pdfsCollection = collections[widget.category]!["pdfs"]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage ${widget.category.toUpperCase()}"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // YEAR DROPDOWN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: selectedYear,
              hint: const Text("Select Year"),
              isExpanded: true,
              items: years
                  .map(
                    (y) => DropdownMenuItem<String>(
                      value: y,
                      child: Text(y),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedYear = val;
                  selectedSubjectId = null;
                  selectedChapterId = null;
                });
              },
            ),
          ),

          const Divider(height: 1),

          // ================== SUBJECTS ==================
          if (selectedYear != null)
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Subject"),
                        onPressed: () => _addSubjectDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(subjectsCollection)
                          .where("year", isEqualTo: selectedYear)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text("Error: ${snapshot.error}"));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text("No subjects found"));
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final subjectDoc = docs[index];
                            final data =
                                subjectDoc.data() as Map<String, dynamic>;
                            final subjectName = data["name"] ?? "Subject";
                            final imageUrl =
                                (data["imageUrl"] ?? "").toString();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: imageUrl.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(imageUrl),
                                        backgroundColor: Colors.grey[200],
                                      )
                                    : const Icon(Icons.book),
                                title: Text(subjectName),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => _editSubject(
                                          subjectDoc.id, subjectName),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          subjectDoc.reference.delete(),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedSubjectId = subjectDoc.id;
                                    selectedChapterId = null;
                                  });
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // ================== CHAPTERS (with drag reorder, local sort) ==================
          if (selectedSubjectId != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(chaptersCollection)
                    .where("subjectId", isEqualTo: selectedSubjectId)
                    // NOTE: no .orderBy('order') to avoid composite index
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  var docs = snapshot.data?.docs.toList() ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text("No chapters found"));
                  }

                  // Sort locally by 'order' (nulls last)
                  docs.sort((a, b) {
                    final ma = (a.data() as Map<String, dynamic>);
                    final mb = (b.data() as Map<String, dynamic>);
                    final oa = (ma['order'] is num) ? ma['order'] as num : 1e9;
                    final ob = (mb['order'] is num) ? mb['order'] as num : 1e9;
                    return oa.compareTo(ob);
                  });

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;

                      // Reorder locally
                      final moved = docs.removeAt(oldIndex);
                      docs.insert(newIndex, moved);

                      // Persist new order back to Firestore
                      // We use 0..n-1 as 'order' values
                      final batch =
                          FirebaseFirestore.instance.batch();
                      for (int i = 0; i < docs.length; i++) {
                        final ref = FirebaseFirestore.instance
                            .collection(chaptersCollection)
                            .doc(docs[i].id);
                        batch.update(ref, {"order": i});
                      }
                      await batch.commit();
                    },
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _buildChapterTile(doc);
                    },
                  );
                },
              ),
            ),

          // ================== PDFs ==================
          if (selectedChapterId != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(pdfsCollection)
                    .where("chapterId", isEqualTo: selectedChapterId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text("No PDFs found"));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final pdfDoc = docs[index];
                      final data =
                          pdfDoc.data() as Map<String, dynamic>;
                      final pdfTitle = (data["title"] ?? "PDF").toString();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          title: Text(pdfTitle),
                          leading: const Icon(Icons.picture_as_pdf,
                              color: Colors.red),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editPdf(
                                    pdfDoc.id, pdfTitle, data["downloadUrl"]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => pdfDoc.reference.delete(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ================== CHAPTER TILE ==================
 Widget _buildChapterTile(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final chapterName = (data["name"] ?? "Chapter").toString();
  final isPremium = data["isPremium"] == true;
  final order = (data["order"] is num) ? data["order"] as num : null;

  return Card(
    key: ValueKey(doc.id),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: ListTile(
      leading: const Icon(Icons.drag_handle),
      title: Text(
        order == null ? chapterName : "$order. $chapterName",
      ),
      subtitle: Text(
        isPremium ? "Premium Content" : "Free Access",
        style: TextStyle(
          color: isPremium ? Colors.red : Colors.green,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PREMIUM SWITCH
          Switch(
            value: isPremium,
            onChanged: (val) {
              FirebaseFirestore.instance
                  .collection(chaptersCollection)
                  .doc(doc.id)
                  .update({"isPremium": val});
            },
          ),

          // ⭐ EDIT BUTTON (QUIZ + NORMAL CONTENT) ⭐
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () async {
              // 👉 QUIZ MODE: OPEN QUIZ EDITOR
              if (widget.category == "quiz") {
                // 1️⃣ find quiz linked to this chapter
                final snap = await FirebaseFirestore.instance
                    .collection("quizPdfs")
                    .where("chapterId", isEqualTo: doc.id)
                    .limit(1)
                    .get();

                String quizId;

                if (snap.docs.isEmpty) {
                  // 2️⃣ create quiz if missing
                  final newQuiz = await FirebaseFirestore.instance
                      .collection("quizPdfs")
                      .add({
                    "chapterId": doc.id,
                    "title": "$chapterName Quiz",
                    "questions": [],
                    "createdAt": FieldValue.serverTimestamp(),
                  });

                  quizId = newQuiz.id;
                } else {
                  quizId = snap.docs.first.id;
                }

                // 3️⃣ open quiz uploader in edit mode
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminQuizUploader(
                      existingQuizId: quizId,
                      existingChapterId: doc.id,
                      existingChapterName: chapterName,
                    ),
                  ),
                );
              } 
              
              // 👉 NORMAL MODULES KEEP OLD EDIT BEHAVIOR
              else {
                _editChapter(doc.id, chapterName, order?.toInt() ?? 0);
              }
            },
          ),

          // DELETE BUTTON
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => doc.reference.delete(),
          ),
        ],
      ),

      // TAP TO LOAD PDFs LIST
      onTap: () {
        setState(() {
          selectedChapterId = doc.id;
        });
      },
    ),
  );
}

  // ================== ADD SUBJECT (with first chapter + PDF) ==================
  Future<void> _addSubjectDialog() async {
    final subjectC = TextEditingController();
    final chapterC = TextEditingController();
    final orderC = TextEditingController(text: "0");
    final pdfTitleC = TextEditingController();

    String? subjectImageUrl;
    String? pdfUrl;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Subject + Chapter + PDF"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectC,
                decoration: const InputDecoration(labelText: "Subject Name"),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("Upload Subject Image"),
                onPressed: () async {
                  final url =
                      await StorageService().uploadFile("subject_images");
                  if (url != null) {
                    subjectImageUrl = url;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("✅ Subject image uploaded")),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 24),
              TextField(
                controller: chapterC,
                decoration: const InputDecoration(labelText: "Chapter Name"),
              ),
              TextField(
                controller: orderC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Chapter Order"),
              ),
              TextField(
                controller: pdfTitleC,
                decoration: const InputDecoration(labelText: "PDF Title"),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text("Upload PDF"),
                onPressed: () async {
                  final url = await StorageService().uploadFile("pdfs");
                  if (url != null) {
                    pdfUrl = url;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ PDF uploaded")),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final subjectName = subjectC.text.trim();
              final chapterName = chapterC.text.trim();
              final pdfTitle = pdfTitleC.text.trim();
              final orderVal = int.tryParse(orderC.text.trim()) ?? 0;

              if (subjectName.isEmpty ||
                  chapterName.isEmpty ||
                  pdfTitle.isEmpty ||
                  subjectImageUrl == null ||
                  pdfUrl == null ||
                  selectedYear == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Fill all fields")),
                  );
                }
                return;
              }

              try {
                // Add subject
                final subjectRef = await FirebaseFirestore.instance
                    .collection(subjectsCollection)
                    .add({
                  "name": subjectName,
                  "year": selectedYear,
                  "imageUrl": subjectImageUrl,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                // Add chapter (with order)
                final chapterRef = await FirebaseFirestore.instance
                    .collection(chaptersCollection)
                    .add({
                  "name": chapterName,
                  "subjectId": subjectRef.id,
                  "order": orderVal,
                  "isPremium": false,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                // Add PDF entry
                await FirebaseFirestore.instance
                    .collection(pdfsCollection)
                    .add({
                  "title": pdfTitle,
                  "downloadUrl": pdfUrl,
                  "chapterId": chapterRef.id,
                  "uploadedAt": FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Subject + Chapter + PDF added"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("❌ Error: $e")),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ================== EDIT SUBJECT ==================
  Future<void> _editSubject(String docId, String oldName) async {
    final controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Subject"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Subject Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(subjectsCollection)
                  .doc(docId)
                  .update({"name": controller.text.trim()});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ================== EDIT CHAPTER (name + order) ==================
  Future<void> _editChapter(String docId, String oldName, int oldOrder) async {
    final nameC = TextEditingController(text: oldName);
    final orderC = TextEditingController(text: oldOrder.toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Chapter"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration:
                  const InputDecoration(labelText: "Chapter Name"),
            ),
            TextField(
              controller: orderC,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Order Number"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(chaptersCollection)
                  .doc(docId)
                  .update({
                "name": nameC.text.trim(),
                "order": int.tryParse(orderC.text.trim()) ?? oldOrder,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ================== EDIT / UPLOAD PDF ==================
  Future<void> _editPdf(
      String docId, String oldTitle, String? oldLink) async {
    final titleC = TextEditingController(text: oldTitle);
    final linkC = TextEditingController(text: oldLink ?? "");

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit / Upload PDF"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(labelText: "PDF Title"),
            ),
            TextField(
              controller: linkC,
              decoration: const InputDecoration(labelText: "Existing Link"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload PDF/Image"),
              onPressed: () async {
                final url = await StorageService().uploadFile(pdfsCollection);
                if (url != null) {
                  linkC.text = url;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✅ File uploaded to Firebase"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(pdfsCollection)
                  .doc(docId)
                  .update({
                "title": titleC.text.trim(),
                "downloadUrl": linkC.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
