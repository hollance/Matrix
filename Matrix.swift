// Matrix.swift
//
// Copyright (c) 2016 Matthijs Hollemans
// Copyright (c) 2014-2015 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import Accelerate

public struct Matrix {
  public let rows: Int
  public let columns: Int
  var grid: [Double]
}

// MARK: - Creating matrices

extension Matrix {
  public init(rows: Int, columns: Int, repeatedValue: Double) {
    self.rows = rows
    self.columns = columns
    self.grid = .init(repeating: repeatedValue, count: rows * columns)
  }

  public init(size: (Int, Int), repeatedValue: Double) {
    self.init(rows: size.0, columns: size.1, repeatedValue: repeatedValue)
  }

  /* Creates a matrix from an array: [[a, b], [c, d], [e, f]]. */
  public init(_ data: [[Double]]) {
    self.init(data, range: 0..<data[0].count)
  }

  /* Extracts one or more columns into a new matrix. */
  public init(_ data: [[Double]], range: CountableRange<Int>) {
    let m = data.count
    let n = range.upperBound - range.lowerBound
    self.init(rows: m, columns: n, repeatedValue: 0)

    /*
    for (i, row) in data.enumerate() {
      for j in range {
        self[i, j - range.startIndex] = row[j]
      }
    }
    */

    for (i, row) in data.enumerated() {
      row.withUnsafeBufferPointer { src in
        cblas_dcopy(Int32(n), src.baseAddress! + range.lowerBound, 1, &grid + i*columns, 1)
      }
    }
  }

  public init(_ data: [[Double]], range: CountableClosedRange<Int>) {
    self.init(data, range: CountableRange(range))
  }

  /* Creates a matrix from a row vector or column vector. */
  public init(_ contents: [Double], isColumnVector: Bool = false) {
    if isColumnVector {
      self.rows = contents.count
      self.columns = 1
    } else {
      self.rows = 1
      self.columns = contents.count
    }
    self.grid = contents
  }

  /* Creates a matrix containing the numbers in the specified range. */
  public init(_ range: CountableRange<Int>, isColumnVector: Bool = false) {
    if isColumnVector {
      self.init(rows: 1, columns: range.upperBound - range.lowerBound, repeatedValue: 0)
      for c in range {
        self[0, c - range.lowerBound] = Double(c)
      }
    } else {
      self.init(rows: range.upperBound - range.lowerBound, columns: 1, repeatedValue: 0)
      for r in range {
        self[r - range.lowerBound, 0] = Double(r)
      }
    }
  }

  public init(_ range: CountableClosedRange<Int>, isColumnVector: Bool = false) {
    self.init(CountableRange(range), isColumnVector: isColumnVector)
  }
}

extension Matrix {
  /* Creates a matrix where each element is 0. */
  public static func zeros(rows: Int, columns: Int) -> Matrix {
    return Matrix(rows: rows, columns: columns, repeatedValue: 0)
  }

  public static func zeros(size: (Int, Int)) -> Matrix {
    return Matrix(size: size, repeatedValue: 0)
  }

  /* Creates a matrix where each element is 1. */
  public static func ones(rows: Int, columns: Int) -> Matrix {
    return Matrix(rows: rows, columns: columns, repeatedValue: 1)
  }

  public static func ones(size: (Int, Int)) -> Matrix {
    return Matrix(size: size, repeatedValue: 1)
  }

  /* Creates a (square) identity matrix. */
  public static func identity(size: Int) -> Matrix {
    var m = zeros(rows: size, columns: size)
    for i in 0..<size { m[i, i] = 1 }
    return m
  }

  /* Creates a matrix of random values between 0.0 and 1.0 (inclusive). */
  public static func random(rows: Int, columns: Int) -> Matrix {
    var m = zeros(rows: rows, columns: columns)
    for r in 0..<rows {
      for c in 0..<columns {
        m[r, c] = Double(arc4random()) / 0xffffffff
      }
    }
    return m
  }
}

extension Matrix: ExpressibleByArrayLiteral {
  /* Array literals are interpreted as row vectors. */
  public init(arrayLiteral: Double...) {
    self.rows = 1
    self.columns = arrayLiteral.count
    self.grid = arrayLiteral
  }
}

extension Matrix {
  /* Duplicates a row vector across "d" rows. */
  public func tile(_ d: Int) -> Matrix {
    precondition(rows == 1)
    var m = Matrix.zeros(rows: d, columns: columns)

    /*
    for r in 0..<d {
      for c in 0..<columns {
        m[r, c] = self[0, c]
      }
    }
    */

    grid.withUnsafeBufferPointer { src in
      m.grid.withUnsafeMutableBufferPointer { dst in
        for i in 0..<d {
          // Alternatively, use memcpy instead of BLAS.
          //memcpy(ptr, src.baseAddress, columns * MemoryLayout<Double>.stride)

          cblas_dcopy(Int32(columns), src.baseAddress, 1, dst.baseAddress?.advanced(by: columns * i), 1)
        }
      }
    }
    return m
  }
}

