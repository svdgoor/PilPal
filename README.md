# Overview
This is a chat app that uses the [GPT-4 API](https://platform.openai.com/docs) to generate responses to queries about medicinal information. It uses the [chat_gpt_sdk](https://pub.dev/packages/chat_gpt_sdk) package to interact with the API.

# Development process
A full overview of the development process is available [here](https://cstwiki.wtb.tue.nl/wiki/PRE2023_3_Group7).

# Installation
The chat_gpt_sdk library on version 3.0.4 contained some faulty types in the response models. To fix this, the following steps need to be taken:
1. As usual install flutter, dart, etc.
2. Pull dependencies.
3. Replace `C:\Users\<user>\AppData\Local\Pub\Cache\hosted\pub.dev\chat_gpt_sdk-3.0.4\lib\src\model\assistant\response\assistant_data.dart` with the [file here](chat_gpt_sdk_patches/assistant_data.dart).
4. Replace `C:\Users\<user>>\AppData\Local\Pub\Cache\hosted\pub.dev\chat_gpt_sdk-3.0.4\lib\src\model\run\response\create_thread_and_run_data.dart` with the [file here](chat_gpt_sdk_patches/create_and_run_thread_data.dart)
5. Run the app with `flutter run` as you are used to.

These steps may not be necessary if the package is updated.