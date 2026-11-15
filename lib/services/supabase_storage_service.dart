import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'loyalty_api.dart';
import 'package:http/http.dart' as http;

class SupabaseStorageService {
  // Upload limits conforming to website specification
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxTotalSizeBytes = 25 * 1024 * 1024; // 25 MB
  static const int maxFilesCount = 5;
  static const int maxFilenameLength = 150;
  static const List<String> allowedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'doc',
    'docx'
  ];

  /// Validates a single file against limits
  static String? validateFile(File file, String filename) {
    if (!file.existsSync()) {
      return 'File does not exist.';
    }

    final int size = file.lengthSync();
    if (size == 0) {
      return 'Selected file is empty.';
    }

    if (size > maxFileSizeBytes) {
      return 'File size exceeds 10MB limit (${(size / (1024 * 1024)).toStringAsFixed(1)}MB).';
    }

    final String extension = filename.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      return 'Unsupported file format ($extension). Allowed formats: PDF, PNG, JPG, JPEG, DOC, DOCX.';
    }

    if (filename.length > maxFilenameLength) {
      return 'Filename is too long (maximum 150 characters).';
    }

    return null;
  }

  /// Sanitizes filename to prevent directory traversal and special character issues
  static String sanitizeFilename(String filename) {
    // Remove unsafe characters, keep alphanumeric, dots, underscores, dashes
    String cleaned = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    // Collapse multiple underscores
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '_');
    if (cleaned.length > maxFilenameLength) {
      final ext = cleaned.contains('.') ? '.${cleaned.split('.').last}' : '';
      cleaned = cleaned.substring(0, maxFilenameLength - ext.length) + ext;
    }
    return cleaned;
  }

  /// Upload through the authenticated shop backend.
  static Future<String> uploadFile({
    required File file,
    required String originalFilename,
    String? orderId,
    String purpose = 'document',
  }) async {
    final error = validateFile(file, originalFilename);
    if (error != null) throw StateError(error);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before uploading a file.');
    if (LoyaltyApi.baseUrl.isEmpty) {
      throw StateError('The shop server URL is missing.');
    }
    final prepared = await LoyaltyApi.call('/api/uploads/prepare', method: 'POST', data: {
      'submissionId': LoyaltyApi.submissionId(),
      'purpose': purpose,
      'files': [{'name': sanitizeFilename(originalFilename), 'size': await file.length()}],
    });
    final ticket = Map<String, dynamic>.from((prepared['files'] as List).first as Map);
    if (ticket['result'] is Map) return ticket['result']['fileUrl'] as String;
    final uploadUri = Uri.parse(ticket['uploadUrl'] as String);
    if (uploadUri.scheme != 'https' || !uploadUri.path.startsWith('/storage/v1/object/upload/sign/')) {
      throw StateError('The shop server returned an invalid cloud upload address.');
    }
    final request = http.MultipartRequest('PUT', uploadUri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path,
          filename: sanitizeFilename(originalFilename)));
    final response = await http.Response.fromStream(await request.send())
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Cloud storage upload failed. Please retry.');
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await LoyaltyApi.call('/api/uploads/finalize', method: 'POST',
            data: {'fileId': ticket['fileId']});
        return result['fileUrl'] as String;
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw StateError('Unable to verify the uploaded file. Please retry.');
  }
}
