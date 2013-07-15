module dynobots

import java.util.concurrent.Executors
import java.lang.Thread

#http
import java.net.InetSocketAddress
import com.sun.net.httpserver
import com.sun.net.httpserver.HttpServer

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder


augment java.util.concurrent.Future {
	# callBackWhenException is a callBack when exception
	function getResult = |this, callBackWhenException| {
		var r  = null
		try {
			r = this:get()	
		} catch (e) {
			if callBackWhenException isnt null { callBackWhenException(e) }
		} finally {
			return r
		}
	}

	function getResult = |this| {
		var r  = null
		try {
			r = this:get()	
		} finally {
			return r
		}
	}

	function cancelTask = |this, callBackWhenCancelled| {
		this:cancel(true)
		callBackWhenCancelled(this:isCancelled())
	}
}

augment java.util.concurrent.ExecutorService {
	# callable : closure to execute
	# message : argument passed to callable
	# callBackWhenSubmitted : 
	#  - called when callable is submitted by ExecutorService
	#  - message is passed as parameter of callBackWhenSubmitted
	# callBackWhenDone : passed as 2nd parameter of the callable
	function getFuture = |this, callable, message, callBackWhenDone, callBackWhenSubmitted| {
		let worker = (-> callable(message, callBackWhenDone)):to(java.util.concurrent.Callable.class)
		if callBackWhenSubmitted isnt null { callBackWhenSubmitted(message) }
		return this:submit(worker) #future is run when submit()
	}

	function getFuture = |this, callable, message, callBackWhenDone| {
		let worker = (-> callable(message, callBackWhenDone)):to(java.util.concurrent.Callable.class)
		return this:submit(worker) #future is run when submit()
	}

	function getFuture = |this, callable, message| {
		let worker = (-> callable(message)):to(java.util.concurrent.Callable.class)
		return this:submit(worker) #future is run when submit()
	}		
} 


function DynoBot = |uniqueId| {

	let dynobot = map[
		  ["id", uniqueId]
		, ["messagesStack", list[]]
		, ["master", null]
		, ["futureListener",null]
		, ["futureAction",null]
		, ["listening",false]
	]

	let startListening = {
		if dynobot:get("listening") is true {
			println("Hop hop hop !I am %s, and i'm still listening":format(dynobot:get("id")))
		} else {
			dynobot:put("listening", true)
			println("I am %s, and i'm waiting for messages":format(dynobot:get("id")))

			# ----- start of callable : callableListener -----
			let callableListener = |msg, callBackWhenDone| { # add callback (?)
				var listening = true
				while (listening is true) {

					if dynobot:get("messagesStack"):size() > 0 {
						let message = dynobot:get("messagesStack"):removeFirst()
						
						println("message for %s : %s":format(dynobot:get("id"), message))

						if message:startsWith("stop") { #after "stop:" there is the sender id 
							listening = false 
						}

						if message:startsWith("cancel") { #after "cancel:" there is the sender id 
							dynobot:put("listening", false)
							dynobot:get("futureListener")
								:cancelTask(
									|isCancelledBeforeEnd| -> println("I am %s, and i've been cancelled":format(dynobot:get("id")))
								)
						}
						
						if message:startsWith("action") {
							println("Action message : %s for %s":format(message, dynobot:get("id")))
							
							let module_name = message:split(":"):get(1)
							let function_name = message:split(":"):get(2)
							let parameters = message:split(":"):get(3)

							let sender = message:split(":"):get(4)

							println(
								"*** FUNCTION : %s IN MODULE : %s WITH : %s FROM : %s"
									:format(
										  function_name
										, module_name
										, parameters
										, sender
									)
							)
							
							
							let callableAction = |parameters, callBackWhenDone| {

								let f = dynobot:get("master"):get("getFunc"):invokeWithArguments(module_name, function_name)									
								let r = f([parameters, dynobot, sender])
								if callBackWhenDone isnt null { callBackWhenDone(function_name+" of "+module_name) }

								return r
							}

							let future = dynobot:get("master"):get("executor"):getFuture(		# run it (callableAction)
								  callableAction
								, parameters							# Message
								, |arg| { 
									println("--> " + arg + " is done") 
								  }	# Callback when callableAction is done / Callback (when done) is passed to callableAction									
							)

							dynobot:put("futureAction",future)
							
						}

					}
				}

				println("I am %s, and i'm stop listening":format(dynobot:get("id")))

				if callBackWhenDone isnt null { callBackWhenDone(dynobot:get("id")) }

				dynobot:put("listening",false)

				return null
			}
			# ----- end of callable : callableListener -----

			# ----- start listening
			dynobot:put("futureListener",
				dynobot:get("master"):get("executor"):getFuture(					# run it (callableListener)
					  callableListener
					, "future Listener : " + dynobot:get("id")		# Message
					, |arg| { println(arg + " is done") }	# Callback when callableListener is done / Callback (when done) is passed to callableListener						
				)
			)
			# ----- ... -----


		} # end else if
		return dynobot
	}
	dynobot:put("startListening", startListening)

	let sendMessageTo = |message, uniqueDynoBotId| {
		# Send message to a bot
		dynobot:get("master"):bots():get(uniqueDynoBotId):get("messagesStack"):push(message + ":" + dynobot:get("id"))
	}
	dynobot:put("sendMessageTo", sendMessageTo)


	return dynobot
}


