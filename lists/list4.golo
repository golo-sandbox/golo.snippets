module name

import java.util.LinkedList



function main = |args| {
	let bookslist = LinkedList()
		:append("A Princess of Mars")
		:append("The Gods of Mars")
		:append("The Chessmen of Mars")

	println(bookslist)

	println(bookslist:ordered(java.util.Collections.reverseOrder()))

	println(bookslist)
}