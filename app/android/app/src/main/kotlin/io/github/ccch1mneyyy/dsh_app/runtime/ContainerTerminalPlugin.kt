package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The container's shell for the app's terminal page: MethodChannel `dsh/container_terminal`.
 *
 * The engine may be down (a plugin broke it, a bad config); this shell still runs, so the
 * user can remove the plugin, fix the config and start the engine again. The page spawns
 * it through `flutter_pty` — a real PTY is what gives the shell its prompt, line editing
 * and job control — using the runtime manifest's own proot template, so the command is
 * exactly the engine's launch with the web command replaced by `/bin/bash`.
 */
class ContainerTerminalPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var methods: MethodChannel? = null
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        methods = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shellSpec" -> {
                val spec = shellSpec()
                if (spec != null) result.success(spec)
                else result.error("not_installed", "the container runtime is not installed", null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * `{executable, arguments, environment}` for `Pty.start`, from the runtime manifest's
     * launch template: the proot argv up to `/usr/bin/env`, then the guest environment the
     * template sets, then `/bin/bash` instead of the web command.
     */
    private fun shellSpec(): Map<String, Any>? {
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
        val executable = head.firstOrNull() ?: return null
        val afterEnv = argv.drop(envAt + 1)
        // The web command (`/bin/sh -c …`) is the engine's; the shell replaces it.
        val guestAt = afterEnv.indexOf("/bin/sh")
        val envList = (if (guestAt >= 0) afterEnv.take(guestAt) else afterEnv)
            .filterNot { it == "{GUEST_ENV}" || it.startsWith("{PORT}") }
            .map(::expand)
        return mapOf(
            "executable" to executable,
            "arguments" to (head.drop(1) + envList + listOf("/bin/bash")),
            "environment" to manifest.launchEnv.mapValues { (_, v) -> expand(v) },
        )
    }

    companion object {
        const val CHANNEL = "dsh/container_terminal"
    }
}
