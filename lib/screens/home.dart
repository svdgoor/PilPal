import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../hive_model/chat_item.dart';
import '../shared/api_key_dialog.dart';
import '../shared/api_files_dialog.dart';
import '../shared/medicine_assistant.dart';
import 'chat_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<ChatItem> chats = [];
  MedicineAssistant? assistant;
  OpenAI? instance;

  @override
  void initState() {
    super.initState();
    debugPrint("Home page init");
    // try to build state as we start the app
    setApiKeyOnStartup().then((_) async {
      tryLoadAssistant();
    });
  }

  Future<void> tryLoadAssistant() async {
    debugPrint("Attempting to load assistant");
    _apiKeyTest(false, () async {
      debugPrint("API key set, checking assistant");
      if (assistant == null) {
        debugPrint("Assistant not loaded, attempting to load");
        List<AssistantData> value =
            await MedicineAssistant.listAssistant(instance!);
        debugPrint(
            "Retrieved assistants: ${value.map((assistant) => assistant.name).toList()}");
        if (value.isEmpty || value.length > 1) {
          return;
        }
        assistant = await MedicineAssistant.recreateAssistant(
            instance!, value.first.id);
        debugPrint("Assistant loaded: ${assistant!.assistant.name}");
        debugPrint(
            "Files: ${assistant!.files.map((e) => "${e.name} (${e.id})").join(', ')}");
      }
      _assistantTest(false, () {
        assistant!.retrieveAndStoreAssistantFiles();
      });
    }, onFailure: () {
      debugPrint("API key not set");
    });
  }

  Future<void> setApiKeyOnStartup() async {
    final sp = await SharedPreferences.getInstance();
    var key = sp.getString(spOpenApiKey);
    if (key == null || key.isEmpty) return;
    instance = OpenAI.instance.build(token: key);
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
                    context: context,
                    builder: (_) => ApiKeyDialog(
                          onApiKeyChange: (key) {
                            setState(() {
                              instance = OpenAI.instance.build(
                                token: key,
                              );
                            });
                            tryLoadAssistant();
                          },
                        ));
              },
              tooltip: 'Add OpenAPI Key',
              icon: const Icon(Icons.key)),
          IconButton(
            onPressed: () {
              _apiKeyTest(true, () {
                showDialog(
                    context: context,
                    builder: (_) {
                      return _assistantSetupPrompt(OpenAI.instance);
                    });
              });
            },
            tooltip: 'Assistants',
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(
              onPressed: () {
                _apiKeyTest(true, () {
                  _assistantTest(true, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApiFilePage(
                          assistant: assistant!,
                          instance: instance!,
                        ),
                      ),
                    );
                  });
                });
              },
              tooltip: 'OpenAI files',
              icon: const Icon(Icons.file_copy_outlined)),
          IconButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        title: const Text('Translate'),
                        content: FutureBuilder(
                          future: OpenAI.instance.onCompletion(
                            request: CompleteText(
                                prompt: '<text>',
                                maxTokens: 200,
                                model: Gpt3TurboInstruct()),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            final response = snapshot.data;
                            if (response == null) {
                              return const Text('Error, data is null');
                            }
                            return Text(response.choices.first.text);
                          },
                        ),
                      );
                    });
              },
              tooltip: 'Test chat_gpt_sdk',
              icon: const Icon(Icons.chat_bubble_outline)),
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
          _apiKeyTest(true, () {
            _assistantTest(true, () {
              showDialog(
                context: context,
                builder: (_) => _buildPickMedicineFileDialog(),
              );
            });
          });
        },
        label: const Text('New Question'),
        icon: const Icon(Icons.message_outlined),
      ),
    );
  }

  // Wraps a function that depends on the API being setup
  void _apiKeyTest(bool notify, Function onSuccess, {Function? onFailure}) {
    if (instance == null) {
      if (onFailure != null) {
        onFailure();
      }
      if (!notify) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: const Text("Can't open this page. API key not added."),
              action: SnackBarAction(
                  label: 'Add key',
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (_) => ApiKeyDialog(
                              onApiKeyChange: (key) {
                                setState(() {
                                  instance = OpenAI.instance.build(
                                    token: key,
                                  );
                                });
                              },
                            ));
                  }),
            ),
          )
          .closed
          .then((reason) {
        if (instance != null) {
          onSuccess();
        }
      });
    } else {
      onSuccess();
    }
  }

  void _assistantTest(bool notify, Function onSuccess) {
    if (assistant == null) {
      if (!notify) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Can't open this page. Assistant not selected."),
          action: SnackBarAction(
              label: 'Select assistant',
              onPressed: () {
                showDialog(
                        context: context,
                        builder: (_) => _assistantSetupPrompt(OpenAI.instance))
                    .then(
                  (value) {
                    if (assistant != null) {
                      onSuccess();
                    }
                  },
                );
              }),
        ),
      );
    } else {
      onSuccess();
    }
  }

  Widget _assistantSetupPrompt(OpenAI instance) {
    Text title;
    Text subtitle;
    if (assistant != null) {
      title = Text('${assistant!.assistant.name} selected');
      subtitle = const Text('Select a different assistant');
    } else {
      title = const Text('Assistant Selection');
      subtitle = const Text('Select an assistant');
    }
    return AlertDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder(
            future: instance.assistant.list(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              final assistants = snapshot.data;
              if (assistants == null) {
                return const Text('Error, data is null');
              }
              if (assistants.isEmpty) {
                return Column(
                  children: [
                    const Text(
                      'No assistants available',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        assistant = await MedicineAssistant.createNewAssistant(
                            instance, assistantName);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: const Text('Create a new assistant'),
                    ),
                  ],
                );
              }
              AssistantData? selectedAssistantData;
              for (var element in assistants) {
                if (assistant != null &&
                    element.id == assistant!.assistant.id) {
                  selectedAssistantData = element;
                  break;
                }
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  subtitle,
                  DropdownButton<AssistantData>(
                    value: selectedAssistantData,
                    items: assistants
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Column(
                                children: [
                                  Text(
                                    e.name,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  Text(
                                    e.id,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      assistant = await MedicineAssistant.recreateAssistant(
                          instance, value.id);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      assistant = await MedicineAssistant.createNewAssistant(
                          instance, assistantName);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('Create a new assistant'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Pick a file from the files list to ask a question about that medicine
  // Alternatively, you can go to the file upload page
  // Alternatively, you can ask a general question
  Widget _buildPickMedicineFileDialog() {
    return AlertDialog();
    /*
      title: const Text('Ask a question'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (files.isEmpty) const Text('No files uploaded yet'),
          if (files.isNotEmpty)
            const Text('Pick a medicine file to ask a question about'),
          DropdownButton<FileContainer>(
            value: null,
            items: assistant!.files
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
              _assistantTest(() {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiFilePage(assistant: assistant!),
                  ),
                );
              });
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
    */
  }
}
