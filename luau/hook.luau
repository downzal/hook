--!strict
--!native

local freeThreads : {thread} = {}

local function runCallBack(callback: (...unknown) -> (), thread: thread, ...: unknown): ()
	if type(callback) ~= "function" then return end
	callback(...)
	if #freeThreads < 64 then
		table.insert(freeThreads, thread)
	end
end

local function yielder() : ()
	while true do
		runCallBack(coroutine.yield())
	end
end

local hook = {}
hook.__index = hook

type node = {
	fn : ((...unknown) -> ())?;
	next : node?;
	prev : node?;
	connected : boolean;
	waiter : thread?;
}

export type connection = {
	disconnect : (self : connection) -> ();
}

export type hook<T...> = {
	_head : node?;
	listen : (self : hook<T...>, fn : (T...) -> ()) -> connection;
	once : (self : hook<T...>, fn : (T...) -> ()) -> connection;
	wait : (self : hook<T...>) -> T...;
	send : (self : hook<T...>, T...) -> ();
	disconnectAll : (self : hook<T...>) -> ();
	hasListeners : (self : hook<T...>) -> boolean;
}

--[[ creates a new hook ]]
function hook.new<T...>() : hook<T...>
	return setmetatable({_head = nil}, hook) :: any
end

local function link<T...>(self : hook<T...>, fn : (T...) -> (), waiter : thread?) : connection
	local head = self._head
	local node : node = {fn = fn :: any, next = head, prev = nil, connected = true, waiter = waiter}
	if head then
		head.prev = node
	end
	self._head = node

	return {
		disconnect = function()
			if not node.connected then
				return
			end
			node.connected = false
			node.fn = nil
			node.waiter = nil

			local prev, nxt = node.prev, node.next
			if prev then
				prev.next = nxt
			else
				self._head = nxt
			end
			if nxt then
				nxt.prev = prev
			end
			node.prev = nil
			node.next = nil
		end
	}
end

--[[ runs given function upon given hook firing ]]
function hook.listen<T...>(self : hook<T...>, fn : (T...) -> ())
	if type(fn) ~= "function" then
		error("invalid argument type for 'fn' (function expected, got " .. typeof(fn) .. ")", 2)
	end
	return link(self, fn, nil)
end

--[[ runs given function upon given hook firing, disconnects after one call ]]
function hook.once<T...>(self : hook<T...>, fn : (T...) -> ())
	local conn : connection
	conn = self:listen(function(...)
		conn:disconnect()
		fn(...)
	end)
	return conn
end

--[[ yields until hook is fired, returns all hook arguments ]]
function hook.wait<T...>(self : hook<T...>) : T... --returns zero values if disconnectAll runs whilst its parked
	local running = coroutine.running()
	local conn : connection

	conn = link(self, function(...)
		conn:disconnect()
		if coroutine.status(running) == "suspended" then
			task.spawn(running, ...)
		end
	end, running)

	return coroutine.yield()
end

--[[ sends arguments to all connected functions ]]
function hook.send<T...>(self : hook<T...>, ...)
	local current = self._head
	local list = {} :: {node}

	while current do
		if current.connected and current.fn then
			table.insert(list, current)
		end
		current = current.next
	end

	for _, node in ipairs(list) do
		if node.connected and node.fn then
			local thread : thread? = table.remove(freeThreads)
			while thread and coroutine.status(thread) ~= "suspended" do
				thread = table.remove(freeThreads)
			end
			if not thread then
				thread = coroutine.create(yielder)
				coroutine.resume(thread)
			end
			task.spawn(thread :: thread, node.fn, thread :: thread, ...)
		end
	end
end

--[[ disconnects all listeners ]]
function hook.disconnectAll<T...>(self : hook<T...>)
	local node : node? = self._head
	self._head = nil
	local waiters : {thread}? = nil

	while node do
		local nextNode = node.next
		local waiter = node.waiter
		if waiter and coroutine.status(waiter) == "suspended" then
			waiters = waiters or {}
			table.insert(waiters :: {thread}, waiter)
		end
		node.connected = false
		node.fn = nil
		node.next = nil
		node.prev = nil
		node.waiter = nil
		node = nextNode
	end

	if waiters then
		for _, waiter in waiters do
			if coroutine.status(waiter) == "suspended" then
				task.spawn(waiter)
			end
		end
		task.spawn(error, debug.traceback(
			`disconnectAll resumed {#waiters} thread(s) waiting on this hook; wait() returned nothing`, 2
		))
	end
end

--[[ checks if hook has any listeners ]]
function hook.hasListeners<T...>(self : hook<T...>) : boolean
	return self._head ~= nil
end

return table.freeze(hook)
