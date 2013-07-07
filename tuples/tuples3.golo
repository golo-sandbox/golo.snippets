module tuple

function Tuple = |elements...| {
	let t = java.util.ArrayList()
	t:addAll(elements:get(0))
	if elements:size() > 1 {
		t:append(elements:get(1))
	}
	#return java.util.Collections.unmodifiableList(t)
	return t:unmodifiableView()
}

function Pair 		= |a, b| -> Tuple(java.util.ArrayList():append(a):append(b))
function Triplet 	= |a, b, c| -> Tuple(Pair(a, b), c)
function Quartet 	= |a, b, c, d| -> Tuple(Triplet(a, b, c), d)
function Quintet 	= |a, b, c, d, e| -> Tuple(Quartet(a, b, c, d), e)
function Sextet 	= |a, b, c, d, e, f| -> Tuple(Quintet(a, b, c, d, e), f)
function Septet 	= |a, b, c, d, e, f, g| -> Tuple(Sextet(a, b, c, d, e, f), g)
function Octet 		= |a, b, c, d, e, f, g, h| -> Tuple(Septet(a, b, c, d, e, f, g), h)
function Ennead 	= |a, b, c, d, e, f, g, h, i| -> Tuple(Octet(a, b, c, d, e, f, g, h), i)
function Decade 	= |a, b, c, d, e, f, g, h, i, j| -> Tuple(Ennead(a, b, c, d, e, f, g, h, i), j)


function main = |args| {
	
	let t1 = Triplet(1,2,Pair("Bob", "Sam"))
	let t2 = Triplet(1,2,Pair("Sam", "Sam"))
	let t3 = Triplet(1,2,Pair("Sam", "Sam"))
	let t4 = Triplet(3,2,Pair("Sam", "Polo"))

	println(t1:equals(t2))
	println(t2:equals(t3))
	println(t3:equals(t4))

	println(t1:get(0))
	println(t1:get(1))
	println(t1:get(2))

	println(t4:toArray():toString())

	#t1:set(2,"Hello") #java.lang.UnsupportedOperationException ->

}
