module list

import java.util.LinkedList



function main = |args| {

	let bookslist = LinkedList()
		:append("A Princess of Mars")
		:append("The Gods of Mars")
		:append("The Chessmen of Mars")

	println("=== sorted : new sorted list ===")
	println(bookslist)
	println(bookslist:ordered())
	println(bookslist)

	println("=== reversed : new reversed list ===")
	println(bookslist)
	println(bookslist:reversed())
	println(bookslist)

	println("=== sort : sort current list ===")
	println(bookslist)
	println(bookslist:order())
	println(bookslist)

	println("=== reverse : reverse current list ===")
	println(bookslist)
	println(bookslist:reverse())
	println(bookslist)

}