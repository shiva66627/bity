// lib/screens/quiz.dart

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';



/// Normalize Firebase / Google Drive URLs -> direct

String normalizeUrl(String url) {

  if (url.contains("firebasestorage.googleapis.com")) return url;

  if (url.contains("drive.google.com")) {

    final regex = RegExp(r"/d/([a-zA-Z0-9_-]+)");

    final match = regex.firstMatch(url);

    if (match != null) {

      return "https://drive.google.com/uc?export=download&id=${match.group(1)}";

    }

  }

  return url;

}



// =================== QUIZ PAGE (HOME) ===================

class QuizPage extends StatefulWidget {

  const QuizPage({super.key});



  @override

  State<QuizPage> createState() => _QuizPageState();

}



class _QuizPageState extends State<QuizPage> {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  String? selectedYear;

  String? selectedSubjectId;

  String? selectedSubjectName;

  String? selectedChapterId;

  String? selectedChapterName;



  Future<bool> _handleBack() async {

    if (selectedChapterId != null) {

      setState(() {

        selectedChapterId = null;

        selectedChapterName = null;

      });

      return false;

    } else if (selectedSubjectId != null) {

      setState(() {

        selectedSubjectId = null;

        selectedSubjectName = null;

      });

      return false;

    } else if (selectedYear != null) {

      setState(() => selectedYear = null);

      return false;

    }

    return true;

  }



  @override

  Widget build(BuildContext context) {

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return WillPopScope(

      onWillPop: _handleBack,

      child: Scaffold(

        appBar: AppBar(

          title: Text(selectedSubjectName != null ? "${selectedSubjectName!} Quiz" : "Quiz"),

          backgroundColor: Colors.red.shade600,

          foregroundColor: Colors.white,

          actions: [

            if (uid != null)

              IconButton(

                tooltip: "My Results",

                icon: const Icon(Icons.history),

                onPressed: () {

                  Navigator.push(context, MaterialPageRoute(builder: (_) => MyResultsPage(userId: uid)));

                },

              ),

          ],

        ),

        body: _buildMainContent(),

      ),

    );

  }



  Widget _buildMainContent() {

    if (selectedYear == null) return _buildYearSelection();

    if (selectedSubjectId == null) return _buildSubjectList();

    if (selectedChapterId == null) return _buildChapterList();

    return _buildQuizList();

  }



  // ---------- Year selection ----------

  Widget _buildYearSelection() {

    final years = [

      {"title": "1st Year", "short": "1st"},

      {"title": "2nd Year", "short": "2nd"},

      {"title": "3rd Year", "short": "3rd"},

      {"title": "4th Year", "short": "4th"},

    ];



    final bgColors = [Colors.blue.shade50, Colors.green.shade50, Colors.orange.shade50, Colors.purple.shade50];

    final textColors = [Colors.blue.shade700, Colors.green.shade700, Colors.orange.shade700, Colors.purple.shade700];



    return Padding(

      padding: const EdgeInsets.all(16.0),

      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const Text("Select Year for Quiz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

        const SizedBox(height: 12),

        Expanded(

          child: GridView.builder(

            itemCount: years.length,

            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05),

            itemBuilder: (context, i) {

              final y = years[i];

              return GestureDetector(

                onTap: () => setState(() => selectedYear = y['title'] as String),

                child: Card(

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                  elevation: 3,

                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

                    CircleAvatar(

                      backgroundColor: bgColors[i],

                      radius: 28,

                      child: Text(y['short']!, style: TextStyle(color: textColors[i], fontWeight: FontWeight.bold, fontSize: 18)),

                    ),

                    const SizedBox(height: 8),

                    Text(y['title']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),

                  ]),

                ),

              );

            },

          ),

        ),

      ]),

    );

  }



  // ---------- Subject list ----------

