#!/usr/bin/env kscript
//DEPS com.offbytwo:docopt:0.6.0.20150202,log4j:log4j:1.2.14
//DEPS org.json:json:20090211

import org.docopt.Docopt
import java.util.*
import org.json.*


val usage = """
Check if the given JSON is valid
Usage: isvalidjson.kts <json> 
"""

val doArgs = Docopt(usage).parse(args.toList())

val json = doArgs["<json>"] as String
val isValid = isValid(json);

val result = if(isValid) "✅" else "❌" 
println("Is JSON valid? $result")

fun isValid(json: String): Boolean = try {
    JSONObject(json)
    true
} catch(e: Exception) {
    try {
        JSONArray(json)
        true
    }catch(e: Exception){
        false
    }
    false
}
