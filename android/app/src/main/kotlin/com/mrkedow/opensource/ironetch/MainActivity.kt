package com.mrkedow.opensource.ironetch

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.mrkedow.opensource.ironetch/epub"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractAsset" -> {
                        val assetPath = call.argument<String>("assetPath")
                        val target = call.argument<String>("target")
                        if (assetPath == null || target == null) {
                            result.error("bad_args", "assetPath and target are required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                assets.open(assetPath).use { input ->
                                    extractZip(ZipInputStream(BufferedInputStream(input)), target)
                                }
                                runOnUiThread { result.success(true) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("extract_asset_failed", error.message, null)
                                }
                            }
                        }.start()
                    }

                    "extractFile" -> {
                        val filePath = call.argument<String>("filePath")
                        val target = call.argument<String>("target")
                        if (filePath == null || target == null) {
                            result.error("bad_args", "filePath and target are required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                File(filePath).inputStream().use { input ->
                                    extractZip(ZipInputStream(BufferedInputStream(input)), target)
                                }
                                runOnUiThread { result.success(true) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("extract_file_failed", error.message, null)
                                }
                            }
                        }.start()
                    }

                    "enqueueDownload" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName") ?: "download.bin"
                        if (url == null) {
                            result.error("bad_args", "url is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(enqueueDownload(url, fileName))
                        } catch (error: Exception) {
                            result.error("download_failed", error.message, null)
                        }
                    }

                    "downloadStatus" -> {
                        val id = call.argument<Number>("downloadId")?.toLong()
                        if (id == null) {
                            result.error("bad_args", "downloadId is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(downloadStatus(id))
                    }

                    "externalDownloadPath" -> {
                        val fileName = call.argument<String>("fileName") ?: "download.bin"
                        result.success(externalDownloadFile(fileName).absolutePath)
                    }

                    "deleteExternalDownload" -> {
                        val fileName = call.argument<String>("fileName") ?: "download.bin"
                        try {
                            externalDownloadFile(fileName).delete()
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun externalDownloadFile(fileName: String): File {
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: File(cacheDir, "downloads")
        if (!dir.exists()) dir.mkdirs()
        return File(dir, fileName)
    }

    private fun enqueueDownload(url: String, fileName: String): Map<String, Any> {
        val target = externalDownloadFile(fileName)
        if (target.exists()) target.delete()
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("下载内置书")
            .setDescription("正在下载《北科·健身全书》，可切到后台继续")
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            .setDestinationInExternalFilesDir(
                this,
                Environment.DIRECTORY_DOWNLOADS,
                fileName,
            )
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val id = manager.enqueue(request)
        return mapOf("id" to id, "path" to target.absolutePath)
    }

    private fun downloadStatus(id: Long): Map<String, Any> {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(id))
        if (cursor == null) {
            return mapOf("status" to -1, "downloaded" to 0L, "total" to 0L)
        }
        try {
            if (cursor.moveToFirst()) {
                val status = cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
                )
                val downloaded = cursor.getLong(
                    cursor.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                    ),
                )
                val total = cursor.getLong(
                    cursor.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_TOTAL_SIZE_BYTES,
                    ),
                )
                return mapOf(
                    "status" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                )
            }
        } finally {
            cursor.close()
        }
        return mapOf("status" to -1, "downloaded" to 0L, "total" to 0L)
    }

    private fun extractZip(zip: ZipInputStream, targetPath: String) {
        val root = File(targetPath)
        if (root.exists()) root.deleteRecursively()
        if (!root.mkdirs() && !root.isDirectory) {
            throw IllegalStateException("无法创建目录: ${root.absolutePath}")
        }
        val rootPrefix = root.canonicalPath + File.separator
        var entry = zip.nextEntry
        while (entry != null) {
            val output = File(root, entry.name)
            if (!output.canonicalPath.startsWith(rootPrefix)) {
                throw SecurityException("非法压缩包路径: ${entry.name}")
            }
            if (entry.isDirectory) {
                output.mkdirs()
            } else {
                output.parentFile?.mkdirs()
                FileOutputStream(output).use { out -> zip.copyTo(out) }
            }
            zip.closeEntry()
            entry = zip.nextEntry
        }
        File(root, ".ft_extracted").writeText("ok")
    }
}
