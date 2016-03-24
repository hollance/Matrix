A fast matrix type for Swift

The API is loosely based on NumPy and Octave/Matlab.

Uses the Accelerate.framework for most of its operations, so it should be pretty
fast.

This matrix is a value type. Any operations return a new instance. That means
it does not always optimally use memory. This should only be a problem if you're
working with huge matrices and you have an algorithm that can work in-place, e.g.
you want to subtract all elements in matrix B from matrix A and store the result
back in A instead of a new matrix C.


TODO:

- MatrixSlice, like ArraySlice. This is a view into a Matrix so we don't have
  to copy any data. Something like m[row: r] could return a MatrixSlice.
  You can convert a slice into a copy using Matrix(slice).
  This also makes transpose() faster: it returns a MatrixSlice with a different
  "stride"; the actual data does not need to change.
  (See also http://www.scipy-lectures.org/advanced/advanced_numpy/index.html,
   how NumPy stores its arrays internally.)

- Make some of the functions more like NumPy:
  - tile(): currently only duplicates a row vector; in NumPy it can tile entire
    matrices in both directions

-	is it possible to create types for the matrix dimensions in Swift?
	like: Matrix<A,B> where A and B are types. So that you can only write:
	M1*M2 when M1 = Matrix<A,B> and M2 = Matrix<B,C> since these two B's have
	to match up.

- insertRow(at:, repeatedValue:, number = 1) / insertColumn(at:, repeatedValue:, number = 1)
- removeRow(index) / removeColumn(index) / removeRows(range:) / removeColumns(range:)
- copy(src: Matrix, fromRow:, rowCount:, fromColumn:, columnCount:, dest: Matrix, toRow:, toColumn:)

- == the elements of two matrices (writes 1.0 if true or 0.0 if false)

- !* of two equal-sized matrices; (M !* M) would be faster than pow(M, 2)
  [I don't think M'*M does the same thing...]; also !/

- !* equivalent of !/
- !+ equivalent of !-

- mean(), std(): I made it so these don't modify the matrix. Was that an optimization
  or did I need that for the particular algorithm?

- make faster!
  - ContiguousArray?
  - benchmark all these versions against one set of test data
  - version using Float instead of Double
  - maybe store the rows as columns and columns as rows? I think in most of the
    machine learning stuff I do computations on rows
  -	maybe NSData will be faster? (or just a malloc'd chunk)
    - benefit is that you can load/save directly to a blob

---------------------------------------

Accelerate all the things!

- these might be useful (if i can't find these in vDSP/BLAS)
    vvdiv()  maybe?
    vvpow()
    vvsqrt()
    vvexp()
    vvlog()

- these look handy but only work on floats, not doubles:
    vIsmax()  finds index of max value
    vIsmin()
    vSsum()

- use grid.withUnsafeBufferPointer { ... } everywhere!
