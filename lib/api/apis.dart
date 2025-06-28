import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart';

import '../services/cloudinary_service.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import 'notification_access_token.dart';

class APIs {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  static ChatUser me = ChatUser(
    id: user.uid,
    name: user.displayName.toString(),
    email: user.email.toString(),
    about: "Hey, I'm using Disco Chat!",
    image: user.photoURL.toString(),
    createdAt: '',
    isOnline: false,
    lastActive: '',
    pushToken: '',
  );

  static User get user => auth.currentUser!;
  static FirebaseMessaging fMessaging = FirebaseMessaging.instance;

  static Future<void> getFirebaseMessagingToken() async {
    await fMessaging.requestPermission();
    await fMessaging.getToken().then((t) {
      if (t != null) {
        me.pushToken = t;
        log('Push Token: $t');
      }
    });
  }

  static Future<void> sendPushNotification(ChatUser chatUser, String msg) async {
    try {
      final body = {
        "message": {
          "token": chatUser.pushToken,
          "notification": {
            "title": me.name,
            "body": msg,
          },
        }
      };

      const projectID = 'disco-chat-bc2eb';
      final bearerToken = await NotificationAccessToken.getToken;

      log('bearerToken: $bearerToken');
      if (bearerToken == null) return;

      var res = await post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectID/messages:send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken',
        },
        body: jsonEncode(body),
      );

      log('Response status: ${res.statusCode}');
      log('Response body: ${res.body}');
    } catch (e) {
      log('\nsendPushNotificationE: $e');
    }
  }

  static Future<bool> userExists() async {
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  static Future<bool> addChatUser(String email) async {
    final data = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    log('data: ${data.docs}');

    if (data.docs.isNotEmpty && data.docs.first.id != user.uid) {
      firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});
      return true;
    } else {
      return false;
    }
  }

  static Future<void> getSelfInfo() async {
    await firestore.collection('users').doc(user.uid).get().then((user) async {
      if (user.exists) {
        me = ChatUser.fromJson(user.data()!);
        await getFirebaseMessagingToken();
        APIs.updateActiveStatus(true);
        log('My Data: ${user.data()}');
      } else {
        await createUser().then((value) => getSelfInfo());
      }
    });
  }

  static Future<void> createUser() async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final chatUser = ChatUser(
      id: user.uid,
      name: user.displayName.toString(),
      email: user.email.toString(),
      about: "Hey, I'm using Disco Chat!",
      image: user.photoURL.toString(),
      createdAt: time,
      isOnline: false,
      lastActive: time,
      pushToken: '',
    );

    return await firestore.collection('users').doc(user.uid).set(chatUser.toJson());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyUsersId() {
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(List<String> userIds) {
    log('\nUserIds: $userIds');

    return firestore
        .collection('users')
        .where('id', whereIn: userIds.isEmpty ? [''] : userIds)
        .snapshots();
  }

  static Future<void> sendFirstMessage(ChatUser chatUser, String msg, Type type) async {
    await firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({})
        .then((value) => sendMessage(chatUser, msg, type));
  }

  static Future<void> updateUserInfo() async {
    await firestore.collection('users').doc(user.uid).update({
      'name': me.name,
      'about': me.about,
    });
  }

  // ✅ Updated for Cloudinary
  static Future<void> updateProfilePicture(File file) async {
    final imageUrl = await CloudinaryService.uploadImage(file, folder: 'profile_pictures');
    if (imageUrl.isNotEmpty) {
      me.image = imageUrl;
      await firestore.collection('users').doc(user.uid).update({'image': me.image});
    } else {
      throw Exception("Image upload failed");
    }
  }


  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(ChatUser chatUser) {
    return firestore.collection('users').where('id', isEqualTo: chatUser.id).snapshots();
  }

  static Future<void> updateActiveStatus(bool isOnline) async {
    firestore.collection('users').doc(user.uid).update({
      'is_online': isOnline,
      'last_active': DateTime.now().millisecondsSinceEpoch.toString(),
      'push_token': me.pushToken,
    });
  }

  static String getConversationID(String id) =>
      user.uid.hashCode <= id.hashCode ? '${user.uid}_$id' : '${id}_${user.uid}';

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  static Future<void> sendMessage(ChatUser chatUser, String msg, Type type) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    final Message message = Message(
      toId: chatUser.id,
      msg: msg,
      read: '',
      type: type,
      fromId: user.uid,
      sent: time,
    );

    final ref = firestore.collection('chats/${getConversationID(chatUser.id)}/messages/');
    await ref.doc(time).set(message.toJson()).then((value) =>
        sendPushNotification(chatUser, type == Type.text ? msg : 'image'));
  }

  static Future<void> updateMessageReadStatus(Message message) async {
    firestore
        .collection('chats/${getConversationID(message.fromId)}/messages/')
        .doc(message.sent)
        .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessage(ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  // ✅ Updated for Cloudinary
  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    final imageUrl = await CloudinaryService.uploadImage(
      file,
      folder: 'chat_images/${getConversationID(chatUser.id)}',
    );

    if (imageUrl.isNotEmpty) {
      await sendMessage(chatUser, imageUrl, Type.image);
    } else {
      log('Image upload failed');
    }
  }
  static Future<void> sendChatVideo(ChatUser chatUser, File file) async {
    final videoUrl = await CloudinaryService.uploadVideo(
      file,
      folder: 'chat_videos/${getConversationID(chatUser.id)}',
    );

    if (videoUrl.isNotEmpty) {
      await sendMessage(chatUser, videoUrl, Type.video);
    } else {
      log('Video upload failed');
    }
  }


  static Future<void> deleteMessage(Message message) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .delete();

    // Can't delete from Cloudinary without a public_id, so skip that
  }

  static Future<void> updateMessage(Message message, String updatedMsg) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .update({'msg': updatedMsg});
  }
}
