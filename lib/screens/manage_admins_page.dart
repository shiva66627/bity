import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAdminsPage extends StatefulWidget {
  const ManageAdminsPage({super.key});

  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  final int _limit = 10;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<DocumentSnapshot> _adminDocs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchMoreAdmins();
    }
  }

  // ============ FETCH ADMINS ============
  Future<void> _fetchAdmins() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "admin")
        .limit(_limit)
        .get();

    final docs = snapshot.docs;

    docs.sort((a, b) {
      final aTime = a.data().containsKey('createdAt')
          ? a['createdAt']?.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.data().containsKey('createdAt')
          ? b['createdAt']?.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    setState(() {
      _adminDocs = docs;
      if (_adminDocs.isNotEmpty) _lastDocument = _adminDocs.last;
      _hasMore = snapshot.docs.length == _limit;
    });
  }

  // ============ LOAD MORE ============
  Future<void> _fetchMoreAdmins() async {
    if (_lastDocument == null) return;
    setState(() => _isLoadingMore = true);

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "admin")
        .startAfterDocument(_lastDocument!)
        .limit(_limit)
        .get();

    final docs = snapshot.docs;

    docs.sort((a, b) {
      final aTime = a.data().containsKey('createdAt')
          ? a['createdAt']?.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.data().containsKey('createdAt')
          ? b['createdAt']?.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    setState(() {
      _adminDocs.addAll(docs);
      if (docs.isNotEmpty) _lastDocument = docs.last;
      _hasMore = snapshot.docs.length == _limit;
      _isLoadingMore = false;
    });
  }

  // ============ DOWNGRADE / DELETE ============
  Future<void> _handleAction(
      DocumentSnapshot admin, String action, String email) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (currentUserId == admin.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("❌ You cannot edit yourself!")));
      return;
    }

    if (action == "downgrade") {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(admin.id)
          .update({"role": "student"});

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("⬇️ $email downgraded to Student")));
    } else if (action == "delete") {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(admin.id)
          .delete();

      setState(() {
        _adminDocs.remove(admin);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("🗑️ Deleted $email")));
    }
  }

  // ============ ADD ADMIN POPUP ============
  Future<void> _showAddAdminDialog() async {
    final emailController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add Admin"),
              content: TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "User Email",
                  hintText: "Enter email to promote",
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Add"),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Enter email")),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          final snap = await FirebaseFirestore.instance
                              .collection("users")
                              .where("email", isEqualTo: email)
                              .limit(1)
                              .get();

                          if (snap.docs.isEmpty) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("❌ No user found with this email")),
                            );
                            return;
                          }

                          final userDoc = snap.docs.first;

                          await FirebaseFirestore.instance
                              .collection("users")
                              .doc(userDoc.id)
                              .update({
                            "role": "admin",
                            "createdAt": FieldValue.serverTimestamp(),
                          });

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    "✅ ${emailController.text.trim()} promoted to Admin")),
                          );

                          _fetchAdmins();
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============ UI ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Admins"),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),

      // ⭐ Floating Button to Add Admin
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red[600],
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: _showAddAdminDialog,
      ),

      body: _adminDocs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAdmins,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _adminDocs.length + 1,
                itemBuilder: (context, index) {
                  if (index == _adminDocs.length) {
                    return _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }

                  final admin = _adminDocs[index];
                  final email = admin["email"];
                  final data = admin.data() as Map<String, dynamic>;
                  final createdAt = data.containsKey('createdAt')
                      ? data['createdAt']?.toDate()
                      : null;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading:
                          const Icon(Icons.admin_panel_settings, color: Colors.blue),
                      title: Text(email),
                      subtitle: Text(
                        "Created: ${createdAt != null ? createdAt.toString() : 'N/A'}",
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleAction(admin, value, email),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: "downgrade",
                            child: Text("Downgrade to Student"),
                          ),
                          PopupMenuItem(
                            value: "delete",
                            child: Text("Delete Admin"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