Widget _buildSubjectList() {

  return StreamBuilder<QuerySnapshot>(

    stream: FirebaseFirestore.instance

        .collection("quizSubjects")

        .where("year", isEqualTo: selectedYear)

        .snapshots(),

    builder: (context, snapshot) {

      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No subjects found"));



      // Remove duplicates by subject name, keep last occurrence

      final unique = <String, QueryDocumentSnapshot>{};

      for (var doc in snapshot.data!.docs) {

        final data = doc.data() as Map<String, dynamic>? ?? {};

        final name = (data['name'] ?? '').toString().trim();

        if (name.isNotEmpty) unique[name] = doc;

      }



      final docs = unique.values.toList(); // List<QueryDocumentSnapshot>



      return GridView.builder(

        padding: const EdgeInsets.all(16),

        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount: 1,

          childAspectRatio: 1.5,

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

        ),

        itemCount: docs.length,

        itemBuilder: (context, index) {

          final doc = docs[index];

          final data = doc.data() as Map<String, dynamic>? ?? {};

          final imageUrl = (data['imageUrl'] ?? '').toString();

          final subjectName = (data['name'] ?? 'Subject').toString();



          return GestureDetector(

            onTap: () {

              setState(() {

                selectedSubjectId = doc.id;         // use doc.id (important)

                selectedSubjectName = subjectName;

              });

            },

            child: Card(

              elevation: 4,

              clipBehavior: Clip.hardEdge,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              child: Stack(

                children: [

                  Positioned.fill(

                    child: imageUrl.isNotEmpty

                        ? Image.network(normalizeUrl(imageUrl), fit: BoxFit.cover)

                        : Container(

                            color: Colors.grey.shade200,

                            child: Center(

                              child: Text(

                                subjectName.substring(0, 1).toUpperCase(),

                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color.fromARGB(221, 228, 9, 9)),

                              ),

                            ),

                          ),

                  ),

                  Align(

                    alignment: Alignment.bottomCenter,

                    child: Container(

                      width: double.infinity,

                      padding: const EdgeInsets.all(6),

                      color: const Color.fromARGB(255, 244, 15, 15).withOpacity(0.5),

                      child: Text(subjectName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),

                    ),

                  ),

                ],

              ),

            ),

          );

        },

      );

    },

  );

}



  // ---------- Chapter list ----------

  Widget _buildChapterList() {

    return StreamBuilder<QuerySnapshot>(

      stream: _firestore.collection("quizChapters").where("subjectId", isEqualTo: selectedSubjectId).snapshots(),

      builder: (context, snap) {

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("No chapters"));



        return ListView.builder(

          padding: const EdgeInsets.all(12),

          itemCount: docs.length,

          itemBuilder: (ctx, i) {

            final d = docs[i].data() as Map<String, dynamic>;

            final name = (d['name'] ?? 'Chapter').toString();

            return Card(

              child: ListTile(

                title: Text(name),

                subtitle: (d['desc'] ?? '').toString().isNotEmpty ? Text(d['desc']) : null,

                trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                onTap: () => setState(() {

                  selectedChapterId = docs[i].id;

                  selectedChapterName = name;

                }),

              ),

            );

          },

        );

      },

    );

  }



  // ---------- Quiz list ----------

  Widget _buildQuizList() {

    return StreamBuilder<QuerySnapshot>(

      stream: _firestore.collection("quizPdfs").where("chapterId", isEqualTo: selectedChapterId).snapshots(),

      builder: (context, snap) {

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("No quizzes found"));



        final quizDoc = docs.first;

        final data = quizDoc.data() as Map<String, dynamic>;

        final List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(data["questions"] ?? []);



        return Center(

          child: ElevatedButton.icon(

            icon: const Icon(Icons.play_arrow),

            label: Text("Start Quiz (${questions.length} Questions)"),

            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),

            onPressed: questions.isEmpty

                ? null

                : () {

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) => QuizAttemptPage(

                          questions: questions,

                          quizId: quizDoc.id,

                          chapterId: selectedChapterId ?? '',

                          chapterName: selectedChapterName ?? 'Chapter',

                          subjectId: selectedSubjectId ?? '',

                          year: selectedYear ?? '',

                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',

                        ),

                      ),

                    );

                  },

          ),

        );

      },

    );

  }

}