extension Matrix {
  /* Copies the contents of an NSData object into the matrix. */
  public init(rows: Int, columns: Int, data: NSData) {
    precondition(data.length >= rows * columns * MemoryLayout<Double>.stride)
    self.init(rows: rows, columns: columns, repeatedValue: 0)

    grid.withUnsafeMutableBufferPointer { dst in
      let src = UnsafePointer<Double>(OpaquePointer(data.bytes))
      cblas_dcopy(Int32(rows * columns), src, 1, dst.baseAddress, 1)
    }
  }

  /* Copies the contents of the matrix into an NSData object. */
  public var data: NSData? {
    if let data = NSMutableData(length: rows * columns * MemoryLayout<Double>.stride) {
      grid.withUnsafeBufferPointer { src in
        let dst = UnsafeMutablePointer<Double>(OpaquePointer(data.bytes))
        cblas_dcopy(Int32(rows * columns), src.baseAddress, 1, dst, 1)
      }
      return data
    } else {
      return nil
    }
  }
}

// MARK: - Querying the matrix

extension Matrix {
  public var size: (Int, Int) {
    return (rows, columns)
  }

  /* Returns the total number of elements in the matrix. */
  public var count: Int {
    return rows * columns
  }

  /* Returns the largest dimension. */
  public var length: Int {
    return Swift.max(rows, columns)
  }

  public subscript(row: Int, column: Int) -> Double {
    get { return grid[(row * columns) + column] }
    set { grid[(row * columns) + column] = newValue }
  }

  /* Subscript for when the matrix is a row or column vector. */
  public subscript(i: Int) -> Double {
    get {
      precondition(rows == 1 || columns == 1, "Not a row or column vector")
      return grid[i]
    }
    set {
      precondition(rows == 1 || columns == 1, "Not a row or column vector")
      grid[i] = newValue
    }
  }

  /* Get or set an entire row. */
  public subscript(row r: Int) -> Matrix {
    get {
      var v = Matrix.zeros(rows: 1, columns: columns)

      /*
      for c in 0..<columns {
        m[c] = self[r, c]
      }
      */

      grid.withUnsafeBufferPointer { src in
        v.grid.withUnsafeMutableBufferPointer { dst in
          cblas_dcopy(Int32(columns), src.baseAddress! + r*columns, 1, dst.baseAddress, 1)
        }
      }
      return v
    }
    set(v) {
      precondition(v.rows == 1 && v.columns == columns, "Not a compatible row vector")

      /*
      for c in 0..<columns {
        self[r, c] = v[c]
      }
      */
      
      v.grid.withUnsafeBufferPointer { src in
        cblas_dcopy(Int32(columns), src.baseAddress, 1, &grid + r*columns, 1)
      }
    }
  }

  /* Get or set multiple rows. */
  public subscript(rows range: CountableRange<Int>) -> Matrix {
    get {
      precondition(range.upperBound <= rows, "Invalid range")

      var m = Matrix.zeros(rows: range.upperBound - range.lowerBound, columns: columns)
      for r in range {
        for c in 0..<columns {
          m[r - range.lowerBound, c] = self[r, c]
        }
      }
      return m
    }
    set(m) {
      precondition(range.upperBound <= rows, "Invalid range")

      for r in range {
        for c in 0..<columns {
          self[r, c] = m[r - range.lowerBound, c]
        }
      }
    }
  }

  public subscript(rows range: CountableClosedRange<Int>) -> Matrix {
    get {
      return self[rows: CountableRange(range)]
    }
    set(m) {
      self[rows: CountableRange(range)] = m
    }
  }

  /* Gets just the rows specified, in that order. */
  public subscript(rows rowIndices: [Int]) -> Matrix {
    var m = Matrix.zeros(rows: rowIndices.count, columns: columns)

    /*
    for (i, r) in rowIndices.enumerate() {
      for c in 0..<columns {
        m[i, c] = self[r, c]
      }
    }
    */

    grid.withUnsafeBufferPointer { src in
      m.grid.withUnsafeMutableBufferPointer { dst in
        for (i, r) in rowIndices.enumerated() {
          cblas_dcopy(Int32(columns), src.baseAddress! + r*columns, 1, dst.baseAddress! + i*columns, 1)
        }
      }
    }
    return m
  }

  /* Get or set an entire column. */
  public subscript(column c: Int) -> Matrix {
    get {
      var v = Matrix.zeros(rows: rows, columns: 1)

      /*
      for r in 0..<rows {
        m[r] = self[r, c]
      }
      */

      grid.withUnsafeBufferPointer { src in
        v.grid.withUnsafeMutableBufferPointer { dst in
          cblas_dcopy(Int32(rows), src.baseAddress! + c, Int32(columns), dst.baseAddress, 1)
        }
      }
      return v
    }
    set(v) {
      precondition(v.rows == rows && v.columns == 1, "Not a compatible column vector")
      
      /*
      for r in 0..<rows {
        self[r, c] = v[r]
      }
      */
      
      v.grid.withUnsafeBufferPointer { src in
        cblas_dcopy(Int32(rows), src.baseAddress, 1, &grid + c, Int32(columns))
      }
    }
  }

