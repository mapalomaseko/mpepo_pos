class Invoice {
  final int id;
  final int receiptId;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? authorityResponse;
  final String status;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.receiptId,
    required this.payload,
    required this.authorityResponse,
    required this.status,
    required this.createdAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as int,
      receiptId: json['receipt_id'] as int,
      payload: Map<String, dynamic>.from(json['payload_json'] as Map),
      authorityResponse: json['authority_response_json'] == null
          ? null
          : Map<String, dynamic>.from(json['authority_response_json'] as Map),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class QueueJob {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String status;

  QueueJob({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    required this.status,
  });
}
