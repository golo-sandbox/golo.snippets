module literals


function Pair 		= |a, b| -> [a, b]
function Triplet 	= |a, b, c| -> [a, b, c]

function Model = |fields| -> DynamicObject()
	:fields(fields)
	:define("getField", |this, fieldName| -> this:fields():get(fieldName))
	:define("setField", |this, fieldName, value| -> this:fields():put(fieldName, value))
	:define("toString", |this| -> this:fields():toString())

function main = |args| {
	let t = [1,"bob",3]

	println(t:get(1))

	t:each(|item|->println(item))

	let p1 = Pair("Bob", "Morane")
	let p2 = Pair("John", "Doe")

	let t1 = Triplet(1,p2,p1)

	t1:each(|item|->println(item:toString()))


	let Bob = Model(map[
		["firstName", "Bob"],
		["lastName", "Morane"]
	])

	println(Bob:getField("firstName"))
	Bob:setField("firstName","BOBBY")
	println(Bob:getField("firstName"))
	Bob:fields():each(|key, value|->println(key+" : "+value))
	println(Bob:toString())

	set[1,2,3]:each(|item|->println("- " + item))

	println(map[
		["firstName", "Bob"],
		["lastName", "Morane"]
	]:equals(map[
		["firstName", "Bob"],
		["lastName", "Morane"]
	]))

	println(map[
		["firstName", "Bobby"],
		["lastName", "Morane"]
	]:equals(map[
		["firstName", "Bob"],
		["lastName", "Morane"]
	]))


}