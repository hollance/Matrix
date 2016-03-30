import Foundation
import XCTest

class MatrixTests: XCTestCase {
  func assertEqual(m1: Matrix, _ m2: Matrix) {
    XCTAssertEqual(m1.rows, m2.rows)
    XCTAssertEqual(m1.columns, m2.columns)
    for r in 0..<m1.rows {
      for c in 0..<m1.columns {
        XCTAssertEqual(m1[r, c], m2[r, c])
      }
    }
  }

  func assertEqual(m1: Matrix, _ m2: Matrix, accuracy epsilon: Double) {
    XCTAssertEqual(m1.rows, m2.rows)
    XCTAssertEqual(m1.columns, m2.columns)
    for r in 0..<m1.rows {
      for c in 0..<m1.columns {
        XCTAssertEqualWithAccuracy(m1[r, c], m2[r, c], accuracy: epsilon)
      }
    }
  }
  
  /*
    Since Matrix is a struct, if you copy the matrix to another variable,
    Swift doesn't actually copy the memory until you modify the new variable.
    Because Matrix uses Accelerate framework to modify its contents, we want
    to make sure that it doesn't modify the original array, only the copy.
    This helper function forces Swift to make a copy.
  */
  func copy(m: Matrix) -> Matrix {
    var q = m
    q[0,0] = m[0,0]  // force Swift to make a copy
    return q
  }
}

// MARK: - Creating matrices

extension MatrixTests {
  func testCreateFromArray() {
    let a = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
    let m = Matrix(a)
    XCTAssertEqual(m.rows, a.count)
    XCTAssertEqual(m.columns, a[0].count)
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        XCTAssertEqual(m[r, c], a[r][c])
      }
    }
  }

  func testCreateFromArrayRange() {
    let a = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]]
    for i in 0..<3 {
      for j in i..<3 {
        let m = Matrix(a, range: i...j)
        XCTAssertEqual(m.rows, a.count)
        XCTAssertEqual(m.columns, j - i + 1)
        for r in 0..<m.rows {
          for c in i...j {
            XCTAssertEqual(m[r, c - i], a[r][c])
          }
        }
      }
    }
  }
  
  func testCreateFromRowVector() {
    let v = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    let m = Matrix(v)
    XCTAssertEqual(m.rows, 1)
    XCTAssertEqual(m.columns, v.count)
    for c in 0..<m.columns {
      XCTAssertEqual(m[0, c], v[c])
    }
  }

  func testCreateFromColumnVector() {
    let v = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    let m = Matrix(v, isColumnVector: true)
    XCTAssertEqual(m.rows, v.count)
    XCTAssertEqual(m.columns, 1)
    for r in 0..<m.rows {
      XCTAssertEqual(m[r, 0], v[r])
    }
  }

  func testCreateRowVectorFromRange() {
    let m1 = Matrix(10..<20)
    XCTAssertEqual(m1.rows, 10)
    for r in 0..<m1.rows {
      XCTAssertEqual(m1[r, 0], Double(r + 10))
    }

    let m2 = Matrix(-10...10)
    XCTAssertEqual(m2.rows, 21)
    for r in 0..<m2.rows {
      XCTAssertEqual(m2[r, 0], Double(-10 + r))
    }
  }

  func testCreateColumnVectorFromRange() {
    let m1 = Matrix(10..<20, isColumnVector: true)
    XCTAssertEqual(m1.columns, 10)
    for c in 0..<m1.columns {
      XCTAssertEqual(m1[0, c], Double(c + 10))
    }

    let m2 = Matrix(-10...10, isColumnVector: true)
    XCTAssertEqual(m2.columns, 21)
    for c in 0..<m2.columns {
      XCTAssertEqual(m2[0, c], Double(-10 + c))
    }
  }

  func testZeros() {
    let m = Matrix.zeros(rows: 3, columns: 3)
    for r in 0..<3 {
      for c in 0..<3 {
        XCTAssertEqual(m[r, c], 0)
      }
    }
  }
  
  func testIdentityMatrix() {
    let m = Matrix.identity(size: 3)

    XCTAssertEqual(m[0, 0], 1)
    XCTAssertEqual(m[0, 1], 0)
    XCTAssertEqual(m[0, 2], 0)

    XCTAssertEqual(m[1, 0], 0)
    XCTAssertEqual(m[1, 1], 1)
    XCTAssertEqual(m[1, 2], 0)

    XCTAssertEqual(m[2, 0], 0)
    XCTAssertEqual(m[2, 1], 0)
    XCTAssertEqual(m[2, 2], 1)
  }
  
  func testTile() {
    let v = Matrix([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])

    let m = v.tile(5)
    XCTAssertEqual(m.rows, 5)
    XCTAssertEqual(m.columns, v.columns)
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        XCTAssertEqual(m[r, c], v[c])
      }
    }

    assertEqual(v, v.tile(1))
  }
  
  func testCopy() {
    let m = Matrix([[1, 2], [3, 4], [5, 6]])
    let M = copy(m)

    assertEqual(m.copy([0]), [1, 2])
    assertEqual(m.copy([1]), [3, 4])
    assertEqual(m.copy([2]), [5, 6])
    
    assertEqual(m.copy([0, 1]), Matrix([[1, 2], [3, 4]]))
    assertEqual(m.copy([1, 0]), Matrix([[3, 4], [1, 2]]))
    assertEqual(m.copy([0, 2]), Matrix([[1, 2], [5, 6]]))
    assertEqual(m.copy([2, 0]), Matrix([[5, 6], [1, 2]]))
    assertEqual(m.copy([2, 1, 0]), Matrix([[5, 6], [3, 4], [1, 2]]))
    
    assertEqual(m, M)
  }

  func testLoad() {
    let a = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
    var m = Matrix.zeros(rows: 3, columns: 4)

    m.load(a, range: 0...1, at: 2)
    assertEqual(m, Matrix([[0, 0, 1, 2], [0, 0, 3, 4], [0, 0, 5, 6]]))

    m.load(a, range: 0...0, at: 3)
    assertEqual(m, Matrix([[0, 0, 1, 1], [0, 0, 3, 3], [0, 0, 5, 5]]))

    m.load(a, range: 0...1, at: 0)
    assertEqual(m, Matrix([[1, 2, 1, 1], [3, 4, 3, 3], [5, 6, 5, 5]]))

    m.load(a, range: 0...1, at: 1)
    assertEqual(m, Matrix([[1, 1, 2, 1], [3, 3, 4, 3], [5, 5, 6, 5]]))
  }
}

