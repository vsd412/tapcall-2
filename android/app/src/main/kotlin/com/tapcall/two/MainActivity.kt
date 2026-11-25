package com.tapcall.two

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract.RawContacts
import android.provider.ContactsContract.Data
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private data class Shortcut(val uri: Uri, val client: String)

    private val lookup = Executors.newSingleThreadExecutor()
    private var permissionReply: MethodChannel.Result? = null
    private val clients = listOf("com.whatsapp", "com.whatsapp.w4b")
    private val videoType = "vnd.android.cursor.item/vnd.com.whatsapp.video.call"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "tapcall/whatsapp").setMethodCallHandler { call, reply ->
            when (call.method) {
                "allowLookup" -> {
                    if (canReadContacts()) reply.success(true)
                    else if (permissionReply != null) reply.success(false)
                    else {
                        permissionReply = reply
                        requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), 100)
                    }
                }
                "video", "chat" -> {
                    val number = call.arguments as? String
                    if (number == null || !Regex("[1-9][0-9]{5,14}").matches(number)) reply.success("invalid")
                    else if (call.method == "chat") reply.success(openChat(number))
                    else startVideo(number, reply)
                }
                else -> reply.notImplemented()
            }
        }
    }

    private fun canReadContacts() = Build.VERSION.SDK_INT < 23 ||
        checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(code: Int, permissions: Array<String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 100) {
            permissionReply?.success(canReadContacts())
            permissionReply = null
        }
    }

    private fun startVideo(number: String, reply: MethodChannel.Result) {
        val installed = clients.any { client ->
            Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$number"))
                .setPackage(client).resolveActivity(packageManager) != null
        }
        if (!installed) {
            reply.success("missing")
            return
        }
        if (!canReadContacts()) {
            reply.success("permission")
            return
        }
        lookup.execute {
            val shortcut = try {
                findVideoShortcut(number)
            } catch (_: RuntimeException) {
                // Access can be revoked, or the provider can disappear during lookup.
                null
            }
            runOnUiThread {
                val opened = !isFinishing && !isDestroyed && shortcut != null &&
                    launch(Intent(Intent.ACTION_VIEW).setDataAndType(shortcut.uri, videoType).setPackage(shortcut.client))
                reply.success(if (opened) "opened" else "manual")
            }
        }
    }

    private fun findVideoShortcut(number: String): Shortcut? {
        // An aggregate contact can contain multiple numbers. Match the exact
        // WhatsApp identity and use the client that owns the matching action.
        val row = contentResolver.query(
            Data.CONTENT_URI, arrayOf(Data._ID, Data.RAW_CONTACT_ID),
            "${Data.MIMETYPE} = ? AND ${Data.DATA1} = ?",
            arrayOf(videoType, "$number@s.whatsapp.net"), null
        )?.use {
            if (it.count != 1 || !it.moveToFirst()) return null
            it.getLong(0) to it.getLong(1)
        } ?: return null

        val rawUri = ContentUris.withAppendedId(RawContacts.CONTENT_URI, row.second)
        val client = contentResolver.query(
            rawUri, arrayOf(RawContacts.ACCOUNT_TYPE), null, null, null
        )?.use { if (it.moveToFirst()) it.getString(0) else null } ?: return null
        if (client !in clients) return null
        return Shortcut(ContentUris.withAppendedId(Data.CONTENT_URI, row.first), client)
    }

    private fun openChat(number: String): String {
        val uri = Uri.parse("https://wa.me/$number")
        return if (clients.any { launch(Intent(Intent.ACTION_VIEW, uri).setPackage(it)) }) "opened" else "missing"
    }

    private fun launch(intent: Intent): Boolean {
        return try { startActivity(intent); true }
        catch (_: ActivityNotFoundException) { false }
        catch (_: SecurityException) { false }
    }

    override fun onDestroy() {
        lookup.shutdown()
        permissionReply?.success(false)
        permissionReply = null
        super.onDestroy()
    }
}