  /* Get or set multiple columns. */
  public subscript(columns range: CountableRange<Int>) -> Matrix {
    get {
      precondition(range.upperBound <= columns, "Invalid range")

      var m = Matrix.zeros(rows: rows, columns: range.upperBound - range.lowerBound)
      for r in 0..<rows {
        for c in range {
          m[r, c - range.lowerBound] = self[r, c]
        }
      }
      return m
    }
    set(m) {
      precondition(range.upperBound <= columns, "Invalid range")

      for r in 0..<rows {
        for c in range {
          self[r, c] = m[r, c - range.lowerBound]
        }
      }
    }
  }

  public subscript(columns range: CountableClosedRange<Int>) -> Matrix {
    get {
      return self[columns: CountableRange(range)]
    }
    set(m) {
      self[columns: CountableRange(range)] = m
    }
  }

  /* Useful for when the matrix is 1x1 or you want to get the first element. */
  public var scalar: Double {
    return grid[0]
  }

  /* Converts the matrix into a 2-dimensional array. */
  public var array: [[Double]] {
    var a = [[Double]](repeating: [Double](repeating: 0, count: columns), count: rows)
    for r in 0..<rows {
      for c in 0..<columns {
        a[r][c] = self[r, c]
      }
    }
    return a
  }
}

// MARK: - Printable

extension Matrix: CustomStringConvertible {
  public var description: String {
    var description = ""

    for i in 0..<rows {
      let contents = (0..<columns).map{ String(format: "%20.10f", self[i, $0]) }.joined(separator: " ")

      switch (i, rows) {
      case (0, 1):
        description += "( \(contents) )\n"
      case (0, _):
        description += "⎛ \(contents) ⎞\n"
      case (rows - 1, _):
        description += "⎝ \(contents) ⎠\n"
      default:
        description += "⎜ \(contents) ⎥\n"
      }
    }
    return description
  }
}

// MARK: - SequenceType

/* Lets you iterate through the rows of the matrix. */
extension Matrix: Sequence {
  public func makeIterator() -> AnyIterator<ArraySlice<Double>> {
    let endIndex = rows * columns
    var nextRowStartIndex = 0
    return AnyIterator {
      if nextRowStartIndex == endIndex {
        return nil
      } else {
        let currentRowStartIndex = nextRowStartIndex
        nextRowStartIndex += self.columns
        return self.grid[currentRowStartIndex..<nextRowStartIndex]
      }
    }
  }
}

// MARK: - Operations

extension Matrix {
  public func inverse() -> Matrix {
    precondition(rows == columns, "Matrix must be square")

    var results = self
    results.grid.withUnsafeMutableBufferPointer { ptr in
      var ipiv = [__CLPK_integer](repeating: 0, count: rows * rows)
      var lwork = __CLPK_integer(columns * columns)
      var work = [CDouble](repeating: 0, count: Int(lwork))
      var error: __CLPK_integer = 0
      var nc = __CLPK_integer(columns)
      var m = nc
      var n = nc

      dgetrf_(&m, &n, ptr.baseAddress, &nc, &ipiv, &error)
      dgetri_(&m, ptr.baseAddress, &nc, &ipiv, &work, &lwork, &error)

      assert(error == 0, "Matrix not invertible")
    }
    return results
  }
}

extension Matrix {
  public func transpose() -> Matrix {
    var results = Matrix(rows: columns, columns: rows, repeatedValue: 0)
    grid.withUnsafeBufferPointer { srcPtr in
      vDSP_mtransD(srcPtr.baseAddress!, 1, &results.grid, 1, vDSP_Length(results.rows), vDSP_Length(results.columns))
    }
    return results
  }
}

postfix operator ′
public postfix func ′ (value: Matrix) -> Matrix {
  return value.transpose()
}

// MARK: - Arithmetic

/*
 Element-by-element addition.

 Either:
 - both matrices have the same size
 - rhs is a row vector with an equal number of columns as lhs
 - rhs is a column vector with an equal number of rows as lhs
 */
public func + (lhs: Matrix, rhs: Matrix) -> Matrix {
  if lhs.columns == rhs.columns {
    if rhs.rows == 1 {   // rhs is row vector
      /*
      var results = lhs
      for r in 0..<results.rows {
        for c in 0..<results.columns {
          results[r, c] += rhs[0, c]
        }
      }
      return results
      */

      var results = Matrix.zeros(size: lhs.size)
      lhs.grid.withUnsafeBufferPointer{ src in
        results.grid.withUnsafeMutableBufferPointer{ dst in
          for c in 0..<lhs.columns {
            var v = rhs[c]
            vDSP_vsaddD(src.baseAddress! + c, lhs.columns, &v, dst.baseAddress! + c, lhs.columns, vDSP_Length(lhs.rows))
          }
        }
      }
      return results

    } else if lhs.rows == rhs.rows {   // lhs and rhs are same size
      var results = rhs
      lhs.grid.withUnsafeBufferPointer { lhsPtr in
        results.grid.withUnsafeMutableBufferPointer { resultsPtr in
          cblas_daxpy(Int32(lhs.grid.count), 1, lhsPtr.baseAddress, 1, resultsPtr.baseAddress, 1)
        }
      }
      return results
    }
  } else if lhs.rows == rhs.rows && rhs.columns == 1 {  // rhs is column vector
    /*
    var results = lhs
    for c in 0..<results.columns {
      for r in 0..<results.rows {
        results[r, c] += rhs[r, 0]
      }
    }
    return results
    */

    var results = Matrix.zeros(size: lhs.size)
    lhs.grid.withUnsafeBufferPointer{ src in
      results.grid.withUnsafeMutableBufferPointer{ dst in
        for r in 0..<lhs.rows {
          var v = rhs[r]
          vDSP_vsaddD(src.baseAddress! + r*lhs.columns, 1, &v, dst.baseAddress! + r*lhs.columns, 1, vDSP_Length(lhs.columns))
        }
      }
    }
    return results
  }

  fatalError("Cannot add \(lhs.rows)×\(lhs.columns) matrix and \(rhs.rows)×\(rhs.columns) matrix")
}

