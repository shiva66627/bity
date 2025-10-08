import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mbbsfreaks/screens/notes.dart'; // ✅ reuse PdfViewerPage
import 'package:mbbsfreaks/screens/notes.dart' show normalizeDriveUrl;

class ScheduleListPage extends StatelessWidget {
  const ScheduleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Plans'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No schedule plans available.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled';
              final fileUrl = data['fileUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text("Tap to view"),
                  onTap: () {
                    if (fileUrl.isNotEmpty) {
                      final directUrl = normalizeDriveUrl(fileUrl);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PdfViewerPage(url: directUrl, title: title),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PDF URL not found')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
