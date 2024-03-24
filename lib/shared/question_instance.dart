import 'dart:async';
import 'dart:io';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';

class QuestionInstance {
  AssistantData assistant;
  OpenAI instance;

  QuestionInstance(this.assistant, this.instance);

}