public func += (lhs: inout Matrix, rhs: Matrix) {
  lhs = lhs + rhs
}

/* Adds a scalar to each element of the matrix. */
public func + (lhs: Matrix, rhs: Double) -> Matrix {
  /*
  var m = lhs
  for r in 0..<m.rows {
    for c in 0..<m.columns {
      m[r, c] += rhs
    }
  }
  return m
  */

  var results = lhs
  lhs.grid.withUnsafeBufferPointer { src in
    results.grid.withUnsafeMutableBufferPointer { dst in
      var scalar = rhs
      vDSP_vsaddD(src.baseAddress!, 1, &scalar, dst.baseAddress!, 1, vDSP_Length(lhs.rows * lhs.columns))
    }
  }
  return results
}

public func += (lhs: inout Matrix, rhs: Double) {
  lhs = lhs + rhs
}

/* Adds a scalar to each element of the matrix. */
public func + (lhs: Double, rhs: Matrix) -> Matrix {
  return rhs + lhs
}

/*
 Element-by-element subtraction.

 Either:
 - both matrices have the same size
 - rhs is a row vector with an equal number of columns as lhs
 - rhs is a column vector with an equal number of rows as lhs
 */
public func - (lhs: Matrix, rhs: Matrix) -> Matrix {
  if lhs.columns == rhs.columns {
    if rhs.rows == 1 {   // rhs is row vector
      /*
      var results = lhs
      for r in 0..<results.rows {
        for c in 0..<results.columns {
          results[r, c] -= rhs[0, c]
        }
      }
      return results
      */

      var results = Matrix.zeros(size: lhs.size)
      lhs.grid.withUnsafeBufferPointer{ src in
        results.grid.withUnsafeMutableBufferPointer{ dst in
          for c in 0..<lhs.columns {
            var v = -rhs[c]
            vDSP_vsaddD(src.baseAddress! + c, lhs.columns, &v, dst.baseAddress! + c, lhs.columns, vDSP_Length(lhs.rows))
          }
        }
      }
      return results

    } else if lhs.rows == rhs.rows {   // lhs and rhs are same size
      var results = lhs
      rhs.grid.withUnsafeBufferPointer { rhsPtr in
        results.grid.withUnsafeMutableBufferPointer { resultsPtr in
          cblas_daxpy(Int32(rhs.grid.count), -1, rhsPtr.baseAddress, 1, resultsPtr.baseAddress, 1)
        }
      }
      return results
    }

  } else if lhs.rows == rhs.rows && rhs.columns == 1 {  // rhs is column vector
    /*
    var results = lhs
    for c in 0..<results.columns {
      for r in 0..<results.rows {
        results[r, c] -= rhs[r, 0]
      }
    }
    return results
    */

    var results = Matrix.zeros(size: lhs.size)
    lhs.grid.withUnsafeBufferPointer{ src in
      results.grid.withUnsafeMutableBufferPointer{ dst in
        for r in 0..<lhs.rows {
          var v = -rhs[r]
          vDSP_vsaddD(src.baseAddress! + r*lhs.columns, 1, &v, dst.baseAddress! + r*lhs.columns, 1, vDSP_Length(lhs.columns))
        }
      }
    }
    return results
  }

  fatalError("Cannot subtract \(lhs.rows)×\(lhs.columns) matrix and \(rhs.rows)×\(rhs.columns) matrix")
}

public func -= (lhs: inout Matrix, rhs: Matrix) {
  lhs = lhs - rhs
}

/* Subtracts a scalar from each element of the matrix. */
public func - (lhs: Matrix, rhs: Double) -> Matrix {
  return lhs + (-rhs)
}

public func -= (lhs: inout Matrix, rhs: Double) {
  lhs = lhs - rhs
}

/* Subtracts each element of the matrix from a scalar. */
public func - (lhs: Double, rhs: Matrix) -> Matrix {
  /*
  var m = rhs
  for r in 0..<m.rows {
    for c in 0..<m.columns {
      m[r, c] = lhs - rhs[r, c]
    }
  }
  return m
  */

  var results = rhs
  var scalar = lhs
  let length = vDSP_Length(rhs.rows * rhs.columns)
  results.grid.withUnsafeMutableBufferPointer { ptr in
    vDSP_vnegD(ptr.baseAddress!, 1, ptr.baseAddress!, 1, length)
    vDSP_vsaddD(ptr.baseAddress!, 1, &scalar, ptr.baseAddress!, 1, length)
  }
  return results
}

