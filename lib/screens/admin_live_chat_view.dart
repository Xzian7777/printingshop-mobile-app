import '../services/app_notifications.dart';
import '../services/profile_directory.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// Returns safe Firestore conversation document ID matching Flask backend:
/// re.sub(r'[^a-zA-Z0-9]', '_', email.strip().lower()) -> f"conv_{safe_email}"
String getSafeConversationId(String email) {
  if (email.isEmpty) return 'conv_general';
  final safeEmail =
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  return 'conv_$safeEmail';
}

// ---------------------------------------------------------------------------
// Data model for a merged customer + optional conversation row
// ---------------------------------------------------------------------------
class _CustomerChatEntry {
  final String uid;
  final String fullName;
  final String email;
  final String convId; // conv_{safe_email}
  final String? lastMessage;
  final String? lastMessageAt;
  final bool hasUnread;
  final bool hasChat;

  _CustomerChatEntry({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.convId,
    this.lastMessage,
    this.lastMessageAt,
    this.hasUnread = false,
    this.hasChat = false,
  });
}

// ---------------------------------------------------------------------------
// AdminLiveChatView — shows all registered customers with real conversations
// ---------------------------------------------------------------------------
class AdminLiveChatView extends StatefulWidget {
  final String? initialConversationId;
  const AdminLiveChatView({super.key, this.initialConversationId});

  @override
  State<AdminLiveChatView> createState() => _AdminLiveChatViewState();
}

