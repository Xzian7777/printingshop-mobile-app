import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Data model for a merged customer + optional chat row
// ---------------------------------------------------------------------------
class _CustomerChatEntry {
  final String uid;
  final String fullName;
  final String email;
  final String customerId; // email prefix used as chat doc ID
  // Chat data (null = no conversation exists yet)
  final String? lastMessage;
  final Timestamp? lastUpdated;
  final bool hasUnread;
  final bool hasChat;

  _CustomerChatEntry({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.customerId,
    this.lastMessage,
    this.lastUpdated,
    this.hasUnread = false,
    this.hasChat = false,
  });
}

// ---------------------------------------------------------------------------
// AdminLiveChatView — shows all registered customers with optional chat data
// ---------------------------------------------------------------------------
class AdminLiveChatView extends StatefulWidget {
  const AdminLiveChatView({super.key});

  @override
  State<AdminLiveChatView> createState() => _AdminLiveChatViewState();
}

class _AdminLiveChatViewState extends State<AdminLiveChatView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  String _searchQuery = '';

  // Live streams
  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _chatsSub;

  List<Map<String, dynamic>> _users = [];
  Map<String, Map<String, dynamic>> _chatsById = {}; // keyed by customerId

  bool _usersLoaded = false;
  bool _chatsLoaded = false;
  String? _error;

  final CollectionReference _chatsRef = FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('chats');

  @override
  void initState() {
    super.initState();
    _subscribeUsers();
    _subscribeChats();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _chatsSub?.cancel();
    _searchController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _subscribeUsers() {
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _users = snap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {
              'uid': d.id,
              'full_name': (data['full_name'] ?? data['displayName'] ?? '').toString(),
              'email': (data['email'] ?? '').toString(),
            };
          }).toList();
          _usersLoaded = true;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _error = 'Failed to load customers: $e');
      },
    );
  }

  void _subscribeChats() {
    _chatsSub = _chatsRef
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        final map = <String, Map<String, dynamic>>{};
        for (final doc in snap.docs) {
          map[doc.id] = {
            ...(doc.data() as Map<String, dynamic>),
            '_docId': doc.id,
          };
        }
        setState(() {
          _chatsById = map;
          _chatsLoaded = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _chatsLoaded = true); // still show customers even if chats fail
      },
    );
  }

  // Build merged, sorted, filtered list
  List<_CustomerChatEntry> _buildEntries() {
    final entries = <_CustomerChatEntry>[];

    for (final u in _users) {
      final email = u['email'] as String;
      final customerId = email.contains('@') ? email.split('@').first : email;
      final chatData = _chatsById[customerId];

      final fullName = (u['full_name'] as String).isNotEmpty
          ? u['full_name'] as String
          : customerId;

      entries.add(_CustomerChatEntry(
        uid: u['uid'] as String,
        fullName: fullName,
        email: email,
        customerId: customerId,
        lastMessage: chatData?['lastMessage'] as String?,
        lastUpdated: chatData?['lastUpdated'] as Timestamp?,
        hasUnread: chatData?['unread'] == true,
        hasChat: chatData != null,
      ));
    }

    // Apply search filter
    final filtered = _searchQuery.isEmpty
        ? entries
        : entries.where((e) {
            return e.fullName.toLowerCase().contains(_searchQuery) ||
                e.email.toLowerCase().contains(_searchQuery);
          }).toList();

    // Sort: customers with chats first (by lastUpdated desc), then no-chat customers (by name asc)
    final withChat = filtered.where((e) => e.hasChat).toList()
      ..sort((a, b) {
        final at = a.lastUpdated?.millisecondsSinceEpoch ?? 0;
        final bt = b.lastUpdated?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

    final withoutChat = filtered.where((e) => !e.hasChat).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    return [...withChat, ...withoutChat];
  }

  // Format relative timestamp
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.80,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF312E81),
                        child: Text(
                          _initials(entry.fullName),
                          style: const TextStyle(
                            color: Colors.white,
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              entry.email,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Messages stream ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatsRef
                        .doc(entry.customerId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snap.error}',
                            style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                      }

                      final msgs = snap.data!.docs;

                      if (msgs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 36,
                                  color: Color(0xFF818CF8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Start a conversation with ${entry.fullName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Send a message below to begin chatting.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      // Mark as read when admin opens conversation
                      _chatsRef.doc(entry.customerId).update({'unread': false}).catchError((_) {});

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final mData = msgs[i].data() as Map<String, dynamic>;
                          final isAdmin = mData['sender'] == 'admin';
                          final text = (mData['text'] ?? '').toString();
                          final timeStr = (mData['time'] ?? '').toString();

                          return Align(
                            alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.72,
                              ),
                              child: Column(
                                crossAxisAlignment: isAdmin
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isAdmin ? 16 : 4),
                                        bottomRight: Radius.circular(isAdmin ? 4 : 16),
                                      ),
                                      border: isAdmin
                                          ? null
                                          : Border.all(color: const Color(0xFF334155), width: 0.8),
                                    ),
                                    child: Text(
                                      text,
                                      style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                                      child: Text(
                                        '${isAdmin ? 'You' : entry.fullName} • $timeStr',
                                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
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
                    color: Color(0xFF0F172A),
                    border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF070A14),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: TextField(
                            controller: _replyController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Type your reply...',
                              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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

    try {
      final chatDoc = _chatsRef.doc(entry.customerId);

      await chatDoc.collection('messages').add({
        'sender': 'admin',
        'text': txt,
        'time': timeStr,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatDoc.set({
        'customerName': entry.fullName,
        'email': entry.email,
        'lastMessage': 'Admin: $txt',
        'lastUpdated': FieldValue.serverTimestamp(),
        'unread': false,
        'customerUnread': true,
      }, SetOptions(merge: true));
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
              const Icon(Icons.error_outline, color: Color(0xFFF43F5E), size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ── Loading state ──
    if (!_usersLoaded || !_chatsLoaded) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    final entries = _buildEntries();
    final withChatCount = entries.where((e) => e.hasChat).length;
    final withoutChatCount = entries.where((e) => !e.hasChat).length;

    return Column(
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1224),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // ── Stats chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _statChip('${entries.length} Customers', const Color(0xFF1E293B), Colors.white),
              const SizedBox(width: 8),
              _statChip('$withChatCount Active', const Color(0xFF312E81), const Color(0xFF818CF8)),
              const SizedBox(width: 8),
              _statChip('$withoutChatCount New', const Color(0xFF0D2211), const Color(0xFF34D399)),
            ],
          ),
        ),

        // ── Customer list ──
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_search_rounded, size: 44, color: Color(0xFF64748B)),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty ? 'No registered customers yet.' : 'No customers match "$_searchQuery".',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];

                    // Section headers
                    final showActiveHeader = index == 0 && entry.hasChat;
                    final showNewHeader = !entry.hasChat &&
                        (index == 0 || entries[index - 1].hasChat);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showActiveHeader) ...[
                          _sectionHeader('Active Conversations', Icons.chat_bubble_rounded, const Color(0xFF818CF8)),
                          const SizedBox(height: 8),
                        ],
                        if (showNewHeader) ...[
                          if (withChatCount > 0) const SizedBox(height: 6),
                          _sectionHeader('All Customers', Icons.people_rounded, const Color(0xFF34D399)),
                          const SizedBox(height: 8),
                        ],
                        _buildCustomerTile(entry),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCustomerTile(_CustomerChatEntry entry) {
    final initials = _initials(entry.fullName);
    final hasUnread = entry.hasUnread;

    return GestureDetector(
      onTap: () => _openConversation(entry),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1224),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? const Color(0xFFF43F5E)
                : entry.hasChat
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFF1E293B),
            width: hasUnread ? 1.5 : 1.0,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: entry.hasChat
                    ? const Color(0xFF312E81)
                    : const Color(0xFF1E293B),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: entry.hasChat ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0D1224), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.lastUpdated != null)
                Text(
                  _formatTime(entry.lastUpdated),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              if (entry.hasChat)
                Text(
                  entry.lastMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasUnread ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                )
              else
                Row(
                  children: const [
                    Icon(Icons.add_comment_outlined, size: 11, color: Color(0xFF34D399)),
                    SizedBox(width: 4),
                    Text(
                      'No messages yet',
                      style: TextStyle(fontSize: 11, color: Color(0xFF34D399)),
                    ),
                  ],
                ),
              const SizedBox(height: 2),
              Text(
                entry.email,
                style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
        ),
      ),
    );
  }
}
