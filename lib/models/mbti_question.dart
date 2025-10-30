class MbtiQuestion {
  final String question;
  final List<String> options;
  final String dimension; // EI, SN, TF, JP
  final int questionNumber;

  const MbtiQuestion({
    required this.question,
    required this.options,
    required this.dimension,
    required this.questionNumber,
  });

  factory MbtiQuestion.fromJson(Map<String, dynamic> json) {
    return MbtiQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      dimension: json['dimension'] ?? '',
      questionNumber: json['questionNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'dimension': dimension,
      'questionNumber': questionNumber,
    };
  }
}

class MbtiTestAnswer {
  final int questionNumber;
  final int selectedOption; // 0 or 1
  final String dimension;
  final DateTime answeredAt;

  const MbtiTestAnswer({
    required this.questionNumber,
    required this.selectedOption,
    required this.dimension,
    required this.answeredAt,
  });

  factory MbtiTestAnswer.fromJson(Map<String, dynamic> json) {
    return MbtiTestAnswer(
      questionNumber: json['questionNumber'] ?? 0,
      selectedOption: json['selectedOption'] ?? 0,
      dimension: json['dimension'] ?? '',
      answeredAt: DateTime.parse(json['answeredAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionNumber': questionNumber,
      'selectedOption': selectedOption,
      'dimension': dimension,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }
}
