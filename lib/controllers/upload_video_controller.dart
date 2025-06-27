import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_api/uploader/cloudinary_uploader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:tiktok_clone/models/video.dart';
import 'package:video_compress/video_compress.dart';

class UploadVideoController extends GetxController {
  final cloudinary = Cloudinary.fromStringUrl(
    'cloudinary://328191118841655:G0iHWlPWO3rxz_q1K1_NssxSNu4@dsilgv85z',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<File> _compressVideo(String videoPath) async {
    final compressedVideo = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.MediumQuality,
    );
    return compressedVideo!.file!;
  }

  Future<File> _getThumbnail(String videoPath) async {
    final thumbnail = await VideoCompress.getFileThumbnail(videoPath);
    return thumbnail;
  }

  Future<String?> _uploadFileToCloudinary(File file) async {
    try {
      var response = await cloudinary.uploader().upload(file);
      print('Cloudinary response: ${response?.data}');
      final data = response?.data;
      if (data != null) {
        // final urlCandidates = [
        //   data.secureUrl,
        //   data.url,
        //   data.toString(),
        // ];
        // for (var candidate in urlCandidates) {
        //   if (candidate != null && candidate.toString().startsWith('http')) {
        //     return candidate.toString();
        //   }
        // }
      }
      return response?.data?.url;
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }

  Future<void> uploadVideo(
    String songName,
    String caption,
    String videoPath,
  ) async {
    try {
      String uid = _auth.currentUser!.uid;
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();
      var allDocs = await _firestore.collection('videos').get();
      int len = allDocs.docs.length;
      String videoId = "Video $len";
      File compressedVideo = await _compressVideo(videoPath);
      String? videoUrl = await _uploadFileToCloudinary(compressedVideo);
      File thumbnailFile = await _getThumbnail(videoPath);
      String? thumbnailUrl = await _uploadFileToCloudinary(thumbnailFile);

      if (videoUrl == null || thumbnailUrl == null) {
        Get.snackbar('Error', 'Cloudinary upload failed');
        return;
      }

      Video video = Video(
        username: (userDoc.data()! as Map<String, dynamic>)['name'],
        uid: uid,
        id: videoId,
        likes: [],
        commentCount: 0,
        shareCount: 0,
        songName: songName,
        caption: caption,
        videoUrl: videoUrl,
        profilePhoto: (userDoc.data()! as Map<String, dynamic>)['profilePhoto'],
        thumbnail: thumbnailUrl,
      );

      print('Saving video metadata to Firestore...');
      await _firestore.collection('videos').doc(videoId).set(video.toJson());
      print('Saved video metadata to Firestore!');
      Get.back();
      Get.snackbar(
        'Success',
        'Video uploaded to Cloudinary and saved in Firebase!',
      );
    } catch (e) {
      print('Error saving video: $e');
      Get.snackbar('Error Uploading Video', e.toString());
    }
  }
}
