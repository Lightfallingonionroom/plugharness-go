package io.github.ccch1mneyyy.dsh_app.runtime

import java.io.File

/**
 * Why the local DSH stopped when nobody asked it to.
 * DSH fatal markers and explicit early V8 heap exhaustion can count toward recovery.
 * An unmarked exit (low-memory kill, battery saver, child-process limits) never does.
 */
enum class FailureKind(val wire: String) {
    /** PRoot, the shell/loader or direct preload could not start DSH before ready. */
    LAUNCH_FAILED("launchFailed"),

    /** Exited with a fatal marker before the runtime reported ready. */
    STARTUP_FAILED("startupFailed"),

    /** Exited with a fatal marker within [CrashClassifier.EARLY_WINDOW_MS] of the ready transition. */
    CRASHED_EARLY("crashedEarly"),

    /** Exited with a fatal marker after running longer than that. */
    CRASHED_LATE("crashedLate"),

    /** Exited without a recognized startup/fatal marker; an external kill is possible. */
    KILLED("killed"),

    /** The output mentions a full disk. */
    NO_SPACE("noSpace");

    /** Counts toward the consecutive failures that lead into safe mode. */
    val counts: Boolean get() = this == STARTUP_FAILED || this == CRASHED_EARLY

    companion object {
        fun parse(wire: String?): FailureKind? = entries.firstOrNull { it.wire == wire }
    }
}

data class RunFailure(
    val kind: FailureKind,
    val exitCode: Int,
    /** Wall-clock time of the exit (ms). */
    val at: Long,
    /** The failed run was a safe-mode run. */
    val safeMode: Boolean,
    /** First fatal or launch error line, without the `dsh: ` prefix and with tokens masked. */
    val summary: String?,
    /** Required rows the startup audit names (`agent-loop (required)`): broken, not necessarily the culprit. */
    val requiredRows: List<String>,
    /** Third-party packages named by stack paths or `Package:` lines. */
    val suspects: List<String>,
    /** Bundles enabled or upgraded since the last good run (filled in by the controller). */
    val recent: List<String> = emptyList(),
    /** Guest path of DSH's startup diagnostics file, if it printed one. */
    val diagnostics: String?,
    /** Seconds between the ready transition and exit; null when ready was never reported. */
    val upSeconds: Long?,
    /**
     * Package name → version for packages the crash evidence actually names.
     *
     * Empty for a silent exit. A suspect whose version is unknown is simply absent here;
     * [CrashClassifier.VersionSource] says why the map has no entry for it.
     */
    val suspectVersions: Map<String, String> = emptyMap(),
    /**
     * How the evidence names each suspect, for the safe-mode briefing to tell
     * "the stack hit it" apart from "it merely changed since the last good run".
     */
    val attributions: List<SuspectAttribution> = emptyList(),
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "kind" to kind.wire,
        "exitCode" to exitCode,
        "at" to at,
        "safeMode" to safeMode,
        "summary" to summary,
        "requiredRows" to requiredRows,
        "suspects" to suspects,
        "recent" to recent,
        "diagnostics" to diagnostics,
        "upSeconds" to upSeconds,
        "suspectVersions" to suspectVersions,
        "attributions" to attributions.map { it.toMap() },
    )
}

/** Why a package is on the suspect list, and how sure that is. */
enum class SuspectSource(val wire: String) {
    /** A stack frame or a `Package:` line named it. The strongest evidence there is. */
    STACK("stack"),

    /** Only `recentChanges()` named it: enabled or upgraded since the last good run. */
    RECENT_CHANGE("recent"),

    /** Both: the stack named it *and* it changed. */
    STACK_AND_RECENT("stackAndRecent"),
}

/**
 * One suspect and the evidence behind it.
 *
 * [version] is null when the manifest could not be read — a missing `package.json`, an
 * unreadable pnpm virtual-store path, or a package that is simply not on disk any more.
 * Guessing a version there would be worse than saying "unknown".
 */
data class SuspectAttribution(
    val name: String,
    val version: String?,
    val source: SuspectSource,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "name" to name,
        "version" to version,
        "source" to source.wire,
    )
}

/**
 * Fill in [RunFailure.attributions] and [RunFailure.suspectVersions] from the runtime's
 * `node_modules`, keeping the evidence source each suspect came from.
 *
 * Called once the `recent` list is known (the controller fills it, the classifier cannot).
 * Everything here is best-effort: a recovery path must never throw while *explaining* a crash.
 */