// =================== ATTEMPT PAGE (Attractive UI) ===================

class QuizAttemptPage extends StatefulWidget {

  final List<Map<String, dynamic>> questions;

  final String quizId;

  final String chapterId;

  final String chapterName;

  final String subjectId;

  final String year;

  final String userId;



  const QuizAttemptPage({

    super.key,

    required this.questions,

    required this.quizId,

    required this.chapterId,

    required this.chapterName,

    required this.subjectId,

    required this.year,

    required this.userId,

  });



  @override

  State<QuizAttemptPage> createState() => _QuizAttemptPageState();

}



class _QuizAttemptPageState extends State<QuizAttemptPage> {

  int currentIndex = 0;

  String? selectedOption;

  final Map<int, String> userAnswers = {};



  void _saveAndNext() {

    // Save current selection

    userAnswers[currentIndex] = selectedOption ?? "";



    if (currentIndex < widget.questions.length - 1) {

      setState(() {

        currentIndex++;

        selectedOption = userAnswers[currentIndex];

      });

    } else {

      _finishQuiz();

    }

  }



  void _previous() {

    if (currentIndex > 0) {

      setState(() {

        currentIndex--;

        selectedOption = userAnswers[currentIndex];

      });

    }

  }



  Future<void> _finishQuiz() async {

    // Recalculate counts

    int score = 0, wrong = 0, skipped = 0;

    for (int i = 0; i < widget.questions.length; i++) {

      final right = widget.questions[i]["correctAnswer"]?.toString() ?? "";

      final ans = (userAnswers[i] ?? "").toString();

      if (ans.isEmpty) skipped++;

      else if (ans == right) score++;

      else wrong++;

    }



    final firestore = FirebaseFirestore.instance;

    final answersAsStrings = userAnswers.map((k, v) => MapEntry(k.toString(), v));

    await firestore.collection("quiz_results").add({

      "userId": widget.userId,

      "quizId": widget.quizId,

      "chapterId": widget.chapterId,

      "score": score,

      "total": widget.questions.length,

      "answers": answersAsStrings,

      "attemptedAt": FieldValue.serverTimestamp(),

    });



    if (!mounted) return;



    // Push result page, pass data for retry/review to work from result context

    Navigator.pushReplacement(

      context,

      MaterialPageRoute(

        builder: (_) => QuizResultPageAnimated(

          correct: score,

          wrong: wrong,

          skipped: skipped,

          total: widget.questions.length,

          title: widget.chapterName,

          // data for result page to navigate itself

          questions: widget.questions,

          userAnswers: Map<int, String>.from(userAnswers),

          quizId: widget.quizId,

          chapterId: widget.chapterId,

          chapterName: widget.chapterName,

          subjectId: widget.subjectId,

          year: widget.year,

          userId: widget.userId,

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final q = widget.questions[currentIndex];

    final options = Map<String, dynamic>.from(q["options"] ?? {});



    return Scaffold(

      appBar: AppBar(

        title: Text("${widget.chapterName} - Q${currentIndex + 1}/${widget.questions.length}"),

        backgroundColor: Colors.red.shade600,

        foregroundColor: Colors.white,

      ),

      body: Padding(

        padding: const EdgeInsets.all(16),

        child: ListView(

          children: [

            Card(

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              elevation: 3,

              child: Padding(

                padding: const EdgeInsets.all(14),

                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  Text("Q${currentIndex + 1}", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),

                  const SizedBox(height: 6),

                  Text(q["question"] ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  if ((q["imageUrl"] ?? "").toString().isNotEmpty) ...[

                    const SizedBox(height: 12),

                    GestureDetector(

                      onTap: () {

                        final img = q["imageUrl"]?.toString() ?? "";

                        if (img.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: img)));

                      },

                      child: ClipRRect(

                        borderRadius: BorderRadius.circular(8),

                        child: Image.network(normalizeUrl(q["imageUrl"]?.toString() ?? ""), height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),

                      ),

                    ),

                  ],

                ]),

              ),

            ),

            const SizedBox(height: 12),

            ...options.entries.map((e) {

              return Card(

                child: RadioListTile<String>(

                  title: Text("${e.key}. ${e.value}"),

                  value: e.key.toString(),

                  groupValue: selectedOption,

                  onChanged: (val) => setState(() => selectedOption = val),

                ),

              );

            }).toList(),

            const SizedBox(height: 14),

            Row(children: [

              Expanded(

                child: ElevatedButton(

                  onPressed: currentIndex == 0 ? null : _previous,

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black),

                  child: const Text("Back"),

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: ElevatedButton(

                  onPressed: selectedOption == null && (userAnswers[currentIndex] ?? "").isEmpty ? null : _saveAndNext,

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),

                  child: Text(currentIndex == widget.questions.length - 1 ? "Finish" : "Save & Next"),

                ),

              ),

            ]),

          ],

        ),

      ),

    );

  }

}



