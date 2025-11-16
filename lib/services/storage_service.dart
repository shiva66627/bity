import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 🧩 Prevent multiple file pickers at once
  bool _isPicking = false;

  Future<String?> uploadFile(String folder) async {
    if (_isPicking) {
      print("⚠️ File picker already active. Ignoring duplicate tap.");
      return null; // Prevents the 'already_active' crash
    }

    _isPicking = true;

    try {
      // Open the file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // You can restrict to FileType.custom for PDFs
      );

      if (result == null) {
        print("❌ No file selected");
        return null;
      }

      // Convert result to File
      File file = File(result.files.single.path!);

      // Create a unique file name
      String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}";

      // Firebase Storage path
      Reference ref = _storage.ref().child("$folder/$fileName");

      // Upload the file
      print("📤 Uploading file to Firebase Storage: $fileName");
      await ref.putFile(file);

      // Get the public download URL
      final downloadUrl = await ref.getDownloadURL();
      print("✅ File uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("❌ Error during upload: $e");
      return null;
    } finally {
      // Always reset lock so user can pick again later
      _isPicking = false;
    }
  }
}
