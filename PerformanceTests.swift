import XCTest

class PerformanceTests: XCTestCase {

  func testCreateFromArrayRange() {
    var a = [[Double]]()
    for _ in 0..<1000 {
      a.append([Double](count: 1000, repeatedValue: M_PI))
    }
    measureBlock() {
      for _ in 1...10 {
        let _ = Matrix(a, range: 0..<1000)
      }
    }
  }

  func testTile() {
    let v = Matrix.random(rows: 1, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        let _ = v.tile(2000)
      }
    }
  }

  func testCopyEntireMatrix() {
    let M = Matrix.random(rows: 1000, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        let _ = M.copy(Array(0..<1000))
      }
    }
  }

  func testSubscriptRowGetter() {
    var M = Matrix.random(rows: 1000, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        for i in 0..<M.rows {
          let _ = M[row: i]
        }
      }
    }
  }

  func testSubscriptRowSetter() {
    var M = Matrix.random(rows: 1000, columns: 1000)
    let v = Matrix.random(rows: 1, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        for i in 0..<M.rows {
          M[row: i] = v
        }
      }
    }
  }
  
  func testSubscripColumnGetter() {
    var M = Matrix.random(rows: 1000, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        for i in 0..<M.columns {
          let _ = M[column: i]
        }
      }
    }
  }

  func testSubscriptColumnSetter() {
    var M = Matrix.random(rows: 1000, columns: 1000)
    let v = Matrix.random(rows: 1000, columns: 1)
    measureBlock() {
      for _ in 1...10 {
        for i in 0..<M.columns {
          M[column: i] = v
        }
      }
    }
  }

  func testSqrt() {
    let M = Matrix.random(rows: 1000, columns: 1000)
    measureBlock() {
      for _ in 1...10 {
        let _ = sqrt(M)
      }
    }
  }

  func testPow2() {
    let M = Matrix.random(rows: 1000, columns: 1000)
    measureBlock() {
      let _ = pow(M, 2)
    }
  }

  func testPow3() {
    let M = Matrix.random(rows: 1000, columns: 1000)
    measureBlock() {
      let _ = pow(M, 3)
    }
  }
}
