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
  List<MedicineFile> files = [];

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
                      builder: (_) => ApiFileDialog(files: files),
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
                      return ChatPage(
                        chatItem: chatItem,
                        file: null,
                      );
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
            showDialog(
              context: context,
              builder: (_) => _buildPickMedicineFileDialog(),
            );
          });
        },
        label: const Text('New Question'),
        icon: const Icon(Icons.message_outlined),
      ),
    );
  }

  // Pick a file from the files list to ask a question about that medicine
  // Alternatively, you can go to the file upload page
  // Alternatively, you can ask a general question
  Widget _buildPickMedicineFileDialog() {
    return AlertDialog(
      title: const Text('Ask a question'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (files.isEmpty) const Text('No files uploaded yet'),
          if (files.isNotEmpty)
            const Text('Pick a medicine file to ask a question about'),
          DropdownButton<MedicineFile>(
            value: null,
            items: files
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.medicineName),
                    ))
                .toList(),
            onChanged: (value) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                      chatItem: ChatItem(
                          value!.medicineName, HiveList(Hive.box('messages'))),
                      file: value.file),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApiFileDialog(files: files),
                ),
              );
            },
            child: const Text('Upload a new file'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _apiKeyTest(() {
                final messagesBox = Hive.box('messages');
                final newChatTitle =
                    'Question ${DateFormat('d/M/y').format(DateTime.now())}';
                var chatItem = ChatItem(newChatTitle, HiveList(messagesBox));
                Hive.box('chats').add(chatItem);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      chatItem: chatItem,
                      file: null,
                    ),
                  ),
                );
              });
            },
            child: const Text('Ask a general question'),
          ),
        ],
      ),
    );
  }
}

class MedicineFile {
  String medicineName;
  final OpenAIFileModel file;

  MedicineFile({required this.medicineName, required this.file});
}
