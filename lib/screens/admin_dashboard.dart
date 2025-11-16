import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mbbsfreaks/view_mode.dart';
import 'package:mbbsfreaks/screens/add_schedule_page.dart';
import 'package:mbbsfreaks/screens/admin_premium_users_page.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'add_team_page.dart';
import 'set_premiums_page.dart';
import 'package:mbbsfreaks/screens/admin_payment_history_page.dart';
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

  /// Role: user / admin / power_admin / super_admin
  String adminRole = 'user';

  /// Local-only theme flag; also informs app via [onThemeChanged]
  bool isDarkMode = false;

  // ====== PERMISSIONS FOR CURRENT ADMIN (FROM FIRESTORE) ======
  bool canUploadContent = true;
  bool canManageContent = true;
  bool canSetPremiums = true;
  bool canViewPayments = true;
  bool canAddDailyQuestion = true;
  bool canDeleteDailyQuestion = true;
  bool canPromoteAdmin = false;
  bool canAddTeam = true;
bool canAddPremiumUsers = true; // ⭐ NEW

  bool get isSuperAdmin => adminRole == 'super_admin';
  bool get isPowerAdmin => adminRole == 'power_admin';
  bool get isAdminOnly => adminRole == 'admin';

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
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final role = (data['role'] as String?)?.trim() ?? 'user';

          // Allow only admin-type roles into this screen
          if (role != 'admin' &&
              role != 'power_admin' &&
              role != 'super_admin') {
            await _auth.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
            return;
          }

          // Default permissions based on role
          final bool defaultAllForThisRole =
              role == 'super_admin' || role == 'power_admin';

          setState(() {
            adminRole = role;
            adminName =
                (data['fullName'] as String?)?.trim().isNotEmpty == true
                    ? data['fullName']
                    : 'Admin';
            adminEmail = (data['email'] as String?) ?? user.email ?? '';
            adminPhotoUrl = (data['photoUrl'] as String?) ?? '';
            isDarkMode = (data['isDarkMode'] as bool?) ?? false;

            canUploadContent =
                (data['perm_uploadContent'] as bool?) ?? defaultAllForThisRole;
            canManageContent =
                (data['perm_manageContent'] as bool?) ?? defaultAllForThisRole;
            canSetPremiums =
                (data['perm_setPremiums'] as bool?) ?? defaultAllForThisRole;
            canViewPayments =
                (data['perm_viewPayments'] as bool?) ?? defaultAllForThisRole;
            canAddDailyQuestion = (data['perm_addDailyQuestion'] as bool?) ??
                defaultAllForThisRole;
            canDeleteDailyQuestion =
                (data['perm_deleteDailyQuestion'] as bool?) ??
                    defaultAllForThisRole;

            // By default only super_admins can promote, unless explicitly granted
            final bool defaultPromote = role == 'super_admin';
            canPromoteAdmin =
                (data['perm_promoteAdmin'] as bool?) ?? defaultPromote;

            canAddTeam =
                (data['perm_addTeam'] as bool?) ?? defaultAllForThisRole;
                canAddPremiumUsers =
    (data['perm_addPremiumUsers'] as bool?) ?? defaultAllForThisRole;


            isLoading = false;
          });

          widget.onThemeChanged?.call(isDarkMode);
        } else {
          // Not an admin user; log out
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
        .where('role', whereIn: ['admin', 'power_admin', 'super_admin'])
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

  // ======================================================================
  // DRAWER
  // ======================================================================

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.red[600]),
            accountName: Text(adminName),
            accountEmail: Text("$adminEmail  (${adminRole.toUpperCase()})"),
            currentAccountPicture: GestureDetector(
              onTap: _showProfileLinkDialog,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                    adminPhotoUrl != null && adminPhotoUrl!.isNotEmpty
                        ? NetworkImage(adminPhotoUrl!)
                        : null,
                child: (adminPhotoUrl == null || adminPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.red)
                    : null,
              ),
            ),
          ),

          // 🔐 Only admins with permission can change roles
         // 🔐 Only admins with permission can change roles
