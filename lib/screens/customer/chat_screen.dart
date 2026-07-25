import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/constants.dart';

class ChatScreen extends StatefulWidget {
  final int orderId;
  final String otherUserName;
  const ChatScreen({Key? key, required this.orderId, required this.otherUserName}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final List<dynamic> _messages = [];
  Timer? _timer;
  int? _myId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _fetchMessages();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _fetchMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString(AppConstants.keyUserData) ?? '{}');
    setState(() => _myId = userData['id']);
  }

  Future<void> _fetchMessages() async {
    if (_myId == null) return;
    try {
      final response = await ApiService.get('messages?order_id=${widget.orderId}&user_id=$_myId');
      if (response['success'] == true) {
        final List newMsgs = response['data'];
        if (newMsgs.length != _messages.length) {
          setState(() {
            _messages.clear();
            _messages.addAll(newMsgs);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Chat error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _myId == null) return;
    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      await ApiService.post('messages', {
        'order_id': widget.orderId,
        'sender_id': _myId,
        'message': text,
      });
      _fetchMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                bool isMe = m['sender_id'].toString() == _myId.toString();
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 16),
                      ),
                    ),
                    child: Text(
                      m['message'],
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF2563EB),
                    child: Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