fun RunFailure.withVersionAttribution(rootfs: java.io.File?): RunFailure {
    val merged = CrashClassifier.attribute(suspects, recent)
    if (rootfs == null) return copy(attributions = merged)
    val versions = merged.mapNotNull { attribution ->
        CrashClassifier.versionOf(rootfs, attribution.name)?.let { attribution.name to it }
    }.toMap()
    val resolved = merged.map { attribution ->
        attribution.copy(version = versions[attribution.name] ?: attribution.version)
    }
    return copy(attributions = resolved, suspectVersions = versions)
}

/** Pure classification of one finished run from its exit code, timing and last output lines. */
object CrashClassifier {
    const val EARLY_WINDOW_MS = 120_000L

    /** Output lines kept per run for classification and the failure log. */
    const val TAIL_LINES = 300

    private val FATAL = listOf(
        Regex("^dsh: startup failed:"),
        Regex("^dsh: fatal (uncaught exception|load failure):"),
        // Thrown before startup proper: a malformed patch layer, a .env with a launch-only variable, ...
        Regex("^[A-Za-z]*Error: dsh: "),
        Regex("^dsh: profile startup and cleanup failed"),
    )
    /**
     * A Node process dying of an uncaught throw, and Node's own trailer.
     *
     * Measured against Node 24 (the version this repo pins): an uncaught throw prints its
     * source line, `^`, `Error: …`, the frames, then exactly one `Node.js v24.22.0` line as
     * the process unwinds. **Both** halves are required — the trailer alone also shows up in
     * `node --version` and in a plugin that merely logs its runtime, and the error line alone
     * also shows up for a throw a plugin caught and printed.
     */
    private val NODE_TRAILER = Regex("^Node\\.js v\\d+\\.\\d+\\.\\d+")
    private val NODE_UNCAUGHT_HEAD = Regex("^(?:\\w*Error|Error): .+")
    /**
     * Node prints this one line for an unhandled rejection on its way out; it is the only
     * marker that tells a rejection apart from a throw when the stack has no `await`.
     */
    private val NODE_UNHANDLED_REJECTION = Regex("^(?:UnhandledPromiseRejection|node:internal/process/promises)")
    /** `Require stack:` / `- /path/to/whatever` — Node's module-loader failure block. */
    private val NODE_REQUIRE_STACK = Regex("^Require stack:|^- \\S")
    /** `node:internal/modules/cjs/loader:1568` — Node's own frames, never a plugin's. */
    private val NODE_INTERNAL = Regex("^node:internal/")
    private val HEAP_OOM = Regex(
        "^FATAL ERROR: (?:Reached heap limit|Ineffective mark-compacts near heap limit) " +
            "Allocation failed - JavaScript heap out of memory$",
    )
    private val NO_SPACE = Regex("ENOSPC|No space left on device")
    // Fixed executable and shell prefix: a plugin's generic error is not launch evidence.
    private val EXEC_FAILED = Regex(
        "^(?:/bin/)?(?:sh|bash|dash): (?:[0-9]+: )?exec: /usr/local/bin/dsh: " +
            "(?:Bad address|Exec format error|Permission denied|not found|Function not implemented|Operation not permitted)$",
    )
    // The first guest command failed before env or DSH could run; this is not an Android kill.
    private val PROOT_EXEC_FAILED = Regex(
        "^proot error: execve\\(\"/usr/bin/env\"\\): (?:Permission denied|Too many symbolic links encountered)$",
    )
    private val DIRECT_FAILED = listOf(
        Regex("^\\[dsh-app-direct] launch failed: .+"),
        Regex("^/.*/opt/node/bin/node: (?:error while loading shared libraries: .+|.+: version [`'].+['`] not found.*)$"),
        Regex("^/.*/ld-linux[^/: ]+\\.so(?:\\.[0-9]+)?: (?:cannot open shared object file|failed to map segment|invalid ELF header|ELF load command|cannot execute).*$"),
        Regex("^Error \\[ERR_MODULE_NOT_FOUND]: Cannot find module ['\"].*/opt/dsh-go/direct/(?:preload|dns|paths|processes|modules)\\.mjs['\"].*$"),
        Regex("^DshDirectModuleIdentityError: this file needs compatible launch; stop the engine and turn off Direct engine$"),
    )
    /**
     * 128 + SIGSYS: Android's seccomp filter killed the direct loader or node for a
     * syscall it forbids (glibc's `access` on x86_64). The kill prints nothing.
     */
    const val SIGSYS_EXIT = 128 + 31
    private const val SECCOMP_KILLED = "killed by the system's syscall filter (SIGSYS)"
    private val DIAGNOSTICS = Regex("^Full diagnostics: (\\S+)")
    private val REQUIRED_ROW = Regex("^\\s{2}(\\S+) \\(required\\)")
    private val PACKAGE = Regex("^\\s+Package: (\\S+)")
    private val TOKEN = Regex("token=[A-Za-z0-9._~%-]+")
    private const val WEB_MODULES = "/profiles/web/node_modules/"
    private const val SHIPPED_SCOPE = "@deepseek-ai/"
    private const val SUMMARY_MAX = 240