function handler = |func| -> func: to(HttpHandler.class)

function Master = |uniqueId| {

	#let executor = Executors.newFixedThreadPool(4000)
	let executor = Executors.newCachedThreadPool()

	let evalEnv = gololang.EvaluationEnvironment()

	let master = map[
		  ["id", uniqueId]
		, ["executor", executor]
		, ["evalEnv", evalEnv]
		, ["bots",map[]]
		, ["httpFuture",null]
		, ["verbose",false]
		, ["actions",map[]]
	]

	let killThemAll = -> master:get("executor"):shutdown() # if newFixedThreadPool

	let addActions = |moduleName, sourceCode| { #add module
		master:get("actions"):add(moduleName, master:get("evalEnv"): asModule(sourceCode))
		return master
	}
	master:put("addActions", addActions)

	let getFunc = |moduleName, functionName|{
		return fun(functionName, master:get("actions"):get(moduleName))
	}
	master:put("getFunc", getFunc)

	let getNewDynoBot = |uniqueDynoBotId| { 
		# TODO : have to verify if dynoBot already exists
		# create DynoBot
		let dyno = DynoBot(uniqueDynoBotId)
		dyno:put("master",master)
		# Add dyno to bots map's master
		master:get("bots"):add(uniqueDynoBotId, dyno) 
		return dyno
	}
	master:put("getNewDynoBot", getNewDynoBot)

	let getDynoBot = |uniqueDynoBotId| {
		# Get DynoBot by Id
		return master:get("bots"):get(uniqueDynoBotId)
	}
	master:put("getDynoBot", getDynoBot)

	let sendMessageTo = |message, uniqueDynoBotId| {
		# Send message to a bot
		master:get("bots"):get(uniqueDynoBotId):get("messagesStack"):push(message + ":" + master:get("id"))
	}
	master:put("sendMessageTo", sendMessageTo)


	let startListening = |httpPort| {

		let server = HttpServer.create(InetSocketAddress("localhost", httpPort), 0)
				
		println("Master is listening on " + httpPort)
			
		server: createContext("/", handler(|exchange| {

			let headers = exchange: getResponseHeaders()
			let uri = exchange: getRequestURI():toString()

			println("URI : " + uri)

			#default response
			#headers: set("Content-Type", "text/html")
			headers: set("Content-Type", "application/json")
			
			var response = "{about:\"DynoBots v1.00\",help:\"http://localhost:port/help\"}"


			if uri: startsWith("/master:stop:") {
				headers: set("Content-Type", "application/json")
				let dyno = uri:split(":"):get(2)
				println("@STOP@ : " + dyno)

				master:get("sendMessageTo"):invokeWithArguments("stop", dyno)
				response = "{%s:\"stopped\"}":format(dyno)
			}

			if uri: startsWith("/master:cancel:") {
				headers: set("Content-Type", "application/json")
				let dyno = uri:split(":"):get(2)
				println("@CANCEL@ : " + dyno)

				master:get("sendMessageTo"):invokeWithArguments("cancel", dyno)
				response = "{%s:\"cancelled\"}":format(dyno)
			}

			if uri: startsWith("/master:start:") {
				headers: set("Content-Type", "application/json")
				let dyno = uri:split(":"):get(2)
				println("@START@ : " + dyno)

				master:get("getDynoBot"):invokeWithArguments(dyno):get("startListening"):invokeWithArguments()
				
				#TODO: verify if already listening
				response = "{%s:\"started\"}":format(dyno)
			}

			if uri: startsWith("/master:result:") {
				let dyno = uri:split(":"):get(2)
				println("@RESULT@ : " + dyno)
				headers: set("Content-Type", "application/json")					
				
				response = "{result:\"" + master:get("getDynoBot"):invokeWithArguments(dyno):get("futureAction"):getResult() + "\"}"
			}

			if uri: startsWith("/master:resultifdone:") {
				let dyno = uri:split(":"):get(2)
				println("@RESULTIFDONE@ : " + dyno)
				headers: set("Content-Type", "application/json")

				if master:get("getDynoBot"):invokeWithArguments(dyno):get("futureAction"):isDone() {
					response = "{result:\"" + master:get("getDynoBot"):invokeWithArguments(dyno):get("futureAction"):getResult() + "\"}"
				} else {
					response = "{result:null}"
				}
			}									

			if uri: startsWith("/master:message:") {
				let dyno = uri:split(":"):get(2)
				let message = uri:split(":"):get(3)

				println("@MESSAGE@ : " + message)

				headers: set("Content-Type", "application/json")

				if message == "action" {
					println("action:" + uri:split("action"):get(1))
					master:get("sendMessageTo"):invokeWithArguments("action" + uri:split("action"):get(1), dyno)	
					response = "{sentmessage:\"%s\",dynobot:\"%s\"}":format("action" + uri:split("action"):get(1), dyno)

				} else  {
					master:get("sendMessageTo"):invokeWithArguments(message, dyno)
					response = "{sentmessage:\"%s\",dynobot:\"%s\"}":format(message, dyno)	
				}
			}


			if uri: startsWith("/master:dynobots") {
				#list od dynobots
				headers: set("Content-Type", "application/json")

				let resp = DynamicObject():value("[")

				master:get("bots"):each(|key, dynobot| {
					resp:value(
						"%s{dynobot:\"%s\",listening:%s, messagesStack:{}},"
						:format(resp:value(), key, dynobot:get("listening"))
					)
				})

				response = resp:value():substring(0,resp:value():length() - 1 ) + "]"
			} 	

			if uri: startsWith("/help") {
				headers: set("Content-Type", "text/html")
				response = """
					<h1>Help</h1>
				"""
			} else {
				#TODO:
			}		

			exchange: sendResponseHeaders(200, response: length())
			exchange: getResponseBody(): write(response: getBytes())
			exchange: close()
		}))

		server: start()		
		#How can i stop by message ? new context
		return master
	}
	master:put("startListening", startListening)

		#TODO : remote dynobot and remote master

	return master
}

