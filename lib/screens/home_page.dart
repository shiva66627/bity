// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'quiz.dart';
import 'edit_profile.dart';
import 'admin_dashboard.dart';
import 'notifications_page.dart';
import 'package:mbbsfreaks/main.dart'; // EducationalApp.of(context)
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mbbsfreaks/screens/schedule_list_page.dart';
import 'team_list_page.dart';
import 'full_reviews_page.dart';
import 'all_offers_page.dart';
import '../utils/device_id.dart';
import 'profile_details_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';



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
  bool isSubmitted = false;

  Map<String, dynamic>? recentActivity;

  final PageController _reviewController =
      PageController(viewportFraction: 0.88);
  int _reviewPage = 0;

  @override
  void initState() {
    super.initState();
    _checkSession();
    fetchUserData();
    fetchDailyQuestion();
    fetchRecentActivity();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

 Future<void> fetchUserData() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid != null) {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final role = (doc.data()?['role'] as String?)?.trim() ?? 'user';

        setState(() {
          fullName = doc.data()?['fullName'] ?? '';
          email = doc.data()?['email'] ?? '';
          phone = doc.data()?['phone'] ?? '';

          // 🔥 Accept admin, super admin, and power admin
          isAdmin = role == 'admin' || role == 'super_admin' || role == 'power_admin';

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
        selectedOption = null;
        isSubmitted = false;
        answerFeedback = null;
      });
    }
  }

  Future<void> _checkSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final deviceId = await DeviceIdHelper.getDeviceId();

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final savedId = doc.data()?["activeDeviceId"];

    if (savedId != null && savedId != deviceId) {
      if (!mounted) return;

      await FirebaseAuth.instance.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("⚠ Logged out: Your account is logged in on another device."),
          backgroundColor: Colors.red,
        ),
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
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

      final quizDoc = await FirebaseFirestore.instance
          .collection("quizPdfs")
          .doc(quizId)
          .get();
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
        centerTitle: true,
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
                physics:
                    const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
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
                    const SizedBox(height: 20),
                    _buildStudentReviews()


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
  accountEmail: Text(email.isNotEmpty ? email : ""),
  currentAccountPicture: GestureDetector(
    onTap: () {
      Navigator.pop(context); // close drawer
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
      );
    },
    child: const CircleAvatar(
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: 40, color: Colors.blue),
    ),
  ),
),


   ListTile(
  leading: const Icon(Icons.notifications, color: Colors.deepOrange),
  title: const Text("Notifications"),
  onTap: () {
    Navigator.pop(context);

    // 🔥 All admins: admin + super_admin + power_admin
    if (isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsPage()),
      );
      
    }
    else {
      // USER VIEW
      Navigator.pushNamed(context, '/user_notifications');
    }


    // 🔥 Users (normal people)
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
                path: '',
                queryParameters: {
                  'subject': 'App Feedback',
                  'body': 'Hi Team,\n\nI would like to share the following feedback:\n\n',
                },
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              }
            },
          ),
          if (isAdmin)
            ListTile(
              leading:
                  const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Switch to Admin'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboard()),
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
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.telegram,
                color: Colors.blue, size: 22),
            title: const Text("Join us on Telegram"),
            onTap: () async {
              final telegramUrl = Uri.parse('https://t.me/mbbsfreaks2606');
              if (await canLaunchUrl(telegramUrl)) {
                await launchUrl(telegramUrl,
                    mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open Telegram')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.group, color: Colors.deepPurple),
            title: const Text("Freaks Team"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamListPage()),
              );
            },
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.instagram,
                color: Colors.purple, size: 22),
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
          ListTile(
            leading: const Icon(Icons.local_offer_outlined, color: Colors.deepOrange),
            title: const Text("All Offers"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllOffersPage()),
              );
            },
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
        _buildMenuCard('Question Bank', Icons.library_books, Colors.green, '/question_bank'),
        _buildMenuCard('Quiz', Icons.quiz, Colors.purple, '/quiz'),
      ],
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, String routeName) {
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 0,
              mainAxisExtent: 44,
            ),
            itemBuilder: (context, index) {
              final opt = options[index];
              final isSelected = selectedOption == opt;
              return InkWell(
                onTap: () => setState(() {
                  selectedOption = opt;
                  isSubmitted = false;
                }),
                child: Row(
                  children: [
                    Radio<String>(
                      value: opt,
                      groupValue: selectedOption,
                      activeColor: Colors.orange,
                      onChanged: (val) => setState(() {
                        selectedOption = val;
                        isSubmitted = false;
                      }),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Expanded(
                      child: Text(
                        opt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
                answerFeedback = isCorrect ? "✅ Correct Answer!" : "❌ Wrong Answer. Correct: $correctAnswer";
                isSubmitted = true;
              });
            },
            child: const Text("Submit Answer"),
          ),
          if (isSubmitted && answerFeedback != null) ...[
            const SizedBox(height: 10),
            Text(
              answerFeedback!,
              style: TextStyle(
                color: answerFeedback!.startsWith('✅') ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isSubmitted) ...[
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
    final shortName = subjectName.length > 18 ? "${subjectName.substring(0, 18)}..." : subjectName;
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
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                backgroundColor: Colors.redAccent,
                child: imageUrl.isEmpty ? const Icon(Icons.quiz, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text("${recentActivity?["score"]}/${recentActivity?["total"]}", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Text(_formatTimeAgo(recentActivity?["attemptedAt"]), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildStudentReviews() {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('testimonials')
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) {
        return const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator()));
      }

      final docs = snap.data!.docs;
      final showCount = docs.length > 3 ? 3 : docs.length;

      if (showCount == 0) {
        return const Text("No reviews yet.",
            style: TextStyle(color: Colors.black54));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Our students review",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: _openAddReviewSheet,
                icon: const Icon(Icons.add, size: 18, color: Colors.blue),
                label: const Text("Add Review",
                    style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ⭐ FIX: Enclose in fixed height & block vertical scroll
          SizedBox(
            height: 260,
            child: NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (notification) {
                notification.disallowIndicator();
                return true;
              },
              child: PageView.builder(
                controller: _reviewController,
                physics: const ClampingScrollPhysics(), // horizontal ONLY
                itemCount: showCount,
                onPageChanged: (i) {
                  setState(() => _reviewPage = i);
                },
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final id = docs[i].id;

                  final ownerUid = data['uid'] ?? "";
                  final canDelete =
                      (currentUid != null && ownerUid == currentUid) || isAdmin;

                  return ReviewCarouselCard(
                    data: data,
                    docId: id,
                    canDelete: canDelete,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ⭐ BOTTOM: arrows + dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LEFT ARROW
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 20, color: Colors.blue),
                onPressed: () {
                  _reviewController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
              ),

              const SizedBox(width: 10),

              // DOTS
              Row(
                children: List.generate(
                  showCount,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _reviewPage == i ? 10 : 7,
                    height: _reviewPage == i ? 10 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _reviewPage == i ? Colors.black : Colors.grey[400],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // RIGHT ARROW
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios,
                    size: 20, color: Colors.blue),
                onPressed: () {
                  _reviewController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
              ),
            ],
          ),

          if (docs.length > 3)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FullReviewsPage()),
                );
              },
              child: const Text("View More",
                  style: TextStyle(color: Colors.blue)),
            ),
        ],
      );
    },
  );
}

  void _openAddReviewSheet() {
    final nameAuto = fullName.isNotEmpty ? fullName : (FirebaseAuth.instance.currentUser?.displayName ?? 'Student');

    final reviewCtrl = TextEditingController();
    final programCtrl = TextEditingController();
    final bottomCtrl = TextEditingController();
    int selectedStars = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: StatefulBuilder(
            builder: (context, setStateBS) {
              bool saving = false;

              Future<void> save() async {
                if (reviewCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write your review.")));
                  return;
                }
                if (selectedStars == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a star rating.")));
                  return;
                }
                setStateBS(() => saving = true);
                try {
                  await FirebaseFirestore.instance.collection('testimonials').add({
                    'name': nameAuto,
                    'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
                    'review': reviewCtrl.text.trim(),
                    'program': programCtrl.text.trim(),
                    'bottom': bottomCtrl.text.trim(),
                    'rating': selectedStars,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Thanks for your review!")));
                  }
                } finally {
                  setStateBS(() => saving = false);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("Write a Review", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(nameAuto, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: "Your review", prefixIcon: Icon(Icons.format_quote), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: programCtrl,
                    decoration: const InputDecoration(labelText: "Program (optional)", prefixIcon: Icon(Icons.school), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bottomCtrl,
                    decoration: const InputDecoration(labelText: "Bottom line (optional)", prefixIcon: Icon(Icons.short_text), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => IconButton(
                      icon: Icon(i < selectedStars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                      onPressed: () {
                        setStateBS(() => selectedStars = i + 1);
                      },
                    )),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: saving ? null : save,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Submit"),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
class ReviewCarouselCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool canDelete;

  const ReviewCarouselCard({
    super.key,
    required this.data,
    required this.docId,
    required this.canDelete,
  });

  @override
  State<ReviewCarouselCard> createState() => _ReviewCarouselCardState();
}

class _ReviewCarouselCardState extends State<ReviewCarouselCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['name'] ?? 'Student').toString();
    final review = (widget.data['review'] ?? '').toString();
    final program = (widget.data['program'] ?? '').toString();
    final bottom = (widget.data['bottom'] ?? '').toString();
    final rating = (widget.data['rating'] ?? 0) as int;

    final ts = widget.data['createdAt'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    final formatted = "${date.day} ${_month(date.month)} ${date.year}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  right: 18,
                  top: 18,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 42,
                  top: 32,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF64B5F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.canDelete)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _confirmDelete(context),
              ),
            ),

          // ⭐ NO MORE SingleChildScrollView — FIXED!
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote,
                  color: Color(0xFF1E88E5), size: 26),

              const SizedBox(height: 6),

              Text(
                review,
                style:
                    const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? "Read less" : "Read more",
                  style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star,
                    size: 18,
                    color: i < rating
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF1E88E5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        if (program.isNotEmpty)
                          Text(program,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54)),
                        if (bottom.isNotEmpty)
                          Text(bottom,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                formatted,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete review?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
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
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _month(int m) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[m - 1];
  }
}
