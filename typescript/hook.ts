const freeThreads: thread[] = []

function runCallback<T extends unknown[]>(
  callback: (...args: T) => void,
  thread: thread,
  ...args: T
): void {
  callback(...args)
  if (freeThreads.size() < 64) {
    freeThreads.push(thread)
  }
}

function yielder() {
  while (true) {
    runCallback(...(coroutine.yield() as unknown as [Callback, thread, ...unknown[]]))
  }
}

export interface connection {
  disconnect(): void
}

interface node<T extends unknown[]> {
  fn?: (...args: T) => void,
  next?: node<T>,
  connected: boolean,
}

export class hook<T extends unknown[] = []> {
  private _head?: node<T>

  public listen(fn: (...args: T) => void): connection {
    const node: node<T> = {
      fn,
      next: this._head,
      connected: true,
    }

    this._head = node

    return {
      disconnect: (): void => {
        if (!node.connected) return
        node.connected = false
        node.fn = undefined

        if (this._head === node) {
          this._head = node.next
        } else {
          let prev = this._head
          while (prev && prev.next !== node) {
            prev = prev.next
          }

          if (prev) {
            prev.next = node.next
          }
        }
      }
    }
  }

  public once(fn: (...args: T) => void): connection {
    const conn = this.listen((...args: T): void => {
      conn.disconnect()
      fn(...args)
    })

    return conn
  }

  public wait(): LuaTuple<T> {
    const running = coroutine.running()
    const conn = this.listen((...args: T): void => {
      conn.disconnect()
      task.spawn(running, ...args)
    })

    return coroutine.yield() as LuaTuple<T>
  }

  public send(...args: T): void {
    let node = this._head

    while (node) {
      const nextNode = node.next
      if (node.connected && node.fn) {
        let thread = freeThreads.pop()

        if (!thread) {
          thread = coroutine.create(yielder)
          coroutine.resume(thread)
        }
        task.spawn(thread, node.fn, thread, ...args)
      }
      node = nextNode
    }
  }

  public disconnectAll(): void {
    let node = this._head
    this._head = undefined

    while (node) {
      const nextNode = node.next
      node.connected = false
      node.fn = undefined
      node.next = undefined
      node = nextNode
    }
  }
}
