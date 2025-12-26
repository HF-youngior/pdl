import 'mbti_question.dart';
import 'mbti_test_result.dart';

class MbtiTestSession {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<MbtiTestAnswer> answers;
  final MbtiTestResult? result;
  final bool isCompleted;
  final int currentQuestionIndex;
  final int totalQuestions;

  const MbtiTestSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.answers,
    this.result,
    required this.isCompleted,
    required this.currentQuestionIndex,
    required this.totalQuestions,
  });

  factory MbtiTestSession.createNew(int totalQuestions) {
    return MbtiTestSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      answers: [],
      isCompleted: false,
      currentQuestionIndex: 0,
      totalQuestions: totalQuestions,
    );
  }

  factory MbtiTestSession.fromJson(Map<String, dynamic> json) {
    return MbtiTestSession(
      sessionId: json['sessionId'] ?? '',
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      answers: (json['answers'] as List<dynamic>?)
          ?.map((answer) => MbtiTestAnswer.fromJson(answer))
          .toList() ?? [],
      result: json['result'] != null ? MbtiTestResult.fromJson(json['result']) : null,
      isCompleted: json['isCompleted'] ?? false,
      currentQuestionIndex: json['currentQuestionIndex'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 93,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'answers': answers.map((answer) => answer.toJson()).toList(),
      'result': result?.toJson(),
      'isCompleted': isCompleted,
      'currentQuestionIndex': currentQuestionIndex,
      'totalQuestions': totalQuestions,
    };
  }

  // 添加答案
  MbtiTestSession addAnswer(MbtiTestAnswer answer) {
    final newAnswers = List<MbtiTestAnswer>.from(answers);
    
    // 检查是否已存在该题目的答案，如果存在则替换
    final existingIndex = newAnswers.indexWhere(
      (existingAnswer) => existingAnswer.questionNumber == answer.questionNumber
    );
    
    if (existingIndex >= 0) {
      newAnswers[existingIndex] = answer;
    } else {
      newAnswers.add(answer);
    }

    // 将questionNumber（1-based）转换为数组索引（0-based）
    final newCurrentIndex = answer.questionNumber - 1;
    final isTestCompleted = newCurrentIndex >= totalQuestions - 1;

    return MbtiTestSession(
      sessionId: sessionId,
      startTime: startTime,
      endTime: isTestCompleted ? DateTime.now() : endTime,
      answers: newAnswers,
      result: result,
      isCompleted: isTestCompleted,
      currentQuestionIndex: newCurrentIndex,
      totalQuestions: totalQuestions,
    );
  }

  // 完成测试并设置结果
  MbtiTestSession completeWithResult(MbtiTestResult testResult) {
    return MbtiTestSession(
      sessionId: sessionId,
      startTime: startTime,
      endTime: DateTime.now(),
      answers: answers,
      result: testResult,
      isCompleted: true,
      currentQuestionIndex: currentQuestionIndex,
      totalQuestions: totalQuestions,
    );
  }

  // 获取进度百分比
  double get progressPercentage {
    return (currentQuestionIndex / totalQuestions) * 100;
  }

  // 获取已回答的题目数量
  int get answeredQuestionsCount {
    return answers.length;
  }

  // 获取剩余题目数量
  int get remainingQuestionsCount {
    return totalQuestions - currentQuestionIndex;
  }

  // 检查特定题目是否已回答
  bool isQuestionAnswered(int questionNumber) {
    return answers.any((answer) => answer.questionNumber == questionNumber);
  }

  // 获取特定题目的答案
  MbtiTestAnswer? getAnswerForQuestion(int questionNumber) {
    try {
      return answers.firstWhere((answer) => answer.questionNumber == questionNumber);
    } catch (e) {
      return null;
    }
  }

  // 获取测试持续时间
  Duration get testDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  // 获取格式化的测试持续时间
  String get formattedDuration {
    final duration = testDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}分${seconds}秒';
  }
}
