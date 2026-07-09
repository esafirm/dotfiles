#!/usr/bin/env kotlin

@file:DependsOn("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

import kotlinx.serialization.json.*
import java.net.HttpURLConnection
import java.net.URI
import java.util.Base64

// ── Config ────────────────────────────────────────────────────────────────
val user = System.getenv("JENKINS_USER") ?: error("Missing JENKINS_USER env var")
val token = System.getenv("JENKINS_TOKEN") ?: error("Missing JENKINS_TOKEN env var")
val auth = "Basic " + Base64.getEncoder().encodeToString("$user:$token".toByteArray())

val jobs = mapOf(
    "run_ui_tests" to JobDef(
        url = "https://android-ci.bandlab.io/job/run_ui_tests",
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

        Environment:
          JENKINS_USER    Jenkins username (LDAP)
          JENKINS_TOKEN   Jenkins API token

        Examples:
          jenkins-cli.main.kts test-report https://android-ci.bandlab.io/job/run_ui_tests/9299
          jenkins-cli.main.kts run-job run_ui_tests branch=feature/test-test testClass=com.example.FooTest
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

// ── Main ──────────────────────────────────────────────────────────────────
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
        "help", "--help", "-h" -> printUsage()
        else -> {
            System.err.println("Unknown command: ${args[0]}")
            printUsage()
            kotlin.system.exitProcess(1)
        }
    }
}

main(args)
