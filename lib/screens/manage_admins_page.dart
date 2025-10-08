import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAdminsPage extends StatefulWidget {
  const ManageAdminsPage({super.key});

  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  final int _limit = 10; // Load 10 at a time
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
      if (_adminDocs.isNotEmpty) {
        _lastDocument = _adminDocs.last;
      }
      _hasMore = snapshot.docs.length == _limit;
    });
  }

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
      if (docs.isNotEmpty) {
        _lastDocument = docs.last;
      }
      _hasMore = snapshot.docs.length == _limit;
      _isLoadingMore = false;
    });
  }

  Future<void> _handleAction(
      DocumentSnapshot admin, String action, String email) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (currentUserId == admin.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ You cannot modify yourself!")),
      );
      return;
    }

    if (action == "downgrade") {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(admin.id)
          .update({"role": "student"});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⬇️ $email downgraded to Student")),
      );
    } else if (action == "delete") {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(admin.id)
          .delete();

      setState(() {
        _adminDocs.remove(admin);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🗑️ Deleted $email")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Admins"),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
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
                      leading: const Icon(Icons.admin_panel_settings,
                          color: Colors.blue),
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
