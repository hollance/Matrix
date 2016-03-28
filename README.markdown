# A fast matrix type for Swift

This is a basic matrix type that I wrote when I was playing with machine learning in Swift. It is by no means complete or finished.

The API is loosely based on NumPy and Octave/MATLAB. `Matrix` uses the Accelerate.framework for most of its operations, so it should be pretty fast -- but no doubt there's lots of room for improvement.

For example, here's how you can use `Matrix` as part of the k-nearest neighbors algorithm:

```swift
// load your data set into matrix X, where each row represents one training
// example, and each column a feature
let X = Matrix(rows: 10000, columns: 200)

// load your test example into the row vector x
let x = Matrix(rows: 1, columns: 200)

// Calculate the distance between the test example and every training example
// and store this in a new column vector
let distances = (x.tile(X.rows) - X).pow(2).sumRows().sqrt()
```

The `sqrt()`, `sumRows()`, and `pow()` functions work on all the elements of the matrix. The `-` operator subtracts the matrices element-wise. This one-liner does the work of several loops, using accelerated CPU instructions from the BLAS, LAPACK, and vDSP libraries inside the Accelerate.framework.

The Xcode project only includes unit tests, you can't run it. Press **Cmd-U** to perform the tests.

> Note: `Matrix` is a value type. Any operations return a new instance. That means it does not always optimally use memory. This should only be a problem if you're working with huge matrices and you have an algorithm that can work in-place, e.g. you want to subtract all elements in matrix B from matrix A and store the result back in A instead of a new matrix C.

## Notes on the API

I decided to make all operations either member functions of `Matrix` or operators. There are no free functions that work on `Matrix`.

Even though the following reads more "mathematical",

    sqrt(sumRows(pow(x.tile(X.rows) - X, 2)))

it requires you to unravel what happens "inside-out". Using member functions you can simply read from left-to-right:

    (x.tile(X.rows) - X).pow(2).sumRows().sqrt()
 
### The `!*`, `!/`, etc operators

This discussion concerns operators that work on two matrices.

The `*` operator exists to multiply two matrices (or a matrix with a vector). Likewise, `/` is for dividing two matrices, i.e. multiplying one matrix with the inverse of another.
 
But what happens when we multiply or divide two matrices where we want the operation to happen on each individual element rather than on the matrix as a whole? We can't use `*` or `/` for that because then we don't have to way to distinguish between "multiply matrix with vector" and "multiply matrix element-wise with vector".

Therefore, all element-wise operations that take place on matrices of different sizes, must use a `!` operator.

(Is there a better symbol to use for this? I like `!` but it already gets used for other purposes. Maybe `∀*` or `⊗⊘⊕⊖`.)

## The TO-DO list

Extend the functionality of:

- `tile()` currently only duplicates a row vector; in NumPy it can tile entire matrices in both directions.
- column-vector versions of `!-` and `!/`

Add functions for inserting/removing rows:

- `insertRow(at:, repeatedValue:)`
- `insertRows(at:, repeatedValue:, count:)`
- `insertColumn(at:, repeatedValue:)`
- `insertColumns(at:, repeatedValue:, count:)`
- `remove(row: Int)`
- `remove(rows: Range<Int>)`
- `remove(column: Int)`
- `remove(columns: Range<Int>)`
- `copy(src: Matrix, rowRange:, columnRange:, dest: Matrix, toRow:, toColumn:)`

Other new functions:

- `subscript(rows: Range<Int>) -> Matrix`
- `subscript(columns: Range<Int>) -> Matrix`

Other new operators:

- `==` operator on the elements of two matrices, writes `1.0` if true or `0.0` if false
- `!*` equivalent of `!/
- `!+` equivalent of `!-`
- `!*` of two equal-sized matrices
- `!/` of two equal-sized matrices (using `vvdiv()`)

## Other ideas for improvements

### Make it faster!

Make different versions and benchmark against one set of test data:

- Use `ContiguousArray` instead of `Array`?
- Use `malloc` or `NSData` to allocate memory instead of using `Array`?
- Use `Float` instead of `Double`?
- Maybe store the rows as columns and columns as rows? In a lot of machine learning stuff, computations are done on columns (where each column represents a feature). This may improve locality of the data.
- Use the new LinearAlgebra framework instead of LAPACK directly?

Some Accelerate.framework functions that might come in handy:

- `catlas_dset()` / `vDSP_vfillD()`: for initializing the "ones" matrix if we use `malloc` instead of Swift array.
- `cblas_dnrm2()` / `vDSP_vdistD()` / `vDSP_vpythg()`: Euclidian length of vector
- `vDSP_normalizeD()`: uses mean and std dev to normalize. This can also just calculate mean and stddev without normalizing, so maybe use this in the `std()` function.
- `vDSP_svesqD()`: sum of squares
- `vDSP_mmovD()`: copy submatrix

### Slices

Make a `MatrixSlice` type, which works like `ArraySlice`. This is a view into a `Matrix` so you don't have to copy any data. Something like `m[row: r]` could return a `MatrixSlice` for just that row.

You can convert a slice into a copy of the data using `Matrix(slice)`.

This also makes `transpose()` faster: it simply returns a `MatrixSlice` with a different "stride"; the actual data does not need to change.

See also [how NumPy stores its arrays internally](http://www.scipy-lectures.org/advanced/advanced_numpy/index.html).

## The end

Based on @mattt's [Surge](https://github.com/mattt/Surge) library.

Also check out this alternative matrix library for Swift: [swix](http://scottsievert.com/swix/)

MIT license
