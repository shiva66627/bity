import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ Normalize Firebase & Drive URLs
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

// =================== QUIZ PAGE ===================
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedYear, selectedSubjectId, selectedSubjectName, selectedChapterId;

  Future<bool> _handleBack() async {
    if (selectedChapterId != null) {
      setState(() => selectedChapterId = null);
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
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: Text(selectedSubjectName != null
              ? "${selectedSubjectName!} Quizzes"
              : "Quizzes"),
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: "My Results",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyResultsPage(
                        userId: FirebaseAuth.instance.currentUser!.uid),
                  ),
                );
              },
            )
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

  // =================== YEAR ===================
  Widget _buildYearSelection() {
  final years = [
    {"title": "1st Year", "short": "1st"},
    {"title": "2nd Year", "short": "2nd"},
    {"title": "3rd Year", "short": "3rd"},
    {"title": "4th Year", "short": "4th"},
  ];

  // 🎨 Different CircleAvatar background colors
  final List<Color> bgColors = [
    Colors.red.shade100,
    Colors.orange.shade100,
    Colors.green.shade100,
    Colors.purple.shade100,
  ];

  // 🎨 Matching text colors for each
  final List<Color> textColors = [
    Colors.red.shade700,
    Colors.orange.shade700,
    Colors.green.shade700,
    Colors.purple.shade700,
  ];

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Chip(
            label: const Text("Quizzes"),
            avatar: const Icon(Icons.quiz, color: Colors.white, size: 18),
            backgroundColor: Colors.red[600],
            labelStyle: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 10),
          Chip(
            label: Text(selectedYear ?? "Select Year"),
            backgroundColor: Colors.grey.shade200,
          ),
        ]),
        const SizedBox(height: 20),
        const Text(
          "Select Year for Quizzes",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            itemCount: years.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final year = years[index];
              return GestureDetector(
                onTap: () => setState(() => selectedYear = year["title"]),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: bgColors[index],
                        radius: 30,
                        child: Text(
                          year["short"]!,
                          style: TextStyle(
                            color: textColors[index],
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        year["title"]!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

  // =================== SUBJECTS ===================
  Widget _buildSubjectList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("quizSubjects")
          .where("year", isEqualTo: selectedYear)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No subjects found"));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1, childAspectRatio: 1.5),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final subject = snapshot.data!.docs[index];
            final imageUrl = normalizeUrl(subject['imageUrl'] ?? '');
            final subjectName = subject['name'] ?? 'Subject';

            return GestureDetector(
              onTap: () => setState(() {
                selectedSubjectId = subject.id;
                selectedSubjectName = subjectName;
              }),
              child: Card(
                elevation: 4,
                clipBehavior: Clip.hardEdge,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Stack(children: [
                  Positioned.fill(
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                  color: Colors.red[100],
                                  child: const Icon(Icons.broken_image,
                                      size: 60, color: Colors.red),
                                ))
                        : Container(
                            color: Colors.red[100],
                            child: Center(
                                child: Text(
                              subjectName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            )),
                          ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: Colors.redAccent.withOpacity(0.7),
                      padding: const EdgeInsets.all(6),
                      child: Text(subjectName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16)),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // =================== CHAPTERS ===================
  Widget _buildChapterList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("quizChapters")
          .where("subjectId", isEqualTo: selectedSubjectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No chapters"));

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final chapterName = doc['name'] ?? 'Chapter';
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(chapterName),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => setState(() => selectedChapterId = doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =================== QUIZ LIST ===================
  Widget _buildQuizList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("quizPdfs")
          .where("chapterId", isEqualTo: selectedChapterId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No quizzes available"));

        final quizDoc = docs.first.data() as Map<String, dynamic>;
        final List<Map<String, dynamic>> questions =
            List<Map<String, dynamic>>.from(quizDoc["questions"] ?? []);

        return Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text("Start Quiz (${questions.length} Questions)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizAttemptPage(
                    quizId: docs.first.id,
                    chapterId: selectedChapterId!,
                    subjectId: selectedSubjectId!,
                    year: selectedYear!,
                    userId: FirebaseAuth.instance.currentUser!.uid,
                    questions: questions,
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

// =================== QUIZ ATTEMPT PAGE ===================
class QuizAttemptPage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final String quizId;
  final String chapterId;
  final String subjectId;
  final String year;
  final String userId;

  const QuizAttemptPage({
    super.key,
    required this.questions,
    required this.quizId,
    required this.chapterId,
    required this.subjectId,
    required this.year,
    required this.userId,
  });

  @override
  State<QuizAttemptPage> createState() => _QuizAttemptPageState();
}

class _QuizAttemptPageState extends State<QuizAttemptPage> {
  int currentIndex = 0;
  int score = 0;
  String? selectedOption;
  final Map<int, String> userAnswers = {};

  void _nextQuestion() {
    final currentQuestion = widget.questions[currentIndex];

    if (selectedOption != null) {
      userAnswers[currentIndex] = selectedOption!;
      if (selectedOption == currentQuestion["correctAnswer"]) {
        score++;
      }
    }

    if (currentIndex < widget.questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedOption = userAnswers[currentIndex];
      });
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        selectedOption = userAnswers[currentIndex];
      });
    }
  }

  Future<void> _finishQuiz() async {
    final firestore = FirebaseFirestore.instance;
    final answersAsStringKeys =
        userAnswers.map((key, value) => MapEntry(key.toString(), value));

    await firestore.collection("quiz_results").add({
      "userId": widget.userId,
      "quizId": widget.quizId,
      "score": score,
      "total": widget.questions.length,
      "answers": answersAsStringKeys,
      "attemptedAt": FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizReviewPage(
            questions: widget.questions,
            userAnswers: userAnswers,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text("Question ${currentIndex + 1}/${widget.questions.length}"),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q["question"],
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if ((q["imageUrl"] ?? "").isNotEmpty) ...[
              const SizedBox(height: 12),
              Image.network(q["imageUrl"],
                  height: 150,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.image, size: 40, color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            ...q["options"].entries.map<Widget>((entry) {
              return RadioListTile<String>(
                value: entry.key,
                groupValue: selectedOption,
                onChanged: (val) {
                  setState(() => selectedOption = val);
                },
                title: Text("${entry.key}. ${entry.value}"),
              );
            }).toList(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: currentIndex == 0 ? null : _previousQuestion,
                    child: const Text("Back"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: selectedOption == null ? null : _nextQuestion,
                    child: Text(
                      currentIndex == widget.questions.length - 1
                          ? "Finish"
                          : "Save & Next",
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =================== QUIZ REVIEW PAGE ===================
class QuizReviewPage extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final Map<int, String> userAnswers;

  const QuizReviewPage({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Review"),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final q = questions[index];
          final userAnswer = userAnswers[index];
          final correctAnswer = q["correctAnswer"];
          final explanation = q["explanation"] ?? "";

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Q${index + 1}. ${q["question"]}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  if ((q["imageUrl"] ?? "").isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Image.network(q["imageUrl"],
                        height: 100,
                        errorBuilder: (c, e, s) => const Icon(Icons.image)),
                  ],
                  const SizedBox(height: 8),
                  ...q["options"].entries.map<Widget>((entry) {
                    final isCorrect = entry.key == correctAnswer;
                    final isChosen = entry.key == userAnswer;
                    return Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle
                              : isChosen
                                  ? Icons.cancel
                                  : Icons.radio_button_unchecked,
                          color: isCorrect
                              ? Colors.green
                              : isChosen
                                  ? Colors.red
                                  : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text("${entry.key}. ${entry.value}"),
                      ],
                    );
                  }).toList(),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "📌 Explanation:",
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      explanation,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ]
                ],
              ),
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
      appBar: AppBar(
        title: const Text("My Results"),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("quiz_results")
            .where("userId", isEqualTo: userId)
            .orderBy("attemptedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final results = snapshot.data!.docs;
          if (results.isEmpty) {
            return const Center(child: Text("No quiz attempts yet."));
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index].data() as Map<String, dynamic>;
              final score = result["score"];
              final total = result["total"];
              final attemptedAt = result["attemptedAt"]?.toDate();

              return Card(
                child: ListTile(
                  title: Text("Score: $score / $total"),
                  subtitle: Text("Attempted: ${attemptedAt ?? "Unknown"}"),
                  leading: const Icon(Icons.assignment),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