if (canPromoteAdmin)
  ListTile(
    leading: const Icon(Icons.person_add),
    title: const Text("Promote / Edit Admin Permissions"),
    onTap: () {
      Navigator.pop(context);
      _showPromoteRoleDialog();
    },
  ),

// ⭐ NEW — MANAGE ADMINS BELOW PROMOTE
if (isSuperAdmin || isPowerAdmin)
  ListTile(
    leading: const Icon(Icons.manage_accounts, color: Colors.blue),
    title: const Text("Manage Admins"),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageAdminsPage()),
      );
    },
  ),


          // Manage Admins – probably only for higher roles
       

          ListTile(
            leading: const Icon(Icons.build, color: Colors.deepPurple),
            title: const Text("Fix Admin CreatedAt"),
            onTap: () {
              Navigator.pop(context);
              _fixAdminCreatedAt();
            },
          ),

          if (canAddDailyQuestion)
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.purple),
              title: const Text("Add Daily Question"),
              onTap: () {
                Navigator.pop(context);
                _showDailyQuestionDialog();
              },
            ),

          if (canDeleteDailyQuestion)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Daily Question"),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDailyQuestionDialog();
              },
            ),

          if (canAddTeam)
            ListTile(
              leading: const Icon(Icons.group_add, color: Colors.indigo),
              title: const Text('Add Team'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTeamPage()),
                );
              },
            ),
            // ================= PREMIUM MANAGEMENT =================


