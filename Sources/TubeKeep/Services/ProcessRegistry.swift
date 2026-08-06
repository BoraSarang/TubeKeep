import Foundation
import Darwin

enum ProcessRegistry {
  private static let lock = NSLock()
  private static var processes: [Process] = []

  static func register(_ process: Process) {
    let existing = process.terminationHandler
    process.terminationHandler = { p in
      existing?(p)
      Self.lock.withLock {
        Self.processes.removeAll { $0 == p }
      }
    }
    lock.withLock {
      processes.append(process)
    }
  }

  @discardableResult
  static func killAll() -> Int {
    let alive = lock.withLock {
      let refs = processes
      processes.removeAll()
      return refs
    }
    for p in alive where p.isRunning {
      p.terminate()
      let pid = p.processIdentifier
      if pid > 0 {
        kill(pid, SIGKILL)
      }
    }
    return alive.count
  }
}
