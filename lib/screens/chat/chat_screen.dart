import 'package:flutter/material.dart';
import '../../models/issue_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../models/private_chat_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isPrivateChat;
  final String title;
  final Issue? issue;
  final User? user;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.isPrivateChat,
    required this.title,
    this.issue,
    this.user,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late Stream<List<ChatMessage>> _messagesStream;
  late User _currentUser;

  @override
  void initState() {
    super.initState();

    if (widget.isPrivateChat) {
      _messagesStream = FirebaseService.getPrivateChatMessages(widget.chatId);
    } else {
      // For issue chats, we'll need to implement this later
      _messagesStream = Stream.value([]);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.user == null) {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _currentUser = args['user'] as User;
    } else {
      _currentUser = widget.user!;
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUser.id,
      content: _messageController.text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isRead: false,
    );

    if (widget.isPrivateChat) {
      await FirebaseService.sendPrivateMessage(widget.chatId, newMessage);
    } else if (widget.issue != null) {
      // For issue chats, we'll need to implement this later
      // await FirebaseService.sendMessage(widget.issue!.id, _messageController.text);
    }

    FocusScope.of(context).requestFocus(FocusNode()); // Refocus the input field
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUser.id;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.content,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : Colors.black54,
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => {
                      _sendMessage(),
                      _messageController.clear(),
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
