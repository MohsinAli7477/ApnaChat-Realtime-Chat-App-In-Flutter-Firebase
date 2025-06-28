import 'dart:developer';
import 'dart:io';
import 'package:Disco_Chat/screens/view_profile_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../api/apis.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../widgets/message_card.dart';
import '../widgets/profile_image.dart';
import '../helper/my_date_util.dart';
import '../main.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Message> _list = [];
  bool _showEmoji = false, _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) {
          if (_showEmoji) {
            setState(() => _showEmoji = !_showEmoji);
            return;
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
        },
        child: Scaffold(
          appBar: AppBar(flexibleSpace: _appBar()),
          backgroundColor: const Color.fromARGB(255, 234, 248, 255),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _chatListView()),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                _chatInput(),
                if (_showEmoji)
                  SizedBox(
                    height: mq.height * .35,
                    child: EmojiPicker(
                      textEditingController: _textController,
                      config: const Config(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatListView() {
    return StreamBuilder(
      stream: APIs.getAllMessages(widget.user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.done) {
          final data = snapshot.data?.docs;
          _list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
          return _list.isEmpty
              ? const Center(child: Text('Say Hii! 👋', style: TextStyle(fontSize: 20)))
              : ListView.builder(
            reverse: true,
            padding: EdgeInsets.only(top: mq.height * .01),
            physics: const BouncingScrollPhysics(),
            itemCount: _list.length,
            itemBuilder: (context, i) => MessageCard(message: _list[i]),
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _appBar() {
    return SafeArea(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(user: widget.user))),
        child: StreamBuilder(
          stream: APIs.getUserInfo(widget.user),
          builder: (context, snap) {
            final list = snap.data?.docs.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
            final user = list.isNotEmpty ? list[0] : widget.user;
            return Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.black54)),
                ProfileImage(size: mq.height * .05, url: user.image),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      user.isOnline ? 'Online' : MyDateUtil.getLastActiveTime(context: context, lastActive: user.lastActive),
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chatInput() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mq.height * .01, horizontal: mq.width * .025),
      child: Row(children: [
        Expanded(
          child: Card(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            child: Row(children: [
              IconButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _showEmoji = !_showEmoji);
                },
                icon: const Icon(Icons.emoji_emotions, color: Colors.blueAccent, size: 25),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  onTap: () {
                    if (_showEmoji) setState(() => _showEmoji = false);
                  },
                  decoration: const InputDecoration(
                      hintText: 'Type Something...',
                      hintStyle: TextStyle(color: Colors.blueAccent),
                      border: InputBorder.none),
                ),
              ),
              // GALLERY button
              IconButton(
                onPressed: () async {
                  final XFile? media = await _picker.pickMedia(); // gallery
                  if (media != null) await _handlePickedFile(File(media.path));
                },
                icon: const Icon(Icons.photo_library, color: Colors.blueAccent, size: 26),
              ),
              // CAMERA button
              IconButton(
                onPressed: () async {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: const Text('Capture Image'),
                            onTap: () async {
                              Navigator.pop(context);
                              final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                              if (image != null) await _handlePickedFile(File(image.path));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.videocam),
                            title: const Text('Capture Video'),
                            onTap: () async {
                              Navigator.pop(context);
                              final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
                              if (video != null) await _handlePickedFile(File(video.path));
                            },
                          ),
                      ListTile(),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.blueAccent, size: 26),
              ),
            ]),
          ),
        ),
        MaterialButton(
          onPressed: () {
            if (_textController.text.isNotEmpty) {
              final msg = _textController.text.trim();
              _sendText(msg);
              _textController.clear();
            }
          },
          color: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          shape: const CircleBorder(),
          child: const Icon(Icons.send, color: Colors.white, size: 28),
        )
      ]),
    );
  }

  Future<void> _handlePickedFile(File file) async {
    setState(() => _isUploading = true);

    final mime = lookupMimeType(file.path);
    if (mime != null && mime.startsWith('video')) {
      await APIs.sendChatVideo(widget.user, file);
    } else {
      await APIs.sendChatImage(widget.user, file);
    }

    setState(() => _isUploading = false);
  }

  void _sendText(String msg) {
    if (_list.isEmpty) {
      APIs.sendFirstMessage(widget.user, msg, Type.text);
    } else {
      APIs.sendMessage(widget.user, msg, Type.text);
    }
  }
}
