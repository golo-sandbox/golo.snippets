module motor

import java.util.HashMap

function getRules = {
	let rules = HashMap()

	let R1 = """
	module M1

	function R1 = |fact| {
		println("R1")
	}
	"""

	let R2 = """
	module M2

	function R2 = |fact| {
		println("R2")
	}
	"""

	let R3 = """
	module M3

	function R3 = |fact| {
		println("R3")
	}	
	"""

	rules:add("M1", R1):add("M2", R2):add("M3", R3)

	return rules
}




function main = |args| {
	let env = gololang.EvaluationEnvironment()

	let rules = getRules()

	let modules = HashMap()

	modules:add("M1", env: asModule(rules:get("M1")))
	modules:add("M2", env: asModule(rules:get("M2")))

	var f = fun("R1",modules:get("M1"))

	f("HELLO")

	f = fun("R2",modules:get("M2"))

	f("HELLO")


	rules:add("M4","""
	module M4

	function R4 = |fact| {
		println("R4")
	}	
	""")

	modules:add("M4", env: asModule(rules:get("M4")))

	f = fun("R4",modules:get("M4"))

	f("HELLO")

	


}

