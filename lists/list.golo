module list

import java.util.LinkedList

augment java.util.LinkedList {
  function count = |this, pred| -> this: filter(pred): size()

  function exists = |this, pred| -> this: filter(pred): size() > 0

  function removed = |this, at| {
    let removedList = this: newWithSameType()
    removedList: addAll(this)
    removedList: remove(at)
    return removedList
  }

}


function main = |args| {

	let bookslist = LinkedList()
		:append("A Princess of Mars")
		:append("The Gods of Mars")
		:append("The Chessmen of Mars")

	println("size : " + bookslist:size())
	println("empty : " + bookslist:isEmpty())
	println("head : " + bookslist:head())
	println("tail : " + bookslist:tail())

	println("last : " + bookslist:getLast())
	println("first : " + bookslist:getFirst())

	println(bookslist)

	println(bookslist:reverse())

	println(
		bookslist:filter(|book|->book!="The Gods of Mars")
	)

	println(
		bookslist:count(|book|->book!="The Gods of Mars")
	)

	#bookslist:remove(0)
	println(bookslist:removed(0)) #return new list
	println(bookslist)

	println(
		bookslist:exists(|book|->book=="The Gods of Mars")
	)

	println(
		bookslist:exists(|book|->book=="Mars")
	)

	#bookslist:each(|book| {
	#   println(book)
	#})
}