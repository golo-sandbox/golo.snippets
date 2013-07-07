module math.augmentations

import java.math.BigDecimal

augment java.lang.Number {
	function add = |this, x| -> this + x
	function subtract = |this, x| -> this - x 

	function multiply = |this, x| -> this * x
	function divide = |this, x| -> this / x	
}

augment java.lang.Integer {

	function fact = |this| {
		var number = this
		var result = 1
		while(number != 0) {
			result = result * number
			number = number - 1
		}
		return result
	}

	function pow = |this, power| {
		return java.lang.Math.pow(this+0.0, power+0.0)
	}

	function incr = |this| -> this + 1
	function decr = |this| -> this - 1

} 

augment java.lang.Double {

	function fact = |this| {
		var number = this
		var result = 1.0
		while(number > 0.0) {
			result = result * number
			number = number - 1.0
		}
		return result
	}

	function pow = |this, power| {
		return java.lang.Math.pow(this, power+0.0)
	}
} 

augment java.math.BigDecimal {

	function fact = |this| {
		#var number = BigDecimal(this)
		var number = this
		var result = BigDecimal(1)
		while (number != BigDecimal(0)) {
			#result = result:multiply(number, java.math.MathContext(10, java.math.RoundingMode.CEILING()))
			result = result:multiply(number)
			number = number:subtract(BigDecimal(1))
		}
		return result
	}
} 


function main = |args| {
	println(5:fact())
	println(5.0:fact())
	println(BigDecimal(5):fact())
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
}


