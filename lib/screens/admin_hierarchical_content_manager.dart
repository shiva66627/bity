import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart'; // ✅ Firebase Storage helper

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

  List<String> years = ["1st Year", "2nd Year", "3rd Year", "4th Year"];

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

          /// YEAR DROPDOWN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: selectedYear,
              hint: const Text("Select Year"),
              isExpanded: true,
              items: years
                  .map((y) => DropdownMenuItem<String>(
                        value: y,
                        child: Text(y),
                      ))
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

          const Divider(),

          /// ================== SUBJECTS ==================
          if (selectedYear != null)
            Expanded(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Subject"),
                    onPressed: () => _addSubjectDialog(),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(subjectsCollection)
                          .where("year", isEqualTo: selectedYear)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No subjects found"));
                        }

                        return ListView(
                          children: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final subjectName = data["name"] ?? "Subject";

                            return Card(
                              child: ListTile(
                                leading: data["imageUrl"] != null &&
                                        data["imageUrl"].toString().isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage:
                                            NetworkImage(data["imageUrl"]),
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
                                      onPressed: () =>
                                          _editSubject(doc.id, subjectName),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => doc.reference.delete(),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedSubjectId = doc.id;
                                    selectedChapterId = null;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          /// ================== CHAPTERS ==================
          if (selectedSubjectId != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(chaptersCollection)
                    .where("subjectId", isEqualTo: selectedSubjectId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No chapters found"));
                  }

                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final chapterName = data["name"] ?? "Chapter";
                      final isPremium = data["isPremium"] ?? false;

                      return Card(
                        child: ListTile(
                          title: Text(chapterName),
                          leading: const Icon(Icons.layers),
                          subtitle: Text(
                            isPremium ? "Premium Content" : "Free Access",
                            style: TextStyle(
                                color: isPremium ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isPremium,
                                onChanged: (val) {
                                  FirebaseFirestore.instance
                                      .collection(chaptersCollection)
                                      .doc(doc.id)
                                      .update({"isPremium": val});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _editChapter(doc.id, chapterName),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => doc.reference.delete(),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              selectedChapterId = doc.id;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

          /// ================== PDFs ==================
          if (selectedChapterId != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(pdfsCollection)
                    .where("chapterId", isEqualTo: selectedChapterId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No PDFs found"));
                  }

                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final pdfTitle = data["title"] ?? "PDF";

                      return Card(
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
                                    doc.id, pdfTitle, data["downloadUrl"]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => doc.reference.delete(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// ================== ADD SUBJECT ==================
  Future<void> _addSubjectDialog() async {
    final subjectC = TextEditingController();
    final chapterC = TextEditingController();
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
                  final url = await StorageService().uploadFile("subject_images");
                  if (url != null) {
                    subjectImageUrl = url;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Subject image uploaded")),
                    );
                  }
                },
              ),
              const Divider(),
              TextField(
                controller: chapterC,
                decoration: const InputDecoration(labelText: "Chapter Name"),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ PDF uploaded")),
                    );
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

              if (subjectName.isEmpty ||
                  chapterName.isEmpty ||
                  pdfTitle.isEmpty ||
                  subjectImageUrl == null ||
                  pdfUrl == null ||
                  selectedYear == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("⚠️ Fill all fields")),
                );
                return;
              }

              try {
                // Add subject
                final subjectDoc = await FirebaseFirestore.instance
                    .collection(subjectsCollection)
                    .add({
                  "name": subjectName,
                  "year": selectedYear,
                  "imageUrl": subjectImageUrl,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                // Add chapter
                final chapterDoc = await FirebaseFirestore.instance
                    .collection(chaptersCollection)
                    .add({
                  "name": chapterName,
                  "subjectId": subjectDoc.id,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                // Add PDF
                await FirebaseFirestore.instance
                    .collection(pdfsCollection)
                    .add({
                  "title": pdfTitle,
                  "downloadUrl": pdfUrl,
                  "chapterId": chapterDoc.id,
                  "uploadedAt": FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("✅ Subject + Chapter + PDF added"),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ Error: $e")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// ================== EDIT HELPERS ==================
  Future<void> _editSubject(String docId, String oldName) async {
    final controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Subject"),
        content: TextField(controller: controller),
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
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _editChapter(String docId, String oldName) async {
    final controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Chapter"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(chaptersCollection)
                  .doc(docId)
                  .update({"name": controller.text.trim()});
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

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
                final url =
                    await StorageService().uploadFile(pdfsCollection);
                if (url != null) {
                  linkC.text = url;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ File uploaded to Firebase"),
                      backgroundColor: Colors.green,
                    ),
                  );
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
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
