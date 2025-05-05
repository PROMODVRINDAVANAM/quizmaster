import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

const String scriptUrl =
    'https://script.google.com/macros/s/AKfycbzPuwIPBGkzLmYbmUX8Zq5xznS3s9IfB23bifQSQ8MKqpMHbYxWJepYPSGRag3Fo98/exec';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String error = '';

  Future<void> login() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    final response = await http.get(Uri.parse(
        '$scriptUrl?action=login&email=${emailController.text}&password=${passwordController.text}'));

    final json = jsonDecode(response.body);
    if (json['success']) {
      int numQuestions = int.tryParse(json['numQuestions'].toString()) ?? 5;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            email: emailController.text,
            numQuestions: numQuestions,
          ),
        ),
      );
    } else {
      setState(() {
        error = json['message'] ?? 'Login failed';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Login", style: TextStyle(fontSize: 24)),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : login,
                child: Text("Login"),
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(error, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String email;
  final int numQuestions;

  const QuizScreen(
      {super.key, required this.email, required this.numQuestions});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List questions = [];
  int currentIndex = 0;
  int selectedIndex = -1;
  int score = 0;
  bool answered = false;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    final response =
        await http.get(Uri.parse('$scriptUrl?action=getQuestions'));
    final data = jsonDecode(response.body);
    data.shuffle();
    setState(() {
      questions = data.take(widget.numQuestions).toList();
    });
  }

  int getCorrectAnswerIndex(Map<String, dynamic> question) {
    switch (question['answer'].toUpperCase()) {
      case 'A':
        return 0;
      case 'B':
        return 1;
      case 'C':
        return 2;
      case 'D':
        return 3;
      default:
        return -1;
    }
  }

  void checkAnswer(int index) {
    if (answered) return;

    int correctIndex = getCorrectAnswerIndex(questions[currentIndex]);

    setState(() {
      selectedIndex = index;
      answered = true;
      if (index == correctIndex) {
        score++;
        _showAnswerPopup(true, correctIndex);
      } else {
        _showAnswerPopup(false, correctIndex);
      }
    });
  }

  void _showAnswerPopup(bool isCorrect, int correctIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isCorrect ? "✅ Correct Answer" : "❌ Wrong Answer"),
          content: Text(
            isCorrect
                ? "Good job! The answer is correct."
                : "The correct answer is: ${questions[currentIndex]['options'][correctIndex]}",
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                nextQuestion();
              },
              child: Text("Next Question"),
            ),
          ],
        );
      },
    );
  }

  Color getOptionColor(int index) {
    if (!answered) return Colors.blue;

    int correctIndex = getCorrectAnswerIndex(questions[currentIndex]);

    if (index == correctIndex) return Colors.green;
    if (index == selectedIndex) return Colors.red;
    return Colors.grey;
  }

  void nextQuestion() {
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedIndex = -1;
        answered = false;
      });
    } else {
      submitResult(score, questions.length);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(score: score, total: questions.length),
        ),
      );
    }
  }

  Future<void> submitResult(int score, int total) async {
    await http.get(Uri.parse(
        '$scriptUrl?action=submitResult&email=${widget.email}&score=$score&total=$total'));
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    var q = questions[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text("Quiz")),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Score: $score/${questions.length}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Q${currentIndex + 1}: ${q['question']}",
                style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            ...List.generate(4, (i) {
              return Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getOptionColor(i),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: answered ? null : () => checkAnswer(i),
                  child: Text(q['options'][i], style: TextStyle(fontSize: 16)),
                ),
              );
            }),
            SizedBox(height: 20),
            if (answered)
              Center(
                child: ElevatedButton(
                  onPressed: nextQuestion,
                  child: Text(currentIndex == questions.length - 1
                      ? "Finish"
                      : "Continue"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;

  const ResultScreen({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Result")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Quiz Complete!", style: TextStyle(fontSize: 24)),
            Text("Your Score: $score / $total", style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text("Restart"),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
