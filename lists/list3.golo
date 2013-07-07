module list

import java.util.LinkedList

#branche list-plus

local function list_data = {
  return LinkedList():
    insert(0, 2):
    append(3, 4):
    prepend(0, 1)
}


function main = |args| {

	list_data(): reverse(): each(|v| {
	   println(v)
	})
	println("-----")
	list_data(): reverse(): order(): each(|v| {
	   println(v)
	})
	println("-----")
	list_data(): order(java.util.Collections.reverseOrder()): each(|v| {
	   println(v)
	})
	println("-----")
	list_data(): ordered(): each(|v| {
	   println(v)
	})	
}