/* Negates each element of the matrix. */
prefix public func -(m: Matrix) -> Matrix {
  /*
  var results = m
  for r in 0..<m.rows {
    for c in 0..<m.columns {
      results[r, c] = -m[r, c]
    }
  }
  return results
  */

  var results = m
  m.grid.withUnsafeBufferPointer { src in
    results.grid.withUnsafeMutableBufferPointer { dst in
      vDSP_vnegD(src.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(m.rows * m.columns))
    }
  }
  return results
}

infix operator <*> : MultiplicationPrecedence

/* Multiplies two matrices, or a matrix with a vector. */
public func <*> (lhs: Matrix, rhs: Matrix) -> Matrix {
  precondition(lhs.columns == rhs.rows, "Cannot multiply \(lhs.rows)×\(lhs.columns) matrix and \(rhs.rows)×\(rhs.columns) matrix")

  var results = Matrix(rows: lhs.rows, columns: rhs.columns, repeatedValue: 0)
  lhs.grid.withUnsafeBufferPointer { lhsPtr in
    rhs.grid.withUnsafeBufferPointer { rhsPtr in
      cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(lhs.rows), Int32(rhs.columns), Int32(lhs.columns), 1, lhsPtr.baseAddress, Int32(lhs.columns), rhsPtr.baseAddress, Int32(rhs.columns), 0, &results.grid, Int32(results.columns))
    }
  }
  return results
}

/*
 Multiplies each element of the lhs matrix by each element of the rhs matrix.

 Either:
 - both matrices have the same size
 - rhs is a row vector with an equal number of columns as lhs
 - rhs is a column vector with an equal number of rows as lhs
 */
public func * (lhs: Matrix, rhs: Matrix) -> Matrix {
  if lhs.columns == rhs.columns {
    if rhs.rows == 1 {   // rhs is row vector
      /*
      var results = lhs
      for r in 0..<results.rows {
        for c in 0..<results.columns {
          results[r, c] *= rhs[0, c]
        }
      }
      return results
      */

      var results = Matrix.zeros(size: lhs.size)
      lhs.grid.withUnsafeBufferPointer{ src in
        results.grid.withUnsafeMutableBufferPointer{ dst in
          for c in 0..<lhs.columns {
            var v = rhs[c]
            vDSP_vsmulD(src.baseAddress! + c, lhs.columns, &v, dst.baseAddress! + c, lhs.columns, vDSP_Length(lhs.rows))
          }
        }
      }
      return results

    } else if lhs.rows == rhs.rows {   // lhs and rhs are same size
      /*
      var results = lhs
      for r in 0..<results.rows {
        for c in 0..<results.columns {
          results[r, c] *= rhs[r, c]
        }
      }
      return results
      */

      var results = Matrix.zeros(size: lhs.size)
      rhs.grid.withUnsafeBufferPointer{ srcX in
        lhs.grid.withUnsafeBufferPointer{ srcY in
          results.grid.withUnsafeMutableBufferPointer{ dstZ in
            vDSP_vmulD(srcX.baseAddress!, 1, srcY.baseAddress!, 1, dstZ.baseAddress!, 1, vDSP_Length(lhs.rows * lhs.columns))
          }
        }
      }
      return results
    }

  } else if lhs.rows == rhs.rows && rhs.columns == 1 {  // rhs is column vector
    /*
    var results = lhs
    for c in 0..<results.columns {
      for r in 0..<results.rows {
        results[r, c] *= rhs[r, 0]
      }
    }
    return results
    */

    var results = Matrix.zeros(size: lhs.size)
    lhs.grid.withUnsafeBufferPointer{ src in
      results.grid.withUnsafeMutableBufferPointer{ dst in
        for r in 0..<lhs.rows {
          var v = rhs[r]
          vDSP_vsmulD(src.baseAddress! + r*lhs.columns, 1, &v, dst.baseAddress! + r*lhs.columns, 1, vDSP_Length(lhs.columns))
        }
      }
    }
    return results
  }

  fatalError("Cannot element-wise multiply \(lhs.rows)×\(lhs.columns) matrix and \(rhs.rows)×\(rhs.columns) matrix")
}

/* Multiplies each element of the matrix with a scalar. */
public func * (lhs: Matrix, rhs: Double) -> Matrix {
  var results = lhs
  results.grid.withUnsafeMutableBufferPointer { ptr in
    cblas_dscal(Int32(lhs.grid.count), rhs, ptr.baseAddress, 1)
  }
  return results
}

/* Multiplies each element of the matrix with a scalar. */
public func * (lhs: Double, rhs: Matrix) -> Matrix {
  return rhs * lhs
}

infix operator </> : MultiplicationPrecedence

