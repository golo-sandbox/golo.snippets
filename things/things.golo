module things


function Human = |args| {

	let h = map[["firstName",args:get(0)],["lastName",args:get(1)]
		,["hello", -> println("HELLO ...")]
		,["salut", |msg|-> println("Salut : "+msg)]
	]
	
	h:put("about", -> println(h:get("firstName")+" "+h:get("lastName")))

	return h
}



function main = |args| {

		


	let bob = Human(["Bob", "Morane"])
	bob:get("hello"):invokeWithArguments()
	bob:get("salut"):invokeWithArguments("tadaaaaa!!!")
	bob:get("about"):invokeWithArguments()


}