// ⭐ ADD PREMIUM USERS (Manual Assign)
if (canAddPremiumUsers)
  ListTile(
    leading: const Icon(Icons.verified_user, color: Colors.green),
    title: const Text("Add Premium Users"),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPremiumUsersPage()),
      );
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
            leading: const Icon(Icons.notifications_active_outlined,
                color: Colors.blue),
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
          
          const Divider(),
          ListTile(
            leading: const Icon(Icons.switch_account, color: Colors.blue),
            title: Text(
                ViewMode.isUserMode ? "Switch to Admin" : "Switch to User"),
            onTap: () {
              setState(() {
                ViewMode.isUserMode = !ViewMode.isUserMode;
              });
              Navigator.pop(context);

              if (ViewMode.isUserMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("✅ You are now viewing as USER")),
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

  // ======================================================================
  // DASHBOARD BODY
  // ======================================================================

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
          const SizedBox(height: 4),
          Text(
            "$adminEmail (${adminRole.toUpperCase()})",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // ================= QUICK ACTIONS (UPLOAD CONTENT) =================
          if (canUploadContent) ...[
            const Text("Quick Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildActionCard(
                        "Upload Notes", Icons.upload_file, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildActionCard(
                        "Upload PYQs", Icons.upload_file, Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildActionCard("Upload Question Bank",
                        Icons.upload_file, Colors.orange)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildActionCard(
                        "Upload Quiz", Icons.quiz, Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ================= MANAGE CONTENT =================
          if (canManageContent) ...[
            const Text("Manage Content",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildManageCard(
                        "Manage Notes", Icons.book, Colors.blue, "notes")),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildManageCard("Manage PYQs",
                        Icons.description, Colors.green, "pyqs")),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildManageCard(
                        "Manage Question Bank",
                        Icons.library_books,
                        Colors.orange,
                        "question_banks")),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildManageCard(
                        "Manage Quiz", Icons.quiz, Colors.purple, "quiz")),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ================= PREMIUMS / PAYMENTS =================
          if (canSetPremiums || canViewPayments)
            Row(
              children: [
                Expanded(
                  child: canSetPremiums
                      ? _buildPremiumCard(
                          "Set Premiums",
                          Icons.workspace_premium_rounded,
                          Colors.amber,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: canViewPayments
                      ? _buildAdminPaymentHistoryCard(
                          "Payment History",
                          Icons.history,
                          Colors.teal,
                        )
                      : const SizedBox.shrink(),
                ),
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
          if (!canUploadContent) return; // safety

          if (title == "Upload Notes") {
            _showUploadDialog("notes");
          } else if (title == "Upload PYQs") {
            _showUploadDialog("pyqs");
          } else if (title == "Upload Question Bank") {
            _showUploadDialog("question_banks");
          } else if (title == "Upload Quiz") {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminQuizUploader()));
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageCard(
      String title, IconData icon, Color color, String category) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!canManageContent) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  hierarchical.AdminHierarchicalContentManager(
                      category: category),
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!canSetPremiums) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SetPremiumsPage()),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPaymentHistoryCard(
      String title, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!canViewPayments) return;
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminPaymentHistoryPage()),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================================
  // UPLOAD DIALOG (Notes / PYQs / QB / Quiz PDFs)
  // ======================================================================

  void _showUploadDialog(String category) {
    final subjectController = TextEditingController();
    final chapterController = TextEditingController();
    final titleController = TextEditingController();

    String selectedYear = "1st Year";
    String? subjectImageUrl;
    String? pdfUrl;
    bool isPremium = false; // ✅ NEW

    final collectionMap = {
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

    final collections = collectionMap[category]!;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Upload ${category.toUpperCase()}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: "Select Year"),
                    items: const [
                      DropdownMenuItem(
                          value: "1st Year", child: Text("1st Year")),
                      DropdownMenuItem(
                          value: "2nd Year", child: Text("2nd Year")),
                      DropdownMenuItem(
                          value: "3rd Year", child: Text("3rd Year")),
                      DropdownMenuItem(
                          value: "4th Year", child: Text("4th Year")),
                    ],
                    onChanged: (val) => setState(() => selectedYear = val!),
                  ),
                  TextField(
                    controller: subjectController,
                    decoration:
                        const InputDecoration(labelText: "Subject Name"),
                  ),
                  const SizedBox(height: 8),

                  if (subjectImageUrl == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Upload Subject Image"),
                      onPressed: () async {
                        final url =
                            await StorageService().uploadFile("subject_images");
                        if (url != null) {
                          setState(() => subjectImageUrl = url);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("📎 Subject image added")),
                          );
                        }
                      },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.network(subjectImageUrl!,
                          width: 40, height: 40, fit: BoxFit.cover),
                      title: const Text("Subject image added"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => subjectImageUrl = null),
                      ),
                    ),

                  TextField(
                    controller: chapterController,
                    decoration:
                        const InputDecoration(labelText: "Chapter Name"),
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
                      leading:
                          const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: const Text("PDF added"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => pdfUrl = null),
                      ),
                    ),

                  // ✅ NEW: Premium toggle
                  SwitchListTile(
                    title: const Text("Mark as Premium"),
                    subtitle: const Text(
                        "Premium PDFs will be locked for free users"),
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
                      const SnackBar(
                          content: Text("⚠️ Please fill all fields")),
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

                    if (existingQuery.docs.isNotEmpty) {
                      subjectId = existingQuery.docs.first.id;
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
                      "isPremium": isPremium,
                      "uploadedAt": FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("✅ Content uploaded successfully"),
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
          );
        },
      ),
    );
  }

  // ======================================================================
  // Daily Question: Add
  // ======================================================================

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    decoration:
                        const InputDecoration(labelText: "Correct Answer"),
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
                        final url = await StorageService()
                            .uploadFile("daily_questions");
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
                      leading: Image.network(imageUrl!,
                          width: 40, height: 40, fit: BoxFit.cover),
                      title: const Text("Image attached"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => imageUrl = null),
                      ),
                    ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: explanationController,
                    decoration: const InputDecoration(
                        labelText: "Explanation (Optional)"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: messageController,
                    decoration:
                        const InputDecoration(labelText: "Message (Optional)"),
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

                  final options =
                      optionControllers.map((c) => c.text.trim()).toList();
                  final answerMap = {
                    "A": options[0],
                    "B": options[1],
                    "C": options[2],
                    "D": options[3]
                  };

                  await FirebaseFirestore.instance
                      .collection("daily_question")
                      .add({
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
                    const SnackBar(
                        content: Text("✅ Daily Question Added with details!"),
                        backgroundColor: Colors.green),
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

  // ======================================================================
  // Daily Question: Delete Latest
  // ======================================================================

  void _showDeleteDailyQuestionDialog() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('daily_question')
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚡ No Daily Questions found to delete"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final doc = snapshot.docs.first;
    final questionText =
        (doc.data()['question'] as String?) ?? "No question text";

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
                  const SnackBar(
                      content: Text("🗑️ Daily Question deleted successfully"),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("❌ Error deleting question: $e"),
                      backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // Profile Link (placeholder)
  // ======================================================================

  void _showProfileLinkDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("⚠️ Profile link action not yet implemented.")),
    );
  }

  // ======================================================================
  // NEW: Promote Role + Permissions Dialog
  // ======================================================================

  void _showPromoteRoleDialog() {
  if (!canPromoteAdmin) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ You don't have permission.")),
    );
    return;
  }

  final emailController = TextEditingController();
  String? selectedRole;
  Map<String, dynamic>? userData;
  String? userId;
  bool loading = false;

  bool permUploadContent = false;
  bool permManageContent = false;
  bool permSetPremiums = false;
  bool permViewPayments = false;
  bool permAddDailyQuestion = false;
  bool permDeleteDailyQuestion = false;
  bool permPromoteAdmin = false;
  bool permAddTeam = false;
  bool permAddPremiumUsers = false; // ⭐ NEW PERMISSION

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> searchUser() async {
          final email = emailController.text.trim();
          if (email.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Enter an email")),
            );
            return;
          }

          setState(() => loading = true);

          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (snap.docs.isEmpty) {
            setState(() {
              userData = null;
              userId = null;
              loading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("❌ No user found")),
            );
            return;
          }

          final data = snap.docs.first.data();
          final role = (data['role'] as String?)?.trim() ?? 'user';

          // initialize permissions
          permUploadContent =
              (data['perm_uploadContent'] as bool?) ?? (role != 'user');
          permManageContent =
              (data['perm_manageContent'] as bool?) ?? (role != 'user');
          permSetPremiums =
              (data['perm_setPremiums'] as bool?) ?? (role != 'user');
          permViewPayments =
              (data['perm_viewPayments'] as bool?) ?? (role != 'user');
          permAddDailyQuestion =
              (data['perm_addDailyQuestion'] as bool?) ?? (role != 'user');
          permDeleteDailyQuestion =
              (data['perm_deleteDailyQuestion'] as bool?) ?? (role != 'user');
          permPromoteAdmin =
              (data['perm_promoteAdmin'] as bool?) ?? (role == 'super_admin');
          permAddTeam =
              (data['perm_addTeam'] as bool?) ?? (role != 'user');

          // ⭐ NEW: Add Premium Users permission
          permAddPremiumUsers =
              (data['perm_addPremiumUsers'] as bool?) ?? (role != 'user');

          setState(() {
            userData = data;
            userId = snap.docs.first.id;
            selectedRole = role;
            loading = false;
          });
        }

        Future<void> updateUser() async {
          if (userId == null || selectedRole == null) return;

          // prevent removing your own super_admin
          final currentUser = _auth.currentUser;
          if (currentUser != null &&
              currentUser.uid == userId &&
              adminRole == 'super_admin' &&
              selectedRole != 'super_admin') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("❌ You cannot remove your own SUPER_ADMIN role.")),
            );
            return;
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'role': selectedRole,
            'perm_uploadContent': permUploadContent,
            'perm_manageContent': permManageContent,
            'perm_setPremiums': permSetPremiums,
            'perm_viewPayments': permViewPayments,
            'perm_addDailyQuestion': permAddDailyQuestion,
            'perm_deleteDailyQuestion': permDeleteDailyQuestion,
            'perm_promoteAdmin': permPromoteAdmin,
            'perm_addTeam': permAddTeam,
            'perm_addPremiumUsers': permAddPremiumUsers, // ⭐ NEW
          });

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ Role & permissions updated to $selectedRole")),
          );
        }

        return AlertDialog(
          title: const Text("Change User Role & Permissions"),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Enter user email",
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: loading ? null : searchUser,
                      child: const Text("Search"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (loading) const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  if (userData != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Name: ${userData!['fullName'] ?? 'Unknown'}"),
                          Text("Current Role: ${(userData!['role'] ?? 'user')}"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: "Select New Role"),
                      value: selectedRole,
                      items: const [
                        DropdownMenuItem(value: "user", child: Text("User")),
                        DropdownMenuItem(value: "admin", child: Text("Admin")),
                        DropdownMenuItem(
                            value: "power_admin", child: Text("Power Admin")),
                        DropdownMenuItem(
                            value: "super_admin", child: Text("Super Admin")),
                      ],
                      onChanged: (value) {
                        setState(() => selectedRole = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Permissions",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),

                    // PERMISSION SWITCHES
                    SwitchListTile(
                      title: const Text("Upload Content"),
                      value: permUploadContent,
                      onChanged: (v) =>
                          setState(() => permUploadContent = v),
                    ),
                    SwitchListTile(
                      title: const Text("Manage Content"),
                      value: permManageContent,
                      onChanged: (v) =>
                          setState(() => permManageContent = v),
                    ),
                    SwitchListTile(
                      title: const Text("Set Premiums"),
                      value: permSetPremiums,
                      onChanged: (v) =>
                          setState(() => permSetPremiums = v),
                    ),
                    SwitchListTile(
                      title: const Text("View Payment History"),
                      value: permViewPayments,
                      onChanged: (v) =>
                          setState(() => permViewPayments = v),
                    ),
                    SwitchListTile(
                      title: const Text("Add Daily Question"),
                      value: permAddDailyQuestion,
                      onChanged: (v) =>
                          setState(() => permAddDailyQuestion = v),
                    ),
                    SwitchListTile(
                      title: const Text("Delete Daily Question"),
                      value: permDeleteDailyQuestion,
                      onChanged: (v) =>
                          setState(() => permDeleteDailyQuestion = v),
                    ),
                    SwitchListTile(
                      title: const Text("Promote Admin"),
                      value: permPromoteAdmin,
                      onChanged: (v) =>
                          setState(() => permPromoteAdmin = v),
                    ),
                    SwitchListTile(
                      title: const Text("Add Team"),
                      value: permAddTeam,
                      onChanged: (v) => setState(() => permAddTeam = v),
                    ),

                    // ⭐ NEW: Add Premium Users
                    SwitchListTile(
                      title: const Text("Add Premium Users"),
                      value: permAddPremiumUsers,
                      onChanged: (v) =>
                          setState(() => permAddPremiumUsers = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            if (userData != null && selectedRole != null)
              ElevatedButton(
                child: const Text("Update"),
                onPressed: updateUser,
              ),
          ],
        );
      },
    ),
  );
}


  // ======================================================================
  // Notification Dialog (unchanged logic, just kept here)
  // ======================================================================

  void _showNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String? imageUrl;
    bool isSending = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                  // Image Upload
                  if (imageUrl == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Attach Image (Optional)"),
                      onPressed: isSending
                          ? null
                          : () async {
                              final url = await StorageService()
                                  .uploadFile("notifications");
                              if (url != null) {
                                setState(() => imageUrl = url);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("📎 Image attached")),
                                );
                              }
                            },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.network(imageUrl!,
                          width: 40, height: 40, fit: BoxFit.cover),
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
                        final message = messageController.text.trim();

                        if (title.isEmpty || message.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("⚠️ Title and Message are required")),
                          );
                          return;
                        }

                        setState(() => isSending = true);

                        try {
                          await FirebaseFirestore.instance
                              .collection("notifications")
                              .add({
                            "title": title,
                            "message": message,
                            "imageUrl": imageUrl,
                            "createdAt": FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("✅ Notification sent successfully"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("❌ Error: $e"),
                                backgroundColor: Colors.red),
                          );
                        } finally {
                          if (mounted) setState(() => isSending = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white),
                child: isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
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
