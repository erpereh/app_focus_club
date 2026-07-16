class CustomerSuggestionRequest {
  const CustomerSuggestionRequest({this.subject, required this.message});

  final String? subject;
  final String message;

  String? get normalizedSubject {
    final value = subject?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String get normalizedMessage => message.trim();

  Map<String, Object?> toPayload() {
    final payload = <String, Object?>{'message': normalizedMessage};
    final value = normalizedSubject;
    if (value != null) payload['subject'] = value;
    return payload;
  }
}
