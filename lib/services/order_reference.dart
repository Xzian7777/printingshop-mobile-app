import 'dart:math';

String generateOrderReference({Random? random}) {
  final number = (random ?? Random.secure()).nextInt(1000000);
  return 'PRNT-${number.toString().padLeft(6, '0')}';
}

bool isSameOrderSubmission(
    Map<String, dynamic> existing, Map<String, dynamic> incoming) {
  if (existing['email'] != incoming['email']) return false;
  final submissionId = incoming['submissionId'];
  if (submissionId is String && submissionId.isNotEmpty) {
    return existing['submissionId'] == submissionId;
  }
  // A legacy queued order can only be a retry of another legacy record.
  return existing['submissionId'] == null;
}
