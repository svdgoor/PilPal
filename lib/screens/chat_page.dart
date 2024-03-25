import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:hive/hive.dart';

import '../hive_model/chat_item.dart';
import '../hive_model/message_item.dart';
import '../hive_model/message_role.dart';
import '../shared/medicine_assistant.dart';

class ChatPage extends StatefulWidget {
  const ChatPage(
      {super.key,
      required this.chatItem,
      required this.assistant,
      required this.instance});

  final MedicineAssistant assistant;
  final OpenAI instance;
  final ChatItem chatItem;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<types.Message> _messages = [];
  final List<Messages> _aiMessages = [];
  late types.User ai;
  late types.User user;
  late Box messageBox;

  late String appBarTitle;

  var chatResponseId = '';
  var chatResponseContent = '';

  bool isAiTyping = false;

  @override
  void initState() {
    super.initState();
    ai = const types.User(id: 'ai', firstName: 'AI');
    user = const types.User(id: 'user', firstName: 'You');

    messageBox = Hive.box('messages');

    appBarTitle = widget.chatItem.title;

    // read chat history from Hive
    for (var messageItem in widget.chatItem.messages) {
      messageItem as MessageItem;
      // Add to chat view
      final textMessage = types.TextMessage(
        author: messageItem.role == MessageRole.ai ? ai : user,
        createdAt: messageItem.createdAt.millisecondsSinceEpoch,
        id: randomString(),
        text: messageItem.message,
      );

      _messages.insert(0, textMessage);

      // construct chatgpt messages
      _aiMessages.add(Messages(
        content: messageItem.message,
        role: messageItem.role == MessageRole.ai ? Role.assistant : Role.user,
      ));
    }
  }

  String randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  void _completeChat(String prompt) async {
    _aiMessages.add(Messages(
      role: Role.user,
      content: prompt,
    ));

    debugPrint("Prompt: $prompt");
    CreateThreadAndRunData data = await widget.instance.threads.runs
        .createThreadAndRun(
            request: CreateThreadAndRun(
                assistantId: widget.assistant.assistant.id,
                thread: {
          "messages": _aiMessages,
        }));

    // start timer for timeout
    bool cancel = false;
    Timer timer = Timer(const Duration(seconds: 20), () {
      debugPrint("Timeout");
      cancel = true;
    });

    isAiTyping = true;

    CreateRunResponse? runResponse;
    while (runResponse == null ||
        runResponse.status == "queued" ||
        runResponse.status == "in_progress") {
      runResponse = await widget.instance.threads.runs
          .retrieveRun(runId: data.id, threadId: data.threadId);
      if (cancel) {
        debugPrint("Retrieving run timed out (20s)");
        isAiTyping = false;
        return;
      }
    }

    if (runResponse.status != "completed") {
      debugPrint("Run failed! Status: ${runResponse.status}");
      timer.cancel();
      isAiTyping = false;
      return;
    }
    debugPrint("Run completed successfully, retrieving message...");

    ListRun? stepDetails;
    while (stepDetails == null ||
        stepDetails.data.last.stepDetails == null ||
        stepDetails.data.last.stepDetails!.messageCreation == null) {
      stepDetails = await widget.instance.threads.runs
          .listRunSteps(threadId: data.threadId, runId: data.id);
      if (cancel) {
        debugPrint("Retrieving run timed out (20s)");
        isAiTyping = false;
        return;
      }
    }
    if (stepDetails.data.last.stepDetails!.messageCreation == null) {
      debugPrint("No message creation");
      timer.cancel();
      isAiTyping = false;
      return;
    }
    debugPrint("Message created successfully");
    timer.cancel();

    String messageId =
        stepDetails.data.last.stepDetails!.messageCreation!.messageId;
    debugPrint("Message ID: $messageId");

    MessageData mData = await widget.instance.threads.messages
        .retrieveMessage(threadId: data.threadId, messageId: messageId);

    String chatResponseContent = mData.content
        .map((content) => content.text)
        .where((element) => element != null)
        .map((text) => text!.value)
        .join(' ');
    // TODO: mData.content.first.text!.annotations
    debugPrint("Response text: $chatResponseContent");

    _addMessageStream(chatResponseContent);

    _aiMessages.add(Messages(
      content: chatResponseContent,
      role: Role.assistant,
    ));

    _saveMessage(chatResponseContent, MessageRole.ai);

    chatResponseId = '';
    chatResponseContent = '';

    isAiTyping = false;
  }

  void onMessageReceived({String? id, required String message}) {
    var newMessage = types.TextMessage(
      author: ai,
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _addMessage(newMessage);
  }

  // add new bubble to chat
  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  /// Save message to Hive database
  void _saveMessage(String message, MessageRole role) {
    final messageItem = MessageItem(message, role, DateTime.now());
    messageBox.add(messageItem);
    widget.chatItem.messages.add(messageItem);
    widget.chatItem.save();
  }

  // modify last bubble in chat
  void _addMessageStream(String message) {
    setState(() {
      _messages.first =
          (_messages.first as types.TextMessage).copyWith(text: message);
    });
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );
    debugPrint("User message: ${message.text}");
    _addMessage(textMessage);
    debugPrint("Saving mesasge: ${message.text}");
    _saveMessage(message.text, MessageRole.user);
    debugPrint("Saved, now completing: ${message.text}");
    _completeChat(message.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: Chat(
        typingIndicatorOptions: TypingIndicatorOptions(
          typingUsers: [if (isAiTyping) ai],
        ),
        inputOptions: InputOptions(enabled: !isAiTyping),
        messages: _messages,
        onSendPressed: _handleSendPressed,
        user: user,
        theme: DefaultChatTheme(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
