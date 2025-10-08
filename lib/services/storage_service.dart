import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile(String folder) async {
    // Pick file (pdf/image/anything)
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();

      // Save to folder (example: "notes", "pyqs", etc.)
      Reference ref = _storage.ref().child("$folder/$fileName");

      await ref.putFile(file);
      return await ref.getDownloadURL();
    }
    return null;
  }
}
