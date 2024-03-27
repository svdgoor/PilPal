// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../hive_model/chat_item.dart';
import '../hive_model/message_item.dart';
import '../hive_model/message_role.dart';
import '../shared/medicine_assistant.dart';

/// A screen that displays a chat interface for communicating with an AI assistant.
///
/// This screen allows users to have a conversation with an AI assistant using a chat interface.
/// It displays a list of messages exchanged between the user and the assistant.
/// Users can send messages to the assistant and receive responses in real-time.
///
/// The [ChatPage] class is a stateful widget that manages the state of the chat screen.
/// It initializes the necessary variables and widgets, retrieves chat history from Hive,
/// and handles user interactions such as sending messages and displaying typing indicators.
///
/// To use this screen, create an instance of [ChatPage] and pass in the required parameters:
/// - [assistant]: The [MedicineAssistant] object representing the AI assistant.
/// - [instance]: The [OpenAI] instance used for making API calls.
/// - [chatItem]: The [ChatItem] object representing the chat conversation.
///
/// Example usage:
/// ```dart
/// ChatPage(
///   assistant: MedicineAssistant(),
///   instance: OpenAI(),
///   chatItem: ChatItem(),
/// )
/// ```
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.assistant,
    required this.instance,
    required this.chatItem,
  });

  final MedicineAssistant assistant;
  final OpenAI instance;
  final ChatItem chatItem;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

/// The state class for the ChatPage widget.
///
/// This class manages the state of the ChatPage widget, including the list of messages,
/// the AI messages, the AI and user objects, the messageBox, the appBarTitle, and the
/// isAiTyping flag. It also provides methods for initializing the state, generating a
/// random string, completing the chat, adding a message to the chat, saving a message
/// to the Hive database, handling the send button press, and building the widget.
class _ChatPageState extends State<ChatPage> {
  /// List of messages exchanged between the AI and the user.
  final List<types.Message> _messages = [];

  /// List of AI-generated messages.
  final List<Messages> _aiMessages = [];

  /// The AI user.
  late types.User ai;

  /// The user.
  late types.User user;

  /// The message box.
  late Box messageBox;

  /// The title of the app bar in the chat page.
  late String appBarTitle;

  /// A flag indicating whether the AI is currently typing or not.
  bool isAiTyping = false;

  /// Initializes the state of the [ChatPage] widget.
  ///
  /// This method is called when the stateful widget is inserted into the tree.
  /// It initializes the necessary variables and retrieves the chat history from Hive.
  /// The chat history is then used to populate the chat view and construct chatgpt messages.
  /// The [appBarTitle] is set to the title of the [ChatItem] passed to the widget.
  @override
  void initState() {
    super.initState();

    // Initialize AI and user users
    ai = const types.User(id: 'ai', firstName: 'AI');
    user = const types.User(id: 'user', firstName: 'You');

    // Retrieve the 'messages' box from Hive
    messageBox = Hive.box('messages');

    // Set the appBarTitle to the title of the chatItem
    appBarTitle = widget.chatItem.title;

    // Read chat history from Hive and populate chat view
    for (var messageItem in widget.chatItem.messages) {
      messageItem as MessageItem;

      // Create a text message based on the messageItem
      final textMessage = types.TextMessage(
        author: messageItem.role == MessageRole.ai ? ai : user,
        createdAt: messageItem.createdAt.millisecondsSinceEpoch,
        id: randomString(),
        text: messageItem.message,
      );

      // Insert the text message at the beginning of the _messages list
      _messages.insert(0, textMessage);

      // Construct chatgpt messages based on the messageItem
      _aiMessages.add(Messages(
        content: messageItem.message,
        role: messageItem.role == MessageRole.ai ? Role.assistant : Role.user,
      ));
    }
  }