function actions4Alldynobots = ->"""
module dynomod

function hello = |args| {

	# args is a tuple : triplet
	# first item is string parameter
	# second item is dynobot
	# third item is sender id

	println("---> I am dynobot %s, message is : \"%s\" from dynobot %s"
		:format(
			  args:get(1):get("id")
			, args:get(0)
			, args:get(2))
	)
	return args:get(1):get("id")+" "+java.lang.System.currentTimeMillis()

}
"""


function main = |args| {
	let dynoBotsMaster = 
		Master("DynoBotsMaster")
			:get("startListening"):invokeWithArguments(9999)

	dynoBotsMaster
		:get("addActions"):invokeWithArguments("dynomod", actions4Alldynobots())

	#let start = java.lang.System.currentTimeMillis()
	for (var counter = 1, counter <=20, counter = counter + 1)  {
		
		let callableAction = |parameters, callBackWhenDone| {
			
			dynoBotsMaster
				:get("getNewDynoBot"):invokeWithArguments("dyno"+counter)
				:get("startListening"):invokeWithArguments()

			if callBackWhenDone isnt null { callBackWhenDone("dyno"+counter) }
				
			return true
		}

		dynoBotsMaster:get("executor"):getFuture(
			  callableAction
			, "dynobots creation"							
			, |arg|->println(arg)							
		)		

		#let duration = java.lang.System.currentTimeMillis() - start
		#println("All dynobots started, duration : " + duration + " ms")
	}

}








