import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:uuid/uuid.dart';

import '../Network/apicall.dart';
import 'login_page.dart';
import '../components/animation_dot.dart';

const _uuid = Uuid();

enum MessageStatus { sending, sent, failed }
enum MessageSender { me, bot, system }
enum MessageType { text, html }

class ChatMessage {
  final String id;
  String text;
  String? htmlContent;
  final MessageSender sender;
  final MessageType type;
  MessageStatus status;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.text,
    this.htmlContent,
    required this.sender,
    this.type = MessageType.text,
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

    String? botReplyText;
    String? botHtmlContent;
    bool messageSentSuccessfully = false;

    try {
      final response = await ApiCall.sendChatMessage(
        token: _accessToken!,
        message: messageText,
        format: "html",
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        messageSentSuccessfully = true;
        final responseBody = jsonDecode(response.body);
        botReplyText = responseBody['response'];
        botHtmlContent = responseBody['html_response'];
      } else {
        if (mounted) _showErrorSnackbar("Failed to send message (Code: ${response.statusCode})");
      }
    } catch (e) {
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

          if (messageSentSuccessfully && (botReplyText != null || botHtmlContent != null)) {
            _messages.add(ChatMessage(
              text: botReplyText ?? "See detailed results below",
              htmlContent: botHtmlContent,
              sender: MessageSender.bot,
              type: botHtmlContent != null ? MessageType.html : MessageType.text,
              status: MessageStatus.sent,
            ));
          }
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _logout() async {
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildMessageStatusIcon(ChatMessage message) {
    if (message.sender != MessageSender.me) return const SizedBox.shrink();
    switch (message.status) {
      case MessageStatus.sending:
        return const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
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

  // Builds only the HTML content view (WebView)
  Widget _buildHtmlContent(ChatMessage message) {
    if (message.htmlContent == null) return const SizedBox.shrink();

    // Wrap the provided HTML snippet in a full HTML document for better control
    final String fullHtmlContent = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body { 
            margin: 0; 
            padding: 0; 
            font-family: Arial, sans-serif; /* Match your app's font if desired */
            word-wrap: break-word; /* Prevent overflow from long words */
          }
          /* Ensure table scales correctly */
          table { 
            width: 100% !important; 
            border-collapse: collapse; 
            table-layout: auto; /* Or 'fixed' if you prefer */
          }
          th, td {
            padding: 4px; /* Adjust padding for density */
            border: 1px solid #ccc; /* Lighter border */
          }
          /* Style from backend is good, this is just a fallback or enhancement */
          img { max-width: 100%; height: auto; } 
        </style>
      </head>
      <body>
        ${message.htmlContent!}
      </body>
      </html>
    """;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000)) // Transparent background
      ..loadHtmlString(fullHtmlContent);

    return Container(
      constraints: BoxConstraints(
        // Allow WebView to grow, but cap its height. It will scroll internally if taller.
        maxHeight: MediaQuery.of(context).size.height * 0.4, // Example: 40% of screen height
      ),
      // Width will be constrained by the parent bubble
      child: WebViewWidget(controller: controller),
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
      body: Column(
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
                // HTML messages are assumed to be from the bot
                final bool isHtml = chatMessage.type == MessageType.html && chatMessage.sender == MessageSender.bot;

                Alignment messageAlignment;
                Color bubbleColor;
                TextStyle textStyle = const TextStyle(); // Default text style

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

                // Unified bubble structure
                Widget messageContent;

                if (isHtml) {
                  messageContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chatMessage.text.isNotEmpty &&
                          chatMessage.text != "See detailed results below" &&
                          chatMessage.text != "No response generated") // Avoid redundant/placeholder text
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(chatMessage.text), // Bot text style is default
                        ),
                      _buildHtmlContent(chatMessage),
                    ],
                  );
                } else { // Regular text message (me, bot text-only, system)
                  messageContent = Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(child: Text(chatMessage.text, style: textStyle)),
                      if (isMe) _buildMessageStatusIcon(chatMessage), // Status icon only for 'me'
                    ],
                  );
                }

                // System messages might have slightly different padding or no explicit bubble sometimes
                // For simplicity, we use the same bubble structure, but they are centered.
                return Align(
                  alignment: messageAlignment,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isSystem
                          ? MediaQuery.of(context).size.width * 0.9 // System messages can be wider
                          : MediaQuery.of(context).size.width * 0.75, // User/Bot messages
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    clipBehavior: Clip.antiAlias, // Important for children to respect rounded corners
                    child: messageContent,
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
                _isSendingMessageGlobal && !_isBotTyping
                    ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                )
                    : IconButton(
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