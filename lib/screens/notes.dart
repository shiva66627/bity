import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// ✅ Convert Google Drive /view links into direct download links
String normalizeDriveUrl(String url) {
  if (url.contains("drive.google.com")) {
    final regex = RegExp(r"/d/([a-zA-Z0-9_-]+)");
    final match = regex.firstMatch(url);
    if (match != null) {
      final fileId = match.group(1);
      return "https://drive.google.com/uc?export=download&id=$fileId";
    }
  }
  return url;
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String? selectedYear;
  String? selectedSubjectId;
  String? selectedSubjectName;
  String? selectedChapterId;
  List<String> premiumYears = [];
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadUserPremiumYears();
  }

  Future<void> _loadUserPremiumYears() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          premiumYears =
              List<String>.from(doc.data()?['premiumYears'] ?? <String>[]);
        });
      }
    }
  }

  bool get hasCurrentYearAccess =>
      selectedYear != null && premiumYears.contains(selectedYear);

  Future<void> _onRefresh() async {
    setState(() => refreshing = true);
    await _loadUserPremiumYears();
    setState(() => refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Premium access refreshed"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
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
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(selectedSubjectName != null
              ? selectedChapterId != null
                  ? selectedSubjectName!
                  : "${selectedSubjectName!} Notes"
              : "Notes"),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: refreshing ? null : _onRefresh,
              tooltip: "Refresh Premium Access",
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: _buildContent(),
        ),
      ),
    );
  }

  // ✅ Fixed function names (no typo)
  Widget _buildContent() {
    if (selectedYear == null) return _buildYearSelection();
    if (selectedSubjectId == null) return _buildSubjectList();
    if (selectedChapterId == null) return _buildChapterList();
    return _buildPdfList();
  }

  // =================== YEAR SELECTION ===================
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
              label: const Text("Notes"),
              avatar: const Icon(Icons.notes, color: Colors.white, size: 18),
              backgroundColor: Colors.blue,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 10),
            Chip(
              label: Text(selectedYear ?? "Select Year"),
              backgroundColor: Colors.grey.shade300,
            ),
          ]),
          const SizedBox(height: 20),
          const Text(
            "Select Year for Notes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // 🟦 Year Grid
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
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: bgColors[index],
                        radius: 28,
                        child: Text(
                          year["short"]!,
                          style: TextStyle(
                              color: textColors[index],
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(year["title"]!,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(thickness: 1),
          const SizedBox(height: 10),

          // 🌟 Salient Features Section
          const Text(
            "⭐ Salient Features of MBBS Freaks Notes",
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
                _BulletPoint(text: "Colorful handwritten notes"),
                _BulletPoint(text: "Concise and Focused on Exam-Relevant Points"),
                _BulletPoint(text: "Short and Crisp"),
                _BulletPoint(text: "Well Organized"),
                _BulletPoint(text: "Covers vast number of Previous year questions"),
                _BulletPoint(text: "Concept explanation with realistic diagrams, flowcharts and cycles"),
                _BulletPoint(text: "Standard Textbook References"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =================== SUBJECT LIST ===================
  Widget _buildSubjectList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("notesSubjects")
          .where("year", isEqualTo: selectedYear)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No subjects found for this year."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final subjectDoc = docs[index];
            final data = subjectDoc.data() as Map<String, dynamic>;
            final subjectName = data['name'] ?? 'Subject';
            final imageUrl = data['imageUrl'] ?? '';

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedSubjectId = subjectDoc.id;
                  selectedSubjectName = subjectName;
                });
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) =>
                                  Container(color: Colors.grey.shade300),
                            )
                          : Container(color: Colors.grey.shade300),
                    ),
                    Container(
                      width: double.infinity,
                      color: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Text(
                        subjectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
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

  // =================== CHAPTER LIST ===================
  Widget _buildChapterList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("notesChapters")
          .where("subjectId", isEqualTo: selectedSubjectId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        final docs = snap.data?.docs.toList() ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No chapters found for this subject."));
        }

        // ✅ Fixed sorting block to avoid crash
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final ao = (aData['order'] ?? 9999) as int;
          final bo = (bData['order'] ?? 9999) as int;
          return ao.compareTo(bo);
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chapterDoc = docs[index];
            final data = chapterDoc.data() as Map<String, dynamic>;
            final chapterName = data['name'] ?? 'Chapter';
            final isPremium = data['isPremium'] == true;
            final locked = isPremium && !hasCurrentYearAccess;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text(chapterName),
                subtitle: Text(
                  locked ? "Premium Content" : "Tap to view",
                  style: TextStyle(
                    color: locked ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  locked ? Icons.lock : Icons.arrow_forward_ios,
                  color: locked ? Colors.red : Colors.black54,
                  size: locked ? 22 : 16,
                ),
                onTap: locked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "🔒 This chapter is for Premium users of this year.")),
                        );
                      }
                    : () {
                        setState(() => selectedChapterId = chapterDoc.id);
                      },
              ),
            );
          },
        );
      },
    );
  }

  // =================== PDF LIST ===================
  Widget _buildPdfList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("notesPdfs")
          .where("chapterId", isEqualTo: selectedChapterId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text("No PDF notes found for this chapter."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final pdfDoc = docs[index];
            final data = pdfDoc.data() as Map<String, dynamic>;
            final url = (data['downloadUrl'] ?? '') as String;
            final title = (data['title'] ?? 'Untitled') as String;
            final isPremium = (data['isPremium'] ?? false) as bool;
            final locked = isPremium && !hasCurrentYearAccess;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: Icon(
                  locked ? Icons.lock : Icons.picture_as_pdf,
                  color: locked ? Colors.grey : Colors.red,
                ),
                title: Text(title),
                subtitle: Text(
                  locked ? "Premium Content" : "Tap to view",
                  style: TextStyle(
                    color: locked ? Colors.red : Colors.black54,
                    fontWeight: locked ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onTap: locked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "🔒 This PDF is for Premium users of this year.")),
                        );
                      }
                    : () {
                        if (url.isNotEmpty) {
                          _openPdf(context, url, title);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("No download URL provided")),
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

  void _openPdf(BuildContext context, String rawUrl, String title) {
    final directUrl = normalizeDriveUrl(rawUrl);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PdfViewerPage(url: directUrl, title: title)),
    );
  }
}

// =================== PDF VIEWER ===================
class PdfViewerPage extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerPage({super.key, required this.url, required this.title});

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
    final safeFileName = 'pdf_cache_${widget.url.hashCode}.pdf';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _pdfController == null
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