/* Divides a matrix by another. This is the same as multiplying with the inverse. */
public func </> (lhs: Matrix, rhs: Matrix) -> Matrix {
  let inv = rhs.inverse()
  precondition(lhs.columns == inv.rows, "Cannot divide \(lhs.rows)×\(lhs.columns) matrix and \(rhs.rows)×\(rhs.columns) matrix")
  return lhs <*> inv
}

/*
 Divides each element of the lhs matrix by each element of the rhs matrix.

 Either:
 - both matrices have the same size
 - rhs is a row vector with an equal number of columns as lhs
 - rhs is a column vector with an equal number of rows as lhs
 */
public func / (lhs: Matrix, rhs: Matrix) -> Matrix {
  if lhs.columns == rhs.columns {
    if rhs.rows == 1 {   // rhs is row vector
      /*
      var results = lhs
      for r in 0..<results.rows {
        for c in 1..<results.columns {
          results[r, c] /= rhs[0, c]
        }
      }
      return results
      */

      var results = Matrix.zeros(size: lhs.size)
      lhs.grid.withUnsafeBufferPointer{ src in
        results.grid.withUnsafeMutableBufferPointer{ dst in
          for c in 0..<lhs.columns {
            var v = rhs[c]
            vDSP_vsdivD(src.baseAddress! + c, lhs.columns, &v, dst.baseAddress! + c, lhs.columns, vDSP_Length(lhs.rows))
          }
        }
      }
      return results

    } else if lhs.rows == rhs.rows {   // lhs and rhs are same size
      /*
      var results = lhs
      for r in 0..<results.rows {
        for c in 0..<results.columns {
          results[r, c] /= rhs[r, c]
        }
      }
      return results
      */

      var results = Matrix.zeros(size: lhs.size)
      rhs.grid.withUnsafeBufferPointer{ srcX in
        lhs.grid.withUnsafeBufferPointer{ srcY in
          results.grid.withUnsafeMutableBufferPointer{ dstZ in
            vDSP_vdivD(srcX.baseAddress!, 1, srcY.baseAddress!, 1, dstZ.baseAddress!, 1, vDSP_Length(lhs.rows * lhs.columns))
          }
        }
      }
      return results
    }

  } else if lhs.rows == rhs.rows && rhs.columns == 1 {  // rhs is column vector
    /*
    var results = lhs
    for c in 0..<results.columns {
      for r in 0..<results.rows {
        results[r, c] /= rhs[r, 0]
      }
    }
    return results
    */

    var results = Matrix.zeros(size: lhs.size)
    lhs.grid.withUnsafeBufferPointer{ src in
      results.grid.withUnsafeMutableBufferPointer{ dst in
        for r in 0..<lhs.rows {
          var v = rhs[r]
          vDSP_vsdivD(src.baseAddress! + r*lhs.columns, 1, &v, dst.baseAddress! + r*lhs.columns, 1, vDSP_Length(lhs.columns))
        }
      }
    }
    return results
  }

  fatalError("Cannot element-wise divide \(lhs.rows)×\(lhs.columns) matrix and \(rhs.rows)×\(rhs.columns) matrix")
}

/* Divides each element of the matrix by a scalar. */
public func / (lhs: Matrix, rhs: Double) -> Matrix {
  var results = lhs
  results.grid.withUnsafeMutableBufferPointer { ptr in
    cblas_dscal(Int32(lhs.grid.count), 1/rhs, ptr.baseAddress, 1)
  }
  return results
}

/* Divides a scalar by each element of the matrix. */
public func / (lhs: Double, rhs: Matrix) -> Matrix {
  /*
  var m = rhs
  for r in 0..<m.rows {
    for c in 0..<m.columns {
      m[r, c] = lhs / rhs[r, c]
    }
  }
  return m
  */
  
  var results = rhs
  rhs.grid.withUnsafeBufferPointer { src in
    results.grid.withUnsafeMutableBufferPointer { dst in
      var scalar = lhs
      vDSP_svdivD(&scalar, src.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(rhs.rows * rhs.columns))
    }
  }
  return results
}

// MARK: - Other maths

extension Matrix {
  /* Exponentiates each element of the matrix. */
  public func exp() -> Matrix {
    /*
    var result = m
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        result[r, c] = exp(m[r, c])
      }
    }
    return result
    */
    
    var result = self
    grid.withUnsafeBufferPointer { src in
      result.grid.withUnsafeMutableBufferPointer { dst in
        var size = Int32(rows * columns)
        vvexp(dst.baseAddress!, src.baseAddress!, &size)
      }
    }
    return result
  }

  /* Takes the natural logarithm of each element of the matrix. */
  public func log() -> Matrix {
    /*
    var result = m
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        result[r, c] = log(m[r, c])
      }
    }
    return result
    */
    
    var result = self
    grid.withUnsafeBufferPointer { src in
      result.grid.withUnsafeMutableBufferPointer { dst in
        var size = Int32(rows * columns)
        vvlog(dst.baseAddress!, src.baseAddress!, &size)
      }
    }
    return result
  }

