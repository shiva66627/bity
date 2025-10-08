import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'quiz.dart';
import 'edit_profile.dart';
import 'admin_dashboard.dart';
import 'notifications_page.dart';
import 'package:mbbsfreaks/main.dart'; // ✅ to access EducationalApp.of(context)
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mbbsfreaks/screens/schedule_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String fullName = '';
  String email = '';
  String phone = '';
  bool isLoading = true;
  bool isAdmin = false;

  Map<String, dynamic>? dailyQuestion;
  String? selectedOption;
  String? correctAnswer;
  String? answerFeedback;

  Map<String, dynamic>? recentActivity;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchDailyQuestion();
    fetchRecentActivity();
  }

  Future<void> fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            fullName = doc.data()?['fullName'] ?? '';
            email = doc.data()?['email'] ?? '';
            phone = doc.data()?['phone'] ?? '';
            isAdmin = (doc.data()?['role'] == 'admin');
            isLoading = false;
          });
        } else {
          setState(() {
            fullName = FirebaseAuth.instance.currentUser?.displayName ?? '';
            email = FirebaseAuth.instance.currentUser?.email ?? '';
            phone = '';
            isAdmin = false;
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          fullName = '';
          email = '';
          phone = '';
          isAdmin = false;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        fullName = '';
        email = '';
        phone = '';
        isAdmin = false;
        isLoading = false;
      });
    }
  }

  Future<void> fetchDailyQuestion() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("daily_question")
        .orderBy("createdAt", descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      setState(() {
        dailyQuestion = doc.data() as Map<String, dynamic>;
        correctAnswer = dailyQuestion?["correctAnswer"];
      });
    }
  }

  Future<void> fetchRecentActivity() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection("quiz_results")
        .where("userId", isEqualTo: userId)
        .orderBy("attemptedAt", descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final quizId = data["quizId"];
      final attemptedAt = data["attemptedAt"]?.toDate();

      String subjectName = '';
      String subjectImage = '';

      final quizDoc =
          await FirebaseFirestore.instance.collection("quizPdfs").doc(quizId).get();
      if (quizDoc.exists) {
        final chapterId = quizDoc.data()?["chapterId"];
        if (chapterId != null) {
          final chapterDoc = await FirebaseFirestore.instance
              .collection("quizChapters")
              .doc(chapterId)
              .get();
          if (chapterDoc.exists) {
            final subjectId = chapterDoc.data()?["subjectId"];
            if (subjectId != null) {
              final subjectDoc = await FirebaseFirestore.instance
                  .collection("quizSubjects")
                  .doc(subjectId)
                  .get();
              if (subjectDoc.exists) {
                subjectName = subjectDoc.data()?["name"] ?? '';
                subjectImage = subjectDoc.data()?["imageUrl"] ?? '';
              }
            }
          }
        }
      }

      setState(() {
        recentActivity = {
          "quizId": quizId,
          "subjectName": subjectName,
          "subjectImage": subjectImage,
          "score": data["score"],
          "total": data["total"],
          "attemptedAt": attemptedAt,
        };
      });
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: true, // ✅ center the title
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text(
          "MBBS FREAKS",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        // ✅ removed the 3-dot menu by not providing any actions
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await fetchDailyQuestion();
                await fetchRecentActivity();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hi, ${fullName.isNotEmpty ? fullName : 'User'}!",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMenuGrid(),
                    const SizedBox(height: 20),
                    if (dailyQuestion != null) _buildDailyQuestionBox(),
                    const SizedBox(height: 20),
                    if (recentActivity != null) _buildRecentActivityCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            accountName: Text(fullName.isNotEmpty ? fullName : "User"),
            accountEmail: const Text(""), // ✅ email hidden
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications, color: Colors.deepOrange),
            title: const Text("Notifications"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback, color: Colors.green),
            title: const Text("Feedback for Improving App"),
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: '', // ✅ no hardcoded address in the UI
                queryParameters: {
                  'subject': 'App Feedback',
                  'body':
                      'Hi Team,\n\nI would like to share the following feedback:\n\n',
                },
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              }
            },
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Switch to Admin'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminDashboard()),
                );
              },
            ),
          ListTile(
            leading: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Colors.orange,
            ),
            title: Text(
              Theme.of(context).brightness == Brightness.dark
                  ? "Switch to Light Mode"
                  : "Switch to Dark Mode",
            ),
            onTap: () {
              final isDark = Theme.of(context).brightness != Brightness.dark;
              final newThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;
              EducationalApp.of(context)!.changeTheme(newThemeMode);
              Navigator.pop(context);
            },
          ),
    // 🚀 Telegram Integration (using FontAwesome)