// MARK: - Subscripts

extension MatrixTests {
  func testChangeMatrixUsingSubscript() {
    var m = Matrix.ones(rows: 3, columns: 3)
    for r in 0..<3 {
      for c in 0..<3 {
        m[r, c] = 100*(Double(r)+1) + 10*(Double(c)+1)
      }
    }
    for r in 0..<3 {
      for c in 0..<3 {
        XCTAssertEqual(m[r, c], 100*(Double(r)+1) + 10*(Double(c)+1))
      }
    }
  }

  func testSubscriptRowVector() {
    let v = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    let m = Matrix(v)
    for c in 0..<m.columns {
      XCTAssertEqual(m[c], v[c])
      XCTAssertEqual(m[c], m[0, c])
    }
  }

  func testSubscriptColumnVector() {
    let v = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    let m = Matrix(v, isColumnVector: true)
    for r in 0..<m.rows {
      XCTAssertEqual(m[r], v[r])
      XCTAssertEqual(m[r], m[r, 0])
    }
  }

  func testSubscriptRowGetter() {
    let a = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
    var m = Matrix(a)
    let M = copy(m)

    let r0 = m[row: 0]
    XCTAssertEqual(r0[0], 1.0)
    XCTAssertEqual(r0[1], 2.0)

    let r1 = m[row: 1]
    XCTAssertEqual(r1[0], 3.0)
    XCTAssertEqual(r1[1], 4.0)

    let r2 = m[row: 2]
    XCTAssertEqual(r2[0], 5.0)
    XCTAssertEqual(r2[1], 6.0)

    assertEqual(m, M)
  }

