// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/link_launcher.dart';
import 'medicine_assistant.dart';

class ApiFilePage extends StatefulWidget {
  final MedicineAssistant assistant;
  final OpenAI instance;

  const ApiFilePage(
      {super.key, required this.assistant, required this.instance});

  @override
  ApiFilePageState createState() => ApiFilePageState();
}

class ApiFilePageState extends State<ApiFilePage> {
  @override
  void initState() {
    super.initState();
    widget.assistant.retrieveAndStoreAssistantFiles();
  }

  Future<void> _uploadFile(FilePickerResult? value) async {
    if (value == null) {
      _showNoFileSelectedWarning();
    } else {
      List<PlatformFile>? succeededFiles = await widget.assistant
          .addFilesToAssistant(value.files, widget.instance);
      if (!mounted) return;
      if (succeededFiles == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text(
                'Failed to upload files. Are you on web? If so, please use the app or windows to upload files.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text(
                'Successfully uploaded ${succeededFiles.length} files: ${succeededFiles.map((e) => e.name).join(', ')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Information Files'),
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
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              if (kIsWeb) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Warning: Web uploads not supported'),
                    content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text('Uploading files is not supported on the web.'),
                          Text(
                              'Please use the app, or windows application, or website to upload files.'),
                        ]),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                      TextButton(
                        onPressed: () {
                          try {
                            LinkLauncher.launch(
                                "https://platform.openai.com/assistants");
                          } catch (_) {/* ignore */}
                        },
                        child: const Text('Open in browser'),
                      ),
                    ],
                  ),
                );
              } else {
                FilePicker.platform.pickFiles().then((value) async {
                  _uploadFile(value);
                  List<FileContainer> files =
                      await widget.assistant.retrieveAssistantFiles();
                  setState(() {
                    widget.assistant.files = files;
                  });
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.replay_outlined),
            onPressed: () async {
              List<FileContainer> files =
                  await widget.assistant.retrieveAssistantFiles();
              setState(() {
                widget.assistant.files = files;
              });
            },
          )
        ],
      ),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: widget.assistant.files.length,
              itemBuilder: (context, index) {
                FileContainer medicineFile = widget.assistant.files[index];
                return ListTile(
                  title: Text(medicineFile.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirmation'),
                              content: const Text(
                                  'Are you sure you want to delete this medicine?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    widget.assistant.removeFileFromAssistant(
                                        medicineFile, widget.instance);
                                    List<FileContainer> files = await widget
                                        .assistant
                                        .retrieveAssistantFiles();
                                    setState(() {
                                      widget.assistant.files = files;
                                    });
                                    if (!mounted) return;
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            )
          ]),
    );
  }

  void _showNoFileSelectedWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: const Text('No file selected'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