  /// Generates a random string.
  ///
  /// This function uses a secure random number generator to generate a list of
  /// 16 random integers between 0 and 255. It then encodes the list using
  /// base64Url encoding and returns the resulting string.
  String randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  /// Completes the chat by sending the user's prompt to the AI and retrieving the AI's response.
  ///
  /// The [prompt] parameter represents the user's prompt.
  /// This method adds the user's prompt to the [_aiMessages] list as a user message.
  /// It then creates a map [m] to store the messages in the required format.
  /// The method loops through each message in [_aiMessages] and adds it to the [m] map.
  /// After that, it creates a thread and runs the data using the [createThreadAndRun] method.
  /// A timer is started to handle timeouts, and a while loop is used to retrieve the run response.
  /// If the run response is not completed, the method returns.
  /// If the run response is completed, it retrieves the message ID from the run response.
  /// If the message ID is null, it retrieves the step details and creation data until the creation data is not null.
  /// Finally, it retrieves the message data using the retrieved message ID and adds the AI's response to the [_aiMessages] list as an assistant message.
  /// The method also saves the AI's response and updates the state.
  void _completeChat(String prompt) async {
    _aiMessages.add(Messages(
      role: Role.user,
      content: prompt,
    ));

    debugPrint("Prompt: $prompt");
    var m = {"messages": []};
    for (var message in _aiMessages) {
      m["messages"]!.add({
        "role":
            "user", // Note: Neither 'AI' nor 'assistant' seem to be allowed but it works
        "content": message.content,
      });
    }

    CreateThreadAndRunData data = await widget.instance.threads.runs
        .createThreadAndRun(
            request: CreateThreadAndRun(
                assistantId: widget.assistant.assistant.id, thread: m));

    // start timer for timeout
    bool cancel = false;
    Timer timer = Timer(const Duration(minutes: 1), () {
      debugPrint("Timeout");
      cancel = true;
    });

    setState(() {
      isAiTyping = true;
    });

    CreateRunResponse? runResponse;
    while (runResponse == null ||
        runResponse.status == "queued" ||
        runResponse.status == "in_progress") {
      runResponse = await widget.instance.threads.runs
          .retrieveRun(runId: data.id, threadId: data.threadId);
      if (cancel) {
        debugPrint("Retrieving run timed out (20s)");
        setState(() {
          isAiTyping = false;
        });
        return;
      }
    }

    if (runResponse.status != "completed") {
      debugPrint("Run failed! Status: ${runResponse.status}");
      timer.cancel();
      setState(() {
        isAiTyping = false;
      });
      return;
    }

    debugPrint("Run completed successfully, retrieving message...");
    String? messageID = runResponse.stepDetails?.messageCreation?.messageId;

    if (messageID == null) {
      ListRun? stepDetails;
      MessageCreation? creationData;
      while (creationData == null) {
        stepDetails = await widget.instance.threads.runs
            .listRunSteps(threadId: data.threadId, runId: data.id);
        creationData = stepDetails.data
            .firstWhere(
                (element) => element.stepDetails!.messageCreation != null)
            .stepDetails!
            .messageCreation;
        debugPrint("Message creation: $creationData");
        if (cancel) {
          debugPrint("Retrieving run timed out (20s)");
          setState(() {
            isAiTyping = false;
          });
          return;
        }
      }
      debugPrint("Message created successfully");
      timer.cancel();

      messageID = creationData.messageId;
    }

    debugPrint("Message ID: $messageID");

    MessageData mData = await widget.instance.threads.messages
        .retrieveMessage(threadId: data.threadId, messageId: messageID);

    debugPrint("Message data: ${mData.toJson()}");

    String chatResponseContent = mData.content.last.text!.value;

    for (var annotation in mData.content.last.text!.annotations) {
      if (annotation["type"] != "file_citation") continue;
      String quoteText = annotation["text"];
      String quote = annotation["file_citation"]["quote"];
      chatResponseContent =
          chatResponseContent.replaceAll(quoteText, "[\"$quote\"]");
    }

    debugPrint("Response text: $chatResponseContent");

    _addMessage(types.TextMessage(
      author: ai,
      id: messageID,
      text: chatResponseContent,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    _aiMessages.add(Messages(
      role: Role.assistant,
      content: chatResponseContent,
    ));

    _saveMessage(chatResponseContent, MessageRole.ai);

    setState(() {
      isAiTyping = false;
    });
  }

  /// add new bubble to chat
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

  /// Handles the event when the send button is pressed.
  ///
  /// This method takes a [types.PartialText] message as input and performs the following steps:
  /// 1. Creates a [types.TextMessage] object with the author, creation timestamp, ID, and text from the input message.
  /// 2. Prints the user message to the debug console.
  /// 3. Adds the text message to the chat.
  /// 4. Saves the user message with the role of [MessageRole.user].
  /// 5. Prints the saved message to the debug console.
  /// 6. Completes the chat with the input message.
  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );
    debugPrint("User message: ${message.text}");
    _addMessage(textMessage);
    debugPrint("Saving message: ${message.text}");
    _saveMessage(message.text, MessageRole.user);
    debugPrint("Saved, now completing: ${message.text}");
    _completeChat(message.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            onPressed: () async {
              if (await canLaunch("tel:112")) {
                launch("tel:112");
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Could not make emergency call. Are you on a phone?'),
                  ),
                );
              }
            },
            tooltip: 'Emergency Call',
            icon: const Icon(
              Icons.phone_callback_sharp,
              color: Colors.red,
            ),
          ),
        ],
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