ListTile(
  leading: const FaIcon(FontAwesomeIcons.telegram, color: Colors.blue, size: 22),
  title: const Text("Join us on Telegram"),
  onTap: () async {
    final telegramUrl = Uri.parse('https://t.me/mbbsfreaks2606');
    if (await canLaunchUrl(telegramUrl)) {
      await launchUrl(telegramUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Telegram')),
      );
    }
  },
),

// 📸 Instagram Integration (using FontAwesome)
ListTile(
  leading: const FaIcon(FontAwesomeIcons.instagram, color: Colors.purple, size: 22),
  title: const Text("Follow us on Instagram"),
  onTap: () async {
    final instagramUrl = Uri.parse('https://www.instagram.com/mbbs_freaks');
    if (await canLaunchUrl(instagramUrl)) {
      await launchUrl(instagramUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Instagram')),
      );
    }
  },
),
ListTile(
  leading: const Icon(Icons.schedule, color: Colors.indigo),
  title: const Text("View Schedule Plans"),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleListPage()),
    );
  },
),



          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () => logout(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildMenuCard('NOTES', Icons.menu_book, Colors.blue, '/notes'),
        _buildMenuCard('PYQS', Icons.description, Colors.orange, '/pyqs'),
        _buildMenuCard(
            'Question Bank', Icons.library_books, Colors.green, '/question_bank'),
        _buildMenuCard('Quiz', Icons.quiz, Colors.purple, '/quiz'),
      ],
    );
  }

  Widget _buildMenuCard(
      String title, IconData icon, Color color, String routeName) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, routeName).then((_) {
          fetchRecentActivity();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyQuestionBox() {
    final options = List<String>.from(dailyQuestion?["options"] ?? []);
    final imageUrl = dailyQuestion?["imageUrl"];
    final explanation = dailyQuestion?["explanation"];
    final message = dailyQuestion?["message"];
    bool answered = selectedOption != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Colors.orange, size: 18),
              SizedBox(width: 5),
              Text(
                "Daily Question",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            dailyQuestion?["question"] ?? "",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: options.map((opt) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width / 2) - 50,
                child: RadioListTile<String>(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: opt,
                  groupValue: selectedOption,
                  activeColor: Colors.orange,
                  title: Text(
                    opt,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  onChanged: (val) {
                    setState(() {
                      selectedOption = val;
                    });
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (selectedOption == null) return;
              final isCorrect = selectedOption == correctAnswer;
              setState(() {
                answerFeedback = isCorrect
                    ? "✅ Correct Answer!"
                    : "❌ Wrong Answer. Correct: $correctAnswer";
              });
            },
            child: const Text("Submit Answer"),
          ),
          if (answerFeedback != null) ...[
            const SizedBox(height: 10),
            Text(
              answerFeedback!,
              style: TextStyle(
                color: answerFeedback!.startsWith('✅')
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (answered) ...[
            if (explanation != null && explanation.isNotEmpty) ...[
              const Text(
                "📝 Explanation:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              Text(
                explanation,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            if (message != null && message.isNotEmpty) ...[
              const Text(
                "📢 Message:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlueAccent,
                ),
              ),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ]
          ]
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final subjectName = recentActivity?["subjectName"] ?? "Quiz";
    final shortName =
        subjectName.length > 18 ? "${subjectName.substring(0, 18)}..." : subjectName;
    final imageUrl = recentActivity?["subjectImage"] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Recent Activity",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                backgroundColor: Colors.redAccent,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.quiz, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      "${recentActivity?["score"]}/${recentActivity?["total"]}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTimeAgo(recentActivity?["attemptedAt"]),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
