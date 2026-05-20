#!/usr/bin/env kotlin

import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Execute a shell command and return its output.
 */
fun execute(command: String): String {
    val parts = command.split(" ").filter { it.isNotBlank() }
    val process = ProcessBuilder(parts)
        .redirectErrorStream(true)
        .start()
    
    val output = process.inputStream.bufferedReader().readText()
    process.waitFor(30, TimeUnit.SECONDS)
    return output
}

fun main(args: Array<String>) {
    val adbArgs = if (args.isNotEmpty()) args.joinToString(" ") else ""
    val adbBase = if (adbArgs.isNotEmpty()) "adb $adbArgs" else "adb"
    
    val remotePath = "/sdcard/view.xml"
    val localFile = File.createTempFile("ui-dump", ".xml")
    
    try {
        val dumpResult = execute("$adbBase shell uiautomator dump $remotePath")
        if (dumpResult.contains("ERROR")) {
            System.err.println("Error dumping UI: $dumpResult")
            return
        }
        
        execute("$adbBase pull $remotePath ${localFile.absolutePath}")
        execute("$adbBase shell rm $remotePath")
        
        if (localFile.exists() && localFile.length() > 0) {
            println(localFile.readText())
        } else {
            System.err.println("Failed to get UI dump. Is the device connected and authorized?")
        }
    } catch (e: Exception) {
        System.err.println("An error occurred: ${e.message}")
    } finally {
        localFile.delete()
    }
}

main(args)
