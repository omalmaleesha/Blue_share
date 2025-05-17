// Update the sendFile method in MainActivity.kt to handle encryption metadata

private fun sendFile(call: MethodCall, result: MethodChannel.Result) {
    val filePath = call.argument<String>("filePath")
    val fileName = call.argument<String>("fileName")
    val isEncrypted = call.argument<Boolean>("isEncrypted") ?: false
    val encryptionKey = call.argument<String>("encryptionKey") ?: ""
    
    if (filePath == null || fileName == null) {
        result.error("INVALID_ARGUMENT", "File path and name are required", null)
        return
    }
    
    if (connectThread?.socket == null) {
        result.error("NOT_CONNECTED", "Not connected to a device", null)
        return
    }
    
    try {
        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File not found", null)
            return
        }
        
        // Start the transfer thread with encryption info
        transferThread = TransferThread(connectThread!!.socket!!, file, fileName, true, isEncrypted, encryptionKey)
        transferThread!!.start()
        
        result.success(true)
    } catch (e: Exception) {
        Log.e(TAG, "Error sending file: ${e.message}")
        result.error("SEND_ERROR", "Failed to send file", e.message)
    }
}

// Update the TransferThread constructor to include encryption parameters
private inner class TransferThread(
    private val socket: BluetoothSocket,
    private val file: File?,
    private val fileName: String?,
    private val isSender: Boolean,
    private val isEncrypted: Boolean = false,
    private val encryptionKey: String = ""
) : Thread() {
    private val inputStream: InputStream = socket.inputStream
    private val outputStream: OutputStream = socket.outputStream
    private var running = true
    
    override fun run() {
        if (isSender) {
            sendFile()
        } else {
            receiveFile()
        }
    }
    
    private fun sendFile() {
        try {
            if (file == null || fileName == null) {
                throw IOException("File or file name is null")
            }
            
            // Send the file name first
            val fileNameBytes = fileName.toByteArray()
            val fileNameLength = fileNameBytes.size
            
            // Send the file name length (4 bytes)
            outputStream.write(fileNameLength shr 24 and 0xFF)
            outputStream.write(fileNameLength shr 16 and 0xFF)
            outputStream.write(fileNameLength shr 8 and 0xFF)
            outputStream.write(fileNameLength and 0xFF)
            
            // Send the file name
            outputStream.write(fileNameBytes)
            
            // Send encryption flag (1 byte)
            outputStream.write(if (isEncrypted) 1 else 0)
            
            // If encrypted, send the encryption key length and key
            if (isEncrypted) {
                val keyBytes = encryptionKey.toByteArray()
                val keyLength = keyBytes.size
                
                // Send key length (4 bytes)
                outputStream.write(keyLength shr 24 and 0xFF)
                outputStream.write(keyLength shr 16 and 0xFF)
                outputStream.write(keyLength shr 8 and 0xFF)
                outputStream.write(keyLength and 0xFF)
                
                // Send the key
                outputStream.write(keyBytes)
            }
            
            // Send the file size (8 bytes)
            val fileSize = file.length()
            outputStream.write((fileSize shr 56 and 0xFF).toInt())
            outputStream.write((fileSize shr 48 and 0xFF).toInt())
            outputStream.write((fileSize shr 40 and 0xFF).toInt())
            outputStream.write((fileSize shr 32 and 0xFF).toInt())
            outputStream.write((fileSize shr 24 and 0xFF).toInt())
            outputStream.write((fileSize shr 16 and 0xFF).toInt())
            outputStream.write((fileSize shr 8 and 0xFF).toInt())
            outputStream.write((fileSize and 0xFF).toInt())
            
            // Send the file data
            val buffer = ByteArray(1024)
            val fileInputStream = FileInputStream(file)
            var bytesRead: Int
            var totalBytesRead: Long = 0
            
            while (fileInputStream.read(buffer).also { bytesRead = it } != -1 && running) {
                outputStream.write(buffer, 0, bytesRead)
                totalBytesRead += bytesRead
                
                // Report progress
                val progress = totalBytesRead.toDouble() / fileSize.toDouble()
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(mapOf(
                        "type" to "sendProgress",
                        "progress" to progress
                    ))
                }
            }
            
            fileInputStream.close()
            
            Log.d(TAG, "File sent successfully")
            
            // Notify the UI
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "type" to "fileSent",
                    "fileName" to fileName
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending file: ${e.message}")
            
            // Notify the UI
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "type" to "error",
                    "message" to "Failed to send file: ${e.message}"
                ))
            }
        }
    }
    
    private fun receiveFile() {
        try {
            // Notify the UI that transfer has started
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "type" to "transferStarted"
                ))
            }
            
            // Read the file name length (4 bytes)
            val fileNameLength = (inputStream.read() shl 24) or
                    (inputStream.read() shl 16) or
                    (inputStream.read() shl 8) or
                    inputStream.read()
            
            // Read the file name
            val fileNameBytes = ByteArray(fileNameLength)
            inputStream.read(fileNameBytes)
            val fileName = String(fileNameBytes)
            
            // Read encryption flag (1 byte)
            val isEncrypted = inputStream.read() == 1
            
            // If encrypted, read the encryption key
            var encryptionKey = ""
            if (isEncrypted) {
                // Read key length (4 bytes)
                val keyLength = (inputStream.read() shl 24) or
                        (inputStream.read() shl 16) or
                        (inputStream.read() shl 8) or
                        inputStream.read()
                
                // Read the key
                val keyBytes = ByteArray(keyLength)
                inputStream.read(keyBytes)
                encryptionKey = String(keyBytes)
            }
            
            // Read the file size (8 bytes)
            val fileSize = (inputStream.read().toLong() shl 56) or
                    (inputStream.read().toLong() shl 48) or
                    (inputStream.read().toLong() shl 40) or
                    (inputStream.read().toLong() shl 32) or
                    (inputStream.read().toLong() shl 24) or
                    (inputStream.read().toLong() shl 16) or
                    (inputStream.read().toLong() shl 8) or
                    inputStream.read().toLong()
            
            // Create the output file
            val outputDir = File(context.getExternalFilesDir(null), "BluetoothPhotoTransfer")
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }
            
            // Create a temporary file name if encrypted
            val tempFileName = if (isEncrypted) "temp_$fileName" else fileName
            val outputFile = File(outputDir, tempFileName)
            val fileOutputStream = FileOutputStream(outputFile)
            
            // Receive the file data
            val buffer = ByteArray(1024)
            var bytesRead: Int
            var totalBytesRead: Long = 0
            
            while (totalBytesRead < fileSize && running) {
                bytesRead = inputStream.read(buffer, 0, buffer.size.coerceAtMost((fileSize - totalBytesRead).toInt()))
                if (bytesRead == -1) break
                
                fileOutputStream.write(buffer, 0, bytesRead)
                totalBytesRead += bytesRead
                
                // Report progress
                val progress = totalBytesRead.toDouble() / fileSize.toDouble()
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(mapOf(
                        "type" to "progress",
                        "progress" to progress
                    ))
                }
            }
            
            fileOutputStream.close()
            
            // Notify the UI with encryption info
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "type" to "fileReceived",
                    "filePath" to outputFile.absolutePath,
                    "fileName" to fileName,
                    "isEncrypted" to isEncrypted,
                    "encryptionKey" to encryptionKey
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error receiving file: ${e.message}")
            
            // Notify the UI
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "type" to "error",
                    "message" to "Failed to receive file: ${e.message}"
                ))
            }
        }
    }
    
    fun cancel() {
        running = false
        try {
            socket.close()
        } catch (e: IOException) {
            Log.e(TAG, "Could not close the socket", e)
        }
    }
}