// =================== RESULT PAGE (Animated & Attractive) ===================

class QuizResultPageAnimated extends StatefulWidget {

  final int correct;

  final int wrong;

  final int skipped;

  final int total;

  final String title;



  // Data to allow result page to navigate (retry/review)

  final List<Map<String, dynamic>> questions;

  final Map<int, String> userAnswers;

  final String quizId;

  final String chapterId;

  final String chapterName;

  final String subjectId;

  final String year;

  final String userId;



  const QuizResultPageAnimated({

    super.key,

    required this.correct,

    required this.wrong,

    required this.skipped,

    required this.total,

    required this.title,

    required this.questions,

    required this.userAnswers,

    required this.quizId,

    required this.chapterId,

    required this.chapterName,

    required this.subjectId,

    required this.year,

    required this.userId,

  });



  @override

  State<QuizResultPageAnimated> createState() => _QuizResultPageAnimatedState();

}



class _QuizResultPageAnimatedState extends State<QuizResultPageAnimated> with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  late Animation<double> _scoreAnim;



  @override

  void initState() {

    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _scoreAnim = Tween<double>(begin: 0, end: widget.correct.toDouble()).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

  }



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  Color _getBadgeColor() {

    final perc = (widget.correct / widget.total) * 100;

    if (perc >= 80) return Colors.green;

    if (perc >= 50) return Colors.orange;

    return Colors.red;

  }



  @override

  Widget build(BuildContext context) {

    final perc = (widget.correct / widget.total) * 100;

    return Scaffold(

      backgroundColor: Colors.transparent,

      body: Container(

        decoration: const BoxDecoration(

          gradient: LinearGradient(colors: [Color(0xFFff7a7a), Color(0xFFffb56b)], begin: Alignment.topLeft, end: Alignment.bottomRight),

        ),

        child: SafeArea(

          child: Column(

            children: [

              Row(

                children: [

                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),

                  const SizedBox(width: 6),

                  const Text("Result", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

                ],

              ),

              const SizedBox(height: 18),

              Expanded(

                child: Center(

                  child: Container(

                    margin: const EdgeInsets.symmetric(horizontal: 18),

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.96), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 8))]),

                    child: Column(mainAxisSize: MainAxisSize.min, children: [

                      CircleAvatar(radius: 36, backgroundColor: _getBadgeColor(), child: const Icon(Icons.emoji_events, color: Colors.white, size: 32)),

                      const SizedBox(height: 12),

                      AnimatedBuilder(animation: _scoreAnim, builder: (context, child) {

                        return Text("${_scoreAnim.value.toInt()} / ${widget.total}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold));

                      }),

                      const SizedBox(height: 6),

                      Text("${perc.toStringAsFixed(1)}% accuracy", style: const TextStyle(fontSize: 14, color: Colors.black54)),

                      const SizedBox(height: 18),

                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [

                        _statChip("Correct", widget.correct.toString(), Colors.green),

                        const SizedBox(width: 10),

                        _statChip("Wrong", widget.wrong.toString(), Colors.red),

                        const SizedBox(width: 10),

                        _statChip("Skipped", widget.skipped.toString(), Colors.orange),

                      ]),

                      const SizedBox(height: 22),



                      // Review uses result page context so it works reliably

                      ElevatedButton(

                        onPressed: () {

                          Navigator.push(context, MaterialPageRoute(builder: (_) => QuizReviewPage(questions: widget.questions, userAnswers: widget.userAnswers)));

                        },

                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Colors.deepPurple, width: 2))),

                        child: const Text("Review Answers"),

                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(

                        onPressed: () {

                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizAttemptPage(questions: widget.questions, quizId: widget.quizId, chapterId: widget.chapterId, chapterName: widget.chapterName, subjectId: widget.subjectId, year: widget.year, userId: widget.userId)));

                        },

                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),

                        child: const Text("Retry", style: TextStyle(color: Colors.white)),

                      ),

                    ]),

                  ),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _statChip(String label, String value, Color color) {

    return Column(children: [

      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),

      const SizedBox(height: 4),

      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),

    ]);

  }

}



