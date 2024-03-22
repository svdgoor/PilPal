import 'dart:async';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:file_picker/file_picker.dart';

import '../constants.dart';

class MedicineAssistant {
  Assistant assistant;
  String assistantID;
  List<FileContainer> files;

  MedicineAssistant(this.assistant, this.assistantID, this.files);

  static Future<Iterable<Map<String, dynamic>>> listAssistant(
      OpenAI instance) async {
    final assistants = await instance.assistant.list();
    return assistants.map((e) => e.toJson());
  }

  static Future<MedicineAssistant> createNewAssistant(
      OpenAI instance, String assistantName) async {
    print('assistantName: $assistantName');
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
    );
  }

  static Future<MedicineAssistant> recreateAssistant(
      OpenAI instance, String assistantID) async {
    List<FileContainer> files = await listAssistantFiles(assistantID, instance);
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
    );
  }

  static Future<List<FileContainer>> listAssistantFiles(
      String assistantID, OpenAI instance) async {
    final ListAssistantFile files =
        await instance.assistant.listFile(assistantId: assistantID);
    return files.data
        .map((data) => FileContainer(data.object, data.id))
        .toList();
  }

  void addFilesToAssistant(List<PlatformFile> newFiles, OpenAI instance) async {
    for (var file in newFiles) {
      UploadResponse fileUpload = await instance.file.uploadFile(UploadFile(
        file: FileInfo(file.path!, file.name),
        purpose: 'assistants',
      ));
      files.add(FileContainer(file.name, fileUpload.id));
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
