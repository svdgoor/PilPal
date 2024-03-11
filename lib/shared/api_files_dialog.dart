import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';

class ApiFileDialog extends StatefulWidget {
  const ApiFileDialog({super.key});

  @override
  State<ApiFileDialog> createState() => _ApiFileDialogState();
}

class _ApiFileDialogState extends State<ApiFileDialog> {
  final TextEditingController apiKeyController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Medicine Information Files'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder(
            future: OpenAI.instance.file.list(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(),
                );
              }
              // Display the list of files
              final List<OpenAIFileModel> files =
                  snapshot.data as List<OpenAIFileModel>;
              return Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: files
                        .map((file) => ListTile(
                              title: Text(file.fileName),
                              subtitle: Text(file.id),
                            ))
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Upload a filer
            OpenAIFileModel uploadedFile = await OpenAI.instance.file.upload(
              file: File("/* FILE PATH HERE */"),
              purpose: "fine-tuning",
            );
            // Update the file list
            setState(() {});
          },
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          child: const Text('Upload File'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
