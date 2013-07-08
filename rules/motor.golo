module motor

import java.util.HashMap

function getRules = {
	let rules = HashMap()

	let R1 = """
	module M1

	function R1 = |fact| {
		println("RULE 1 : " + fact:subject()+ " " + fact:verb() + " " + fact:object())
		if fact:subject() is "Bob" { println("Hello Bob!!!") }
	}
	"""

	let R2 = """
	module M2

	function R2 = |fact| {
		println("RULE 2 : " + fact:subject()+ " " + fact:verb() + " " + fact:object())
		if fact:verb() is "eats" { println("enjoy your meal :)") }
	}
	"""

	let R3 = """
	module M3

	function R3 = |fact| {
		println("RULE 3 : " + fact:subject()+ " " + fact:verb() + " " + fact:object())
		if fact:object() is "apple" { println("it is good for health") }
	}	
	"""

	rules:add("M1", R1):add("M2", R2):add("M3", R3)

	return rules
}

function getModules = |env, rules| {
	return DynamicObject()
		:env(env)
		:rules(rules)
		:modules(HashMap())
		:define("add", |this, moduleName|{
			this:modules():add(moduleName, this:env(): asModule(this:rules():get(moduleName)))
		})
		:define("getFunc", |this, functionName, moduleName|{
			return fun(functionName, this:modules():get(moduleName))
		})
}

function main = |args| {
	let env = gololang.EvaluationEnvironment()

	#00- this is a fact
	let fact = DynamicObject()
				:subject("Bob")
				:verb("eats")
				:object("apple")

	#01- get rules and modules
	let rules = getRules()

	let modules = getModules(env, rules)

	#02- add modules to execution environment
	modules:add("M1")
	modules:add("M2")
	modules:add("M3")

	#03- test the fact with the rules
	var f = modules:getFunc("R1", "M1")

	f(fact)

	f = modules:getFunc("R2", "M2")

	f(fact)

	f = modules:getFunc("R3", "M3")

	f(fact)


	#04- add rule
	rules:add("M4","""
	module M4

	function R4 = |fact| {
		println("RULE 4 : " + fact:subject()+ " " + fact:verb() + " " + fact:object())
		if fact:subject() is "Bob" { 
			println("Bye Bob!")
		} else {
			println("But you're not Bob!")
		}
	}	
	""")

	#05- add module to execution environment
	modules:add("M4")


	#06- test fact with new rule
	f = modules:getFunc("R4", "M4")

	f(fact)

}

