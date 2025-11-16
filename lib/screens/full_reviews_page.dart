import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FullReviewsPage extends StatefulWidget {
  const FullReviewsPage({super.key});

  @override
  State<FullReviewsPage> createState() => _FullReviewsPageState();
}

class _FullReviewsPageState extends State<FullReviewsPage> {
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadIsAdmin();
  }

  Future<void> _loadIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        isAdmin = (doc.data()?['role'] == 'admin');
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reviews'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('testimonials')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No reviews yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final ownerUid = (data['uid'] ?? '').toString();
              final canDelete = (currentUid != null && ownerUid == currentUid) || isAdmin;

              return _ReviewCardVertical(
                data: data,
                docId: id,
                canDelete: canDelete,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewCardVertical extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool canDelete;

  const _ReviewCardVertical({
    required this.data,
    required this.docId,
    required this.canDelete,
  });

  @override
  State<_ReviewCardVertical> createState() => _ReviewCardVerticalState();
}

class _ReviewCardVerticalState extends State<_ReviewCardVertical> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['name'] ?? 'Student').toString().trim().isEmpty
        ? 'Student'
        : (widget.data['name'] ?? 'Student').toString();
    final review = (widget.data['review'] ?? '').toString();
    final rating = (widget.data['rating'] ?? 0) as int;
    final program = (widget.data['program'] ?? '').toString();
    final bottom = (widget.data['bottom'] ?? '').toString();

    final ts = widget.data['createdAt'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    final formatted = "${date.day} ${_month(date.month)} ${date.year}";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Delete (if allowed)
          Row(
            children: [
              const CircleAvatar(radius: 20, child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (widget.canDelete)
                IconButton(
                  tooltip: 'Delete review',
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _confirmDelete,
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Stars
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star,
                size: 18,
                color: i < rating ? Colors.amber : Colors.grey.shade300,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Review text
          Text(
            review,
            style: const TextStyle(fontSize: 14),
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Read more / less
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? "Read less" : "Read more",
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Optional lines (program, bottom)
          if (program.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(program, style: const TextStyle(color: Colors.black54)),
          ],
          if (bottom.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(bottom, style: const TextStyle(color: Colors.black54)),
          ],

          const SizedBox(height: 10),
          Text(formatted, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete review?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('testimonials')
                  .doc(widget.docId)
                  .delete();
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Review deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _month(int m) {
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return months[m - 1];
  }
}