  /* Raised each element of the matrix to power alpha. */
  public func pow(_ alpha: Double) -> Matrix {
    /*
    var result = m
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        result[r, c] = pow(m[r, c], alpha)
      }
    }
    return result
    */

    var result = self
    grid.withUnsafeBufferPointer { src in
      result.grid.withUnsafeMutableBufferPointer { dst in
        if alpha == 2 {
          vDSP_vsqD(src.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(rows * columns))
        } else {
          var size = Int32(rows * columns)
          var exponent = alpha
          vvpows(dst.baseAddress!, &exponent, src.baseAddress!, &size)
        }
      }
    }
    return result
  }

  /* Takes the square root of each element of the matrix. */
  public func sqrt() -> Matrix {
    /*
    var result = m
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        result[r, c] = sqrt(m[r, c])
      }
    }
    return result
    */

    var result = self
    grid.withUnsafeBufferPointer { src in
      result.grid.withUnsafeMutableBufferPointer { dst in
        var size = Int32(rows * columns)
        vvsqrt(dst.baseAddress!, src.baseAddress!, &size)
      }
    }
    return result
  }

  /* Adds up all the elements in the matrix. */
  public func sum() -> Double {
    var result = 0.0

    /*
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        result += m[r, c]
      }
    }
    */
    
    grid.withUnsafeBufferPointer { src in
      vDSP_sveD(src.baseAddress!, 1, &result, vDSP_Length(rows * columns))
    }
    return result
  }

  /* Adds up the elements in each row. Returns a column vector. */
  public func sumRows() -> Matrix {
    var result = Matrix.zeros(rows: rows, columns: 1)
    
    /*
    for r in 0..<m.rows {
      for c in 0..<m.columns {
        result[r] += m[r, c]
      }
    }
    */
    
    grid.withUnsafeBufferPointer { src in
      result.grid.withUnsafeMutableBufferPointer { dst in
        for r in 0..<rows {
          vDSP_sveD(src.baseAddress! + r*columns, 1, dst.baseAddress! + r, vDSP_Length(columns))
        }
      }
    }
    return result
  }

  /* Adds up the elements in each column. Returns a row vector. */
  public func sumColumns() -> Matrix {
    var result = Matrix.zeros(rows: 1, columns: columns)
    
    /*
    for c in 0..<m.columns {
      for r in 0..<m.rows {
        result[c] += m[r, c]
      }
    }
    */
    
    grid.withUnsafeBufferPointer { src in
      result.grid.withUnsafeMutableBufferPointer { dst in
        for c in 0..<columns {
          vDSP_sveD(src.baseAddress! + c, columns, dst.baseAddress! + c, vDSP_Length(rows))
        }
      }
    }
    return result
  }
}

// MARK: - Minimum and maximum

extension Matrix {
  public func min(row r: Int) -> (Double, Int) {
    /*
    var result = self[r, 0]
    var index = 0
    for c in 1..<columns {
      if self[r, c] < result {
        result = self[r, c]
        index = c
      }
    }
    return (result, index)
    */

    var result = 0.0
    var index: vDSP_Length = 0
    grid.withUnsafeBufferPointer { ptr in
      vDSP_minviD(ptr.baseAddress! + r*columns, 1, &result, &index, vDSP_Length(columns))
    }
    return (result, Int(index))
  }

  public func max(row r: Int) -> (Double, Int) {
    /*
    var result = self[r, 0]
    var index = 0
    for c in 1..<columns {
      if self[r, c] > result {
        result = self[r, c]
        index = c
      }
    }
    return (result, index)
    */

    var result = 0.0
    var index: vDSP_Length = 0
    grid.withUnsafeBufferPointer { ptr in
      vDSP_maxviD(ptr.baseAddress! + r*columns, 1, &result, &index, vDSP_Length(columns))
    }
    return (result, Int(index))
  }

  public func minRows() -> Matrix {
    var mins = Matrix.zeros(rows: rows, columns: 1)
    for r in 0..<rows {
      mins[r] = min(row: r).0
    }
    return mins
  }

  public func maxRows() -> Matrix {
    var maxs = Matrix.zeros(rows: rows, columns: 1)
    for r in 0..<rows {
      maxs[r] = max(row: r).0
    }
    return maxs
  }

  public func min(column c: Int) -> (Double, Int) {
    /*
    var result = self[0, c]
    var index = 0
    for r in 1..<rows {
      if self[r, c] < result {
        result = self[r, c]
        index = r
      }
    }
    return (result, index)
    */

    var result = 0.0
    var index: vDSP_Length = 0
    grid.withUnsafeBufferPointer { ptr in
      vDSP_minviD(ptr.baseAddress! + c, columns, &result, &index, vDSP_Length(rows))
    }
    return (result, Int(index) / columns)
  }

  public func max(column c: Int) -> (Double, Int) {
    /*
    var result = self[0, c]
    var index = 0
    for r in 1..<rows {
      if self[r, c] > result {
        result = self[r, c]
        index = r
      }
    }
    return (result, index)
    */

    var result = 0.0
    var index: vDSP_Length = 0
    grid.withUnsafeBufferPointer { ptr in
      vDSP_maxviD(ptr.baseAddress! + c, columns, &result, &index, vDSP_Length(rows))
    }
    return (result, Int(index) / columns)
  }

