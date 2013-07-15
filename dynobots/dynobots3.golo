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

struct DynoBot = {
	  id
	, messagesStack
	, master
	, futureListener
	, futureAction
	, listening
}

augment dynobots.types.DynoBot {
	function init = |this, uniqueId| {
		this:id(uniqueId):messagesStack(list[]):listening(false)
		# master = null
		# futureListener = null
		# futureAction = null

		return this
	}

	function startListening = |this| {
		if this:listening() is true {
			println("Hop hop hop !I am %s, and i'm still listening":format(this:id()))
		} else {
			this:listening(true)
			println("I am %s, and i'm waiting for messages":format(this:id()))

			# ----- start of callable : callableListener -----
			let callableListener = |msg, callBackWhenDone| { # add callback (?)
				var listening = true
				while (listening is true) {

					if this:messagesStack():size() > 0 {
						let message = this:messagesStack():removeFirst()
						
						println("message for %s : %s":format(this:id(), message))

						if message:startsWith("stop") { #after "stop:" there is the sender id 
							listening = false 
						}

						if message:startsWith("cancel") { #after "cancel:" there is the sender id 
							this:listening(false)
							this:futureListener()
								:cancelTask(
									|isCancelledBeforeEnd| -> println("I am %s, and i've been cancelled":format(this:id()))
								)
						}
						
						if message:startsWith("action") {
							println("Action message : %s for %s":format(message, this:id()))
							
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

								let f = this:master():getFunc(module_name, function_name)									
								let r = f([parameters, this, sender])
								if callBackWhenDone isnt null { callBackWhenDone(function_name+" of "+module_name) }

								return r
							}

							let future = this:master():executor():getFuture(		# run it (callableAction)
								  callableAction
								, parameters							# Message
								, |arg| { 
									println("--> " + arg + " is done") 
								  }	# Callback when callableAction is done / Callback (when done) is passed to callableAction									
							)

							this:futureAction(future)
							
						}

					}
				}

				println("I am %s, and i'm stop listening":format(this:id()))

				if callBackWhenDone isnt null { callBackWhenDone(this:id()) }

				this:listening(false)

				return null
			}
			# ----- end of callable : callableListener -----

			# ----- start listening
			this:futureListener(
				this:master():executor():getFuture(					# run it (callableListener)
					  callableListener
					, "future Listener : " + this:id()		# Message
					, |arg| { println(arg + " is done") }	# Callback when callableListener is done / Callback (when done) is passed to callableListener						
				)
			)
			# ----- ... -----


		} # end else if
		return this		
	}

	function sendMessageTo = |this, message, uniqueDynoBotId| {
		# Send message to a bot
		this:master():bots():get(uniqueDynoBotId):messagesStack():push(message + ":" + this:id())
	}

} 


function handler = |func| -> func: to(HttpHandler.class)

struct Master = {
	  id
	, executor
	, evalEnv
	, bots
	, httpFuture
	, verbose	
	, actions
}

