import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdfx/pdfx.dart'; // ✅ use pdfx instead of flutter_pdfview
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Normalizes both Firebase and Drive URLs
String normalizeUrl(String url) {
  if (url.contains("firebasestorage.googleapis.com")) return url;

  if (url.contains("drive.google.com")) {
    final regex = RegExp(r"/d/([a-zA-Z0-9_-]+)");
    final match = regex.firstMatch(url);
    if (match != null) {
      return "https://drive.google.com/uc?export=download&id=${match.group(1)}";
    }
  }
  return url;
}

class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});
  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  String? selectedYear, selectedSubjectId, selectedSubjectName;
  final MaterialColor primaryColor = Colors.green;

  Future<bool> _handleBack() async {
    if (selectedSubjectId != null) {
      setState(() {
        selectedSubjectId = null;
        selectedSubjectName = null;
      });
      return false;
    } else if (selectedYear != null) {
      setState(() => selectedYear = null);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: Text(selectedSubjectName != null
              ? "${selectedSubjectName!} Question Bank"
              : "Question Bank"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop) Navigator.pop(context);
            },
          ),
        ),
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (selectedYear == null) return _buildYearSelection();
    if (selectedSubjectId == null) return _buildSubjectList();
    return _buildChapterList();
  }

  // =================== YEAR ===================
  Widget _buildYearSelection() {
    final years = [
      {"title": "1st Year", "short": "1st"},
      {"title": "2nd Year", "short": "2nd"},
      {"title": "3rd Year", "short": "3rd"},
      {"title": "4th Year", "short": "4th"},
    ];

    final List<Color> bgColors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
    ];

    final List<Color> textColors = [
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Chip(
              label: const Text("Question Bank"),
              avatar: const Icon(Icons.library_books, color: Colors.white, size: 18),
              backgroundColor: Colors.green,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 10),
            Chip(
              label: Text(selectedYear ?? "Select Year"),
              backgroundColor: Colors.grey.shade200,
            ),
          ]),
          const SizedBox(height: 20),
          const Text(
            "Select Year for Question Bank",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: years.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final year = years[index];
              return GestureDetector(
                onTap: () => setState(() => selectedYear = year["title"]),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: bgColors[index],
                        radius: 30,
                        child: Text(
                          year["short"]!,
                          style: TextStyle(
                              color: textColors[index],
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        year["title"]!,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 1),
          const SizedBox(height: 10),

          const Text(
            "⭐ Salient Features of MBBS Freaks Question Bank",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletPoint(
                    text:
                        "👉 Our Question Bank covers previous 23 Years University Papers"),
                _BulletPoint(
                    text: "👉 Questions are arranged Topic wise in chapter"),
                _BulletPoint(
                    text:
                        "👉 More Number of Questions are added from a single Chapter"),
                _BulletPoint(
                    text: "👉 Chapters from a Subject are well organised"),
                _BulletPoint(
                    text:
                        "👉 Most repeated questions are highlighted by adding stars to it"),
                _BulletPoint(
                    text:
                        "👉 No. of stars = The more no. of times repeated = Most important"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =================== SUBJECTS ===================
  Widget _buildSubjectList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("qbSubjects")
          .where("year", isEqualTo: selectedYear)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No subjects found"));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final subject = snapshot.data!.docs[index];
            final imageUrl = subject['imageUrl'] ?? '';
            final subjectName = subject['name'] ?? 'Subject';

            return GestureDetector(
              onTap: () => setState(() {
                selectedSubjectId = subject.id;
                selectedSubjectName = subjectName;
              }),
              child: Card(
                elevation: 4,
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: imageUrl.isNotEmpty
                          ? Image.network(normalizeUrl(imageUrl), fit: BoxFit.cover)
                          : Container(
                              color: primaryColor.shade100,
                              child: Center(
                                child: Text(
                                  subjectName.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
                                ),
                              ),
                            ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: primaryColor.withOpacity(0.7),
                        padding: const EdgeInsets.all(6),
                        child: Text(subjectName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =================== CHAPTERS (open PDF directly) ===================
  Widget _buildChapterList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("qbChapters")
          .where("subjectId", isEqualTo: selectedSubjectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No chapters"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chapterDoc = snapshot.data!.docs[index];
            final data = chapterDoc.data() as Map<String, dynamic>;
            final chapterName = data['name'] ?? 'Chapter';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(chapterName),
                trailing: const Icon(Icons.picture_as_pdf, color: Colors.green),
                onTap: () async {
                  final pdfSnap = await FirebaseFirestore.instance
                      .collection("qbPdfs")
                      .where("chapterId", isEqualTo: chapterDoc.id)
                      .get();

                  if (pdfSnap.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No PDF found for this chapter")),
                    );
                    return;
                  }

                  final pdfData = pdfSnap.docs.first.data() as Map<String, dynamic>;
                  final pdfUrl = pdfData['downloadUrl'] ?? '';
                  final pdfTitle = pdfData['title'] ?? chapterName;

                  if (pdfUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerPage(
                          url: normalizeUrl(pdfUrl),
                          title: pdfTitle,
                          tag: "qb",
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

// =================== PDF VIEWER ===================
class PdfViewerPage extends StatefulWidget {
  final String url, title, tag;
  const PdfViewerPage({super.key, required this.url, required this.title, required this.tag});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    final dir = await getApplicationDocumentsDirectory();
    final safeFileName = '${widget.tag}_${widget.url.hashCode}.pdf';
    final file = File("${dir.path}/$safeFileName");

    PdfDocument doc;
    if (await file.exists()) {
      doc = await PdfDocument.openFile(file.path);
    } else {
      final response = await http.get(Uri.parse(widget.url));
      await file.writeAsBytes(response.bodyBytes, flush: true);
      doc = await PdfDocument.openFile(file.path);
    }

    setState(() {
      _totalPages = doc.pagesCount;
      _pdfController = PdfControllerPinch(document: Future.value(doc));
    });
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Color get _appBarColor {
    if (widget.tag == "notes") return Colors.blue;
    if (widget.tag == "qb") return Colors.green;
    if (widget.tag == "pyqs") return Colors.red;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
      ),
      body: _pdfController == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PdfViewPinch(
                  controller: _pdfController!,
                  scrollDirection: Axis.vertical,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.white),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      "$_currentPage / $_totalPages",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// =================== BULLET POINT WIDGET ===================
class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ",
              style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