    /** A token deadline must not hide existing evidence, nor invent it for a silent loader. */
    fun classifyAfterTokenTimeout(tokenTimedOut: Boolean, failure: RunFailure): Boolean =
        tokenTimedOut && failure.kind in setOf(
            FailureKind.STARTUP_FAILED, FailureKind.NO_SPACE, FailureKind.LAUNCH_FAILED,
        )

    fun isFatal(line: String): Boolean = FATAL.any { it.containsMatchIn(line) }

    /**
     * Whether the tail holds a Node process dying of an uncaught throw or rejection.
     *
     * Requires the trailer (`Node.js vX.Y.Z`) *and* an error head, and rejects the shapes
     * that are not a host death:
     *
     * - a plugin that catches its own throw and logs it also prints `Error: …`, but the
     *   process keeps running, so no trailer follows;
     * - `node --version`, `process.version` or a plugin's startup banner prints the trailer
     *   with no error head;
     * - a *tool* that failed (a lint run, a test run) exits non-zero with an error head but
     *   prints `node:internal` frames only when Node itself died — a tool's own stack names
     *   the tool's files.
     *
     * Returns the offending error line so the caller can both classify and summarise it.
     */
    fun nodeUncaught(tail: List<String>): String? {
        val trailer = tail.indexOfLast { NODE_TRAILER.matches(it) }
        if (trailer < 0) return null
        // The throw's own line is the last `Error: …` before the trailer, not the first:
        // Node prints the source line, `^`, then the error.
        val head = (0 until trailer).lastOrNull { NODE_UNCAUGHT_HEAD.matches(tail[it]) } ?: return null
        // Node's own frames must be in the block; a bare two-line "Error + trailer" is a
        // plugin printing its version right after a caught error.
        val frames = (head + 1 until trailer).map { tail[it] }
        val nodeFrames = frames.count { NODE_INTERNAL.matches(it) }
        val pluginFrames = frames.count { it.trimStart().startsWith("at ") }
        if (nodeFrames == 0 && pluginFrames == 0) return null
        return tail[head]
    }

    /** True for Node's module-loader block, which names a package but not a running module. */
    fun isRequireFailure(tail: List<String>): Boolean = tail.any { NODE_REQUIRE_STACK.matches(it) }

    fun redact(line: String): String = TOKEN.replace(line, "•••")

