import 'package:flutter/material.dart';
import '../../models/issue_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  late Issue _currentIssue;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize with some mock messages
    _messages.addAll([
      ChatMessage(
        id: 'msg_1',
        issueId: 'issue_1',
        senderId: 'operator_1',
        content: 'The temperature sensor is giving erratic readings',
        type: MessageType.text,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'msg_2',
        issueId: 'issue_1',
        senderId: 'maintenance_1',
        content: 'Can you check if the sensor cable is properly connected?',
        type: MessageType.text,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    _currentIssue = args['issue'] as Issue;
    _currentUser = args['user'] as User;
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      issueId: _currentIssue.id,
      senderId: _currentUser.id,
      content: _messageController.text,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${_currentIssue.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == _currentUser.id;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                          message.timestamp.toString().substring(11, 16),
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
                    onSubmitted: (_) => _sendMessage(),
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
