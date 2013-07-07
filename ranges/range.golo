module range

#branche range-plus

function main = |args| {
	let r = range(0,36):incrementBy(2)

	println(
		"from %s to %s"
		:format(
				r:from():toString()
			,	r:to():toString()
		)
	)
	#let r = range(0,36):incrementBy(2)
	foreach i in r {
		if i > (r:to()/2) { println("more than half") }
		println(i)
	}

	println("increment : %s":format(r:increment()))
	

}