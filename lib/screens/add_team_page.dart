import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTeamPage extends StatefulWidget {
  const AddTeamPage({super.key});

  @override
  State<AddTeamPage> createState() => _AddTeamMemberPageState();
}

class _AddTeamMemberPageState extends State<AddTeamPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController roleController = TextEditingController();

  bool isSaving = false;

  // SAVE TEAM MEMBER
  Future<void> _saveTeamMember() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final role = roleController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isSaving = true);

    // Get new order index
    final snap = await FirebaseFirestore.instance
        .collection('team')
        .orderBy('order')
        .get();

    int newOrder = snap.docs.isEmpty
        ? 0
        : ((snap.docs.last.data()['order'] ?? 0) + 1);

    await FirebaseFirestore.instance.collection('team').add({
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'order': newOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });

    nameController.clear();
    emailController.clear();
    phoneController.clear();
    roleController.clear();

    setState(() => isSaving = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("✅ Team member added")));
  }

  // EDIT MEMBER
  Future<void> _editTeamMember(String id, Map<String, dynamic> data) async {
    nameController.text = data['name'] ?? '';
    emailController.text = data['email'] ?? '';
    phoneController.text = data['phone'] ?? '';
    roleController.text = data['role'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Member"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
            TextField(controller: roleController, decoration: const InputDecoration(labelText: "Role")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('team').doc(id).update({
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
                'phone': phoneController.text.trim(),
                'role': roleController.text.trim(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Updated successfully")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // DELETE MEMBER
  Future<void> _deleteTeamMember(String id) async {
    await FirebaseFirestore.instance.collection('team').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑️ Member deleted")),
    );
  }

  // SAVE REORDER RESULT TO FIRESTORE
  Future<void> _updateOrder(List<QueryDocumentSnapshot> docs) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < docs.length; i++) {
      batch.update(docs[i].reference, {"order": i});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Team Member"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // INPUT FIELDS
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email),
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
                labelText: "Phone Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: roleController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge),
                labelText: "Role (Ex: App Owner / Creator)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: isSaving ? null : _saveTeamMember,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Team Member", style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 25),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Previous Team Members",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            // ⬇️ REORDERABLE LIST
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('team')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No team members added yet."),
                  );
                }

                return ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;

                    final item = docs.removeAt(oldIndex);
                    docs.insert(newIndex, item);

                    await _updateOrder(docs);
                  },
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;

                    return Container(
                      key: ValueKey(id),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),

                          // DETAILS
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  (data['role'] ?? '').replaceAll("\n", " "),
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(data['email'] ?? ''),
                                Text(data['phone'] ?? ''),
                              ],
                            ),
                          ),

                          // EDIT + DELETE
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.green),
                                onPressed: () => _editTeamMember(id, data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTeamMember(id),
                              ),
                            ],
                          ),

                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
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