class _AdminLiveChatViewState extends State<AdminLiveChatView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  String _searchQuery = '';
  bool _initialOpened = false;

  // Live streams
  StreamSubscription<List<ProfileRecord>>? _usersSub;
  StreamSubscription<QuerySnapshot>? _convsSub;

  List<Map<String, dynamic>> _users = [];
  Map<String, Map<String, dynamic>> _convsByEmail = {}; // keyed by clean email

  bool _usersLoaded = false;
  bool _convsLoaded = false;
  String? _error;

  final CollectionReference _conversationsRef =
      FirebaseFirestore.instance.collection('conversations');

  @override
  void initState() {
    super.initState();
    _subscribeUsers();
    _subscribeConversations();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _convsSub?.cancel();
    _searchController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _subscribeUsers() {
    _usersSub = watchProfiles().listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _users = snap
              .where((d) =>
                  d.data()['role'] != 'admin' && d.data()['archived'] != true)
              .map((d) {
            final data = d.data();
            return {
              'uid': d.id,
              'full_name': (data['fullName'] ??
                      data['full_name'] ??
                      data['displayName'] ??
                      '')
                  .toString(),
              'email': (data['email'] ?? '').toString(),
            };
          }).toList();
          _usersLoaded = true;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Error loading customer users: $e';
          _usersLoaded = true;
        });
      },
    );
  }

  void _subscribeConversations() {
    _convsSub = _conversationsRef.snapshots().listen(
      (snap) {
        if (!mounted) return;
        final map = <String, Map<String, dynamic>>{};
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final cEmail =
              (data['customerEmail'] ?? '').toString().trim().toLowerCase();
          if (cEmail.isNotEmpty) {
            map[cEmail] = {
              ...data,
              '_docId': doc.id,
            };
          }
        }
        setState(() {
          _convsByEmail = map;
          _convsLoaded = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _convsLoaded = true);
      },
    );
  }

  // Build merged, sorted, filtered list
  List<_CustomerChatEntry> _buildEntries() {
    final entries = <_CustomerChatEntry>[];
    final seenEmails = <String>{};

    for (final u in _users) {
      final email = (u['email'] as String).trim().toLowerCase();
      if (email.isEmpty) continue;
      seenEmails.add(email);

      final convData = _convsByEmail[email];
      final convId =
          convData?['_docId'] as String? ?? getSafeConversationId(email);

      final fullName = (u['full_name'] as String).isNotEmpty
          ? u['full_name'] as String
          : (convData?['customerName'] ?? email.split('@').first).toString();

      final lastMsg = convData?['lastMessage'] as String?;
      final lastMsgAt =
          (convData?['lastMessageAt'] ?? convData?['updatedAt']) as String?;
      final unreadAdmin = (convData?['unreadCountAdmin'] as num? ?? 0) > 0 ||
          convData?['unread'] == true;
      final hasChat = lastMsg != null && lastMsg.isNotEmpty;

      entries.add(_CustomerChatEntry(
        uid: u['uid'] as String,
        fullName: fullName,
        email: email,
        convId: convId,
        lastMessage: lastMsg,
        lastMessageAt: lastMsgAt,
        hasUnread: unreadAdmin,
        hasChat: hasChat,
      ));
    }

    // Also include any conversation present in Firestore that might not have a mobile users doc
    _convsByEmail.forEach((cEmail, convData) {
      if (!seenEmails.contains(cEmail)) {
        final lastMsg = convData['lastMessage'] as String?;
        final lastMsgAt =
            (convData['lastMessageAt'] ?? convData['updatedAt']) as String?;
        final unreadAdmin = (convData['unreadCountAdmin'] as num? ?? 0) > 0 ||
            convData['unread'] == true;
        final hasChat = lastMsg != null && lastMsg.isNotEmpty;

        entries.add(_CustomerChatEntry(
          uid: convData['customerId']?.toString() ?? cEmail,
          fullName:
              (convData['customerName'] ?? cEmail.split('@').first).toString(),
          email: cEmail,
          convId:
              (convData['_docId'] ?? getSafeConversationId(cEmail)).toString(),
          lastMessage: lastMsg,
          lastMessageAt: lastMsgAt,
          hasUnread: unreadAdmin,
          hasChat: hasChat,
        ));
      }
    });

    // Apply search filter
    final filtered = _searchQuery.isEmpty
        ? entries
        : entries.where((e) {
            return e.fullName.toLowerCase().contains(_searchQuery) ||
                e.email.toLowerCase().contains(_searchQuery);
          }).toList();

    // Sort: customers with chats first (by lastMessageAt desc), then no-chat customers (by name asc)
    final withChat = filtered.where((e) => e.hasChat).toList()
      ..sort((a, b) {
        final at = a.lastMessageAt ?? '';
        final bt = b.lastMessageAt ?? '';
        return bt.compareTo(at);
      });

    final withoutChat = filtered.where((e) => !e.hasChat).toList()
      ..sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    return [...withChat, ...withoutChat];
  }

  // Format relative timestamp from ISO String
  String _formatTime(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // Initials avatar
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Open conversation modal bottom sheet
  void _openConversation(_CustomerChatEntry entry) {
    _replyController.clear();

    // Mark as read when admin opens conversation
    _conversationsRef.doc(entry.convId).set({
      'unreadCountAdmin': 0,
      'unread': false,
    }, SetOptions(merge: true)).catchError((_) {});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.80,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFFBBF7D0))),
            ),
            child: Column(
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFBBF7D0))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF166534),
                        child: Text(
                          _initials(entry.fullName),
                          style: const TextStyle(
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.fullName,
                              style: const TextStyle(
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              entry.email,
                              style: const TextStyle(
                                color: Color(0xFF4B7A5E),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF4B7A5E)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Messages stream ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _conversationsRef
                        .doc(entry.convId)
                        .collection('messages')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snap.error}',
                            style: const TextStyle(
                                color: Color(0xFFF43F5E), fontSize: 12),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF16A34A)));
                      }

                      final rawDocs = snap.data!.docs;

                      // Sort ascending so newest messages are at the bottom of ListView (reverse: true)
                      final sortedDocs =
                          List<QueryDocumentSnapshot>.from(rawDocs)
                            ..sort((a, b) {
                              final da = a.data() as Map<String, dynamic>;
                              final db = b.data() as Map<String, dynamic>;
                              final ta =
                                  (da['createdAt'] ?? da['timestamp'] ?? '')
                                      .toString();
                              final tb =
                                  (db['createdAt'] ?? db['timestamp'] ?? '')
                                      .toString();
                              return tb.compareTo(ta);
                            });

                      if (sortedDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 36,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Start a conversation with ${entry.fullName}',
                                style: const TextStyle(
                                  color: Color(0xFF14532D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Send a message below to begin chatting.',
                                style: TextStyle(
                                    color: Color(0xFF4B7A5E), fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: sortedDocs.length,
                        itemBuilder: (context, i) {
                          final mData =
                              sortedDocs[i].data() as Map<String, dynamic>;
                          final senderRole = (mData['senderRole'] ??
                                  mData['sender'] ??
                                  'customer')
                              .toString()
                              .toLowerCase();
                          final isAdmin =
                              senderRole == 'admin' || senderRole == 'staff';
                          final text = (mData['text'] ?? mData['message'] ?? '')
                              .toString();
                          final timeStr = (mData['time'] ?? '').toString();
                          final senderName = (mData['senderName'] ??
                                  (isAdmin ? 'You (Staff)' : entry.fullName))
                              .toString();

                          return Align(
                            alignment: isAdmin
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72,
                              ),
                              child: Column(
                                crossAxisAlignment: isAdmin
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFBBF7D0),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft:
                                            Radius.circular(isAdmin ? 16 : 4),
                                        bottomRight:
                                            Radius.circular(isAdmin ? 4 : 16),
                                      ),
                                      border: isAdmin
                                          ? null
                                          : Border.all(
                                              color: const Color(0xFF334155),
                                              width: 0.8),
                                    ),
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                          color: Color(0xFF14532D),
                                          fontSize: 12.5,
                                          height: 1.4),
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 3, left: 4, right: 4),
                                      child: Text(
                                        '$senderName • $timeStr',
                                        style: const TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF4B7A5E)),
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

                // ── Reply input ──
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
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
                            controller: _replyController,
                            style: const TextStyle(
                                color: Color(0xFF14532D), fontSize: 13),
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Type your reply...',
                              hintStyle: TextStyle(
                                  fontSize: 12, color: Color(0xFF4B7A5E)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendReply(entry),
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
                              color: const Color(0xFF16A34A)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: Color(0xFF14532D), size: 18),
                          onPressed: () => _sendReply(entry),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendReply(_CustomerChatEntry entry) async {
    final txt = _replyController.text.trim();
    if (txt.isEmpty) return;
    _replyController.clear();

    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';
    final nowIso = now.toIso8601String();

    try {
      final convDoc = _conversationsRef.doc(entry.convId);
      final msgId =
          'msg_${now.millisecondsSinceEpoch}_${math.Random().nextInt(999999).toString().padLeft(6, '0')}';

      final batch = FirebaseFirestore.instance.batch();
      batch.set(convDoc.collection('messages').doc(msgId), {
        'id': msgId,
        'conversationId': entry.convId,
        'senderId': 'admin@kczprint.com',
        'senderRole': 'admin',
        'senderName': 'Staff',
        'sender': 'admin', // compatibility
        'message': txt,
        'text': txt,
        'time': timeStr,
        'createdAt': nowIso,
        'timestamp': nowIso,
        'read': false,
      });

      batch.set(
          convDoc,
          {
            'id': entry.convId,
            'customerName': entry.fullName,
            'customerEmail': entry.email,
            'lastMessage': txt.length > 120 ? txt.substring(0, 120) : txt,
            'lastMessageSender': 'admin',
            'lastMessageSenderName': 'Staff',
            'lastMessageAt': nowIso,
            'updatedAt': nowIso,
            'unreadCountAdmin': 0,
            'unreadCountCustomer': FieldValue.increment(1),
            'unread': false,
            'customerUnread': true,
          },
          SetOptions(merge: true));
      batch.set(
          FirebaseFirestore.instance.collection('push_jobs').doc('chat_$msgId'),
          {
            'type': 'chat',
            'conversationId': entry.convId,
            'messageId': msgId,
            'state': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
      batch.set(FirebaseFirestore.instance.collection('notifications').doc('chat_$msgId'),
        notificationRecord(id: 'chat_$msgId', recipient: entry.email.toLowerCase(),
          email: entry.email, title: 'New reply from KCZ Printing',
          message: txt.substring(0, txt.length > 300 ? 300 : txt.length),
          type: 'chat', messageId: msgId, conversationId: entry.convId, link: '/customer?tab=chat'));
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Error state ──
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFF43F5E), size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _usersLoaded = false;
                    _convsLoaded = false;
                  });
                  _subscribeUsers();
                  _subscribeConversations();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                ),
                child:
                    const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // ── Loading state ──
    if (!_usersLoaded || !_convsLoaded) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF16A34A)));
    }

    final entries = _buildEntries();
    if (!_initialOpened && widget.initialConversationId != null) {
      final matches = entries.where((entry) => entry.convId == widget.initialConversationId);
      if (matches.isNotEmpty) {
        _initialOpened = true;
        final entry = matches.first;
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _openConversation(entry); });
      }
    }

    return Column(
      children: [
        // ── Search & Header bar ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF0FDF4),
            border: Border(bottom: BorderSide(color: Color(0xFFBBF7D0))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_rounded,
                      color: Color(0xFF15803D), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Customer Chat',
                    style: TextStyle(
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFF16A34A).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${entries.length} registered',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search customer name or email...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF4B7A5E), size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Color(0xFF4B7A5E), size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FFF9),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF16A34A)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Customer List ──
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.people_outline,
                        color: const Color(0xFF86EFAC),
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No customers match "$_searchQuery"'
                            : 'No registered customers found.',
                        style: const TextStyle(
                            color: Color(0xFF4B7A5E), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFF111827),
                    indent: 68,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final timeText = _formatTime(entry.lastMessageAt);

                    return InkWell(
                      onTap: () => _openConversation(entry),
                      splashColor:
                          const Color(0xFF16A34A).withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // ── Avatar ──
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: entry.hasChat
                                      ? const Color(0xFF166534)
                                      : const Color(0xFFBBF7D0),
                                  child: Text(
                                    _initials(entry.fullName),
                                    style: TextStyle(
                                      color: entry.hasChat
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF4B7A5E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (entry.hasUnread)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF43F5E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // ── Name & Last message / No messages yet ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.fullName,
                                          style: TextStyle(
                                            color: Color(0xFF14532D),
                                            fontWeight: entry.hasUnread
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (timeText.isNotEmpty)
                                        Text(
                                          timeText,
                                          style: TextStyle(
                                            color: entry.hasUnread
                                                ? const Color(0xFF15803D)
                                                : const Color(0xFF86EFAC),
                                            fontSize: 10,
                                            fontWeight: entry.hasUnread
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.hasChat
                                              ? (entry.lastMessage ?? '')
                                              : 'No messages yet',
                                          style: TextStyle(
                                            color: entry.hasChat
                                                ? (entry.hasUnread
                                                    ? Colors.white
                                                    : const Color(0xFF4B7A5E))
                                                : const Color(0xFF86EFAC),
                                            fontSize: 11.5,
                                            fontStyle: entry.hasChat
                                                ? FontStyle.normal
                                                : FontStyle.italic,
                                            fontWeight: entry.hasUnread
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (entry.hasUnread)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF43F5E),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'NEW',
                                            style: TextStyle(
                                              color: Color(0xFF14532D),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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
    );
  }
}
