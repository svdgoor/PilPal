import 'dart:async';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../screens/home.dart';

class ApiFileDialog extends StatefulWidget {
  final List<MedicineFile> files;

  const ApiFileDialog({super.key, required this.files});

  @override
  _ApiFileDialogState createState() => _ApiFileDialogState();
}

class _ApiFileDialogState extends State<ApiFileDialog> {
  Future<void> _uploadFile(FilePickerResult? value) async {
    if (value == null) {
      _showNoFileSelectedWarning();
    } else {
      for (var i = 0; i < value.files.length; i++) {
        var file = value.files[i];
        if (file.path != null) {
          // Upload a file
          OpenAIFileModel uploadedFile = await OpenAI.instance.file.upload(
            file: File(file.path!),
            purpose: "assistants",
          );
          setState(() {
            widget.files.add(MedicineFile(
                medicineName: uploadedFile.fileName, file: uploadedFile));
          });
        } else {
          _showNullPathError(i);
        }
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
        ],
      ),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: widget.files.length,
              itemBuilder: (context, index) {
                MedicineFile medicineFile = widget.files[index];
                return ListTile(
                  title: Text(medicineFile.medicineName),
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
                                  ..text = medicineFile.medicineName,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      medicineFile.medicineName =
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
      widget.files.removeAt(index);
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