  func testSubscriptRowSetter() {
    let a = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
    var m = Matrix(a)

    m[row: 0] = Matrix([-1, -2])
    XCTAssertEqual(m[0, 0], -1.0)
    XCTAssertEqual(m[0, 1], -2.0)

    m[row: 1] = Matrix([-3, -4])
    XCTAssertEqual(m[1, 0], -3.0)
    XCTAssertEqual(m[1, 1], -4.0)

    m[row: 2] = Matrix([-5, -6])
    XCTAssertEqual(m[2, 0], -5.0)
    XCTAssertEqual(m[2, 1], -6.0)
  }

  func testSubscriptRowsGetter() {
    let a = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]]
    var m = Matrix(a)
    let M = copy(m)

    let r0 = m[rows: 0...0]
    XCTAssertEqual(r0.rows, 1)
    XCTAssertEqual(r0.columns, 3)
    XCTAssertEqual(r0[0, 0], 1.0)
    XCTAssertEqual(r0[0, 1], 2.0)
    XCTAssertEqual(r0[0, 2], 3.0)

    let r1 = m[rows: 0...1]
    XCTAssertEqual(r1.rows, 2)
    XCTAssertEqual(r1.columns, 3)
    XCTAssertEqual(r1[0, 0], 1.0)
    XCTAssertEqual(r1[0, 1], 2.0)
    XCTAssertEqual(r1[0, 2], 3.0)
    XCTAssertEqual(r1[1, 0], 4.0)
    XCTAssertEqual(r1[1, 1], 5.0)
    XCTAssertEqual(r1[1, 2], 6.0)

    let r2 = m[rows: 0...2]
    assertEqual(r2, m)

    let r3 = m[rows: 1...2]
    XCTAssertEqual(r3.rows, 2)
    XCTAssertEqual(r3.columns, 3)
    XCTAssertEqual(r3[0, 0], 4.0)
    XCTAssertEqual(r3[0, 1], 5.0)
    XCTAssertEqual(r3[0, 2], 6.0)
    XCTAssertEqual(r3[1, 0], 7.0)
    XCTAssertEqual(r3[1, 1], 8.0)
    XCTAssertEqual(r3[1, 2], 9.0)

    let r4 = m[rows: 2...2]
    XCTAssertEqual(r4.rows, 1)
    XCTAssertEqual(r4.columns, 3)
    XCTAssertEqual(r4[0, 0], 7.0)
    XCTAssertEqual(r4[0, 1], 8.0)
    XCTAssertEqual(r4[0, 2], 9.0)

    assertEqual(m, M)
  }

  func testSubscriptRowsSetter() {
    var m = Matrix([[1, 2, 3], [4, 5, 6], [7, 8, 9]])

    m[rows: 0...0] = Matrix([-1, -2, -3])
    assertEqual(m, Matrix([[-1, -2, -3], [4, 5, 6], [7, 8, 9]]))

    m[rows: 0...1] = Matrix([[10, 20, 30], [-4, -5, -6]])
    assertEqual(m, Matrix([[10, 20, 30], [-4, -5, -6], [7, 8, 9]]))

    m[rows: 0...2] = Matrix([[-10, -20, -30], [40, 50, 60], [-7, -8, -9]])
    assertEqual(m, Matrix([[-10, -20, -30], [40, 50, 60], [-7, -8, -9]]))

    m[rows: 1...2] = Matrix([[-40, -50, -60], [70, 80, 90]])
    assertEqual(m, Matrix([[-10, -20, -30], [-40, -50, -60], [70, 80, 90]]))

    m[rows: 2...2] = Matrix([-70, -80, -90])
    assertEqual(m, Matrix([[-10, -20, -30], [-40, -50, -60], [-70, -80, -90]]))
  }

  func testSubscriptColumnGetter() {
    let a = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
    var m = Matrix(a)
    let M = copy(m)

    let c0 = m[column: 0]
    XCTAssertEqual(c0[0], 1.0)
    XCTAssertEqual(c0[1], 3.0)
    XCTAssertEqual(c0[2], 5.0)

    let c1 = m[column: 1]
    XCTAssertEqual(c1[0], 2.0)
    XCTAssertEqual(c1[1], 4.0)
    XCTAssertEqual(c1[2], 6.0)

    assertEqual(m, M)
  }

  func testSubscriptColumnSetter() {
    let a = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
    var m = Matrix(a)

    m[column: 0] = Matrix([-1, -3, -5], isColumnVector: true)
    XCTAssertEqual(m[0, 0], -1.0)
    XCTAssertEqual(m[1, 0], -3.0)
    XCTAssertEqual(m[2, 0], -5.0)

    m[column: 1] = Matrix([-2, -4, -6], isColumnVector: true)
    XCTAssertEqual(m[0, 1], -2.0)
    XCTAssertEqual(m[1, 1], -4.0)
    XCTAssertEqual(m[2, 1], -6.0)
  }

  func testSubscriptColumnsGetter() {
    let a = [[1.0, 4.0, 7.0], [2.0, 5.0, 8.0], [3.0, 6.0, 9.0]]
    var m = Matrix(a)
    let M = copy(m)

    let r0 = m[columns: 0...0]
    XCTAssertEqual(r0.rows, 3)
    XCTAssertEqual(r0.columns, 1)
    XCTAssertEqual(r0[0, 0], 1.0)
    XCTAssertEqual(r0[1, 0], 2.0)
    XCTAssertEqual(r0[2, 0], 3.0)

    let r1 = m[columns: 0...1]
    XCTAssertEqual(r1.rows, 3)
    XCTAssertEqual(r1.columns, 2)
    XCTAssertEqual(r1[0, 0], 1.0)
    XCTAssertEqual(r1[1, 0], 2.0)
    XCTAssertEqual(r1[2, 0], 3.0)
    XCTAssertEqual(r1[0, 1], 4.0)
    XCTAssertEqual(r1[1, 1], 5.0)
    XCTAssertEqual(r1[2, 1], 6.0)

    let r2 = m[columns: 0...2]
    assertEqual(r2, m)

    let r3 = m[columns: 1...2]
    XCTAssertEqual(r3.rows, 3)
    XCTAssertEqual(r3.columns, 2)
    XCTAssertEqual(r3[0, 0], 4.0)
    XCTAssertEqual(r3[1, 0], 5.0)
    XCTAssertEqual(r3[2, 0], 6.0)
    XCTAssertEqual(r3[0, 1], 7.0)
    XCTAssertEqual(r3[1, 1], 8.0)
    XCTAssertEqual(r3[2, 1], 9.0)

    let r4 = m[columns: 2...2]
    XCTAssertEqual(r4.rows, 3)
    XCTAssertEqual(r4.columns, 1)
    XCTAssertEqual(r4[0, 0], 7.0)
    XCTAssertEqual(r4[1, 0], 8.0)
    XCTAssertEqual(r4[2, 0], 9.0)

    assertEqual(m, M)
  }

  func testSubscriptColumnsSetter() {
    var m = Matrix([[1, 4, 7], [2, 5, 8], [3, 6, 9]])

    m[columns: 0...0] = Matrix([[-1], [-2], [-3]])
    assertEqual(m, Matrix([[-1, 4, 7], [-2, 5, 8], [-3, 6, 9]]))

    m[columns: 0...1] = Matrix([[10, -4], [20, -5], [30, -6]])
    assertEqual(m, Matrix([[10, -4, 7], [20, -5, 8], [30, -6, 9]]))

    m[columns: 0...2] = Matrix([[-10, 40, -7], [-20, 50, -8], [-30, 60, -9]])
    assertEqual(m, Matrix([[-10, 40, -7], [-20, 50, -8], [-30, 60, -9]]))

    m[columns: 1...2] = Matrix([[-40, 70], [-50, 80], [-60, 90]])
    assertEqual(m, Matrix([[-10, -40, 70], [-20, -50, 80], [-30, -60, 90]]))

    m[columns: 2...2] = Matrix([[-70], [-80], [-90]])
    assertEqual(m, Matrix([[-10, -40, -70], [-20, -50, -80], [-30, -60, -90]]))
  }

  func testSubscriptScalar() {
    let a1 = [[7.0, 6.0], [5.0, 4.0], [3.0, 2.0]]
    let m1 = Matrix(a1)
    XCTAssertEqual(m1.value, a1[0][0])
    
    let a2 = [[9.0]]
    let m2 = Matrix(a2)
    XCTAssertEqual(m2.value, a2[0][0])
  }
}

