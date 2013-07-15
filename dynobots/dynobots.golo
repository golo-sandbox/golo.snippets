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

# 1 DynoBot has a thread to listen message (use future for listening too : cancel is possible)
# if message -> action (future)

function DynoBot = |uniqueId| {
	let dynoBot = DynamicObject()
		:id(uniqueId)
		:messagesStack(list[]) 					# messages stack
		:master(null)							# master
		:futureListener(null)
		:futureAction(null)
		:listening(false)
		:define("startListening", |this| {		# when message call action()
			if this:listening() is true {
				println("Hop hop hop !I am %s, and i'm still listening":format(this:id()))
			} else {
				this:listening(true)
				
				println("I am %s, and i'm waiting for messages":format(this:id()))

				#TODO : create listening state

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

							# === TODO: ===
							# doing something (call method with message as parameter)
							# a map of actions (strings)
							# =============

							# action:module:method:parameters -> with a future too !!!
							
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
				#, |arg| { if this:master():verbose() is true { println(arg + " Submitted") } }	# Callback when callableListener is submitted
				# ----- ... -----
			} # end else (if)
			return this
		})
		:define("sendMessageTo", |this, message, uniqueDynoBotId| {
			# Send message to a bot
			this:master():bots():get(uniqueDynoBotId):messagesStack():push(message + ":" + this:id())
			#this:master():bots():get(uniqueDynoBotId):messagesStack():push(message)
		})

		#TODO : Send remote message

	return dynoBot
}

function handler = |func| -> func: to(HttpHandler.class)

function Master = |uniqueId| {
	# Constructor
	# TODO: other kinds of executors ? 
	#let executor = Executors.newFixedThreadPool(threadNumber)

	let executor = Executors.newCachedThreadPool()

	let evalEnv = gololang.EvaluationEnvironment()

	let master = DynamicObject()
		:id(uniqueId)
		:executor(executor)
		:evalEnv(evalEnv)
		:bots(map[])
		:httpFuture(null)
		:verbose(false)
		:actions(map[])
		:define("addActions", |this, moduleName, sourceCode| { #add module
			this:actions():add(moduleName, this:evalEnv(): asModule(sourceCode))
			#this:evalEnv(): asModule(sourceCode)
			return this
		})
		:define("getFunc", |this, moduleName, functionName|{
			return fun(functionName, this:actions():get(moduleName))
		})		
		:define("getNewDynoBot", |this, uniqueDynoBotId| { #if id exists ?

			# TODO : have to verify if dynoBot already exists

			# create DynoBot
			let dyno = DynoBot(uniqueDynoBotId)

			dyno:master(this)
			# Add dyno to bots map's master
			this:bots():add(uniqueDynoBotId, dyno) 

			return dyno
		})
		:define("getDynoBot", |this, uniqueDynoBotId| {
			# Get DynoBot by Id
			return this:bots():get(uniqueDynoBotId)
		})
		:define("sendMessageTo", |this, message, uniqueDynoBotId| {
			# Send message to a bot
			this:bots():get(uniqueDynoBotId):messagesStack():push(message + ":" + this:id())
			#this:bots():get(uniqueDynoBotId):messagesStack():push(message)
		})
		:define("killThemAll", |this|->this:executor():shutdown()) # if newFixedThreadPool
		:define("startListening", |this, httpPort| {

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
					#Use templates
					#response = this:bots():toString()

					#TODO: to be continued

					headers: set("Content-Type", "application/json")

					let resp = DynamicObject():value("[")

					this:bots():each(|key, dynobot|{
						resp:value(
							"%s{dynobot:\"%s\",listening:%s, messagesStack:{}},"
							:format(resp:value(), key, dynobot:listening())
						)
					})
	
					response = resp:value():substring(0,resp:value():length() - 1 ) + "]"

						#:id(uniqueId)
						#:messagesStack(list[]) 					
						#:master(null)							
						#:executor(null)							
						#:evalEnv(null)							
						#:actions(map[])
						#:futureListener(null)
						#:futureAction(null)
						#:listening(false)

				} 	

				if uri: startsWith("/help") {
					headers: set("Content-Type", "text/html")
					response = """
						<h1>Help</h1>
						<ul>
							<li>stop a dynobot : http://localhost:port/master:stop:dynobotId</li>
							<li>cancel a dynobot : http://localhost:port/master:cancel:dynobotId</li>
							<li>start an existing dynobot : http://localhost:port/master:start:dynobotId</li>
							<li>send message to a dynobot : http://localhost:port/master:message:dynobotId:message_content</li>
							<li>send action message to a dynobot : http://localhost:port/master:message:dynobotId:action:module:function:message</li>
							<li>list of dynobots : http://localhost:port/master:dynobots</li>
							<li>result of dynobot action (future:getResult()) : http://localhost:port/master:result:dynobotId</li>
							<li>result of dynobot action (only if future is done) : http://localhost:port/master:result:dynobotId</li>
							<li>...</li>					
						</ul>
						Try this : 
						<ul>
							<li>
								<a href="/master:message:dyno001:Hello">/master:message:dyno001:Hello</a>
							</li>	
							<li>
								<a href="/master:message:dyno002:Morgen">/master:message:dyno002:Morgen</a>
							</li>												
							<li>
								<a href="/master:message:dyno002:action:tools:hello:bob_morane">/master:message:dyno002:action:tools:hello:bob_morane</a>
							</li>
							<li>
								<a href="/master:message:dyno003:action:mymodule:work1:hello_world">/master:message:dyno003:action:mymodule:work1:hello_world</a>
							</li>
							<li>
								<a href="/master:message:dyno003:action:mymodule:work2:salut_tout_le_monde">/master:message:dyno003:action:mymodule:work2:salut_tout_le_monde</a>
							</li>							
						</ul>
					"""
				} else {
					#TODO:
				}		


				#http://localhost:9999/master:message:dyno002:action:tools:hello:bob_morane
				

				#dynoBotsMaster:sendMessageTo("action:mymodule:work1:???", "dyno003")
				#dynoBotsMaster:sendMessageTo("action:mymodule:work2:!!!", "dyno003")

				#dynoBotsMaster:sendMessageTo("action:tools:hello:bob_morane", "dyno002")

				#dynoBotsMaster:sendMessageTo("Hello", "dyno001")
				#dynoBotsMaster:sendMessageTo("Morgen", "dyno002")

				#dynoBotsMaster:getDynoBot("dyno001"):startListening()				
				
				#dynoBotsMaster:sendMessageTo("stop", "dyno001") 	master:stop:dyno001
				#dynoBotsMaster:sendMessageTo("cancel", "dyno002")	master:cancel:dyno002
				#dynoBotsMaster:sendMessageTo("stop", "dyno003")	master:stop:dyno003
			
				#headers: set("Content-Type", "text/plain")
				
				#headers: set("Content-Type", "text/html")

				exchange: sendResponseHeaders(200, response: length())
				exchange: getResponseBody(): write(response: getBytes())
				exchange: close()
			}))

			server: start()		

			#How can i stop by message ? new context

			return this
		})

		#TODO : remote dynobot and remote master

	return master
}

