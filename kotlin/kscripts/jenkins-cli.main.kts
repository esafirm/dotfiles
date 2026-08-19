#!/usr/bin/env kotlin

@file:DependsOn("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

import kotlinx.serialization.json.*
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.util.Base64

// ── Config ────────────────────────────────────────────────────────────────
val user = System.getenv("JENKINS_USER") ?: error("Missing JENKINS_USER env var")
val token = System.getenv("JENKINS_TOKEN") ?: error("Missing JENKINS_TOKEN env var")
val auth = "Basic " + Base64.getEncoder().encodeToString("$user:$token".toByteArray())

val jobs = mapOf(
    "run_ui_tests" to JobDef(
        url = "https://jenkins.example.com/job/run_ui_tests",
        params = listOf(
            ParamDef("branch", "branch to test"),
            ParamDef("testClass", "FQCN of test class or method", required = false),
            ParamDef("deviceName", "device pool name", default = "Pixel_7"),
        )
    )
)

data class ParamDef(val name: String, val desc: String, val default: String? = null, val required: Boolean = true)
data class JobDef(val url: String, val params: List<ParamDef>)

// ── Help ──────────────────────────────────────────────────────────────────
fun printUsage() {
    println(
        """
        Usage: jenkins-cli.main.kts <command> [args]

        Commands:
          test-report <buildOrTestReportUrl>   Show build cause, summary, and failed tests
          run-job <jobName> [key=value...]     Trigger a build non-interactively
          run [<jobName>]                      Interactive mode — pick or enter params
          jobs                                 List configured jobs and their parameters
          warnings <build-or-origin-url>       Show static analysis warnings
          get-job-config <name-or-url>         Print a job's config.xml
          update-job-config <name-or-url> <config-file>
                                               Update a job's config.xml (full replace)
          build-info <job>/<buildNumber>       Show a build's result and parameters
                     or <build-url>

        Environment:
          JENKINS_USER    Jenkins username (LDAP)
          JENKINS_TOKEN   Jenkins API token

        Examples:
          jenkins-cli.main.kts test-report https://jenkins.example.com/job/run_ui_tests/9299
          jenkins-cli.main.kts run-job run_ui_tests branch=feature/test-test testClass=com.example.FooTest
          jenkins-cli.main.kts warnings https://jenkins.example.com/job/build_android_pull_requests/87431/
          jenkins-cli.main.kts warnings https://jenkins.example.com/job/build_android_pull_requests/87431/analysis/origin.-1125574399/
        """.trimIndent()
    )
}

// ── HTTP helpers ──────────────────────────────────────────────────────────
// Safely extract string from JsonElement, treating JsonNull / missing keys as null
fun JsonObject?.str(key: String): String? {
    val el = this?.get(key) ?: return null
    if (el is JsonNull) return null
    return (el as? JsonPrimitive)?.content
}

fun JsonObject?.int(key: String): Int? = this.str(key)?.toIntOrNull()

fun JsonObject?.double(key: String): Double? = this.str(key)?.toDoubleOrNull()

fun JsonObject?.long(key: String): Long? = this.str(key)?.toLongOrNull()

fun fetchUrl(
    url: String,
    method: String = "GET",
    followRedirects: Boolean = true
): HttpURLConnection {
    val conn = URI(url).toURL().openConnection() as HttpURLConnection
    conn.requestMethod = method
    conn.setRequestProperty("Authorization", auth)
    conn.instanceFollowRedirects = followRedirects
    return conn
}

fun fetchJson(url: String): JsonElement =
    Json.parseToJsonElement(fetchUrl(url).inputStream.bufferedReader().readText())

// ── run-job (non-interactive) ─────────────────────────────────────────────
fun runJob(jobName: String, args: List<String>) {
    val def = jobs[jobName] ?: error("Unknown job '$jobName'. Available: ${jobs.keys.joinToString(", ")}")
    val cliParams = args.associate { p ->
        val eq = p.indexOf('=')
        if (eq <= 0) error("Invalid param format '$p' — use key=value")
        p.substring(0, eq) to p.substring(eq + 1)
    }
    val resolved = def.params.map { p ->
        val value = cliParams[p.name] ?: p.default ?: if (p.required) error("Missing required parameter: ${p.name}=<value>") else null
        value?.let { p.name to it }
    }.filterNotNull()
    runJobInternal(jobName, def, resolved)
}

// ── run (interactive) ─────────────────────────────────────────────────────
fun interactiveRun(jobName: String?) {
    val selectedName = if (jobName != null && jobName in jobs) {
        jobName
    } else {
        println("Available jobs:")
        val names = jobs.keys.toList()
        names.forEachIndexed { i, n -> println("  ${i + 1}. $n  → ${jobs[n]!!.url}") }
        print("\nJob name or number: ")
        val input = readLine()?.trim().orEmpty()
        names.firstOrNull { it == input }
            ?: input.toIntOrNull()?.let { i -> names.getOrNull(i - 1) }
            ?: error("Invalid selection: $input")
    }
    val def = jobs[selectedName]!!
    val resolved = mutableListOf<Pair<String, String>>()
    for (p in def.params) {
        val prompt = if (p.default != null) "${p.name} [${p.default}]: " else "${p.name}: "
        while (true) {
            print(prompt)
            val input = readLine()?.trim().orEmpty()
            val value = input.ifBlank { p.default }
            if (value != null) { resolved.add(p.name to value); break }
            if (!p.required) break
            println("  This parameter is required")
        }
    }
    runJobInternal(selectedName, def, resolved)
}

fun runJobInternal(jobName: String, def: JobDef, resolved: List<Pair<String, String>>) {
    val jobUrl = def.url.trimEnd('/')
    val buildUrl = "${jobUrl}/buildWithParameters"
    val query = resolved.joinToString("&") { "${it.first}=${URI(it.second).toASCIIString()}" }

    println("─── Triggering build ───────────────────────")
    println("  Job: $jobName ($jobUrl)")
    println("  Parameters: ${resolved.joinToString(" ") { "${it.first}=${it.second}" }}")
    println("  Sending request...")

    val conn = fetchUrl("$buildUrl?$query", method = "POST", followRedirects = false)
    val status = conn.responseCode
    if (status !in 200..302) {
        System.err.println("Error: HTTP $status — ${conn.responseMessage}")
        kotlin.system.exitProcess(1)
    }

    val location = conn.getHeaderField("Location")
    val queueUrl = location?.let { loc ->
        val jenkinsRoot = jobUrl.substringBefore("/job/")
        if (loc.startsWith("http")) loc else "$jenkinsRoot$loc"
    }
    println("  Status: $status")
    if (queueUrl != null) println("  Queue: $queueUrl")
    println()

    if (queueUrl != null) {
        val queueApiUrl = queueUrl.trimEnd('/') + "/api/json?tree=executable[number,url]"
        println("  Waiting for build to start...")
        for (i in 1..30) {
            Thread.sleep(2000)
            try {
                val qJson = fetchJson(queueApiUrl).jsonObject
                val executable = qJson["executable"]?.jsonObject
                if (executable != null) {
                    val num = executable.int("number")
                    val buildUrlResult = executable.str("url").orEmpty()
                    println("  ✔ Build #$num started")
                    println("  URL: ${buildUrlResult.ifBlank { "${jobUrl}/${num}/" }}")
                    return
                }
            } catch (_: Exception) { }
        }
        println("  Timed out waiting for build to start (60s)")
    }
}

// ── test-report ───────────────────────────────────────────────────────────
fun testReport(url: String) {
    val cleanUrl = url.trimEnd('/')
    val buildUrl = if (cleanUrl.endsWith("/testReport")) cleanUrl.removeSuffix("/testReport") else cleanUrl
    val testReportUrl = "$buildUrl/testReport"

    // Build cause
    val causeApiUrl = "$buildUrl/api/json?tree=actions[causes[shortDescription,userId,userName,upstreamProject,upstreamBuild,upstreamUrl]]"
    val buildJson = fetchJson(causeApiUrl)
    val causes = mutableListOf<String>()
    for (action in buildJson.jsonObject["actions"]?.jsonArray ?: emptyList()) {
        for (cause in action.jsonObject["causes"]?.jsonArray ?: continue) {
            val desc = cause.jsonObject.str("shortDescription")
            if (!desc.isNullOrBlank()) causes.add(desc)
        }
    }

    println("─── Build Cause ───────────────────────────")
    if (causes.isEmpty()) println("  (no cause information)") else causes.forEach { println("  • $it") }
    println()

    // Test report (summary + suites) — use errorStackTrace (Jenkins field name)
    val reportApiUrl = "$testReportUrl/api/json?tree=totalCount,failCount,skipCount,duration,suites[cases[className,name,status,errorDetails,errorStackTrace]]"
    val json = fetchJson(reportApiUrl).jsonObject

    // Count cases directly for an accurate total
    val suites = json["suites"]?.jsonArray ?: emptyList()
    val allCases = suites.flatMap { it.jsonObject["cases"]?.jsonArray ?: emptyList() }
    val caseTotal = allCases.size
    val caseFailed = allCases.count {
        val s = it.jsonObject.str("status")
        s == "FAILED" || s == "REGRESSION"
    }
    val caseSkipped = allCases.count { it.jsonObject.str("status") == "SKIPPED" }

    val failed = json.int("failCount")?.takeIf { it > 0 } ?: caseFailed
    val skipped = json.int("skipCount")?.takeIf { it > 0 } ?: caseSkipped
    val total = json.int("totalCount")?.takeIf { it > 0 } ?: caseTotal
    val passed = total - failed - skipped
    val durationMs = json.double("duration") ?: 0.0

    println("─── Summary ───────────────────────────────")
    println("  Total: $total  Passed: $passed  Failed: $failed  Skipped: $skipped  Duration: ${"%.1f".format(durationMs / 1000.0)}s")
    println()

    var failures = 0
    for (suite in suites) {
        val cases = suite.jsonObject["cases"]?.jsonArray ?: continue
        for (c in cases) {
            val obj = c.jsonObject
            val status = obj.str("status") ?: continue
            if (status == "FAILED" || status == "REGRESSION") {
                failures++
                val className = obj.str("className").orEmpty()
                val testName = obj.str("name").orEmpty()
                val errorDetails = obj.str("errorDetails").orEmpty()
                val stackTrace = obj.str("errorStackTrace").orEmpty()

                println("─── FAILED #$failures ───────────────────────")
                println("Test: $className.$testName")
                if (errorDetails.isNotBlank()) println("Error: $errorDetails")
                if (stackTrace.isNotBlank()) {
                    stackTrace.lines().take(15).forEach { println("  $it") }
                    if (stackTrace.lines().size > 15) println("  ... (${stackTrace.lines().size - 15} more lines)")
                }
                println()
            }
        }
    }

    if (failures == 0) println("✓ No failures found in test report")
}

// ── warnings ──────────────────────────────────────────────────────────────
fun showWarnings(url: String) {
    val cleanUrl = url.trimEnd('/')
    val isOriginUrl = cleanUrl.contains("/analysis/origin.")

    val (summaryUrl, issuesUrl) = if (isOriginUrl) {
        Pair(cleanUrl + "/api/json", cleanUrl + "/api/json")
    } else {
        Pair(cleanUrl + "/analysis/api/json", cleanUrl + "/analysis/all/api/json")
    }

    // Fetch issues
    val issuesJson = fetchJson(issuesUrl).jsonObject
    val issues = issuesJson["issues"]?.jsonArray ?: emptyList()

    // Summary
    val total = issues.size
    val bySeverity = issues.groupBy { it.jsonObject.str("severity") ?: "UNKNOWN" }
    val byOrigin = issues.groupBy { it.jsonObject.str("originName") ?: it.jsonObject.str("origin") ?: "Unknown" }

    println("─── Static Analysis Warnings ───────────────")
    println("  Total: $total")
    for ((sev, list) in bySeverity.toSortedMap()) {
        println("    $sev: ${list.size}")
    }
    println()

    if (!isOriginUrl) {
        try {
            val summaryJson = fetchJson(summaryUrl).jsonObject
            val qg = summaryJson["qualityGates"]?.jsonObject
            if (qg != null) {
                println("  Quality Gate: ${qg.str("overallResult") ?: "N/A"}")
                for (item in qg["resultItems"]?.jsonArray ?: emptyList()) {
                    val gate = item.jsonObject
                    println("    ${gate.str("qualityGate") ?: "?"}: ${gate.str("result") ?: "?"} (${gate.str("value") ?: "?"} / threshold ${gate.str("threshold") ?: "?"})")
                }
                println()
            }
        } catch (_: Exception) { /* summary may not be available */ }
    }

    // Group by origin/tool
    for ((origin, originIssues) in byOrigin) {
        println("─── $origin (${originIssues.size}) ─────────────────────")
        for (issue in originIssues) {
            val obj = issue.jsonObject
            val file = obj.str("baseName") ?: obj.str("fileName")?.substringAfterLast("/") ?: "?"
            val line = obj.int("lineStart")?.toString() ?: "?"
            val sev = obj.str("severity") ?: "?"
            val msg = obj.str("message") ?: "?"

            println("  $file:$line [$sev] $msg")
        }
        println()
    }

    if (issues.isEmpty()) println("  ✓ No warnings found")
}

// ── get-job-config ─────────────────────────────────────────────────────────
fun resolveJobUrl(ref: String): String =
    jobs[ref]?.url?.trimEnd('/')
        ?: if (ref.startsWith("http://") || ref.startsWith("https://")) ref.trimEnd('/')
        else error("Unknown job '$ref'. Available: ${jobs.keys.joinToString(", ")}")

fun getJobConfig(ref: String) {
    val jobUrl = resolveJobUrl(ref)
    val configUrl = "$jobUrl/config.xml"
    System.err.println("─── Job Config ───────────────────────────")
    System.err.println("  Job: $jobUrl")
    System.err.println("  Fetching $configUrl ...")
    System.err.println()
    val xml = fetchUrl(configUrl).inputStream.bufferedReader().readText()
    print(xml)
}

// ── update-job-config ─────────────────────────────────────────────────────
fun updateJobConfig(ref: String, configFile: String) {
    val jobUrl = resolveJobUrl(ref)
    val configUrl = "$jobUrl/config.xml"
    val xml = File(configFile).readText()
    println("─── Update Job Config ─────────────────────")
    println("  Job: $jobUrl")
    println("  Sending ${xml.length} bytes from $configFile ...")
    val conn = fetchUrl(configUrl, method = "POST", followRedirects = false)
    conn.setRequestProperty("Content-Type", "application/xml")
    conn.doOutput = true
    conn.outputStream.use { it.write(xml.toByteArray()) }
    val status = conn.responseCode
    if (status !in 200..302) {
        System.err.println("Error: HTTP $status — ${conn.responseMessage}")
        kotlin.system.exitProcess(1)
    }
    println("  Status: $status")
}

// ── build-info ────────────────────────────────────────────────────────────
fun showBuildInfo(ref: String) {
    val buildUrl = if (ref.startsWith("http")) ref.trimEnd('/')
        else error("Usage: jenkins-cli.main.kts build-info <job-url> or <build-url>")
    val apiUrl = "$buildUrl/api/json?tree=number,result,building,displayName,timestamp,duration,actions[parameters[name,value]],description"
    println("─── Build Info ────────────────────────────")
    val root = fetchJson(apiUrl).jsonObject
    val num = root.int("number")
    val result = root.str("result") ?: (if (root["building"]?.jsonPrimitive?.content == "true") "BUILDING" else "?")
    val display = root.str("displayName")
    val ts = root.long("timestamp")
    val durMs = root.long("duration")
    println("  Build: $display")
    println("  Number: $num")
    println("  Result: $result")
    println("  URL: $buildUrl")
    if (ts != null) println("  Started: ${java.time.Instant.ofEpochMilli(ts)}")
    if (durMs != null) println("  Duration: ${durMs / 1000}s")
    println()
    println("  Parameters:")
    val params = root["actions"]?.jsonArray
        ?.flatMap { it.jsonObject["parameters"]?.jsonArray ?: emptyList() }
        ?: emptyList()
    if (params.isEmpty()) {
        println("    (none)")
    } else {
        for (p in params) {
            val obj = p.jsonObject
            val name = obj.str("name") ?: continue
            val value = obj.str("value") ?: "«null»"
            println("    $name = $value")
        }
    }
    val desc = root.str("description")
    if (desc != null) println("\n  Description: $desc")
}

// ── trigger (URL-based) ───────────────────────────────────────────────────
fun triggerBuild(ref: String, args: List<String>) {
    val jobUrl = if (ref.startsWith("http")) ref.trimEnd('/')
        else error("Usage: jenkins-cli.main.kts trigger <job-url> [key=value...]")
    val buildUrl = "$jobUrl/buildWithParameters"
    val cliParams = args.associate { p ->
        val eq = p.indexOf('=')
        if (eq <= 0) error("Invalid param format '$p' — use key=value")
        p.substring(0, eq) to p.substring(eq + 1)
    }
    val query = cliParams.entries.joinToString("&") { "${it.key}=${URI(it.value).toASCIIString()}" }

    println("─── Triggering build ───────────────────────")
    println("  Job: $jobUrl")
    println("  Parameters: ${cliParams.entries.joinToString(" ") { "${it.key}=${it.value}" }}")
    println("  Sending request...")

    val conn = fetchUrl("$buildUrl?$query", method = "POST", followRedirects = false)
    val status = conn.responseCode
    if (status !in 200..302) {
        System.err.println("Error: HTTP $status — ${conn.responseMessage}")
        kotlin.system.exitProcess(1)
    }
    val location = conn.getHeaderField("Location")
    println("  Status: $status")
    if (location != null) println("  Queue: $location")
}

// ── artifacts ─────────────────────────────────────────────────────────────
fun showArtifacts(ref: String) {
    val buildUrl = if (ref.startsWith("http")) ref.trimEnd('/')
        else error("Usage: jenkins-cli.main.kts artifacts <build-url>")
    val apiUrl = "$buildUrl/api/json?tree=artifacts[fileName,size,relativePath]"
    println("─── Artifacts (${buildUrl}) ────────────────")
    val root = fetchJson(apiUrl).jsonObject
    val arts = root["artifacts"]?.jsonArray ?: emptyList()
    if (arts.isEmpty()) {
        println("  (none)")
        return
    }
    for (a in arts) {
        val obj = a.jsonObject
        val fileName = obj.str("fileName") ?: "?"
        val size = obj.int("size") ?: 0
        val rel = obj.str("relativePath") ?: "?"
        println("  ${"%,d".format(size)}  $rel")
    }
}

// ── plugins ───────────────────────────────────────────────────────────────
fun showPlugins(query: String?) {
    val url = "https://android-ci.bandlab.io/pluginManager/api/json?depth=1&tree=plugins[shortName,version,active]"
    println("─── Installed Plugins ──────────────────────")
    val root = fetchJson(url).jsonObject
    val plugins = root["plugins"]?.jsonArray ?: emptyList()
    val wanted = query?.lowercase()
    for (p in plugins) {
        val obj = p.jsonObject
        val name = obj.str("shortName") ?: continue
        if (wanted != null && !name.lowercase().contains(wanted)) continue
        val version = obj.str("version") ?: "?"
        val active = obj.str("active") ?: "?"
        println("  $name  $version  active=$active")
    }
}

// ── console ───────────────────────────────────────────────────────────────
private val consoleCacheDir = File(
    System.getProperty("java.io.tmpdir"), "jenkins-console-cache"
).apply { mkdirs() }

// Fetch the full console once and cache it on disk, keyed by build URL.
// A finished build's consoleText is immutable, so the cache is safe to reuse.
private fun cachedConsole(buildUrl: String, refresh: Boolean): String {
    val key = buildUrl.trimEnd('/')
        .replace(Regex("[^A-Za-z0-9]"), "_")
        .trim('_')
    val cacheFile = File(consoleCacheDir, "$key.log")
    if (!refresh && cacheFile.exists() && cacheFile.length() > 0) {
        return cacheFile.readText()
    }
    val text = fetchUrl("$buildUrl/consoleText").inputStream.bufferedReader().readText()
    cacheFile.writeText(text)
    println("  (cached ${text.length} bytes -> ${cacheFile.name})")
    return text
}

fun showConsole(ref: String, mode: String, maxBytes: Int, refresh: Boolean) {
    val buildUrl = if (ref.startsWith("http")) ref.trimEnd('/')
        else error("Usage: jenkins-cli.main.kts console <build-url> [head|tail|range:<start>:<len>] [bytes] [--refresh]")
    println("─── Console (${buildUrl}) ──────────────────")
    val text = cachedConsole(buildUrl, refresh)

    when {
        mode.startsWith("range") -> {
            val parts = mode.removePrefix("range:").split(":")
            if (parts.size != 2) error("range mode needs range:start:len, e.g. range:0:5000")
            val start = parts[0].toIntOrNull() ?: error("range start must be a number")
            val len = parts[1].toIntOrNull() ?: error("range len must be a number")
            val from = start.coerceIn(0, text.length)
            println(text.substring(from, (from + len).coerceAtMost(text.length)))
            println("\n... (range [$from, ${from + len}) of ${text.length} bytes)")
        }
        mode == "head" -> {
            if (text.length <= maxBytes) {
                println(text)
            } else {
                // The CopyArtifact/SCM steps run first, so the head shows what the tail hides.
                println(text.take(maxBytes))
                println("\n... (truncated to first $maxBytes bytes)")
            }
        }
        else -> { // tail (default)
            if (text.length <= maxBytes) {
                println(text)
            } else {
                // Prefer the tail: the interesting steps (baseline profile) run late.
                println(text.takeLast(maxBytes))
                println("\n... (truncated to last $maxBytes bytes)")
            }
        }
    }
}

// ── download ──────────────────────────────────────────────────────────────
fun downloadArtifact(ref: String, relPath: String?, outPath: String?) {
    // Two forms:
    //   download <artifact-url> [outPath]
    //   download <job-url> <relativePath> [outPath]   (resolves latest successful build)
    val url: String
    val out: String
    if (relPath != null) {
        val jobUrl = ref.trimEnd('/')
        // Resolve the latest successful build's number, fall back to the latest build.
        val apiUrl = "$jobUrl/api/json?tree=lastSuccessfulBuild[number],lastBuild[number]"
        val root = fetchJson(apiUrl).jsonObject
        val num = root["lastSuccessfulBuild"]?.jsonObject?.int("number")
            ?: root["lastBuild"]?.jsonObject?.int("number")
            ?: error("No builds found for $jobUrl")
        url = "$jobUrl/$num/artifact/${relPath.trimStart('/')}"
        out = outPath ?: relPath.substringAfterLast('/').ifBlank { "download.bin" }
        println("─── Download (job latest successful build #$num) ─")
    } else {
        url = ref.trimEnd('/')
        out = outPath ?: url.substringAfterLast('/').let { if (it.isBlank()) "download.bin" else it }
        println("─── Download ───────────────────────────────")
    }
    println("  URL: $url")
    println("  -> $out")
    val conn = fetchUrl(url, method = "GET", followRedirects = false)
    if (conn.responseCode !in 200..302) {
        System.err.println("Error: HTTP ${conn.responseCode} — ${conn.responseMessage}")
        kotlin.system.exitProcess(1)
    }
    conn.inputStream.use { input ->
        java.io.File(out).outputStream().use { output -> input.copyTo(output) }
    }
    println("  OK: ${java.io.File(out).length()} bytes")
}

// ── Main ──────────────────────────────────────────────────────────────────
// ── config-history ────────────────────────────────────────────────────────
fun showConfigHistory(ref: String, downloadDate: String?) {
    val jobUrl = resolveJobUrl(ref)
    val listUrl = "$jobUrl/jobConfigHistory/api/json"
    println("─── Config History ───────────────────────")
    println("  Job: $jobUrl")
    val root = fetchJson(listUrl).jsonObject
    val history = root["jobConfigHistory"]?.jsonArray ?: error("No jobConfigHistory array")
    for (entry in history) {
        val e = entry.jsonObject
        val date = e.str("date")
        val user = e.str("user")
        val op = e.str("operation")
        val marker = if (date == downloadDate) "  <-- downloading" else ""
        println("  $date  [$op]  $user$marker")
    }
    if (downloadDate != null) {
        val out = downloadDate.replace(':', '_') + ".xml"
        val url = "$jobUrl/jobConfigHistory/configOutput?type=raw&timestamp=$downloadDate"
        System.err.println("  Fetching $url ...")
        val conn = fetchUrl(url, method = "GET", followRedirects = false)
        if (conn.responseCode !in 200..302) {
            System.err.println("Error: HTTP ${conn.responseCode} — ${conn.responseMessage}")
            kotlin.system.exitProcess(1)
        }
        conn.inputStream.use { input ->
            java.io.File(out).outputStream().use { output -> input.copyTo(output) }
        }
        println("  -> $out (${File(out).length()} bytes)")
    }
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        printUsage()
        return
    }

    when (args[0]) {
        "test-report" -> {
            val url = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts test-report <testReportUrl>")
            testReport(url)
        }
        "warnings" -> {
            val url = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts warnings <build-url-or-origin-url>")
            showWarnings(url)
        }
        "run-job", "build" -> {
            val name = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts run-job <jobName> [key=value...]")
            runJob(name, args.drop(2))
        }
        "run" -> {
            interactiveRun(args.getOrNull(1))
        }
        "jobs" -> {
            for ((name, def) in jobs) {
                println("$name  → ${def.url}")
                for (p in def.params) {
                    val required = if (p.required) "required" else "optional"
                    val default = if (p.default != null) " (default: ${p.default})" else ""
                    println("    ${p.name}: ${p.desc} [$required]$default")
                }
                println()
            }
        }
        "get-job-config", "config" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts get-job-config <jobName-or-url>")
            getJobConfig(ref)
        }
        "config-history" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts config-history <jobName-or-url> [timestamp]")
            showConfigHistory(ref, args.getOrNull(2))
        }
        "update-job-config" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts update-job-config <jobName-or-url> <config.xml>")
            val configFile = args.getOrNull(2) ?: error("Usage: jenkins-cli.main.kts update-job-config <jobName-or-url> <config.xml>")
            updateJobConfig(ref, configFile)
        }
        "build-info" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts build-info <job>/<buildNumber> or <build-url>")
            showBuildInfo(ref)
        }
        "trigger" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts trigger <job-url> [key=value...]")
            triggerBuild(ref, args.drop(2))
        }
        "console" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts console <build-url> [head|tail|range:start:len] [bytes] [--refresh]")
            val modeArg = args.getOrNull(2) ?: "tail"
            val refresh = args.any { it == "--refresh" }
            val mode = if (modeArg in setOf("head", "tail") || modeArg.startsWith("range:")) modeArg else "tail"
            val maxBytes = if (mode == "tail" || mode == "head") {
                args.getOrNull(3)?.toIntOrNull() ?: 12000
            } else 12000
            showConsole(ref, mode, maxBytes, refresh)
        }
        "artifacts" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts artifacts <build-url>")
            showArtifacts(ref)
        }
        "plugins" -> {
            showPlugins(args.getOrNull(1))
        }
        "download" -> {
            val ref = args.getOrNull(1) ?: error("Usage: jenkins-cli.main.kts download <artifact-url> [outPath] | <job-url> <relativePath> [outPath]")
            downloadArtifact(ref, args.getOrNull(2), args.getOrNull(3))
        }
        "help", "--help", "-h" -> printUsage()
        else -> {
            System.err.println("Unknown command: ${args[0]}")
            printUsage()
            kotlin.system.exitProcess(1)
        }
    }
}

main(args)