// MARK: - Operations

extension MatrixTests {
  func testInverse() {
    let m = Matrix([[1, 2, 3], [0, 4, 0], [3, 2, 1]])
    let M = copy(m)

    let i = m.inverse()
    XCTAssertEqual(m.rows, i.rows)
    XCTAssertEqual(m.columns, i.columns)
    
    XCTAssertEqual(i[0, 0], -0.125)
    XCTAssertEqual(i[0, 1], -0.125)
    XCTAssertEqual(i[0, 2], 0.375)

    XCTAssertEqual(i[1, 0], 0)
    XCTAssertEqual(i[1, 1], 0.25)
    XCTAssertEqual(i[1, 2], 0)

    XCTAssertEqual(i[2, 0], 0.375)
    XCTAssertEqual(i[2, 1], -0.125)
    XCTAssertEqual(i[2, 2], -0.125)
    
    let o = i.inverse()
    assertEqual(m, o)

    // make sure accelerate framework magic didn't overwrite the original
    assertEqual(m, M)
  }

  func testInverseIdentityMatrix() {
    let m = Matrix.identity(size: 3)
    let i = m.inverse()
    assertEqual(m, i)
  }

  func testInverseSingularMatrix() {
    // Note: currently non-invertible matrices give an assertion.
    // Either trap that with a test (how?), or maybe return nil?
  }

