package io.github.ccch1mneyyy.dsh_app.runtime

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CrashClassifierTest {
    @get:Rule val tmp = TemporaryFolder()

    private val fatal = listOf("dsh: startup failed: required row missing")

    /** Exactly what Node 24 prints for `node -e 'throw new Error("boom")'`, measured. */
    private val nodeThrow = listOf(
        "[eval]:1",
        "throw new Error(\"boom\")",
        "^",
        "",
        "Error: boom",
        "    at [eval]:1:7",
        "    at runScriptInThisContext (node:internal/vm:219:10)",
        "    at node:internal/process/execution:451:12",
        "Node.js v24.22.0",
    )

    /** What a plugin that caught its own throw and logged it prints: no trailer. */
    private val caughtError = listOf(
        "handled: caught",
        "Error: caught",
        "plugin kept running",
    )

    /** `node --version` — a trailer with nothing before it. */
    private val versionOnly = listOf("Node.js v24.22.0")

    @Test fun classifiesAllFiveFailureKinds() {
        fun classify(ready: Long?, now: Long, tail: List<String>) =
            CrashClassifier.classify(137, ready, now, 123L, tail, false).kind
        assertEquals(FailureKind.KILLED, classify(1L, 180_000L, listOf("normal output")))
        assertEquals(FailureKind.STARTUP_FAILED, classify(null, 1L, fatal))
        assertEquals(FailureKind.CRASHED_EARLY, classify(1L, 120_001L, fatal))
        assertEquals(FailureKind.CRASHED_LATE, classify(1L, 120_002L, fatal))
        assertEquals(FailureKind.NO_SPACE, classify(null, 1L, fatal + "ENOSPC"))
    }

    @Test fun summariesNeverContainLaunchTokens() {
        val failure = CrashClassifier.classify(1, null, 1L, 1L,
            listOf("dsh: startup failed: http://localhost/?token=private-value"), false)
        assertFalse(failure.summary!!.contains("private-value"))
        assertTrue(failure.summary!!.contains("token="))
    }

    // --- #2: a plugin's uncaught throw must count, but only when it really killed Node ---

    @Test fun anUncaughtPluginThrowCountsAsAFatalMarker() {
        val failure = CrashClassifier.classify(1, null, 1L, 1L, nodeThrow, false)
        // No `dsh:` marker anywhere: before this change this was KILLED and never retried safely.
        assertEquals(FailureKind.STARTUP_FAILED, failure.kind)
        assertEquals("Error: boom", failure.summary)
        assertTrue("an uncaught throw must count toward safe mode", failure.kind.counts)
    }

    @Test fun anUncaughtThrowAfterReadyIsAnEarlyCrashNotAStartupFailure() {
        val failure = CrashClassifier.classify(1, 1L, 60_000L, 1L, nodeThrow, false)
        assertEquals(FailureKind.CRASHED_EARLY, failure.kind)
        assertEquals(60L, failure.upSeconds)
    }

    @Test fun aCaughtPluginErrorIsNotFatal() {
        // The plugin logged `Error: …` but the process never printed a trailer: it kept running.
        assertNull(CrashClassifier.nodeUncaught(caughtError))
        assertEquals(FailureKind.KILLED, CrashClassifier.classify(1, 1L, 180_000L, 1L, caughtError, false).kind)
    }

    @Test fun aBareVersionBannerIsNotAFatalMarker() {
        assertNull(CrashClassifier.nodeUncaught(versionOnly))
        assertEquals(FailureKind.KILLED, CrashClassifier.classify(1, 1L, 180_000L, 1L, versionOnly, false).kind)
    }

    @Test fun anErrorWithNoFramesAtAllIsNotTreatedAsAHostDeath() {
        // "Error: x" immediately followed by the trailer is a plugin printing a version after
        // a handled error, not a V8 unwind (a real one always has frames between the two).
        val thin = listOf("Error: not actually fatal", "Node.js v24.22.0")
        assertNull(CrashClassifier.nodeUncaught(thin))
        assertEquals(FailureKind.KILLED, CrashClassifier.classify(1, 1L, 180_000L, 1L, thin, false).kind)
    }

    @Test fun aZeroExitNeverBecomesFatalFromAStrayTrailer() {
        // A plugin that prints a Node banner and exits cleanly on purpose.
        val failure = CrashClassifier.classify(0, 1L, 180_000L, 1L, nodeThrow, false)
        assertEquals(FailureKind.KILLED, failure.kind)
    }

    @Test fun aModuleLoadFailureIsRecognised() {
        val requireFail = listOf(
            "node:internal/modules/cjs/loader:1568",
            "  throw err;",
            "  ^",
            "",
            "Error: Cannot find module '/tmp/nope'",
            "Require stack:",
            "- /tmp/[eval]",
            "    at Module._resolveFilename (node:internal/modules/cjs/loader:1564:15)",
            "Node.js v24.22.0",
        )
        assertTrue(CrashClassifier.isRequireFailure(requireFail))
        assertEquals(FailureKind.STARTUP_FAILED, CrashClassifier.classify(1, null, 1L, 1L, requireFail, false).kind)
    }

    // --- #2: attribution must separate "the stack hit it" from "it merely changed" ---

    @Test fun onlyAStackHitIsACulpritAndAChangeAloneIsOnlyACandidate() {
        val byStack = CrashClassifier.attribute(suspects = listOf("dsh-purge"), recent = emptyList())
        assertEquals(SuspectSource.STACK, byStack.single().source)

        val byChange = CrashClassifier.attribute(suspects = emptyList(), recent = listOf("dsh-purge"))
        assertEquals(SuspectSource.RECENT_CHANGE, byChange.single().source)

        val both = CrashClassifier.attribute(suspects = listOf("dsh-purge"), recent = listOf("dsh-purge"))
        assertEquals(SuspectSource.STACK_AND_RECENT, both.single().source)
    }

    @Test fun attributionListsStackSuspectsBeforeChangeOnlyOnes() {
        val list = CrashClassifier.attribute(
            suspects = listOf("a-plugin"),
            recent = listOf("b-bundle"),
        )
        assertEquals(listOf("a-plugin", "b-bundle"), list.map { it.name })
        assertEquals(SuspectSource.STACK, list[0].source)
        assertEquals(SuspectSource.RECENT_CHANGE, list[1].source)
    }

    @Test fun aMissingManifestLeavesTheVersionUnknownInsteadOfThrowing() {
        val root = tmp.newFolder("rootfs")
        assertNull(CrashClassifier.versionOf(root, "dsh-purge"))

        // A directory with no package.json: still null, still no exception.
        tmp.newFolder("rootfs", "node_modules", "dsh-purge")
        assertNull(CrashClassifier.versionOf(root, "dsh-purge"))
    }

    @Test fun readsTheVersionFromTheRealManifest() {
        val root = tmp.newFolder("rootfs2")
        val pkg = tmp.newFolder("rootfs2", "node_modules", "dsh-purge")
        java.io.File(pkg, "package.json").writeText("""{"name":"dsh-purge","version":"1.1.67"}""")
        assertEquals("1.1.67", CrashClassifier.versionOf(root, "dsh-purge"))
    }

    @Test fun aHalfWrittenManifestIsSurvivable() {
        val root = tmp.newFolder("rootfs3")
        val pkg = tmp.newFolder("rootfs3", "node_modules", "dsh-purge")
        java.io.File(pkg, "package.json").writeText("""{"name":"dsh-purge","vers""")
        assertNull(CrashClassifier.versionOf(root, "dsh-purge"))
    }

    @Test fun aScopedPackageNameKeepsItsScope() {
        assertEquals("@scope/pkg", CrashClassifier.stackPackage(
            "    at f (/profiles/web/node_modules/@scope/pkg/lib/index.js:1:1)",
        ))
        assertEquals("pkg", CrashClassifier.stackPackage(
            "    at f (/profiles/web/node_modules/.pnpm/pkg@1.0.0/node_modules/pkg/lib/index.js:1:1)",
        ))
    }
}