// ignore_for_file: deprecated_member_use

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  /// A list of chat items.
  List<ChatItem> chats = [];

  /// The medicine assistant.
  MedicineAssistant? assistant;

  /// The OpenAI instance.
  OpenAI? instance;

  /// Initializes the state of the home page.
  /// This method is called when the widget is inserted into the tree.
  /// It sets up the initial state of the widget and performs any necessary setup operations.
  @override
  void initState() {
    super.initState();
    debugPrint("Home page init");
    setApiKeyOnStartup().then((_) async {
      tryLoadAssistant();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDisclaimerDialog();
    });
  }

  /// Asynchronously tries to load the assistant.
  /// This method checks if the API key is set, retrieves the assistant data,
  /// recreates the assistant, and updates the UI with the loaded assistant.
  /// If the assistant is already loaded, it retrieves and stores the assistant files.
  /// If the API key is not set, it logs a debug message.
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

        // setstate uipdate
        assistant = await MedicineAssistant.recreateAssistant(
            instance!, value.first.id);
        setState(() {/* Update tiles with assistant */});

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

  /// Sets the API key on startup by retrieving it from SharedPreferences.
  /// If the API key is not found or is empty, the function returns without setting the key.
  /// Otherwise, it sets the API key for the OpenAI instance.
  Future<void> setApiKeyOnStartup() async {
    final sp = await SharedPreferences.getInstance();
    var key = sp.getString(spOpenApiKey);
    if (key == null || key.isEmpty) return;
    instance = OpenAI.instance.build(token: key);
  }

  void showDisclaimerDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disclaimer'),
        content: const SizedBox(
          width: 300, // Adjust the width as needed
          child: Text(
            'Please note that the system is using AI to answer questions. While we strive to provide accurate information, we cannot guarantee its accuracy. By clicking "Confirm", you acknowledge that we hold no liability for the answers.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PilPal | Home'),
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
                    _apiKeyTest(true, () {
                      _assistantTest(true, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) {
                          return ChatPage(
                            chatItem: chatItem,
                            assistant: assistant!,
                            instance: instance!,
                          );
                        }));
                      });
                    });
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
              ChatItem newQuestion = ChatItem(
                'New Question',
                HiveList(Hive.box('messages')),
              );
              Hive.box('chats').add(newQuestion);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    chatItem: newQuestion,
                    assistant: assistant!,
                    instance: instance!,
                  ),
                ),
              );
            });
          });
        },
        label: const Text('New Question'),
        icon: const Icon(Icons.message_outlined),
      ),
    );
  }

  /// Performs an API key test.
  ///
  /// This method checks if the API key is available. If the API key is not available,
  /// it shows a snackbar with an option to add the key. If the key is added successfully,
  /// the [onSuccess] callback is called. If the key is not added or if an [onFailure]
  /// callback is provided, the [onFailure] callback is called.
  ///
  /// Parameters:
  /// - [notify]: A boolean value indicating whether to show a snackbar if the key is not added.
  /// - [onSuccess]: A callback function to be called when the key is added successfully.
  /// - [onFailure]: An optional callback function to be called when the key is not added.
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

  /// A method to test the assistant.
  ///
  /// The [notify] parameter determines whether to show a notification if the assistant is not selected.
  /// The [onSuccess] callback function is called when the assistant is selected or already exists.
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
                builder: (_) => _assistantSetupPrompt(OpenAI.instance),
              ).then(
                (value) {
                  if (assistant != null) {
                    onSuccess();
                  }
                },
              );
            },
          ),
        ),
      );
    } else {
      onSuccess();
    }
  }

  /// Widget for displaying the assistant setup prompt.
  ///
  /// This widget is used to prompt the user to select an assistant or create a new one.
  /// It displays a dialog with a title, subtitle, a dropdown list of available assistants,
  /// and buttons for selecting an assistant, creating a new assistant, and canceling the prompt.
  ///
  /// Parameters:
  /// - [instance]: An instance of the OpenAI class.
  ///
  /// Returns:
  /// A [Widget] representing the assistant setup prompt.
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
}