    /**
     * [readyAt] and [now] share one monotonic clock (elapsedRealtime); [readyAt] is null when
     * the runtime never reported ready. [wallClock] only stamps the result.
     */
    fun classify(
        exitCode: Int,
        readyAt: Long?,
        now: Long,
        wallClock: Long,
        tail: List<String>,
        safeMode: Boolean,
        directEngine: Boolean = false,
    ): RunFailure {
        // V8 running out of heap while starting or just after counts like a DSH fatal (#75);
        // later it stays KILLED, which restarts. Neither names a culprit plugin.
        val early = exitCode != 0 && (readyAt == null || now - readyAt <= EARLY_WINDOW_MS)
        val dshFatal = tail.firstOrNull(::isFatal)
        // A plugin's uncaught throw kills Node with no `dsh:` marker at all. Treat it as
        // fatal only when the process really died: a non-zero exit *and* Node's trailer.
        // A plugin that logged a caught error and kept running has no trailer and stays
        // out of this branch, so it never counts toward safe mode.
        val nodeFatal = if (exitCode != 0) nodeUncaught(tail) else null
        val fatal = dshFatal ?: nodeFatal ?: tail.firstOrNull { HEAP_OOM.matches(it) }?.takeIf { early }
        val launch = if (readyAt == null && exitCode != 0) tail.firstOrNull {
            EXEC_FAILED.matches(it) || (!directEngine && PROOT_EXEC_FAILED.matches(it)) ||
                (directEngine && DIRECT_FAILED.any { pattern -> pattern.matches(it) })
        } ?: (if (directEngine && exitCode == SIGSYS_EXIT) SECCOMP_KILLED else null) else null
        val kind = when {
            tail.any { NO_SPACE.containsMatchIn(it) } -> FailureKind.NO_SPACE
            fatal == null && launch != null -> FailureKind.LAUNCH_FAILED
            fatal == null -> FailureKind.KILLED
            readyAt == null -> FailureKind.STARTUP_FAILED
            now - readyAt <= EARLY_WINDOW_MS -> FailureKind.CRASHED_EARLY
            else -> FailureKind.CRASHED_LATE
        }
        val required = LinkedHashSet<String>()
        val suspects = LinkedHashSet<String>()
        var diagnostics: String? = null
        for (line in tail) {
            REQUIRED_ROW.find(line)?.let { required += it.groupValues[1] }
            PACKAGE.find(line)?.groupValues?.get(1)?.let { if (!it.startsWith(SHIPPED_SCOPE)) suspects += it }
            stackPackage(line)?.let { if (!it.startsWith(SHIPPED_SCOPE)) suspects += it }
            DIAGNOSTICS.find(line)?.let { diagnostics = it.groupValues[1] }
        }
        val attributions = attribute(suspects.toList(), emptyList())
        return RunFailure(
            kind = kind,
            exitCode = exitCode,
            at = wallClock,
            safeMode = safeMode,
            summary = fatal?.let(::summarize)
                ?: (if (kind == FailureKind.LAUNCH_FAILED) launch else tail.lastOrNull { NO_SPACE.containsMatchIn(it) })
                    ?.let(::summarize),
            requiredRows = required.toList(),
            suspects = suspects.toList(),
            diagnostics = diagnostics,
            upSeconds = readyAt?.let { ((now - it).coerceAtLeast(0)) / 1000 },
            attributions = attributions,
        )
    }

    /**
     * Pair each suspect with what we actually know about it.
     *
     * [recent] comes from the controller (bundles changed since the last good run) and is
     * the weaker evidence: it says "this changed", not "this crashed". A package in both
     * lists is [SuspectSource.STACK_AND_RECENT] — the only case worth calling a culprit.
     *
     * Versions come from [versionOf]; a package whose manifest cannot be read keeps a null
     * version and the briefing says "version unknown" instead of inventing one.
     */
    fun attribute(suspects: List<String>, recent: List<String>): List<SuspectAttribution> {
        val recentSet = recent.toSet()
        return suspects.map { name ->
            SuspectAttribution(
                name = name,
                version = null,
                source = if (name in recentSet) SuspectSource.STACK_AND_RECENT else SuspectSource.STACK,
            )
        } + recent.filter { it !in suspects }.map { name ->
            SuspectAttribution(name = name, version = null, source = SuspectSource.RECENT_CHANGE)
        }
    }

    /**
     * Read `version` out of `<root>/<package path>/package.json`.
     *
     * Deliberately swallows everything: a missing file, a half-written manifest during an
     * install, a pnpm virtual-store layout we do not recognise. A recovery path that throws
     * while *explaining* a crash is worse than one that says "version unknown".
     */
    fun versionOf(root: File, name: String): String? = try {
        val manifest = File(File(root, "node_modules/$name"), "package.json")
        if (!manifest.isFile) null
        else Regex("\"version\"\\s*:\\s*\"([^\"]+)\"").find(manifest.readText())?.groupValues?.get(1)
    } catch (_: Exception) {
        null
    }

    /** `…/profiles/web/node_modules/[.pnpm/x@1/node_modules/]<pkg>/…` → `<pkg>` (scoped names kept whole). */
    fun stackPackage(line: String): String? {
        val start = line.indexOf(WEB_MODULES)
        if (start < 0) return null
        var rest = line.substring(start + WEB_MODULES.length).takeWhile { !it.isWhitespace() && it != ')' }
        val nested = rest.lastIndexOf("node_modules/")
        if (nested >= 0) rest = rest.substring(nested + "node_modules/".length)
        val parts = rest.split('/')
        val name = if (parts[0].startsWith("@") && parts.size > 1) parts[0] + "/" + parts[1] else parts[0]
        return name.takeIf { it.isNotEmpty() && !it.startsWith(".") && !it.contains(':') }
    }

    private fun summarize(line: String): String {
        var text = redact(line.trim())
        text = text.removePrefix("dsh: ")
        text = text.replaceFirst(Regex("^[A-Za-z]*Error: dsh: "), "")
        return if (text.length > SUMMARY_MAX) text.take(SUMMARY_MAX - 1) + "…" else text
    }
}
