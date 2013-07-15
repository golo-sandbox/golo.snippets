module boids

import dynobots

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
	#code
	#java.util.UUID.randomUUID().toString()

	let dynoBotsMaster = Master("DynoBotsMaster")
			:startListening(9999)

	dynoBotsMaster:addActions("dynomod", actions4Alldynobots())


	let start = java.lang.System.currentTimeMillis()

	for (var counter = 1, counter <=1000, counter = counter + 1)  {

		#let dyno = dynoBotsMaster:getNewDynoBot(java.util.UUID.randomUUID():toString())
		let dyno = dynoBotsMaster:getNewDynoBot("dyno"+counter):startListening()
		
	}

	let duration = java.lang.System.currentTimeMillis() - start
	println("All dynobots started, duration : " + duration + " ms")
}