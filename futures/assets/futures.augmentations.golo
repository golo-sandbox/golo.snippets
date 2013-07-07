module futures.augmentations

augment java.util.concurrent.Future {
	# callBackWhenException is a callBack when exception
	function getResult = |this, callBackWhenException| {
		var r  = null
		try {
			r = this:get()	
		} catch (e) {
			if callBackWhenException isnt null { callBackWhenException(e) }
		} finally {
			return r
		}
	}

	function getResult = |this| {
		var r  = null
		try {
			r = this:get()	
		} finally {
			return r
		}
	}

	function cancelTask = |this, callBackWhenCancelled| {
		this:cancel(true)
		callBackWhenCancelled(this:isCancelled())
	}
}

augment java.util.concurrent.ExecutorService {
	# callable : closure to execute
	# message : argument passed to callable
	# callBackWhenSubmitted : 
	#  - called when callable is submitted by ExecutorService
	#  - message is passed as parameter of callBackWhenSubmitted
	# callBackWhenDone : passed as 2nd parameter of the callable
	function getFuture = |this, callable, message, callBackWhenSubmitted, callBackWhenDone| {
		let worker = (-> callable(message, callBackWhenDone)):to(java.util.concurrent.Callable.class)
		if callBackWhenSubmitted isnt null { callBackWhenSubmitted(message) }
		return this:submit(worker) #future is run when submit()
	}

	# REM : callBackWhenDone : not necessarily useful

	function getFuture = |this, callable, message, callBackWhenSubmitted| {
		let worker = (-> callable(message)):to(java.util.concurrent.Callable.class)
		if callBackWhenSubmitted isnt null { callBackWhenSubmitted(message) }
		return this:submit(worker) #future is run when submit()
	}

	function getFuture = |this, callable, message| {
		let worker = (-> callable(message)):to(java.util.concurrent.Callable.class)
		return this:submit(worker) #future is run when submit()
	}		
} 