module dynobots

import java.util.concurrent.Executors
import java.lang.Thread

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
		:executor(null)							# master:executor()
		:evalEnv(null)							# master:evalEnv()
		:actions(map[])
		:futureListener(null)
		:listening(false)
		:define("addActions", |this, moduleName, sourceCode| { #add module
			this:actions():add(moduleName, this:evalEnv(): asModule(sourceCode))
			#this:evalEnv(): asModule(sourceCode)
			return this
		})
		:define("getFunc", |this, moduleName, functionName|{
			return fun(functionName, this:actions():get(moduleName))
		})
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
							var message = this:messagesStack():removeFirst()
							println("message for %s : %s":format(this:id(), message))

							if message == "stop" { listening = false }
							if message == "cancel" { 
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

								println(
									"*** FUNCTION : %s IN MODULE : %s WITH : %s"
										:format(
											  function_name
											, module_name
											, parameters
										)
								)
								
								
								let callableAction = |parameters, callBackWhenDone| {
									var f = this:getFunc(module_name, function_name)
									var r = f(parameters)
									if callBackWhenDone isnt null { callBackWhenDone(function_name+" of "+module_name) }

									return r
								}

								let future = this:executor():getFuture(		# run it (callableAction)
									  callableAction
									, parameters							# Message
									, |arg| { 
										println("--> " + arg + " is done") 
									  }	# Callback when callableAction is done / Callback (when done) is passed to callableAction									
								)
								
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
					this:executor():getFuture(					# run it (callableListener)
						  callableListener
						, "future Listener : " + this:id()		# Message
						, |arg| { println(arg + " is done") }	# Callback when callableListener is done / Callback (when done) is passed to callableListener
						, |arg| { println(arg + " Submitted") }	# Callback when callableListener is submitted
					)
				)
				# ----- ... -----
			} # end else (if)
			return this
		})

	return dynoBot
}


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
		:define("getNewDynoBot", |this, uniqueDynoBotId| { #if id exists ?

			# TODO : have to verify if dynoBot already exists

			# create DynoBot
			let dyno = DynoBot(uniqueDynoBotId)

			dyno:master(this)
			dyno:executor(this:executor())
			dyno:evalEnv(this:evalEnv())

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
			this:bots():get(uniqueDynoBotId):messagesStack():push(message)
		})
		:define("killThemAll", |this|->this:executor():shutdown()) # if newFixedThreadPool

		#TODO : remote dynobot and remote master

	return master
}



function main = |args| {

	#let dynoBotsMaster = Master("DynoBotsMaster", 50)
	let dynoBotsMaster = Master("DynoBotsMaster")

	dynoBotsMaster:getNewDynoBot("dyno001"):startListening()
	let dyno002 = dynoBotsMaster:getNewDynoBot("dyno002"):startListening()

	let dyno003 = dynoBotsMaster:getNewDynoBot("dyno003"):startListening()

	dyno003:addActions("mymodule", """
		module mymodule

		function action1 = |arg| {
			println("ACTION 1 .... " + arg)
		}

		function action2 = |arg| {
			println("ACTION 2 .... " + arg)
		}			
	""")

	dyno002:addActions("tools", """
		module tools

		function hello = |args| {
			println("#### hello world from %s ####":format(args))
		}
	""")


	dynoBotsMaster:sendMessageTo("action:mymodule:action1:???", "dyno003")
	dynoBotsMaster:sendMessageTo("action:mymodule:action2:!!!", "dyno003")

	dynoBotsMaster:sendMessageTo("action:tools:hello:bob_morane", "dyno002")

	dynoBotsMaster:sendMessageTo("Hello", "dyno001")
	dynoBotsMaster:sendMessageTo("Morgen", "dyno002")

	dynoBotsMaster:getDynoBot("dyno001"):startListening()

	dynoBotsMaster:sendMessageTo("stop", "dyno001")
	dynoBotsMaster:sendMessageTo("cancel", "dyno002")

	dynoBotsMaster:sendMessageTo("stop", "dyno003")

	println(dynoBotsMaster:bots())

	dynoBotsMaster:killThemAll()



}