import 'dart:async';
import 'dart:io';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';

class MedicineAssistant {
  AssistantData assistant;
  List<FileContainer> files;
  OpenAI instance;

  MedicineAssistant(this.assistant, this.files, this.instance);

  static Future<List<AssistantData>> listAssistant(OpenAI instance) async {
    return await instance.assistant.list();
  }

  static Future<MedicineAssistant> createNewAssistant(
      OpenAI instance, String assistantName) async {
    final AssistantData assistantData = await instance.assistant.create(
        assistant: Assistant(
      model: AssistantModelFromValue(model: openAIModel),
      instructions: assistantInstruction,
      name: assistantName,
      tools: [
        {"type": "retrieval"}
      ],
    ));
    return MedicineAssistant(
      assistantData,
      [],
      instance,
    );
  }

  static Future<MedicineAssistant> recreateAssistant(
      OpenAI instance, String assistantID) async {
    final AssistantData assistantData =
        await instance.assistant.retrieves(assistantId: assistantID);
    final List<FileContainer> files =
        await retrieveAssistantFilesByID(assistantID, instance);
    return MedicineAssistant(assistantData, files, instance);
  }

  static Future<List<FileContainer>> retrieveAssistantFilesByID(
      String assistantID, OpenAI instance) async {
    final ListAssistantFile files =
        await instance.assistant.listFile(assistantId: assistantID);
    List<FileContainer> fileContainers = [];
    for (AssistantFileData file in files.data) {
      final UploadResponse fileData = await instance.file.retrieve(file.id);
      fileContainers.add(FileContainer(fileData.filename, file.id));
    }
    return fileContainers;
  }

  Future<List<FileContainer>> retrieveAssistantFiles() async {
    return await retrieveAssistantFilesByID(assistant.id, instance);
  }

  void retrieveAndStoreAssistantFiles() async {
    files = await retrieveAssistantFiles();
  }

  Future<List<PlatformFile>?> addFilesToAssistant(
      List<PlatformFile> newFiles, OpenAI instance) async {
    if (kIsWeb) {
      debugPrint('Cannot upload files on web platform');
      return null;
    }
    List<PlatformFile> uploadedFiles = [];
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
      uploadedFiles.add(f);
      files.add(FileContainer(f.name, fileUpload.id));
    }
    try {
      await _updateAssistantFiles(instance);
    } catch (e) {
      debugPrint('Error updating assistant files: $e');
      return null;
    }
    return uploadedFiles;
  }

  Future<void> removeFileFromAssistant(
      FileContainer file, OpenAI instance) async {
    await instance.assistant
        .deleteFile(assistantId: assistant.id, fileId: file.id);
    files.remove(file);
    _updateAssistantFiles(instance);
  }

  Future<void> _updateAssistantFiles(OpenAI instance) async {
    try {
      await instance.assistant.modifies(
          assistantId: assistant.id,
          assistant: Assistant(
            model: AssistantModelFromValue(model: openAIModel),
            instructions: assistant.instructions,
            name: assistant.name,
            tools: assistant.tools,
            fileIds: files.map((e) => e.id).toList(),
          ));
    } catch (e) {
      debugPrint('Error updating assistant files: $e');
    }
  }
}

class FileContainer {
  String name;
  final String id;

  FileContainer(this.name, this.id);
}
