--!strict
--!native

local freeThreads : {thread} = {}

local function runCallBack(callback : (...unknown) -> (), thread : thread, ...) : ()
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
	connected : boolean;
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
}

function hook.new<T...>() : hook<T...>
	return setmetatable({_head = nil}, hook) :: any
end

function hook:listen<T...>(fn : (T...) -> ())
	local node : node = {fn = fn :: any; next = self._head; connected = true}
	self._head = node

	return {
		disconnect = function()
			if not node.connected then
				return
			end
			node.connected = false
			node.fn = nil

			if self._head == node then
				self._head = (node.next :: node)
			else
				local prev = self._head
				while prev and prev.next ~= node do
					prev = prev.next
				end
				if prev then
					prev.next = node.next
				end
			end
		end
	}
end

function hook:once<T...>(fn : (...unknown) -> ())
	local conn : connection
	conn = self:listen(function(...)
		conn:disconnect()
		fn(...)
	end)
	return conn
end

function hook:wait()
	local running = coroutine.running()
	local conn : connection

	conn = self:listen(function(...)
		conn:disconnect()
		task.spawn(running, ...)
	end)

	return coroutine.yield()
end

function hook:send(...)
	local node = self._head

	while node do
		local nextNode = node.next
		if node.connected and node.fn then
			local thread = table.remove(freeThreads)
			if not thread then
				thread = coroutine.create(yielder)
				coroutine.resume(thread)
			end
			task.spawn((thread :: thread), node.fn, thread, ...)
		end
		node = nextNode
	end
end

function hook:disconnectAll()
	local node : node? = self._head
	self._head = nil

	while node do
		local nextNode = node.next
		node.connected = false
		node.fn = nil
		node.next = nil
		node = nextNode
	end
end

return hook