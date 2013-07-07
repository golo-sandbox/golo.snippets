module math.augmentations

import gololang.math

function main = |args| {
	println(5:fact())
	println(5.0:fact())

	var b = java.math.BigDecimal(5)

	println(b:fact())
	println(5.0:pow(2.0))
	println(2.0:pow(2.0):fact())
	println(4.0:fact())

	println(5:incr():incr():divide(2))
	println(5:incr():incr():divide(2.0))

	println(7:divide(2.0))
	println(7:divide(2))
	println(7.0:divide(2))

	println(7:multiply(2.0))

	println(2:pow(5.0))

	println(PI():multiply(2))
	println(E():pow(2))
}


