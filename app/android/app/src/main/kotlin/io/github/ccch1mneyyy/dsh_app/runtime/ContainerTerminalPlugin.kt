package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.OutputStream
import kotlin.concurrent.thread

/**
 * The container's own shell, independent of the engine: MethodChannel `dsh/container_terminal`
 * and EventChannel `dsh/container_terminal/output`.
 *
 * The engine may be down (a plugin broke it, a bad config); this shell still runs, so the
 * user can remove the plugin, fix the config and start the engine again.
 *
 * - `start` → begins `/bin/sh` in the runtime rootfs (proot), streams its output.
 * - `write {text}` → appends [text] to the shell's stdin (a newline is added when missing).
 * - `stop` → ends the shell.
 * - `run {command}` → one shot: `start`, `write`, waits, returns the collected output.
 */
class ContainerTerminalPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())

    private var process: Process? = null
    private var stdin: OutputStream? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, OUTPUT).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { eventSink = sink }

                override fun onCancel(arguments: Any?) { eventSink = null }
            })
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopShell()
        methods?.setMethodCallHandler(null)
        methods = null
        events?.setStreamHandler(null)
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val started = startShell()
                if (started) result.success(true)
                else result.error("start_failed", "the container shell could not be started", null)
            }
            "write" -> {
                val text = call.argument<String>("text")
                if (text == null) { result.error("invalid", "text is required", null); return }
                if (!write(text)) { result.error("not_running", "the container shell is not running", null); return }
                result.success(true)
            }
            "stop" -> { stopShell(); result.success(null) }
            "run" -> {
                val command = call.argument<String>("command")
                if (command == null) { result.error("invalid", "command is required", null); return }
                thread(name = "dsh-container-run") {
                    val outcome = runCatching { runOnce(command) }
                    main.post {
                        outcome.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("run_failed", it.message, null) },
                        )
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    // ── Shell ────────────────────────────────────────────────────────────────

    /** Starts the shell once; a second call while it lives only reports success. */
    @Synchronized
    private fun startShell(): Boolean {
        if (process?.isAlive == true) return true
        stopShell()
        val argv = shellArgv() ?: return false
        val launched = runCatching { ProcessBuilder(argv).start() }.getOrNull() ?: return false
        process = launched
        stdin = launched.outputStream
        thread(name = "dsh-container-out", isDaemon = true) { pump(launched) }
        return true
    }

    /** One command in its own shell, so it never disturbs a live session. */
    private fun runOnce(command: String): Map<String, Any> {
        val argv = shellArgv(listOf("/bin/sh", "-c", command))
            ?: error("the container runtime is not installed")
        val launched = ProcessBuilder(argv).start()
        val out = launched.inputStream.readBytes().toString(Charsets.UTF_8)
        val err = launched.errorStream.readBytes().toString(Charsets.UTF_8)
        val code = launched.waitFor()
        return mapOf("stdout" to out, "stderr" to err, "exitCode" to code)
    }

    private fun write(text: String): Boolean {
        val stream = stdin ?: return false
        return runCatching {
            stream.write((if (text.endsWith("\n")) text else "$text\n").toByteArray(Charsets.UTF_8))
            stream.flush()
            true
        }.getOrDefault(false)
    }

    @Synchronized
    private fun stopShell() {
        runCatching { stdin?.close() }
        stdin = null
        process?.let { runCatching { it.destroy() } }
        process = null
    }

    /** Reads the shell's stdout/stderr and forwards every chunk to the Dart side. */
    private fun pump(launched: Process) {
        val buffer = ByteArray(8 * 1024)
        try {
            while (true) {
                val available = launched.inputStream.available()
                if (available > 0) {
                    val read = launched.inputStream.read(buffer)
                    if (read < 0) break
                    if (read > 0) emit(String(buffer, 0, read, Charsets.UTF_8))
                } else {
                    Thread.sleep(40)
                }
            }
        } catch (_: InterruptedException) {
            // stopped
        } catch (_: Exception) {
            // the process ended
        } finally {
            runCatching { launched.waitFor() }
            main.post { eventSink?.success(mapOf("event" to "exit")) }
        }
    }

    private fun emit(text: String) {
        main.post { eventSink?.success(mapOf("event" to "output", "text" to text)) }
    }

    /**
     * The runtime manifest's proot template, with the guest command replaced by a shell.
     * Placeholders are expanded the same way [DshProcess] expands the engine's launch.
     */
    private fun shellArgv(guest: List<String> = listOf("/bin/sh")): List<String>? {
        val manifest = runCatching { RuntimeManifest.load(context) }.getOrNull() ?: return null
        val rootfs = File(context.filesDir, "runtime/rootfs")
        if (!rootfs.isDirectory) return null
        val tmp = File(context.cacheDir, "proot-tmp").apply { mkdirs() }
        val nativeLib = context.applicationInfo.nativeLibraryDir ?: return null
        val vars = mapOf(
            "{NATIVE_LIB_DIR}" to nativeLib,
            "{ROOTFS}" to rootfs.canonicalPath,
            "{TMP}" to tmp.absolutePath,
            "{FILES_DIR}" to context.filesDir.absolutePath,
        )
        fun expand(s: String) = vars.entries.fold(s) { acc, (k, v) -> acc.replace(k, v) }
        val argv = manifest.launchArgv
        val envAt = argv.indexOf("/usr/bin/env")
        if (envAt < 1) return null
        val head = argv.take(envAt + 1).map(::expand)
        // The engine's launch carries {GUEST_ENV} and the web command; the shell needs neither.
        val env = argv.drop(envAt + 1)
            .filterNot { it == "{GUEST_ENV}" || it.startsWith("{PORT}") || it == "/bin/sh" || it == "-c" }
            .map(::expand)
        return head + env + guest.map(::expand)
    }

    companion object {
        const val CHANNEL = "dsh/container_terminal"
        const val OUTPUT = "dsh/container_terminal/output"
    }
}