  public func minColumns() -> Matrix {
    var mins = Matrix.zeros(rows: 1, columns: columns)
    for c in 0..<columns {
      mins[c] = min(column: c).0
    }
    return mins
  }

  public func maxColumns() -> Matrix {
    var maxs = Matrix.zeros(rows: 1, columns: columns)
    for c in 0..<columns {
      maxs[c] = max(column: c).0
    }
    return maxs
  }

  public func min() -> (Double, Int, Int) {
    var result = 0.0
    var index: vDSP_Length = 0
    grid.withUnsafeBufferPointer { ptr in
      vDSP_minviD(ptr.baseAddress!, 1, &result, &index, vDSP_Length(rows * columns))
    }
    let r = Int(index) / rows
    let c = Int(index) - r * columns
    return (result, r, c)
  }

  public func max() -> (Double, Int, Int) {
    var result = 0.0
    var index: vDSP_Length = 0
    grid.withUnsafeBufferPointer { ptr in
      vDSP_maxviD(ptr.baseAddress!, 1, &result, &index, vDSP_Length(rows * columns))
    }
    let r = Int(index) / rows
    let c = Int(index) - r * columns
    return (result, r, c)
  }
}

// MARK: - Statistics

extension Matrix {
  /* Calculates the mean for each of the matrix's columns. */
  public func mean() -> Matrix {
    return mean(0..<columns)
  }

  /*
   Calculates the mean for some of the matrix's columns.

   Note: This returns a matrix of the same size as the original one.
   Any columns not in the range are set to 0.
   */
  public func mean(_ range: CountableRange<Int>) -> Matrix {
    /*
    var mu = Matrix.zeros(rows: 1, columns: columns)
    for r in 0..<rows {
      for c in range {
        mu[0, c] += self[r, c]
      }
    }
    for c in range {
      mu[0, c] /= Double(rows)
    }
    return mu
    */

    var mu = Matrix.zeros(rows: 1, columns: columns)
    grid.withUnsafeBufferPointer{ srcBuf in
      mu.grid.withUnsafeMutableBufferPointer{ dstBuf in
        var srcPtr = srcBuf.baseAddress! + range.lowerBound
        var dstPtr = dstBuf.baseAddress! + range.lowerBound
        for _ in range {
          vDSP_meanvD(srcPtr, columns, dstPtr, vDSP_Length(rows))
          srcPtr += 1
          dstPtr += 1
        }
      }
    }
    return mu
  }

  /*
   Calculates the mean for some of the matrix's columns.

   Note: This returns a matrix of the same size as the original one.
   Any columns not in the range are set to 0.
   */
  public func mean(_ range: CountableClosedRange<Int>) -> Matrix {
    return mean(CountableRange(range))
  }

  /* Calculates the standard deviation for each of the matrix's columns. */
  public func std() -> Matrix {
    return std(0..<columns)
  }

  /*
   Calculates the standard deviation for some of the matrix's columns.

   Note: This returns a matrix of the same size as the original one.
   Any columns not in the range are set to 0.
   */
  public func std(_ range: CountableRange<Int>) -> Matrix {
    let mu = mean(range)

    /*
    var sigma = Matrix.zeros(rows: 1, columns: columns)
    for r in 0..<rows {
      for c in range {
        let d = (self[r, c] - mu[0, c])
        sigma[0, c] += d*d
      }
    }
    for c in range {
      sigma[0, c] /= Double(rows) - 1
      sigma[0, c] = sqrt(sigma[0, c])
    }
    return sigma
    */

    var sigma = Matrix.zeros(rows: 1, columns: columns)
    var temp = Matrix.zeros(rows: rows, columns: columns)

    grid.withUnsafeBufferPointer{ buf1 in
      temp.grid.withUnsafeMutableBufferPointer{ buf2 in
        sigma.grid.withUnsafeMutableBufferPointer{ buf3 in
          var ptr1 = buf1.baseAddress! + range.lowerBound
          var ptr2 = buf2.baseAddress! + range.lowerBound
          var ptr3 = buf3.baseAddress! + range.lowerBound

          for c in range {
            var v = -mu[c]
            vDSP_vsaddD(ptr1, columns, &v, ptr2, columns, vDSP_Length(rows))
            vDSP_vsqD(ptr2, columns, ptr2, columns, vDSP_Length(rows))
            vDSP_sveD(ptr2, columns, ptr3, vDSP_Length(rows))

            ptr1 += 1
            ptr2 += 1
            ptr3 += 1
          }
        }
      }
    }

    // Note: we cannot access sigma[] inside the withUnsafeMutableBufferPointer
    // block, so we do it afterwards.
    sigma = sigma / (Double(rows) - 1)   // sample stddev, not population
    sigma = sigma.sqrt()

    return sigma
  }

  /*
   Calculates the standard deviation for some of the matrix's columns.
   
   Note: This returns a matrix of the same size as the original one.
   Any columns not in the range are set to 0.
   */
  public func std(_ range: CountableClosedRange<Int>) -> Matrix{
    return std(CountableRange(range))
  }
}
