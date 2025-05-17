import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class EncryptionService {
  // Generate a random encryption key
  static String generateEncryptionKey() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  // Encrypt a file and return the path to the encrypted file
  static Future<String> encryptFile(String filePath, String encryptionKey) async {
    try {
      // Read the file
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      // Create a temporary file for the encrypted data
      final tempDir = await getTemporaryDirectory();
      final encryptedFilePath = path.join(
        tempDir.path, 
        'encrypted_${path.basename(filePath)}'
      );
      
      // Encrypt the data
      final encryptedBytes = await compute(
        _encryptBytes, 
        _EncryptionParams(bytes, encryptionKey)
      );
      
      // Write the encrypted data to the temporary file
      await File(encryptedFilePath).writeAsBytes(encryptedBytes);
      
      return encryptedFilePath;
    } catch (e) {
      throw 'Failed to encrypt file: $e';
    }
  }

  // Decrypt a file and return the path to the decrypted file
  static Future<String> decryptFile(String encryptedFilePath, String encryptionKey, String originalFileName) async {
    try {
      // Read the encrypted file
      final file = File(encryptedFilePath);
      final bytes = await file.readAsBytes();
      
      // Create a file for the decrypted data
      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${appDir.path}/BluetoothPhotoTransfer');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      final decryptedFilePath = path.join(
        outputDir.path, 
        originalFileName
      );
      
      // Decrypt the data
      final decryptedBytes = await compute(
        _decryptBytes, 
        _EncryptionParams(bytes, encryptionKey)
      );
      
      // Write the decrypted data to the file
      await File(decryptedFilePath).writeAsBytes(decryptedBytes);
      
      return decryptedFilePath;
    } catch (e) {
      throw 'Failed to decrypt file: $e';
    }
  }
  
  // Helper method to encrypt bytes in an isolate
  static Uint8List _encryptBytes(_EncryptionParams params) {
    try {
      // Create a key from the encryption key string
      final key = encrypt.Key.fromUtf8(params.key.padRight(32, '0').substring(0, 32));
      final iv = encrypt.IV.fromLength(16);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(params.bytes, iv: iv);
      
      // Combine IV and encrypted data
      final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
      result.setRange(0, iv.bytes.length, iv.bytes);
      result.setRange(iv.bytes.length, result.length, encrypted.bytes);
      
      return result;
    } catch (e) {
      throw 'Encryption failed: $e';
    }
  }
  
  // Helper method to decrypt bytes in an isolate
  static Uint8List _decryptBytes(_EncryptionParams params) {
    try {
      // Create a key from the encryption key string
      final key = encrypt.Key.fromUtf8(params.key.padRight(32, '0').substring(0, 32));
      
      // Extract IV from the first 16 bytes
      final ivBytes = params.bytes.sublist(0, 16);
      final iv = encrypt.IV(ivBytes);
      
      // Extract encrypted data
      final encryptedBytes = params.bytes.sublist(16);
      final encrypted = encrypt.Encrypted(encryptedBytes);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw 'Decryption failed: $e';
    }
  }
  
  // Generate a hash of the file for verification
  static Future<String> generateFileHash(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

// Helper class for passing parameters to isolate
class _EncryptionParams {
  final Uint8List bytes;
  final String key;
  
  _EncryptionParams(this.bytes, this.key);
}
