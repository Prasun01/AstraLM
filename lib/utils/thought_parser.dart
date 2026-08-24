class ThoughtParts {
  final String thought;
  final String answer;
  final bool isThinking;

  const ThoughtParts({
    required this.thought,
    required this.answer,
    required this.isThinking,
  });

  bool get hasThought => thought.trim().isNotEmpty;
  bool get hasAnswer => answer.trim().isNotEmpty;
}

ThoughtParts splitThoughtTags(String text, {bool isStreaming = false}) {
  final startExp = RegExp(r'<(think|thought|reasoning)>', caseSensitive: false);
  final endExp = RegExp(r'</(think|thought|reasoning)>', caseSensitive: false);
  final start = startExp.firstMatch(text);

  if (start == null) {
    return ThoughtParts(thought: '', answer: text, isThinking: false);
  }

  final before = text.substring(0, start.start);
  final afterStart = text.substring(start.end);
  final end = endExp.firstMatch(afterStart);

  if (end == null) {
    if (isStreaming) {
      return ThoughtParts(
        thought: afterStart,
        answer: before,
        isThinking: true,
      );
    }

    // Finished generation without closing tag: check for explicit conclusion separator
    final conclusionExp = RegExp(
      r'(\n\n(?:Final Answer|Conclusion|Therefore|In summary|Summary|Answer|Here is the|To summarize)[^\n]*\n[\s\S]*$)',
      caseSensitive: false,
    );
    final match = conclusionExp.firstMatch(afterStart);
    if (match != null) {
      final thoughtPart = afterStart.substring(0, match.start).trim();
      final answerPart = afterStart.substring(match.start).trim();
      return ThoughtParts(
        thought: thoughtPart,
        answer: '$before\n\n$answerPart'.trim(),
        isThinking: false,
      );
    }

    return ThoughtParts(
      thought: afterStart.trim(),
      answer: before.trim(),
      isThinking: false,
    );
  }

  final thought = afterStart.substring(0, end.start);
  final after = afterStart.substring(end.end);
  final answer = '$before$after'.trim();

  return ThoughtParts(
    thought: thought.trim(),
    answer: answer,
    isThinking: false,
  );
}
