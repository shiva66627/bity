import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class AddSchedulePage extends StatefulWidget {
  const AddSchedulePage({super.key});

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  final TextEditingController _titleController = TextEditingController();
  File? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadSchedule() async {
    final title = _titleController.text.trim();

    if (title.isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and select PDF')),
      );
      return;
    }

    try {
      setState(() => _isUploading = true);

      // Upload PDF to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('schedules/${DateTime.now().millisecondsSinceEpoch}.pdf');

      await storageRef.putFile(_selectedFile!);
      final downloadUrl = await storageRef.getDownloadURL();

      // Save metadata to Firestore
      await FirebaseFirestore.instance.collection('schedules').add({
        'title': title,
        'fileUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _titleController.clear();
        setState(() {
          _selectedFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule uploaded successfully ✅')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteSchedule(String docId, String fileUrl) async {
    try {
      // Delete Firestore document
      await FirebaseFirestore.instance.collection('schedules').doc(docId).delete();

      // Delete file from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(fileUrl);
      await ref.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted successfully 🗑️')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Schedule Plans'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== UPLOAD SECTION =====
            const Text(
              'Upload New Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Schedule Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Select PDF'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedFile != null
                        ? _selectedFile!.path.split('/').last
                        : 'No file selected',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    onPressed: _uploadSchedule,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload Schedule'),
                  ),
            const SizedBox(height: 25),

            // ===== MANAGE SECTION =====
            const Divider(),
            const Text(
              'Existing Schedules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schedules')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Text('No schedules uploaded yet.');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled';
                    final url = data['fileUrl'];
                    final createdAt = data['createdAt'];
                    final docId = docs[index].id;

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(title),
                        subtitle: Text('Uploaded: ${_formatDate(createdAt)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSchedule(docId, url),
                        ),
                        onTap: () async {
                          final pdfUrl = Uri.parse(url);
                          if (await canLaunchUrl(pdfUrl)) {
                            await launchUrl(pdfUrl, mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open PDF')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
