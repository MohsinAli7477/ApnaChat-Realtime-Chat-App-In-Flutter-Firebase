import 'dart:developer';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../main.dart';
import '../models/message.dart';

// for showing single message details
class MessageCard extends StatefulWidget {
  const MessageCard({super.key, required this.message});

  final Message message;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    final msg = widget.message.msg;
    if (widget.message.type == Type.video || msg.toLowerCase().endsWith(".mp4")) {
      _initVideo();
    }
  }


  void _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.message.msg),
    );

    await _videoController!.initialize();
    _videoController!.setLooping(false);
    setState(() => _isVideoInitialized = true);
  }


  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMe = APIs.user.uid == widget.message.fromId;
    return InkWell(
        onLongPress: () => _showBottomSheet(isMe),
        child: isMe ? _greenMessage() : _blueMessage());
  }

  Widget _messageContent() {
    final msg = widget.message.msg;

    bool isVideoUrl(String url) => url.toLowerCase().endsWith(".mp4");

    if (widget.message.type == Type.text && isVideoUrl(msg)) {
      // Fallback for incorrect message type
      if (!_isVideoInitialized) _initVideo();
    }

    if ((widget.message.type == Type.video || isVideoUrl(msg)) && _isVideoInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 48,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    if (widget.message.type == Type.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: CachedNetworkImage(
          imageUrl: msg,
          fit: BoxFit.cover,
          placeholder: (_, __) =>
          const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Icon(Icons.image, size: 70),
        ),
      );
    }

    return Text(msg, style: const TextStyle(fontSize: 15, color: Colors.black87));
  }


  Widget _blueMessage() {
    if (widget.message.read.isEmpty) {
      APIs.updateMessageReadStatus(widget.message);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.all(mq.width * .03),
            margin: EdgeInsets.symmetric(horizontal: mq.width * .04, vertical: mq.height * .01),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 221, 245, 255),
              border: Border.all(color: Colors.lightBlue),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: _messageContent(),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: mq.width * .04),
          child: Text(
            MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _greenMessage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(width: mq.width * .04),
            if (widget.message.read.isNotEmpty)
              const Icon(Icons.done_all_rounded, color: Colors.blue, size: 20),
            const SizedBox(width: 2),
            Text(
              MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        Flexible(
          child: Container(
            padding: EdgeInsets.all(mq.width * .03),
            margin: EdgeInsets.symmetric(horizontal: mq.width * .04, vertical: mq.height * .01),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 218, 255, 176),
              border: Border.all(color: Colors.lightGreen),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              ),
            ),
            child: _messageContent(),
          ),
        ),
      ],
    );
  }

  void _showBottomSheet(bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            Container(
              height: 4,
              margin: EdgeInsets.symmetric(vertical: mq.height * .015, horizontal: mq.width * .4),
              decoration: const BoxDecoration(
                  color: Colors.grey, borderRadius: BorderRadius.all(Radius.circular(8))),
            ),
            if (widget.message.type == Type.text)
              _OptionItem(
                icon: const Icon(Icons.copy_all_rounded, color: Colors.blue, size: 26),
                name: 'Copy Text',
                onTap: (context) async {
                  await Clipboard.setData(ClipboardData(text: widget.message.msg));
                  Navigator.pop(context);
                  Dialogs.showSnackbar(context, 'Text Copied!');
                },
              )
            else
              _OptionItem(
                icon: const Icon(Icons.download_rounded, color: Colors.blue, size: 26),
                name: 'Save to Gallery',
                onTap: (context) async {
                  final isVideo = widget.message.type == Type.video;
                  final result = isVideo
                      ? await GallerySaver.saveVideo(widget.message.msg, albumName: 'Disco Chat')
                      : await GallerySaver.saveImage(widget.message.msg, albumName: 'Disco Chat');

                  Navigator.pop(context);
                  if (result == true) Dialogs.showSnackbar(context, 'Saved to Gallery!');
                },
              ),
            if (isMe) const Divider(color: Colors.black54),
            if (widget.message.type == Type.text && isMe)
              _OptionItem(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 26),
                name: 'Edit Message',
                onTap: (context) {
                  Navigator.pop(context);
                  _showMessageUpdateDialog(context);
                },
              ),
            if (isMe)
              _OptionItem(
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 26),
                name: 'Delete Message',
                onTap: (context) async {
                  await APIs.deleteMessage(widget.message);
                  Navigator.pop(context);
                },
              ),
            const Divider(color: Colors.black54),
            _OptionItem(
              icon: const Icon(Icons.access_time, color: Colors.blue),
              name: 'Sent At: ${MyDateUtil.getMessageTime(time: widget.message.sent)}',
              onTap: (_) {},
            ),
            _OptionItem(
              icon: const Icon(Icons.remove_red_eye, color: Colors.green),
              name: widget.message.read.isEmpty
                  ? 'Read At: Not seen yet'
                  : 'Read At: ${MyDateUtil.getMessageTime(time: widget.message.read)}',
              onTap: (_) {},
            ),
          ],
        );
      },
    );
  }

  void _showMessageUpdateDialog(BuildContext ctx) {
    String updatedMsg = widget.message.msg;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 10),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        title: const Row(children: [
          Icon(Icons.message, color: Colors.blue, size: 28),
          Text(' Update Message'),
        ]),
        content: TextFormField(
          initialValue: updatedMsg,
          maxLines: null,
          onChanged: (value) => updatedMsg = value,
          decoration: const InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15)))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                APIs.updateMessage(widget.message, updatedMsg);
                Navigator.pop(ctx);
              },
              child: const Text('Update'))
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final Icon icon;
  final String name;
  final Function(BuildContext) onTap;

  const _OptionItem({required this.icon, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(context),
      child: Padding(
        padding: EdgeInsets.only(
          left: mq.width * .05,
          top: mq.height * .015,
          bottom: mq.height * .015,
        ),
        child: Row(children: [
          icon,
          Flexible(
              child: Text('    $name',
                  style: const TextStyle(fontSize: 15, color: Colors.black54, letterSpacing: 0.5))),
        ]),
      ),
    );
  }
}