// =================== FULLSCREEN IMAGE VIEWER ===================

class FullScreenImage extends StatelessWidget {

  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),

      body: Center(

        child: InteractiveViewer(

          minScale: 0.5,

          maxScale: 4.0,

          child: Image.network(normalizeUrl(imageUrl), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 40)),

        ),

      ),

    );

  }

}



// =================== REVIEW PAGE ===================

class QuizReviewPage extends StatelessWidget {

  final List<Map<String, dynamic>> questions;

  final Map<int, String> userAnswers;



  const QuizReviewPage({super.key, required this.questions, required this.userAnswers});



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Review Answers"), backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),

      body: ListView.builder(

        padding: const EdgeInsets.all(16),

        itemCount: questions.length,

        itemBuilder: (ctx, i) {

          final q = questions[i];

          final correct = q["correctAnswer"]?.toString() ?? "";

          final userAns = userAnswers[i] ?? "";

          final options = Map<String, dynamic>.from(q["options"] ?? {});

          final imageUrl = (q["imageUrl"] ?? "").toString();



          return Card(

            margin: const EdgeInsets.symmetric(vertical: 8),

            elevation: 3,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

            child: Padding(

              padding: const EdgeInsets.all(12),

              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Text("Q${i + 1}: ${q['question']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                const SizedBox(height: 8),

                if (imageUrl.isNotEmpty)

                  GestureDetector(

                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: imageUrl))),

                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(normalizeUrl(imageUrl), height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))),

                  ),

                if (imageUrl.isNotEmpty) const SizedBox(height: 10),

                ...options.entries.map((e) {

                  final isCorrect = e.key.toString() == correct;

                  final isSelected = e.key.toString() == userAns;

                  Color color = Colors.black87;

                  IconData icon = Icons.circle_outlined;

                  if (isCorrect) {

                    color = Colors.green;

                    icon = Icons.check_circle;

                  } else if (isSelected) {

                    color = Colors.red;

                    icon = Icons.close;

                  }

                  return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Expanded(child: Text("${e.key}. ${e.value}", style: TextStyle(color: color)))]));
                }).toList(),
                if ((q["explanation"] ?? "").toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text("Explanation: ${q["explanation"]}", style: const TextStyle(color: Colors.black54)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}
// =================== MY RESULTS PAGE ===================
class MyResultsPage extends StatelessWidget {
  final String userId;
  const MyResultsPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Results"), backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("quiz_results").where("userId", isEqualTo: userId).orderBy("attemptedAt", descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No attempts yet"));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final score = d['score'] ?? 0;
              final total = d['total'] ?? 0;
              final attemptedAt = d['attemptedAt']?.toDate();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment),
                  title: Text("Score: $score / $total"),
                  subtitle: Text("Attempted: ${attemptedAt ?? 'Unknown'}"),
                  onTap: () {
                    final answers = (d['answers'] ?? {}) as Map<String, dynamic>;
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Attempt details"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView(shrinkWrap: true, children: answers.entries.map((e) => Text("Q${e.key} -> ${e.value}")).toList()),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
