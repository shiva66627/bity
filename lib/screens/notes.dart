// notes.dart
// MBBS Freaks – Notes Page
// Handles: Year → Subject → Chapter → PDF
// Includes premium unlock logic (6m / 1y expiry)

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'subscription_selection_screen.dart';
import 'payment_screen.dart';

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
  Map<String, List<String>> premiumSubjects = {};
  Map<String, DateTime> premiumExpiries = {};
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadUserPremium();
  }

  /// 🔹 Load premium access from Firestore (and remove expired)
  Future<void> _loadUserPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userDoc.exists || userDoc.data() == null) {
      setState(() {
        premiumYears = [];
        premiumSubjects = {};
        premiumExpiries = {};
      });
      return;
    }

    final data = userDoc.data()!;
    final now = DateTime.now();

    final expiryRaw =
        Map<String, dynamic>.from(data['premiumExpiries'] ?? {});
    final Map<String, DateTime> expiryParsed = {};
    expiryRaw.forEach((k, v) {
      try {
        expiryParsed[k] = DateTime.parse(v.toString());
      } catch (_) {}
    });

    final List<String> allYears = List<String>.from(data['premiumYears'] ?? []);
    final Map<String, dynamic> subMap =
        Map<String, dynamic>.from(data['premiumSubjects'] ?? {});

    final activeYears = <String>[];
    final activeSubs = <String, List<String>>{};

    for (final y in allYears) {
      final exp = expiryParsed[y];
      if (exp == null || exp.isAfter(now)) activeYears.add(y);
    }
    subMap.forEach((y, list) {
      final exp = expiryParsed[y];
      if (exp == null || exp.isAfter(now)) {
        activeSubs[y] = List<String>.from(list ?? []);
      }
    });

    setState(() {
      premiumYears = activeYears;
      premiumSubjects = activeSubs;
      premiumExpiries = expiryParsed;
    });
  }

  /// 🔒 Checks if user has access to current selection
 bool get hasAccess {
  if (selectedYear == null || selectedSubjectName == null) return false;

  // STEP 1: Check expiry for THIS YEAR
  final expiry = premiumExpiries[selectedYear];
  if (expiry != null && expiry.isBefore(DateTime.now())) {
    return false; // expired
  }

  final unlockedSubjects = premiumSubjects[selectedYear] ?? [];

final selected = selectedSubjectName!.trim().toLowerCase();

// ⭐ Bulk offer unlocks ALL subjects
if (unlockedSubjects.any((s) => s.trim().toLowerCase() == "all")) {
  return true;
}
if (unlockedSubjects.any((s) => s.trim().toLowerCase() == "all subjects")) {
  return true;
}

// ⭐ Normal subject-level unlock
return unlockedSubjects
    .map((s) => s.trim().toLowerCase())
    .contains(selected);

}


  Future<void> _onRefresh() async {
    setState(() => refreshing = true);
    await _loadUserPremium();
    setState(() => refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Premium access refreshed"),
        duration: Duration(seconds: 2)));
  }

  /// ✅ Modified for instant unlock + animation feedback
  Future<void> _openSubscription() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SubscriptionSelectionScreen(selectedYear: selectedYear ?? ''),
      ),
    );

    if (result == true) {
      await _loadUserPremium();
      setState(() {});

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: AnimatedScale(
            scale: 1.1,
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_open_rounded,
                      color: Colors.green, size: 70),
                  SizedBox(height: 10),
                  Text(
                    "Premium Unlocked!",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Enjoy your new access 🔓",
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Premium unlocked instantly!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedChapterId != null) {
          setState(() => selectedChapterId = null);
          return false;
        }
        if (selectedSubjectId != null) {
          setState(() {
            selectedSubjectId = null;
            selectedSubjectName = null;
          });
          return false;
        }
        if (selectedYear != null) {
          setState(() => selectedYear = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            selectedSubjectName != null
                ? (selectedChapterId != null
                    ? selectedSubjectName!
                    : "${selectedSubjectName!} Notes")
                : "Notes",
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
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

  Widget _buildContent() {
    if (selectedYear == null) return _buildYearList();
    if (selectedSubjectId == null) return _buildSubjectList();
    if (selectedChapterId == null) return _buildChapterList();
    return _buildPdfList();
  }

  // ----------------------------------------------
  // YEAR LIST
  // ----------------------------------------------
  Widget _buildYearList() {
    final years = [
      {"title": "1st Year", "short": "1st"},
      {"title": "2nd Year", "short": "2nd"},
      {"title": "3rd Year", "short": "3rd"},
      {"title": "4th Year", "short": "4th"},
    ];
    final bgColors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50
    ];
    final textColors = [
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Year for Notes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: years.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1),
            itemBuilder: (context, i) {
              final y = years[i];
              return GestureDetector(
                onTap: () => setState(() => selectedYear = y['title']),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: bgColors[i],
                        radius: 28,
                        child: Text(y['short']!,
                            style: TextStyle(
                                color: textColors[i],
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                      const SizedBox(height: 8),
                      Text(y['title']!,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          _FeatureBox(),
        ],
      ),
    );
  }

  // ----------------------------------------------
  // SUBJECT LIST
  // ----------------------------------------------
 // --------------------------- SUBJECT LIST (GRID STYLE WITH IMAGE + BLUE BAR) ---------------------------
// --------------------------- SUBJECT LIST (MATCH PYQS STYLE) ---------------------------
Widget _buildSubjectList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection("notesSubjects")
        .where("year", isEqualTo: selectedYear)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No subjects found"));

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,        // full width card like your screenshot  
          childAspectRatio: 1.5,    // identical card height  
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                children: [
                  // Background Image
                  Positioned.fill(
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.blue[50],
                            child: Center(
                              child: Text(
                                subjectName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Bottom Title Bar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: Colors.blueAccent.withOpacity(0.75),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        subjectName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
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



  // ----------------------------------------------
  // CHAPTER LIST
  // ----------------------------------------------
  Widget _buildChapterList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notesChapters')
          .where('subjectId', isEqualTo: selectedSubjectId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(child: Text("Error: ${snap.error}"));

        final docs = snap.data?.docs.toList() ?? [];
        if (docs.isEmpty)
          return const Center(child: Text("No chapters found."));

        docs.sort((a, b) {
          final aOrder = (a['order'] ?? 9999) as int;
          final bOrder = (b['order'] ?? 9999) as int;
          return aOrder.compareTo(bOrder);
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final chapter = data['name'] ?? 'Chapter';
            final isPremium = data['isPremium'] == true;
            final locked = isPremium && !hasAccess;

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text(chapter),
                subtitle: Text(
                  locked ? "Premium Content" : "Tap to View",
                  style: TextStyle(
                      color: locked ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500),
                ),
                trailing: Icon(
                  locked ? Icons.lock : Icons.arrow_forward_ios,
                  color: locked ? Colors.red : Colors.black54,
                  size: 20,
                ),
                onTap: () async {
                  if (locked) {
                    await _openSubscription();
                  } else {
                    setState(() => selectedChapterId = doc.id);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------
  // PDF LIST
  // ----------------------------------------------
  Widget _buildPdfList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notesPdfs')
          .where('chapterId', isEqualTo: selectedChapterId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(child: Text("Error: ${snap.error}"));

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return const Center(child: Text("No PDFs found."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final pdfDoc = docs[i];
            final data = pdfDoc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled';
            final url = data['downloadUrl'] ?? '';
            final isPremium = (data['isPremium'] ?? false) as bool;
            final locked = isPremium && !hasAccess;

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: Icon(
                    locked
                        ? Icons.lock_outline
                        : Icons.picture_as_pdf_rounded,
                    color: locked ? Colors.grey : Colors.red),
                title: Text(title),
                subtitle: Text(
                  locked ? "Premium Content" : "Tap to View",
                  style: TextStyle(
                      color: locked ? Colors.red : Colors.black54),
                ),
                onTap: locked
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("🔒 Premium users only. Subscribe!")))
                    : () => _openPdf(context, url, title),
              ),
            );
          },
        );
      },
    );
  }

  void _openPdf(BuildContext context, String raw, String title) {
    final direct = normalizeDriveUrl(raw);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PdfViewerPage(url: direct, title: title)),
    );
  }
}

// ------------------------------------------------------
// PDF VIEWER PAGE – **Offline support added here**
// ------------------------------------------------------
class PdfViewerPage extends StatefulWidget {
  final String url;
  final String title;
  const PdfViewerPage({super.key, required this.url, required this.title});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? controller;
  int currentPage = 1;
  int totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  // 🔥🔥 OFFLINE PDF SUPPORT
  Future<void> _loadPdf() async {
    try {
      PdfDocument doc;

      if (kIsWeb) {
        final res = await http.get(Uri.parse(widget.url));
        if (res.statusCode != 200) throw Exception("Failed to load PDF");
        doc = await PdfDocument.openData(res.bodyBytes);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/pdf_${widget.url.hashCode}.pdf");

        // 1️⃣ Try local file first (offline)
        if (await file.exists() && await file.length() > 0) {
          doc = await PdfDocument.openFile(file.path);
        } else {
          // 2️⃣ Download once if not downloaded
          final res = await http.get(Uri.parse(widget.url));
          if (res.statusCode != 200) throw Exception("Download error");

          await file.writeAsBytes(res.bodyBytes, flush: true);

          doc = await PdfDocument.openFile(file.path);
        }
      }

      setState(() {
        controller = PdfControllerPinch(document: Future.value(doc));
        totalPages = doc.pagesCount;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load PDF: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
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
      body: controller == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue))
          : Stack(
              children: [
                PdfViewPinch(
                  controller: controller!,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (p) => setState(() => currentPage = p),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$currentPage / $totalPages",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
    );
  }
}

// ----------------------------------------------
// FEATURES BOX
// ----------------------------------------------
class _FeatureBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("⭐ Salient Features of MBBS Freaks Notes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Divider(),
          SizedBox(height: 6),
          _BulletPoint(text: "Colorful handwritten notes"),
          _BulletPoint(text: "Concise and focused on exam-relevant points"),
          _BulletPoint(text: "Well organized and short"),
          _BulletPoint(text: "PYQs and conceptual flowcharts"),
          _BulletPoint(text: "Covers all important diagrams & cycles"),
        ],
      ),
    );
  }
}

// ----------------------------------------------
// BULLET POINT WIDGET
// ----------------------------------------------
class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("• ",
            style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, color: Colors.black87)),
        ),
      ]),
    );
  }
}
