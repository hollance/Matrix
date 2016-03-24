import XCTest

class PerformanceTests: XCTestCase {
  func testTile() {
    let v = Matrix.random(rows: 1, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        let _ = v.tile(2000)
      }
    }
  }
}
