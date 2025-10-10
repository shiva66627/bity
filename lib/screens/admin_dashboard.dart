import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mbbsfreaks/view_mode.dart';
import 'package:mbbsfreaks/screens/add_schedule_page.dart';
import 'package:mbbsfreaks/screens/admin_premium_users_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'admin_hierarchical_content_manager.dart' as hierarchical;
import 'manage_admins_page.dart';
import 'admin_quiz_uploader.dart';
import '../services/storage_service.dart';

class AdminDashboard extends StatefulWidget {
  /// When provided, toggling dark mode here will also update the app-wide theme.
  final void Function(bool)? onThemeChanged;

  const AdminDashboard({super.key, this.onThemeChanged});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String adminName = '';
  String adminEmail = '';
  String? adminPhotoUrl;
  bool isLoading = true;

  /// Local-only theme flag; also informs app via [onThemeChanged]
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc['role'].toString().trim() == "admin") {
          setState(() {
            adminName = (doc.data()?['fullName'] as String?)?.trim().isNotEmpty == true
                ? doc['fullName']
                : 'Admin';
            adminEmail = (doc.data()?['email'] as String?) ?? user.email ?? '';
            adminPhotoUrl = (doc.data()?['photoUrl'] as String?) ?? '';
            isDarkMode = (doc.data()?['isDarkMode'] as bool?) ?? false;
            isLoading = false;
          });

          widget.onThemeChanged?.call(isDarkMode);
        } else {
          await _auth.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  
  // 🛠️ Fix createdAt for admins (in case missing)
  Future<void> _fixAdminCreatedAt() async {
    final adminsSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (final doc in adminsSnapshot.docs) {
      if (!doc.data().containsKey('createdAt')) {
        await _firestore.collection('users').doc(doc.id).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Fixed missing createdAt for Admin accounts'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeData = isDarkMode
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return Theme(
      data: themeData,
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              "MBBS FREAKS",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            centerTitle: true,
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          drawer: _buildDrawer(),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildDashboardContent(),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.red[600]),
            accountName: Text(adminName),
            accountEmail: Text(adminEmail),
            currentAccountPicture: GestureDetector(
              onTap: _showProfileLinkDialog,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: adminPhotoUrl != null && adminPhotoUrl!.isNotEmpty
                    ? NetworkImage(adminPhotoUrl!)
                    : null,
                child: (adminPhotoUrl == null || adminPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.red)
                    : null,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text("Promote Admin"),
            onTap: () {
              Navigator.pop(context);
              _showPromoteDialog();
            },
          ),

          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text("Manage Admins"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAdminsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.build, color: Colors.deepPurple),
            title: const Text("Fix Admin CreatedAt"),
            onTap: () {
              Navigator.pop(context);
              _fixAdminCreatedAt();
            },
          ),


          ListTile(
            leading: const Icon(Icons.bolt, color: Colors.purple),
            title: const Text("Add Daily Question"),
            onTap: () {
              Navigator.pop(context);
              _showDailyQuestionDialog();
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Delete Daily Question"),
            onTap: () {
              Navigator.pop(context);
              _showDeleteDailyQuestionDialog();
            },
          ),

          ListTile(
            leading: const Icon(Icons.send, color: Colors.teal),
            title: const Text("Send Notification"),
            onTap: () {
              Navigator.pop(context);
              _showNotificationDialog();
            },
          ),

          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
            title: const Text("Manage Notifications"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.indigo),
            title: const Text("Add Schedule Plan"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSchedulePage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.indigo),
            title: const Text("Add Premium Users"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPremiumUsersPage()),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.switch_account, color: Colors.blue),
            title: Text(ViewMode.isUserMode ? "Switch to Admin" : "Switch to User"),
            onTap: () {
              setState(() {
                ViewMode.isUserMode = !ViewMode.isUserMode;
              });
              Navigator.pop(context);

              if (ViewMode.isUserMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ You are now viewing as USER")),
                );
                Navigator.pushReplacementNamed(context, '/home');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🛠️ Switched back to ADMIN")),
                );
                Navigator.pushReplacementNamed(context, '/admin_dashboard');
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),

        ],
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection("users").doc(user.uid).update({
        "isDarkMode": isDarkMode,
      });
    }

    widget.onThemeChanged?.call(isDarkMode);
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, $adminName!",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(adminEmail, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),

          const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildActionCard("Upload Notes", Icons.upload_file, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard("Upload PYQs", Icons.upload_file, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildActionCard("Upload Question Bank", Icons.upload_file, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard("Upload Quiz", Icons.quiz, Colors.purple)),
            ],
          ),

          const SizedBox(height: 24),
          const Text("Manage Content", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildManageCard("Manage Notes", Icons.book, Colors.blue, "notes")),
              const SizedBox(width: 12),
              Expanded(child: _buildManageCard("Manage PYQs", Icons.description, Colors.green, "pyqs")),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildManageCard("Manage Question Bank", Icons.library_books, Colors.orange, "question_banks")),
              const SizedBox(width: 12),
              Expanded(child: _buildManageCard("Manage Quiz", Icons.quiz, Colors.purple, "quiz")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (title == "Upload Notes") {
            _showUploadDialog("notes");
          } else if (title == "Upload PYQs") {
            _showUploadDialog("pyqs");
          } else if (title == "Upload Question Bank") {
            _showUploadDialog("question_banks");
          } else if (title == "Upload Quiz") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminQuizUploader()));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageCard(String title, IconData icon, Color color, String category) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => hierarchical.AdminHierarchicalContentManager(category: category),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================= UPLOAD DIALOG =========================
  void _showUploadDialog(String category) {
    final subjectController = TextEditingController();
    final chapterController = TextEditingController();
    final titleController = TextEditingController();

    String selectedYear = "1st Year";
    String? subjectImageUrl;
    String? pdfUrl;
    bool isPremium = false; // ✅ NEW

    final collectionMap = {
      "notes": {"subjects": "notesSubjects", "chapters": "notesChapters", "pdfs": "notesPdfs"},
      "pyqs": {"subjects": "pyqsSubjects", "chapters": "pyqsChapters", "pdfs": "pyqsPdfs"},
      "question_banks": {"subjects": "qbSubjects", "chapters": "qbChapters", "pdfs": "qbPdfs"},
      "quiz": {"subjects": "quizSubjects", "chapters": "quizChapters", "pdfs": "quizPdfs"},
    };

    final collections = collectionMap[category]!;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Upload ${category.toUpperCase()}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: "Select Year"),
                    items: const [
                      DropdownMenuItem(value: "1st Year", child: Text("1st Year")),
                      DropdownMenuItem(value: "2nd Year", child: Text("2nd Year")),
                      DropdownMenuItem(value: "3rd Year", child: Text("3rd Year")),
                      DropdownMenuItem(value: "4th Year", child: Text("4th Year")),
                    ],
                    onChanged: (val) => setState(() => selectedYear = val!),
                  ),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: "Subject Name"),
                  ),
                  const SizedBox(height: 8),

                  if (subjectImageUrl == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Upload Subject Image"),
                      onPressed: () async {
                        final url = await StorageService().uploadFile("subject_images");
                        if (url != null) {
                          setState(() => subjectImageUrl = url);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("📎 Subject image added")),
                          );
                        }
                      },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.network(subjectImageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                      title: const Text("Subject image added"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => subjectImageUrl = null),
                      ),
                    ),

                  TextField(
                    controller: chapterController,
                    decoration: const InputDecoration(labelText: "Chapter Name"),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "PDF Title"),
                  ),
                  const SizedBox(height: 8),

                  if (pdfUrl == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Upload PDF"),
                      onPressed: () async {
                        final url = await StorageService().uploadFile("pdfs");
                        if (url != null) {
                          setState(() => pdfUrl = url);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("📎 PDF added")),
                          );
                        }
                      },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: const Text("PDF added"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => pdfUrl = null),
                      ),
                    ),

                  // ✅ NEW: Premium toggle
                  SwitchListTile(
                    title: const Text("Mark as Premium"),
                    subtitle: const Text("Premium PDFs will be locked for free users"),
                    value: isPremium,
                    onChanged: (val) {
                      setState(() => isPremium = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (subjectController.text.isEmpty ||
                      chapterController.text.isEmpty ||
                      titleController.text.isEmpty ||
                      pdfUrl == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("⚠️ Please fill all fields")),
                    );
                    return;
                  }

                  try {
                    final subjectName = subjectController.text.trim();

                    // ✅ Check if subject already exists
                    final existingQuery = await FirebaseFirestore.instance
                        .collection(collections["subjects"]!)
                        .where("name", isEqualTo: subjectName)
                        .where("year", isEqualTo: selectedYear)
                        .limit(1)
                        .get();

                    String subjectId;
                    String finalImageUrl = subjectImageUrl ?? '';

                    if (existingQuery.docs.isNotEmpty) {
                      subjectId = existingQuery.docs.first.id;
                      finalImageUrl = existingQuery.docs.first.data()['imageUrl'];
                    } else {
                      final newSubjectDoc = await FirebaseFirestore.instance
                          .collection(collections["subjects"]!)
                          .add({
                        "name": subjectName,
                        "imageUrl": subjectImageUrl,
                        "year": selectedYear,
                        "createdAt": FieldValue.serverTimestamp(),
                      });
                      subjectId = newSubjectDoc.id;
                    }

                    // ➕ Add chapter
                    final chapterDoc = await FirebaseFirestore.instance
                        .collection(collections["chapters"]!)
                        .add({
                      "name": chapterController.text.trim(),
                      "subjectId": subjectId,
                      "createdAt": FieldValue.serverTimestamp(),
                    });

                    // ➕ Add PDF with Premium flag ✅
                    await FirebaseFirestore.instance
                        .collection(collections["pdfs"]!)
                        .add({
                      "title": titleController.text.trim(),
                      "downloadUrl": pdfUrl,
                      "chapterId": chapterDoc.id,
                      "isPremium": isPremium, // ✅ ADDED
                      "uploadedAt": FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Content uploaded successfully"), backgroundColor: Colors.green),
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
          );
        },
      ),
    );
  }


  // ========================= Daily Question: Add =========================

  void _showDailyQuestionDialog() {
    final questionController = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    final explanationController = TextEditingController();
    final messageController = TextEditingController();
    String correctOption = "A";
    String? imageUrl;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text("Add Daily Question"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(labelText: "Question"),
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < 4; i++)
                    TextField(
                      controller: optionControllers[i],
                      decoration: InputDecoration(labelText: "Option ${i + 1}"),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: correctOption,
                    decoration: const InputDecoration(labelText: "Correct Answer"),
                    items: const [
                      DropdownMenuItem(value: "A", child: Text("Option A")),
                      DropdownMenuItem(value: "B", child: Text("Option B")),
                      DropdownMenuItem(value: "C", child: Text("Option C")),
                      DropdownMenuItem(value: "D", child: Text("Option D")),
                    ],
                    onChanged: (val) => correctOption = val ?? "A",
                  ),
                  const SizedBox(height: 10),

                  // Optional image
                  if (imageUrl == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Attach Image (Optional)"),
                      onPressed: () async {
                        final url = await StorageService().uploadFile("daily_questions");
                        if (url != null) {
                          setState(() => imageUrl = url);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("📎 Image attached")),
                          );
                        }
                      },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.network(imageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                      title: const Text("Image attached"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => imageUrl = null),
                      ),
                    ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: explanationController,
                    decoration: const InputDecoration(labelText: "Explanation (Optional)"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(labelText: "Message (Optional)"),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (questionController.text.trim().isEmpty ||
                      optionControllers.any((c) => c.text.trim().isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("⚠️ Fill all fields")),
                    );
                    return;
                  }

                  final options = optionControllers.map((c) => c.text.trim()).toList();
                  final answerMap = {"A": options[0], "B": options[1], "C": options[2], "D": options[3]};

                  await FirebaseFirestore.instance.collection("daily_question").add({
                    "question": questionController.text.trim(),
                    "options": options,
                    "correctAnswer": answerMap[correctOption],
                    "imageUrl": imageUrl,
                    "explanation": explanationController.text.trim().isNotEmpty
                        ? explanationController.text.trim()
                        : null,
                    "message": messageController.text.trim().isNotEmpty
                        ? messageController.text.trim()
                        : null,
                    "createdAt": FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Daily Question Added with details!"), backgroundColor: Colors.green),
                  );
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========================= Daily Question: Delete Latest =========================

  void _showDeleteDailyQuestionDialog() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('daily_question')
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚡ No Daily Questions found to delete"), backgroundColor: Colors.orange),
      );
      return;
    }

    final doc = snapshot.docs.first;
    final questionText = (doc.data()['question'] as String?) ?? "No question text";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Daily Question"),
        content: Text(
          "Are you sure you want to delete this Daily Question?\n\n❓ $questionText",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text("Delete"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('daily_question')
                    .doc(doc.id)
                    .delete();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🗑️ Daily Question deleted successfully"), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ Error deleting question: $e"), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ========================= Profile Link Dialog (Missing implementation) =========================
  void _showProfileLinkDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Profile link action not yet implemented.")),
    );
  }

  // ========================= Promote Admin Dialog (Missing implementation) =========================
  void _showPromoteDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Promote Admin action not yet implemented.")),
    );
  }

  // 🚨 CORRECTED & COMPLETED: Notification Dialog with Cloud Functions Call 🚨
  void _showNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String? imageUrl;
    bool isSending = false; // Add state to handle loading

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text("Send Notification"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Title"),
                  ),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(labelText: "Message"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // Image Upload Button/Preview
                  if (imageUrl == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Attach Image (Optional)"),
                      onPressed: isSending
                          ? null
                          : () async {
                              final url = await StorageService().uploadFile("notification_images");
                              if (url != null) {
                                setState(() => imageUrl = url);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("📎 Image attached")),
                                );
                              }
                            },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.network(imageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                      title: const Text("Image attached"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => imageUrl = null),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final body = messageController.text.trim();

                        if (title.isEmpty || body.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("⚠️ Title and Message are required")),
                          );
                          return;
                        }

                        setState(() => isSending = true);

                        try {
                          // 🚀 FIX: Set region to 'us-central1' as confirmed by your Firebase dashboard 
                          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
                              .httpsCallable('broadcastNotification');

                          await callable.call(<String, dynamic>{
                            'title': title,
                            'body': body,
                            'imageUrl': imageUrl,
                          });

                          if (mounted) {
                            Navigator.pop(context); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("✅ Notification sent successfully!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } on FirebaseFunctionsException catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                // Show the error code and message
                                content: Text("❌ Error: [${e.code}] ${e.message ?? 'Unknown error'}"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("❌ An unexpected error occurred: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => isSending = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSending ? Colors.grey : Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Text("Send"),
              ),
            ],
          );
        },
      ),
    );
  }
}