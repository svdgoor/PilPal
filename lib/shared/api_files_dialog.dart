import 'dart:async';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'medicine_assistant.dart';

class ApiFilePage extends StatefulWidget {
  final MedicineAssistant assistant;
  final OpenAI instance;

  const ApiFilePage(
      {super.key, required this.assistant, required this.instance});

  @override
  _ApiFilePageState createState() => _ApiFilePageState();
}

class _ApiFilePageState extends State<ApiFilePage> {
  @override
  void initState() {
    super.initState();
    widget.assistant.retrieveAndStoreAssistantFiles();
  }

  Future<void> _uploadFile(FilePickerResult? value) async {
    if (value == null) {
      _showNoFileSelectedWarning();
    } else {
      widget.assistant.addFilesToAssistant(value.files, widget.instance);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Information Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              FilePicker.platform.pickFiles().then((value) {
                _uploadFile(value);
              });
            },
          ),
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
                                  onPressed: () {
                                    _deleteFile(index);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          TextEditingController textEditingController =
                              TextEditingController();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Edit Medicine Name'),
                              content: TextField(
                                controller: textEditingController
                                  ..text = medicineFile.name,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      medicineFile.name =
                                          textEditingController.text;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Save'),
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

  void _showNullPathError(int fileNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: Text('File path for file ${fileNumber + 1} is null'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteFile(int index) {
    setState(() {
      widget.assistant.files.removeAt(index);
    });
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
