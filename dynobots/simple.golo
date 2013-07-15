module simple

import dynobots


function main = |args| {

	#let dynoBotsMaster = Master("DynoBotsMaster", 50)
	let dynoBotsMaster = Master("DynoBotsMaster")
							:startListening(9999)

	dynoBotsMaster:getNewDynoBot("dyno000")

	dynoBotsMaster:getNewDynoBot("dyno001"):startListening()
	
	let dyno002 = dynoBotsMaster:getNewDynoBot("dyno002"):startListening()

	let dyno003 = dynoBotsMaster:getNewDynoBot("dyno003"):startListening()

	dynoBotsMaster:addActions("mymodule", """
		module mymodule

		function work1 = |args| {

			# args is a tuple : triplet
			# first item is string parameter
			# second item is dynobot
			# third item is sender id

			println("ACTION 1 FOR %s, PARAMETERS : \"%s\" FROM %s"
				:format(
					  args:get(1):id()
					, args:get(0)
					, args:get(2))
			)

			return "work1 is done"

		}

		function work2 = |args| {

			println("ACTION 2 FOR %s, PARAMETERS : \"%s\" FROM %s"
				:format(
					  args:get(1):id()
					, args:get(0)
					, args:get(2))
			)

			return "work2 is done"
		}

		function youvegotamessage = |args| {
			println("HELLO %s, YOU'VE GOT A MESSAGE : \"%s\" FROM %s"
				:format(
					  args:get(1):id()
					, args:get(0)
					, args:get(2))
			)

			return "TADAAAAA"
		}			
	""")

	dynoBotsMaster:addActions("tools", """
		module tools

		function hello = |args| {
			println("===> " + args:get(1):id())
			println("#### hello world from %s ####":format(args:get(0)))

			let selfDyno = args:get(1)

			selfDyno:sendMessageTo("action:mymodule:youvegotamessage:hello", "dyno003")

			return "WOOOOOOOT"
		}
	""")


	#dynoBotsMaster:sendMessageTo("action:mymodule:work1:???", "dyno003")
	#dynoBotsMaster:sendMessageTo("action:mymodule:work2:!!!", "dyno003")
	#dynoBotsMaster:sendMessageTo("action:tools:hello:bob_morane", "dyno002")
	#dynoBotsMaster:sendMessageTo("Hello", "dyno001")
	#dynoBotsMaster:sendMessageTo("Morgen", "dyno002")

	#dynoBotsMaster:getDynoBot("dyno001"):startListening()

	#dynoBotsMaster:sendMessageTo("stop", "dyno001") 	master:stop:dyno001
	#dynoBotsMaster:sendMessageTo("cancel", "dyno002")	master:cancel:dyno002
	#dynoBotsMaster:sendMessageTo("stop", "dyno003")	master:stop:dyno003

	println(dynoBotsMaster:bots():toString())

	#dynoBotsMaster:killThemAll()

}