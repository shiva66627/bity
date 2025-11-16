import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Normalizes Google Drive links & Firebase URLs
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

class PyqsPage extends StatefulWidget {
  const PyqsPage({super.key});
  @override
  State<PyqsPage> createState() => _PyqsPageState();
}

class _PyqsPageState extends State<PyqsPage> {
  String? selectedYear, selectedSubjectId, selectedSubjectName, selectedChapterId;

  Future<bool> _handleBack() async {
    if (selectedChapterId != null) {
      setState(() => selectedChapterId = null);
      return false;
    } else if (selectedSubjectId != null) {
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
              ? (selectedChapterId != null
                  ? selectedSubjectName!
                  : "${selectedSubjectName!} Practice Papers")
              : "Practice Papers"),
          backgroundColor: Colors.red,
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
    if (selectedChapterId == null) return _buildChapterList();
    return _buildPdfList();
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
      Colors.red.shade50,
      Colors.orange.shade50,
      Colors.teal.shade50,
      Colors.purple.shade50,
    ];

    final List<Color> textColors = [
      Colors.red.shade700,
      Colors.orange.shade700,
      Colors.teal.shade700,
      Colors.purple.shade700,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Chip(
              label: const Text("Practice Papers"),
              avatar: const Icon(Icons.description, color: Colors.white, size: 18),
              backgroundColor: Colors.red,
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
            "Select Year for Practice Papers",
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
                      Text(year["title"]!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
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
            "⭐ Salient Features of MBBS Freaks Practice Papers",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
                        "👉 Similar to real university question paper pattern"),
                _BulletPoint(
                    text: "👉 College wise papers categorization"),
                _BulletPoint(text: "👉 Helps student to practice MCQs"),
                _BulletPoint(
                    text: "👉 Helps student to encounter variety of questions"),
                _BulletPoint(text: "👉 Boosts exam confidence"),
                _BulletPoint(text: "👉 Free access to everyone"),
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
          .collection("pyqsSubjects")
          .where("year", isEqualTo: selectedYear)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (  snapshot.data!.docs.isEmpty) return const Center(child: Text("No subjects found"));

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: imageUrl.isNotEmpty
                          ? Image.network(normalizeUrl(imageUrl), fit: BoxFit.cover)
                          : Container(
                              color: Colors.red[100],
                              child: Center(
                                child: Text(
                                  subjectName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red),
                                ),
                              ),
                            ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: Colors.redAccent.withOpacity(0.7),
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

  // =================== CHAPTERS (locally sorted by "order") ===================
  Widget _buildChapterList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("pyqsChapters")
          .where("subjectId", isEqualTo: selectedSubjectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.toList();

        // ✅ Sort locally by "order" (set from admin drag)
     docs.sort((a, b) {
  final aData = a.data() as Map<String, dynamic>;
  final bData = b.data() as Map<String, dynamic>;
  final ao = (aData['order'] ?? 9999) as int;
  final bo = (bData['order'] ?? 9999) as int;
  return ao.compareTo(bo);
});


        if (docs.isEmpty) return const Center(child: Text("No chapters"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chapter = docs[index];
            final chapterName = chapter['name'] ?? 'Chapter';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(chapterName, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => setState(() => selectedChapterId = chapter.id),
              ),
            );
          },
        );
      },
    );
  }

  // =================== PDFs ===================
  Widget _buildPdfList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("pyqsPdfs")
          .where("chapterId", isEqualTo: selectedChapterId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No PDFs found"));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final url = data['downloadUrl'] ?? '';
            final title = data['title'] ?? 'Untitled';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(title),
                subtitle: const Text("Tap to view"),
                onTap: () {
                  if (url.isNotEmpty) {
                    _openPdf(context, url, title);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _openPdf(BuildContext context, String rawUrl, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(url: normalizeUrl(rawUrl), title: title),
      ),
    );
  }
}

// =================== PDF VIEWER ===================
class PdfViewerPage extends StatefulWidget {
  final String url, title;
  const PdfViewerPage({super.key, required this.url, required this.title});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  String? _localPath;
  int _currentPage = 0, _totalPages = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _downloadAndLoadPdf();
  }

 Future<void> _downloadAndLoadPdf() async {
  try {
    final dir = await getApplicationDocumentsDirectory();

    // Safe hashed file name (no conflict, unique)
    final fileName = "pyqs_${widget.url.hashCode}.pdf";
    final file = File("${dir.path}/$fileName");

    // 🟢 If file already exists → load offline
    if (await file.exists()) {
      _localPath = file.path;
      setState(() => _isLoading = false);
      return;
    }

    // 🟡 First-time download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⏳ Downloading PDF...")),
    );

    final response = await http.get(Uri.parse(widget.url));

    if (response.statusCode != 200) {
      throw Exception("Failed to download PDF");
    }

    // Save locally
    await file.writeAsBytes(response.bodyBytes, flush: true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ PDF saved for offline use")),
    );

    _localPath = file.path;
    setState(() => _isLoading = false);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to load PDF: $e")),
      );
      setState(() => _isLoading = false);
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: _isLoading || _localPath == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PDFView(
                  filePath: _localPath!,
                  swipeHorizontal: false,
                  pageFling: true,
                  pageSnap: false,
                  autoSpacing: false,
                  fitPolicy: FitPolicy.WIDTH,
                  onRender: (pages) => setState(() => _totalPages = pages ?? 0),
                  onPageChanged: (page, total) =>
                      setState(() => _currentPage = page ?? 0),
                ),
                if (_totalPages > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text("${_currentPage + 1} / $_totalPages",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
    );
  }
}

// =================== BULLET POINT ===================
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
