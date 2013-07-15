module yakka

import java.lang.Thread
import java.util.concurrent
import gololang.concurrent.workers.WorkerEnvironment
import java.util.LinkedList
import java.util.HashMap

#import java.lang
import java.lang.String
import java.lang.StringBuilder
import java.net.InetSocketAddress
import com.sun.net.httpserver
import com.sun.net.httpserver.HttpServer

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder


function handler = |func| -> func: to(HttpHandler.class)

#TODO: Directors : subscribe to each other
#becareful about order of launch
#try catch with remote call
#external configuration 
#REMOTE : POST instead GET
#Create Dynamic Actors : big tests
#Create Threads for Director ? Possibility to query the director


function Director  = |id, environment| {

	return DynamicObject()
		:id(id)
		:actors(HashMap())
		:environment(environment)
		:state("?")
		:define("sendMessageTo", |this, actorId, message|{ #todo : message type (structure)
			let actor = this:actors():get(actorId)
			if actor isnt null { actor:messagesStack():push(message) }
			#comment retourner le fait que pas d'acteur ?
			return this
		})
		:define("sendRemoteMessageTo", |this, url, actorId, message|{ #todo : message type (structure)
			let url = URL(url+"/"+actorId+"/"+URLEncoder.encode(message,"UTF-8"))
			let connection = url:openConnection()
			connection:setRequestMethod("GET")
			connection:connect()

			let stream = connection:getInputStream()
			return this
		})		
		:define("sendMessageToAll", |this, message|{ #todo : message type (structure)
			#TODO
			#POURRAIT ETRE TRAITER PAR D'AUTRES ACTEURS DEDIES
			return this
		})		
		:define("startActor", |this, actorId, message|{
			this:actors():get(actorId):play(message)
			return this
		})
		:define("listen", |this, httpPort| {
			this:httpPort(httpPort)
			let worker = this:environment():spawn(|message| {

				println(message)

  				let server = HttpServer.create(InetSocketAddress("localhost", httpPort), 0)
  				
  				this:server(server)
  			
				server: createContext("/", handler(|exchange| {
					let headers = exchange: getResponseHeaders()

					let actorId = exchange: getRequestURI():toString():split("/"):get(1)
					let actorMessage = exchange: getRequestURI():toString():split("/"):get(2)

					let response = "id:"+actorId+" message:"+actorMessage
					#java.util.Date()

					#===Send message===
					this:sendMessageTo(actorId, actorMessage)
					#===Send message===
				
					headers: set("Content-Type", "text/plain")
						exchange: sendResponseHeaders(200, response: length())
						exchange: getResponseBody(): write(response: getBytes())
						exchange: close()
				}))

				server: start()
				
			})
			
			worker:send(this:id()+ " is listening on " + httpPort)
		})	
} 

function Actor = |id, director| {

	let actor = DynamicObject()
		:id(id)
		:director(director)
		:messagesStack(LinkedList())
		:environment(director:environment())
		:state("?")
		:worker(null)
		:define("script", |this, lambda| {
			
			let worker = this:environment():spawn(|message| {
				lambda(message, this)
			})	
			this:worker(worker)
			return this
		})		
		:define("play", |this, message|{
			this:worker():send(message)
			return this
		})
		:define("sendMessageTo", |this, actorId, message|{ #todo : message type (structure)
			#this:director():actors():get(actorId):messagesStack():push(message)
			this:director():sendMessageTo(actorId, message)
			return this #or exception or return code ? or status code
		})
		:define("sendRemoteMessageTo", |this, url, actorId, message| { #todo : message type (structure)
			this:director():sendRemoteMessageTo(url, actorId, message)
			return this #or exception or return code ? or status code
		})
		:define("getFirstMessage", |this|-> this:messagesStack():peekFirst())
		:define("delFirstMessage", |this|-> this:messagesStack():removeFirst())

	director:actors():put(id, actor)

	return actor	
} 
