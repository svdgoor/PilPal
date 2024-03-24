import 'dart:async';
import 'dart:io';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';

class MedicineAssistant {
  Assistant assistant;
  String assistantID;
  List<FileContainer> files;
  OpenAI instance;

  MedicineAssistant(
      this.assistant, this.assistantID, this.files, this.instance);

  static Future<Iterable<Map<String, dynamic>>> listAssistant(
      OpenAI instance) async {
    final assistants = await instance.assistant.list();
    return assistants.map((e) => e.toJson());
  }

  static Future<MedicineAssistant> createNewAssistant(
      OpenAI instance, String assistantName) async {
    final Assistant assistant = Assistant(
      model: Gpt4AModel(),
      instructions: assistantInstruction,
      name: assistantName,
      // tools: [
      //   {"type": "retrieval"}
      // ],
    );
    final AssistantData assistantData =
        await instance.assistant.create(assistant: assistant);
    return MedicineAssistant(
      assistant,
      assistantData.id,
      [],
      instance,
    );
  }

  static Future<MedicineAssistant> recreateAssistant(
      OpenAI instance, String assistantID) async {
    List<FileContainer> files =
        await retrieveAssistantFilesByID(assistantID, instance);
    return MedicineAssistant(
        Assistant(
          model: Gpt4AModel(),
          instructions: assistantInstruction,
          name: assistantName,
          tools: [
            {"type": "retrieval"}
          ],
          fileIds: files.map((file) => file.id).toList(),
        ),
        assistantID,
        files,
        instance);
  }

  static Future<List<FileContainer>> retrieveAssistantFilesByID(
      String assistantID, OpenAI instance) async {
    final ListAssistantFile files =
        await instance.assistant.listFile(assistantId: assistantID);
    return files.data
        .map((data) => FileContainer(data.object, data.id))
        .toList();
  }

  Future<List<FileContainer>> retrieveAssistantFiles() async {
    return await retrieveAssistantFilesByID(assistantID, instance);
  }

  void retrieveAndStoreAssistantFiles() async {
    files = await retrieveAssistantFiles();
  }

  void addFilesToAssistant(List<PlatformFile> newFiles, OpenAI instance) async {
    if (kIsWeb) {
      debugPrint('Cannot upload files on web platform');
      return;
    }
    for (PlatformFile f in newFiles) {
      if (files.any((element) => element.name == f.name)) continue;
      final File file = File(f.path!);
      if (file.existsSync() == false) {
        debugPrint('Error uploading file, could not find path: ${f.path}');
        continue;
      }
      UploadResponse fileUpload = await instance.file.uploadFile(UploadFile(
        file: FileInfo(file.path, f.name),
        purpose: 'assistants',
      ));
      files.add(FileContainer(f.name, fileUpload.id));
    }
    _updateAssistantFiles(instance);
  }

  void removeFileFromAssistant(FileContainer file, OpenAI instance) async {
    await instance.file.delete(file.id);
    files.remove(file);
    _updateAssistantFiles(instance);
  }

  void _updateAssistantFiles(OpenAI instance) async {
    assistant = Assistant(
      model: Gpt4AModel(),
      instructions: assistant.instructions,
      name: assistant.name,
      tools: [
        {"type": "retrieval"}
      ],
      fileIds: files.map((file) => file.id).toList(),
    );
    final AssistantData assistantData = await instance.assistant.modifies(
      assistantId: assistantID,
      assistant: assistant,
    );
    assistantID = assistantData.id;
  }
}

class FileContainer {
  String name;
  final String id;

  FileContainer(this.name, this.id);
}
