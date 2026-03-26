import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageResult {
  final Uint8List bytes;
  final String name;
  final String? path;
  final int size;
  
  ImageResult({
    required this.bytes,
    required this.name,
    this.path,
    required this.size,
  });
}

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();
  
  Future<ImageResult?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: kIsWeb ? 2048 : 1800,  
        maxHeight: kIsWeb ? 2048 : 1800,
        imageQuality: kIsWeb ? 90 : 85, 
      );
      
      if (pickedFile == null) return null;
      
      final bytes = await pickedFile.readAsBytes();
      
      if (bytes.length > 10 * 1024 * 1024) { 
        debugPrint('Imagen demasiado grande: ${bytes.length} bytes');
        return null;
      }
      
      return ImageResult(
        bytes: bytes,
        name: pickedFile.name,
        path: kIsWeb ? null : pickedFile.path,
        size: bytes.length,
      );
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      return null;
    }
  }
  
  Future<ImageResult?> pickImageFromCamera() async {
    if (kIsWeb) {
      try {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
        );
        
        if (pickedFile == null) return null;
        
        final bytes = await pickedFile.readAsBytes();
        
        return ImageResult(
          bytes: bytes,
          name: pickedFile.name,
          size: bytes.length,
        );
      } catch (e) {
        debugPrint('Cámara no disponible en web, usando galería: $e');
        return await pickImageFromGallery();
      }
    }
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return null;
      
      final bytes = await pickedFile.readAsBytes();
      
      return ImageResult(
        bytes: bytes,
        name: pickedFile.name,
        path: pickedFile.path,
        size: bytes.length,
      );
    } catch (e) {
      debugPrint('Error al capturar imagen: $e');
      return null;
    }
  }
  
  Future<List<ImageResult>> pickMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: kIsWeb ? 2048 : 1800,
        maxHeight: kIsWeb ? 2048 : 1800,
        imageQuality: kIsWeb ? 90 : 85,
      );
      
      if (pickedFiles.isEmpty) return [];
      
      List<ImageResult> results = [];
      
      for (XFile file in pickedFiles) {
        final bytes = await file.readAsBytes();
        
        if (bytes.length > 10 * 1024 * 1024) continue;
        
        results.add(ImageResult(
          bytes: bytes,
          name: file.name,
          path: kIsWeb ? null : file.path,
          size: bytes.length,
        ));
      }
      
      return results;
    } catch (e) {
      debugPrint('Error al seleccionar múltiples imágenes: $e');
      return [];
    }
  }
}