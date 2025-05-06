import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart'; // Import flutter_html
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../Network/apicall.dart';
import 'login_page.dart';
import '../components/animation_dot.dart'; // Your AnimatedTypingDots widget

const _uuid = Uuid();

enum MessageStatus { sending, sent, failed }
enum MessageSender { me, bot, system }
enum MessageContentType { text, html } // To distinguish content type

class ChatMessage {
  final String id;
  String text; // Used for plain text or as a fallback/title for HTML
  String? htmlContent; // To store HTML string if any
  MessageContentType contentType; // Type of content
  final MessageSender sender;
  MessageStatus status;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.text,
    this.htmlContent,
    this.contentType = MessageContentType.text, // Default to text
    required this.sender,
    required this.status,
    DateTime? timestamp,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final _storage = const FlutterSecureStorage();
  String? _accessToken;
  bool _isLoadingDetails = true;
  Map<String, dynamic>? _userDetails;
  bool _isSendingMessageGlobal = false;
  bool _isBotTyping = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchDetails();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
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
  }

  Future<void> _loadTokenAndFetchDetails() async {
    // ... (no changes here)
    setState(() { _isLoadingDetails = true; });
    try {
      _accessToken = await _storage.read(key: 'access_token');
      if (_accessToken == null) {
        if(mounted) _logout();
        return;
      }
      await _fetchUserDetails();
    } catch (e) {
      if(mounted) _showErrorSnackbar("Failed to load authentication token.");
      if(mounted) _logout();
    } finally {
      if(mounted) setState(() { _isLoadingDetails = false; });
    }
  }

  Future<void> _fetchUserDetails() async {
    // ... (no changes here)
    if (_accessToken == null) return;
    try {
      final http.Response response = await ApiCall.fetchUserDetails(token: _accessToken!);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _userDetails = jsonDecode(response.body);
            _messages.insert(0, ChatMessage(
                id: _uuid.v4() + "_system",
                text: "Welcome, ${_userDetails?['username'] ?? 'User'}!",
                sender: MessageSender.system,
                status: MessageStatus.sent
            ));
          });
          _scrollToBottom();
        }
      } else if (response.statusCode == 401) {
        if(mounted) _showErrorSnackbar("Session expired. Please log in again.");
        if(mounted) _logout();
      } else {
        if(mounted) _showErrorSnackbar('Failed to load user data (Code: ${response.statusCode})');
      }
    } catch (e) {
      if(mounted) _showErrorSnackbar('Network error fetching user data: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    if (_accessToken == null) {
      _showErrorSnackbar("Authentication error. Cannot send message.");
      return;
    }

    final optimisticMessageId = _uuid.v4();
    final userMessage = ChatMessage(
      id: optimisticMessageId,
      text: messageText,
      sender: MessageSender.me,
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(userMessage);
      _isSendingMessageGlobal = true;
      _isBotTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    String? plainTextReply;
    String? htmlReply; // <<< To store potential HTML from backend
    bool messageSentSuccessfully = false;

    try {
      print("Calling API to send: $messageText");
      final response = await ApiCall.sendChatMessage(
        token: _accessToken!,
        message: messageText,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        messageSentSuccessfully = true;
        print("Message sent successfully via API. Body: ${response.body}");
        final responseBody = jsonDecode(response.body);

        // --- Check for HTML content first ---
        // Adjust 'html_response' and 'natural_language_response' based on your actual backend keys
        htmlReply = responseBody['html_response']; // Example key
        plainTextReply = responseBody['natural_language_response'] ?? responseBody['response']; // Fallback

        if (htmlReply != null && htmlReply.isNotEmpty) {
          print("Received HTML response from bot.");
        } else if (plainTextReply != null && plainTextReply.isNotEmpty) {
          print("Received plain text response from bot.");
        }

      } else {
        print("Failed to send message via API: ${response.statusCode} ${response.body}");
        if (mounted) _showErrorSnackbar("Failed to send message (Code: ${response.statusCode})");
      }
    } catch (e) {
      print("Error sending message API call: $e");
      if (mounted) _showErrorSnackbar("Network error sending message: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isBotTyping = false;
          _isSendingMessageGlobal = false;

          final int messageIndex = _messages.indexWhere((msg) => msg.id == optimisticMessageId);
          if (messageIndex != -1) {
            _messages[messageIndex].status = messageSentSuccessfully ? MessageStatus.sent : MessageStatus.failed;
          }

          if (messageSentSuccessfully) {
            if (htmlReply != null && htmlReply.isNotEmpty) {
              _messages.add(ChatMessage(
                text: plainTextReply ?? "View HTML content below", // Fallback text or title
                htmlContent: htmlReply,
                contentType: MessageContentType.html,
                sender: MessageSender.bot,
                status: MessageStatus.sent,
              ));
            } else if (plainTextReply != null && plainTextReply.isNotEmpty) {
              _messages.add(ChatMessage(
                text: plainTextReply,
                contentType: MessageContentType.text,
                sender: MessageSender.bot,
                status: MessageStatus.sent,
              ));
            } else {
              print("Received success status, but bot response was empty.");
              // Optionally add a generic error message for the user
              // _messages.add(ChatMessage(text: "Bot returned an empty response.", sender: MessageSender.system, status: MessageStatus.sent));
            }
          }
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _logout() async {
    // ... (no changes here)
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showErrorSnackbar(String message) {
    // ... (no changes here)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildMessageStatusIcon(ChatMessage message) {
    if (message.sender != MessageSender.me) return const SizedBox.shrink();
    switch (message.status) {
      case MessageStatus.sending:
        return const Padding( // Added missing CircularProgressIndicator
          padding: EdgeInsets.only(left: 8.0),
          child: SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey)),
          ),
        );
      case MessageStatus.failed:
        return const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Icon(Icons.error_outline, size: 15, color: Colors.red),
        );
      case MessageStatus.sent:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBotTypingIndicator() {
    // ... (no changes here)
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: AnimatedTypingDots(color: Colors.grey[600]),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoadingDetails ? 'Loading Chat...' : 'Chat - ${_userDetails?['username'] ?? 'User'}'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
        ],
      ),
      body: _isLoadingDetails // Added this check back from your original code
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10.0),
              itemCount: _messages.length + (_isBotTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isBotTyping && index == _messages.length) {
                  return _buildBotTypingIndicator();
                }
                final chatMessage = _messages[index];
                final bool isMe = chatMessage.sender == MessageSender.me;
                final bool isSystem = chatMessage.sender == MessageSender.system;

                Alignment messageAlignment;
                Color bubbleColor;
                TextStyle textStyle = const TextStyle(color: Colors.black87); // Default text color

                if (isMe) {
                  messageAlignment = Alignment.centerRight;
                  bubbleColor = Colors.blue[100]!;
                  if (chatMessage.status == MessageStatus.sending) {
                    textStyle = TextStyle(color: Colors.black.withOpacity(0.6), fontStyle: FontStyle.italic);
                  } else if (chatMessage.status == MessageStatus.failed) {
                    textStyle = TextStyle(color: Colors.black.withOpacity(0.7));
                  }
                } else if (isSystem) {
                  messageAlignment = Alignment.center;
                  bubbleColor = Colors.amber[100]!;
                  textStyle = const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 12);
                } else { // Bot
                  messageAlignment = Alignment.centerLeft;
                  bubbleColor = Colors.grey[300]!;
                }

                // --- Widget to display content (text or HTML) ---
                Widget messageContent;
                if (chatMessage.sender == MessageSender.bot &&
                    chatMessage.contentType == MessageContentType.html &&
                    chatMessage.htmlContent != null &&
                    chatMessage.htmlContent!.isNotEmpty) {
                  messageContent = Html(
                    data: chatMessage.htmlContent!,
                    style: { // Basic styling, customize as needed
                      "body": Style(margin: Margins.zero, padding: EdgeInsets.zero, fontSize: FontSize.medium),
                      "table": Style(backgroundColor: Colors.white, border: Border.all(color: Colors.grey.shade400)),
                      "th": Style(padding: const EdgeInsets.all(6), backgroundColor: Colors.grey.shade200),
                      "td": Style(padding: const EdgeInsets.all(6), alignment: Alignment.topLeft),
                    },
                    // You can add onLinkTap, onImageTap, etc.
                  );
                } else {
                  messageContent = Text(chatMessage.text, style: textStyle);
                }
                // --- End widget to display content ---

                return Align(
                  alignment: messageAlignment,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isSystem ? 0.9 : 0.75)),
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: [
                          if (chatMessage.contentType == MessageContentType.html && chatMessage.sender == MessageSender.bot)
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            )
                        ]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(child: messageContent), // Use the conditional content widget
                        if(chatMessage.sender == MessageSender.me) // Only show status for user's messages
                          _buildMessageStatusIcon(chatMessage),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
            color: Theme.of(context).cardColor,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration.collapsed(hintText: 'Enter your message...'),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _isSendingMessageGlobal ? null : (_) => _sendMessage(),
                    enabled: !_isSendingMessageGlobal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _isSendingMessageGlobal ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}