  func testTranspose() {
    let m = Matrix([[1, 2], [3, 4], [5, 6]])
    let M = copy(m)

    let t = m.transpose()
    XCTAssertEqual(m.rows, t.columns)
    XCTAssertEqual(m.columns, t.rows)
    
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        XCTAssertEqual(m[r, c], t[c, r])
      }
    }
    
    let o = t.transpose()
    assertEqual(m, o)
    assertEqual(m, M)
  }
}

// MARK: - Arithmetic

extension MatrixTests {
  func testAddMatrixMatrix() {
    let a = Matrix([[ 1,  2], [ 3,  4], [ 5,  6]])
    let b = Matrix([[10, 20], [30, 40], [50, 60]])
    let c = Matrix([[11, 22], [33, 44], [55, 66]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a + b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testAddMatrixRowVector() {
    let a = Matrix([[10, 20], [30, 40], [50, 60]])
    let b = Matrix([5, 10])
    let c = Matrix([[15, 30], [35, 50], [55, 70]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a + b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testAddMatrixColumnVector() {
    let a = Matrix([[10, 20], [30, 40], [50, 60]])
    let b = Matrix([5, 10, 1], isColumnVector: true)
    let c = Matrix([[15, 25], [40, 50], [51, 61]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a + b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testAddMatrixScalar() {
    let a = Matrix([[ 1,  2], [ 3,  4], [ 5,  6]])
    let b = Matrix([[11, 12], [13, 14], [15, 16]])
    let A = copy(a)
    assertEqual(a + 10, b)
    assertEqual(10 + a, b)
    assertEqual(a, A)
  }

  func testSubtractMatrixMatrix() {
    let a = Matrix([[ 1,  2], [ 3,  4], [ 5,  6]])
    let b = Matrix([[10, 20], [30, 40], [50, 60]])
    let c = Matrix([[ 9, 18], [27, 36], [45, 54]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(b - a, c)
    assertEqual(a, A)
    assertEqual(b, B)
    let d = Matrix([[-9, -18], [-27, -36], [-45, -54]])
    assertEqual(a - b, d)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testSubtractMatrixRowVector() {
    let a = Matrix([[10, 20], [30, 40], [50, 60]])
    let b = Matrix([5, 10])
    let c = Matrix([[5, 10], [25, 30], [45, 50]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a - b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testSubtractMatrixColumnVector() {
    let a = Matrix([[10, 20], [30, 40], [50, 60]])
    let b = Matrix([5, 10, 1], isColumnVector: true)
    let c = Matrix([[5, 15], [20, 30], [49, 59]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a - b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testSubtractMatrixScalar() {
    let a = Matrix([[ 1,  2], [ 3,  4], [ 5,  6]])
    let b = Matrix([[11, 12], [13, 14], [15, 16]])
    let B = copy(b)
    assertEqual(b - 10, a)
    let c = Matrix([[-1, -2], [-3, -4], [-5, -6]])
    assertEqual(10 - b, c)
    assertEqual(b, B)
  }

  func testNegateMatrix() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([[-1, -2], [-3, -4], [-5, -6]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(-a, b)
    assertEqual(-b, a)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testMultiplyMatrixMatrix() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])    // 3x2
    let b = Matrix([[10], [20]])                // 2x1
    let c = Matrix([[50], [110], [170]])        // 3x1
    let A = copy(a)
    let B = copy(b)
    assertEqual(a <*> b, c)
    assertEqual(a, A)
    assertEqual(b, B)

    let d = Matrix([[10, 20, 30], [40, 50, 60]])                        // 2x3
    let e = Matrix([[90, 120, 150], [190, 260, 330], [290, 400, 510]])  // 3x3
    let f = Matrix([[220, 280], [490, 640]])                            // 2x2
    let D = d
    assertEqual(a <*> d, e)
    assertEqual(d <*> a, f)
    assertEqual(a, A)
    assertEqual(d, D)
    
    let i = Matrix.identity(size: 2)    // 2x2
    let j = Matrix.identity(size: 3)    // 3x3
    assertEqual(a <*> i, a)
    assertEqual(j <*> a, a)
  }

  func testMultiplyMatrixMatrixElementwise() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([[10, 20], [30, 40], [50, 60]])
    let c = Matrix([[10, 40], [90, 160], [250, 360]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a * b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testMultiplyMatrixRowVector() {
    let a = Matrix([[2, 5], [6, 10], [12, 20]])
    let b = Matrix([5, 4])
    let c = Matrix([[10, 20], [30, 40], [60, 80]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a * b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testMultiplyMatrixColumnVector() {
    let a = Matrix([[2, 4], [2, 3], [6, 8]])
    let b = Matrix([5, 15, 10], isColumnVector: true)
    let c = Matrix([[10, 20], [30, 45], [60, 80]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a * b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testMultiplyMatrixScalar() {
    let a = Matrix([[ 1,  2], [ 3,  4], [ 5,  6]])
    let b = Matrix([[10, 20], [30, 40], [50, 60]])
    let A = copy(a)
    assertEqual(a * 10, b)
    assertEqual(10 * a, b)
    assertEqual(a, A)
  }
  
  func testDivideMatrixMatrix() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])     // 3x2
    let b = Matrix([[5, 6], [7, 8]])             // 2x2
    let c = Matrix([[3, -2], [2, -1], [1, 0]])   // 3x2
    let A = copy(a)
    let B = copy(b)
    assertEqual(a </> b, c, accuracy: 1e-10)
    assertEqual(a <*> b.inverse(), c, accuracy: 1e-10)
    assertEqual(a, A)
    assertEqual(b, B)

    let i = Matrix.identity(size: 2)    // 2x2
    assertEqual(a </> i, a)
  }

  func testDivideMatrixMatrixElementwise() {
    let a = Matrix([[10, 40], [90, 160], [250, 360]])
    let b = Matrix([[10, 20], [30, 40], [50, 60]])
    let c = Matrix([[1, 2], [3, 4], [5, 6]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a / b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testDivideMatrixRowVector() {
    let a = Matrix([[10, 20], [30, 40], [60, 80]])
    let b = Matrix([5, 4])
    let c = Matrix([[2, 5], [6, 10], [12, 20]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a / b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testDivideMatrixColumnVector() {
    let a = Matrix([[10, 20], [30, 45], [60, 80]])
    let b = Matrix([5, 15, 10], isColumnVector: true)
    let c = Matrix([[2, 4], [2, 3], [6, 8]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a / b, c)
    assertEqual(a, A)
    assertEqual(b, B)
  }

  func testDivideMatrixScalar() {
    let a = Matrix([[ 1,  2], [ 3,  4], [ 5,  6]])
    let b = Matrix([[10, 20], [30, 40], [50, 60]])
    let c = Matrix([[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]])
    let A = copy(a)
    let B = copy(b)
    assertEqual(a / 10, c, accuracy: 1e-10)
    assertEqual(b / 10, a)
    assertEqual(a, A)
    assertEqual(b, B)

    let d = Matrix([[10, 5], [10/3, 2.5], [2, 10/6]])
    assertEqual(10 / a, d, accuracy: 1e-10)
  }
}

// MARK: - Other maths

extension MatrixTests {
  func testExp() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([[2.7182818285, 7.3890560989], [20.0855369232, 54.5981500331], [148.4131591026, 403.4287934927]])
    let A = copy(a)
    assertEqual(a.exp(), b, accuracy: 1e-10)
    assertEqual(a, A)
  }

  func testLog() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([[0.0000000000, 0.6931471806], [1.0986122887, 1.3862943611], [1.6094379124, 1.7917594692]])
    let A = copy(a)
    assertEqual(a.log(), b, accuracy: 1e-10)
    assertEqual(a, A)
  }

  func testPow() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([[1, 4], [9, 16], [25, 36]])
    let c = Matrix([[1.0000000000, 1.4142135624], [1.7320508076, 2.0000000000], [2.2360679775, 2.4494897428]])
    let A = copy(a)
    assertEqual(a.pow(2), b, accuracy: 1e-10)
    assertEqual(a.pow(0.5), c, accuracy: 1e-10)
    assertEqual(a, A)
  }
  
  func testSqrt() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([[1, 4], [9, 16], [25, 36]])
    let A = copy(a)
    assertEqual(b.sqrt(), a, accuracy: 1e-10)
    assertEqual(a.sqrt(), a.pow(0.5), accuracy: 1e-10)
    assertEqual(a, A)
  }

  func testSumAll() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let A = copy(a)
    XCTAssertEqual(a.sum(), 21)
    assertEqual(a, A)

    let b = Matrix([[-1, -2], [-3, -4], [-5, -6]])
    XCTAssertEqual(b.sum(), -21)
    
    let i = Matrix.identity(size: 10)
    XCTAssertEqual(i.sum(), 10)
    
    let z = Matrix.zeros(rows: 10, columns: 20)
    XCTAssertEqual(z.sum(), 0)

    let o = Matrix.ones(rows: 50, columns: 50)
    XCTAssertEqual(o.sum(), 2500)
  }
  
  func testSumRows() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([3, 7, 11], isColumnVector: true)
    let A = copy(a)
    assertEqual(a.sumRows(), b)
    assertEqual(a, A)
  }

  func testSumColumns() {
    let a = Matrix([[1, 2], [3, 4], [5, 6]])
    let b = Matrix([9, 12])
    let A = copy(a)
    assertEqual(a.sumColumns(), b)
    assertEqual(a, A)
  }
}

// MARK: - Minimum and maximum

extension MatrixTests {
  func testMinRow() {
    let a = Matrix([[19, 7, 21], [3, 40, 15], [5, 4, -1]])
    let A = copy(a)

    let r0 = a.min(row: 0)
    XCTAssertEqual(r0.0, 7)
    XCTAssertEqual(r0.1, 1)

    let r1 = a.min(row: 1)
    XCTAssertEqual(r1.0, 3)
    XCTAssertEqual(r1.1, 0)

    let r2 = a.min(row: 2)
    XCTAssertEqual(r2.0, -1)
    XCTAssertEqual(r2.1, 2)

    assertEqual(a, A)
  }

  func testMaxRow() {
    let a = Matrix([[19, 7, 21], [3, 40, 15], [5, 4, -1]])
    let A = copy(a)

    let r0 = a.max(row: 0)
    XCTAssertEqual(r0.0, 21)
    XCTAssertEqual(r0.1, 2)

    let r1 = a.max(row: 1)
    XCTAssertEqual(r1.0, 40)
    XCTAssertEqual(r1.1, 1)

    let r2 = a.max(row: 2)
    XCTAssertEqual(r2.0, 5)
    XCTAssertEqual(r2.1, 0)
  
    assertEqual(a, A)
  }

  func testMinRows() {
    let a = Matrix([[19, 7, 21], [3, 40, 15], [5, 4, -1]])
    let b = Matrix([7, 3, -1], isColumnVector: true)
    let A = copy(a)
    assertEqual(a.minRows(), b)
    assertEqual(a, A)
  }

  func testMaxRows() {
    let a = Matrix([[19, 7, 21], [3, 40, 15], [5, 4, -1]])
    let b = Matrix([21, 40, 5], isColumnVector: true)
    let A = copy(a)
    assertEqual(a.maxRows(), b)
    assertEqual(a, A)
  }

  func testMinColumn() {
    let a = Matrix([[19, 7, -1], [3, 40, 15], [5, 4, 21]])
    let A = copy(a)

    let r0 = a.min(column: 0)
    XCTAssertEqual(r0.0, 3)
    XCTAssertEqual(r0.1, 1)

    let r1 = a.min(column: 1)
    XCTAssertEqual(r1.0, 4)
    XCTAssertEqual(r1.1, 2)

    let r2 = a.min(column: 2)
    XCTAssertEqual(r2.0, -1)
    XCTAssertEqual(r2.1, 0)

    assertEqual(a, A)
  }

  func testMaxColumn() {
    let a = Matrix([[19, 7, -1], [3, 40, 15], [5, 4, 21]])
    let A = copy(a)

    let r0 = a.max(column: 0)
    XCTAssertEqual(r0.0, 19)
    XCTAssertEqual(r0.1, 0)

    let r1 = a.max(column: 1)
    XCTAssertEqual(r1.0, 40)
    XCTAssertEqual(r1.1, 1)

    let r2 = a.max(column: 2)
    XCTAssertEqual(r2.0, 21)
    XCTAssertEqual(r2.1, 2)

    assertEqual(a, A)
  }

  func testMinColumns() {
    let a = Matrix([[19, 7, -1], [3, 40, 15], [5, 4, 21]])
    let b = Matrix([3, 4, -1])
    let A = copy(a)
    assertEqual(a.minColumns(), b)
    assertEqual(a, A)
  }

  func testMaxColumns() {
    let a = Matrix([[19, 7, -1], [3, 40, 15], [5, 4, 21]])
    let b = Matrix([19, 40, 21])
    let A = copy(a)
    assertEqual(a.maxColumns(), b)
    assertEqual(a, A)
  }

  func testMin() {
    let a = Matrix([[19, 7, 15], [3, 40, -1], [5, 4, 21]])
    let A = copy(a)
    let r = a.min()
    XCTAssertEqual(r.0, -1)
    XCTAssertEqual(r.1, 1)
    XCTAssertEqual(r.2, 2)
    assertEqual(a, A)
  }

  func testMax() {
    let a = Matrix([[19, 7, -1], [3, 4, 15], [5, 40, 21]])
    let A = copy(a)
    let r = a.max()
    XCTAssertEqual(r.0, 40)
    XCTAssertEqual(r.1, 2)
    XCTAssertEqual(r.2, 1)
    assertEqual(a, A)
  }
}

// MARK: - Statistics

extension MatrixTests {
  func testMean() {
    let a = Matrix([[19, 7, -1], [3, 40, 15], [5, 4, 22]])
    let A = copy(a)
    assertEqual(a.mean(), [9, 17, 12])
    assertEqual(a.mean(0...0), [9, 0, 0])
    assertEqual(a.mean(1...1), [0, 17, 0])
    assertEqual(a.mean(2...2), [0, 0, 12])
    assertEqual(a.mean(0...1), [9, 17, 0])
    assertEqual(a.mean(1...2), [0, 17, 12])
    assertEqual(a.mean(0...2), [9, 17, 12])
    assertEqual(a, A)
  }

  func testStandardDeviation() {
    let a = Matrix([[19, 7, -1], [3, 40, 15], [5, 4, 22]])
    let A = copy(a)
    assertEqual(a.std(), [8.7177978871, 19.9749843554, 11.7898261226], accuracy: 1e-10)
    assertEqual(a, A)
  }
}
