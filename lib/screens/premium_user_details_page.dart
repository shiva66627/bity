import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumUserDetailsPage extends StatefulWidget {
  final String userId;
  const PremiumUserDetailsPage({super.key, required this.userId});

  @override
  State<PremiumUserDetailsPage> createState() => _PremiumUserDetailsPageState();
}

class _PremiumUserDetailsPageState extends State<PremiumUserDetailsPage> {
  bool isSaving = false;

  Future<void> _revokeYear(String year) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(widget.userId);
    final snap = await ref.get();
    final List<String> list = List<String>.from(snap.data()?['premiumYears'] ?? []);
    list.remove(year);
    await ref.update({'premiumYears': list});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $year')));
    }
  }

  Future<void> _addPremiumYear(List<String> currentYears) async {
    final allYears = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    final choices = allYears.where((y) => !currentYears.contains(y)).toList();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All years already added')));
      return;
    }
    String selected = choices.first;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Premium Year'),
        content: DropdownButtonFormField<String>(
          value: selected,
          items: choices.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
          onChanged: (v) => selected = v ?? selected,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ref = FirebaseFirestore.instance.collection('users').doc(widget.userId);
              final snap = await ref.get();
              final List<String> list = List<String>.from(snap.data()?['premiumYears'] ?? []);
              if (!list.contains(selected)) {
                list.add(selected);
                await ref.update({'premiumYears': list});
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editDetails(Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: (data['fullName'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (data['phone'] ?? '').toString());
    final collegeCtrl = TextEditingController(text: (data['collegeName'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: collegeCtrl, decoration: const InputDecoration(labelText: 'College Name')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              setState(() => isSaving = true);
              await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                'fullName': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'collegeName': collegeCtrl.text.trim(),
              });
              if (mounted) Navigator.pop(context);
              setState(() => isSaving = false);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(widget.userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: ref.snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final data = (snap.data!.data() ?? {}) as Map<String, dynamic>;
          final name = (data['fullName'] ?? 'Unknown').toString();
          final email = (data['email'] ?? '').toString();
          final phone = (data['phone'] ?? 'N/A').toString();
          final college = (data['collegeName'] ?? 'N/A').toString();
          final List<String> years = List<String>.from(data['premiumYears'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ===== Profile Header (P3) =====
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),

                // ===== Details Card =====
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _row('Full Name', name),
                        _row('Email', email),
                        _row('Phone', phone),
                        _row('College', college),
                        _row('Premium Years', years.isEmpty ? '—' : years.join(', ')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Manage Premium =====
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Manage Premium', style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                if (years.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No premium years yet'),
                  ),
                if (years.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: years.map((y) {
                      return Chip(
                        label: Text(y),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () => _revokeYear(y),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Premium Year'),
                    onPressed: () => _addPremiumYear(years),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Edit Button =====
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Name / Phone / College'),
                    onPressed: isSaving ? null : () => _editDetails(data),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
