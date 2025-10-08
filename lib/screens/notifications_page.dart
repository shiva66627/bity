import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mbbsfreaks/view_mode.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _auth = FirebaseAuth.instance;
  bool _isAdmin = false;
  bool _loading = true;

  // ✅ Removed _checkAdminStatus() from initState
  @override
  void initState() {
    super.initState();
  }

  // ✅ Use didChangeDependencies so it refreshes each time the page is shown
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final isActuallyAdmin =
        userDoc.exists && userDoc.data()?['role'] == 'admin';

    setState(() {
      // 🚀 If admin but switched to user mode => treat as user
      _isAdmin = isActuallyAdmin && !ViewMode.isUserMode;
      _loading = false;
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    return DateFormat('hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? "Manage Notifications" : "Notifications"),
        backgroundColor: _isAdmin ? Colors.red : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications found 📭"));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final message = data['message'] ?? '';
              final imageUrl = data['imageUrl'];
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.notifications,
                          color: _isAdmin ? Colors.red : Colors.blue),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: _isAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editNotification(doc.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteNotification(doc.id),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      backgroundColor: const Color(0xFFF5F5F5),
    );
  }

  void _editNotification(String docId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title']);
    final messageController = TextEditingController(text: data['message']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Notification"),
        content: Column(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(docId)
                  .update({
                'title': titleController.text.trim(),
                'message': messageController.text.trim(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Notification updated")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteNotification(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Notification"),
        content:
            const Text("Are you sure you want to delete this notification?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🗑️ Notification deleted")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