augment dynobots.types.Master {
	function init = |this, uniqueId| {
		this:id(uniqueId):bots(map[]):verbose(false):actions(map[])
		# httpFuture = null
	
		#let executor = Executors.newFixedThreadPool(4000)
		let executor = Executors.newCachedThreadPool()
		let evalEnv = gololang.EvaluationEnvironment()	

		this:executor(executor):evalEnv(evalEnv)

		return this	
	}

	function addActions = |this, moduleName, sourceCode| { #add module
		this:actions():add(moduleName, this:evalEnv(): asModule(sourceCode))
		return this
	}	

	function getFunc = |this, moduleName, functionName|{
		return fun(functionName, this:actions():get(moduleName))
	}

	function getNewDynoBot = |this, uniqueDynoBotId| { 
		# TODO : have to verify if dynoBot already exists
		# create DynoBot
		let dyno = DynoBot():init(uniqueDynoBotId)
		dyno:master(this)
		# Add dyno to bots map's master
		this:bots():add(uniqueDynoBotId, dyno) 
		return dyno
	}

	function getDynoBot = |this, uniqueDynoBotId| {
		# Get DynoBot by Id
		return this:bots():get(uniqueDynoBotId)
	}

	function sendMessageTo = |this, message, uniqueDynoBotId| {
		# Send message to a bot
		this:bots():get(uniqueDynoBotId):messagesStack():push(message + ":" + this:id())
	}

	function killThemAll = |this| -> this:executor():shutdown() # if newFixedThreadPool

	function startListening = |this, httpPort| {

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

				this:sendMessageTo("stop", dyno)
				response = "{%s:\"stopped\"}":format(dyno)
			}

			if uri: startsWith("/master:cancel:") {
				headers: set("Content-Type", "application/json")
				let dyno = uri:split(":"):get(2)
				println("@CANCEL@ : " + dyno)

				this:sendMessageTo("cancel", dyno)
				response = "{%s:\"cancelled\"}":format(dyno)
			}

			if uri: startsWith("/master:start:") {
				headers: set("Content-Type", "application/json")
				let dyno = uri:split(":"):get(2)
				println("@START@ : " + dyno)

				this:getDynoBot(dyno):startListening()
				
				#TODO: verify if already listening
				response = "{%s:\"started\"}":format(dyno)
			}

			if uri: startsWith("/master:result:") {
				let dyno = uri:split(":"):get(2)
				println("@RESULT@ : " + dyno)
				headers: set("Content-Type", "application/json")					
				
				response = "{result:\"" + this:getDynoBot(dyno):futureAction():getResult() + "\"}"
			}

			if uri: startsWith("/master:resultifdone:") {
				let dyno = uri:split(":"):get(2)
				println("@RESULTIFDONE@ : " + dyno)
				headers: set("Content-Type", "application/json")

				if this:getDynoBot(dyno):futureAction():isDone() {
					response = "{result:\"" + this:getDynoBot(dyno):futureAction():getResult() + "\"}"
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
					this:sendMessageTo("action" + uri:split("action"):get(1), dyno)	
					response = "{sentmessage:\"%s\",dynobot:\"%s\"}":format("action" + uri:split("action"):get(1), dyno)

				} else  {
					this:sendMessageTo(message, dyno)
					response = "{sentmessage:\"%s\",dynobot:\"%s\"}":format(message, dyno)	
				}
			}


			if uri: startsWith("/master:dynobots") {
				#list od dynobots
				headers: set("Content-Type", "application/json")

				let resp = DynamicObject():value("[")

				this:bots():each(|key, dynobot| {
					resp:value(
						"%s{dynobot:\"%s\",listening:%s, messagesStack:{}},"
						:format(resp:value(), key, dynobot:listening())
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
		return this
	}

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
			  args:get(1):id()
			, args:get(0)
			, args:get(2))
	)
	
	return args:get(1):id()+" "+java.lang.System.currentTimeMillis()

}
"""


function main = |args| {
	let dynoBotsMaster = 
		Master():init("DynoBotsMaster")
			:startListening(9999)

	dynoBotsMaster
		:addActions("dynomod", actions4Alldynobots())

	#let start = java.lang.System.currentTimeMillis()
	for (var counter = 1, counter <= 1000 , counter = counter + 1)  {
		
		let callableAction = |parameters, callBackWhenDone| {
			
			dynoBotsMaster
				:getNewDynoBot("dyno"+counter)
				:startListening()

			if callBackWhenDone isnt null { callBackWhenDone("dyno"+counter) }
				
			return true
		}

		dynoBotsMaster:executor():getFuture(
			  callableAction
			, "dynobots creation"							
			, |arg|->println(arg)							
		)		

		#let duration = java.lang.System.currentTimeMillis() - start
		#println("All dynobots started, duration : " + duration + " ms")
	}

}


