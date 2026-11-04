import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// Returns safe Firestore conversation document ID matching Flask backend:
/// re.sub(r'[^a-zA-Z0-9]', '_', email.strip().lower()) -> f"conv_{safe_email}"
String getSafeConversationId(String email) {
  if (email.isEmpty) return 'conv_general';
  final safeEmail = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  return 'conv_$safeEmail';
}

class CustomerChatScreen extends StatefulWidget {
  final String userEmail;

  const CustomerChatScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  late final String _convId;
  late final String _customerEmailClean;
  late final String _customerName;

  CollectionReference get _conversationsRef =>
      FirebaseFirestore.instance.collection('conversations');

  @override
  void initState() {
    super.initState();
    _customerEmailClean = widget.userEmail.trim().toLowerCase();
    _convId = getSafeConversationId(_customerEmailClean);
    _customerName = _customerEmailClean.contains('@')
        ? _customerEmailClean.split('@').first
        : _customerEmailClean;

    // Mark customer unread count to 0 and update read flags
    _markConversationAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markConversationAsRead() async {
    try {
      final convDoc = _conversationsRef.doc(_convId);
      final snapshot = await convDoc.get();

      if (snapshot.exists) {
        await convDoc.update({
          'unreadCountCustomer': 0,
          'customerUnread': false,
        });
      } else {
        // Initialize the conversation document matching the web backend structure
        final nowIso = DateTime.now().toIso8601String();
        await convDoc.set({
          'id': _convId,
          'customerId': 'CUST-${DateTime.now().millisecondsSinceEpoch}',
          'customerEmail': _customerEmailClean,
          'customerName': _customerName,
          'customerPhone': '',
          'lastMessage': '',
          'lastMessageSender': '',
          'lastMessageSenderName': '',
          'lastMessageAt': nowIso,
          'updatedAt': nowIso,
          'createdAt': nowIso,
          'unreadCountAdmin': 0,
          'unreadCountCustomer': 0,
          'customerUnread': false,
        }, SetOptions(merge: true));
      }

      // Mark unread admin messages as read in subcollection
      final unreadSnap = await convDoc
          .collection('messages')
          .where('senderRole', whereIn: ['admin', 'staff'])
          .where('read', isEqualTo: false)
          .get();

      for (final doc in unreadSnap.docs) {
        doc.reference.update({
          'read': true,
          'readAt': DateTime.now().toIso8601String(),
        }).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (text.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message too long (max 1000 characters).'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final timeFormatted = _formatTime(now);

      final msgId = 'msg_${now.millisecondsSinceEpoch}_${math.Random().nextInt(999999).toString().padLeft(6, '0')}';
      final convDoc = _conversationsRef.doc(_convId);

      // Save message to messages subcollection matching web schema
      final msgData = {
        'id': msgId,
        'conversationId': _convId,
        'senderId': _customerEmailClean,
        'senderRole': 'customer',
        'senderName': _customerName,
        'sender': 'customer', // backward compatibility
        'message': text,
        'text': text,
        'time': timeFormatted,
        'createdAt': nowIso,
        'timestamp': nowIso,
        'read': false,
      };

      await convDoc.collection('messages').doc(msgId).set(msgData);

      // Update thread metadata for web Admin inbox
      await convDoc.set({
        'id': _convId,
        'customerEmail': _customerEmailClean,
        'customerName': _customerName,
        'lastMessage': text.length > 120 ? text.substring(0, 120) : text,
        'lastMessageSender': 'customer',
        'lastMessageSenderName': _customerName,
        'lastMessageAt': nowIso,
        'updatedAt': nowIso,
        'unreadCountAdmin': FieldValue.increment(1),
        'unreadCountCustomer': 0,
        'unread': true, // compatibility flag
        'customerUnread': false,
      }, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0FDF4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF14532D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Color(0xFF14532D), size: 20),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF0FDF4), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'KCZ Support Team',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Live Customer Support • Online',
                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFBBF7D0)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Helpful customer welcome badge
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF15803D)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ask about print pricing, paper specs, rush orders, or file checks.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF4B7A5E)),
                    ),
                  ),
                ],
              ),
            ),

            // Message Stream from conversations/{conv_id}/messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _conversationsRef
                    .doc(_convId)
                    .collection('messages')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Connection error: ${snapshot.error}',
                          style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                    );
                  }

                  final rawDocs = snapshot.data?.docs ?? [];

                  // Sort client-side by createdAt / timestamp ascending
                  final sortedDocs = List<QueryDocumentSnapshot>.from(rawDocs)
                    ..sort((a, b) {
                      final da = a.data() as Map<String, dynamic>;
                      final db = b.data() as Map<String, dynamic>;
                      final ta = (da['createdAt'] ?? da['timestamp'] ?? '').toString();
                      final tb = (db['createdAt'] ?? db['timestamp'] ?? '').toString();
                      return tb.compareTo(ta); // newest at index 0 for reverse ListView
                    });

                  if (sortedDocs.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 44, color: Color(0xFF15803D)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Start a conversation with our Print Staff',
                              style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Send a message below. Our shop administrators will assist you in real time.',
                              style: TextStyle(color: Color(0xFF4B7A5E), fontSize: 11.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // newest messages at bottom
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      final data = sortedDocs[index].data() as Map<String, dynamic>;
                      final senderRole = (data['senderRole'] ?? data['sender'] ?? 'customer').toString().toLowerCase();
                      final isMe = senderRole == 'customer';
                      final text = (data['text'] ?? data['message'] ?? '').toString();
                      final timeStr = (data['time'] ?? 'Just now').toString();
                      final senderName = (data['senderName'] ?? (isMe ? 'You' : 'Staff')).toString();

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.76,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF16A34A) : const Color(0xFFBBF7D0),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: isMe ? null : Border.all(color: const Color(0xFF334155), width: 0.8),
                                ),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : const Color(0xFF14532D),
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  "${isMe ? 'You' : senderName} • $timeStr",
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF4B7A5E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                border: Border(top: BorderSide(color: Color(0xFFBBF7D0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FFF9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF4B7A5E)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF16A34A)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Color(0xFF14532D), strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
