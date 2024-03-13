import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../hive_model/chat_item.dart';
import '../shared/api_key_dialog.dart';
import '../shared/api_files_dialog.dart';
import 'chat_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<ChatItem> chats = [];

  @override
  void initState() {
    super.initState();
    setApiKeyOnStartup();
  }

  Future<void> setApiKeyOnStartup() async {
    final sp = await SharedPreferences.getInstance();
    var key = sp.getString(spOpenApiKey);
    if (key == null || key.isEmpty) return;
    OpenAI.apiKey = key;
  }

  // Wraps a function that depends on the API being setup
  void _apiKeyTest(Function onSuccess) {
    try {
      OpenAI.instance;
      onSuccess();
    } on MissingApiKeyException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Can't open this page. API key not added."),
          action: SnackBarAction(
              label: 'Add key',
              onPressed: () {
                showDialog(
                    context: context, builder: (_) => const ApiKeyDialog());
              }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PilPal | Home'),
        actions: [
          IconButton(
              onPressed: () {
                showDialog(
                    context: context, builder: (_) => const ApiKeyDialog());
              },
              tooltip: 'Add OpenAPI Key',
              icon: const Icon(Icons.key)),
          IconButton(
              onPressed: () {
                _apiKeyTest(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ApiFileDialog(),
                    ),
                  );
                });
              },
              tooltip: 'OpenAI files',
              icon: const Icon(Icons.file_copy_outlined)),
        ],
      ),
      body: ValueListenableBuilder(
          valueListenable: Hive.box('chats').listenable(),
          builder: (context, box, _) {
            if (box.isEmpty) {
              return const Center(child: Text('No questions yet'));
            }
            return ListView.builder(
              itemCount: box.length,
              itemBuilder: (context, index) {
                final chatItem = box.getAt(index) as ChatItem;
                return ListTile(
                  title: Text(chatItem.title),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return ChatPage(chatItem: chatItem);
                    }));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      box.deleteAt(index);
                    },
                  ),
                );
              },
            );
          }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _apiKeyTest(() {
            // create hive object
            final messagesBox = Hive.box('messages');
            final newChatTitle =
                'Question ${DateFormat('d/M/y').format(DateTime.now())}';
            var chatItem = ChatItem(newChatTitle, HiveList(messagesBox));

            // add to hive
            Hive.box('chats').add(chatItem);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(chatItem: chatItem),
              ),
            );
          });
        },
        label: const Text('New Question'),
        icon: const Icon(Icons.message_outlined),
      ),
    );
  }
}
