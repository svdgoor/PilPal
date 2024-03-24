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
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              FilePicker.platform.pickFiles().then((value) {
                _uploadFile(value);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_done),
            onPressed: () {
              // Retrieve and show in a textbox which files are uploaded
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Uploaded Files'),
                  content: FutureBuilder<List<FileContainer>>(
                    future: widget.assistant.retrieveAssistantFiles(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData == false ||
                          snapshot.data!.isEmpty) {
                        return const Text('No files uploaded');
                      } else {
                        List<FileContainer> files = snapshot.data ?? [];
                        return Text(files.map((e) => e.name).join('\n'));
                      }
                    },
                  ),
                ),
              );
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
                                  onPressed: () {
                                    widget.assistant.removeFileFromAssistant(
                                        medicineFile, widget.instance);
                                    setState(() {/* Refresh the list */});
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
