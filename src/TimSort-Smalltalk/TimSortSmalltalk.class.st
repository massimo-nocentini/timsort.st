"
I am the entry point of TimSort-Smalltalk, timsort in pure Smalltalk: the class side sorts SequenceableCollections (Arrays, OrderedCollections, any collection with `at:` and `at:put:`) in place and answers them. The algorithm, a faithful port of timsort.c (CPython's listsort), is `TimSortSmalltalkSorter`; see its comment for the design and the map to the C code.

The sort is stable, also descending, adaptive (about one comparison per element on sorted, reversed or nearly sorted input) and makes few comparisons on random input, which pays when comparing is expensive. Exceptions of the comparison go to the caller, and the collection keeps a permutation of its elements.

## The orders

- the natural order, `#<`, ascending or descending, the same permutations as `aCollection sort` and `aCollection sort: [ :a :b | a >= b ]`:

```smalltalk
TimSortSmalltalk sort: #(3 1 2) copy.  ""#(1 2 3)""
TimSortSmalltalk sortDescending: #(3 1 2) copy.  ""#(3 2 1)""
```

- a sortBlock in the style of Pharo (`a <= b` answers true when a may come before b), with the same result as `aCollection sort: aSortBlock`:

```smalltalk
TimSortSmalltalk sort: words by: [ :a :b | a size <= b size ].
```

- a strict less-than block, the comparison of timsort.c and CPython (true when a must come before b):

```smalltalk
TimSortSmalltalk sort: words lessThan: [ :a :b | a size < b size ].
TimSortSmalltalk
	sortDescending: words
	lessThan: [ :a :b | a size < b size ].
```

- the same on a slice, `from: start to: stop`.

I do not depend on the TimSort package (the VM plugin and the FFI library) and do not extend any class.
"
Class {
	#name : 'TimSortSmalltalk',
	#superclass : 'Object',
	#category : 'TimSort-Smalltalk',
	#package : 'TimSort-Smalltalk'
}

{ #category : 'sorting' }
TimSortSmalltalk class >> sort: aSequenceableCollection [
	"Sort aSequenceableCollection by the natural order of its elements (#<) and answer it"

	^ TimSortSmalltalkNaturalOrderSorter new sort: aSequenceableCollection
]

{ #category : 'sorting' }
TimSortSmalltalk class >> sort: aSequenceableCollection by: aSortBlock [
	"Sort aSequenceableCollection by aSortBlock, true when its first argument may come before the second ([ :a :b | a <= b ]), and answer it: the result of aSequenceableCollection sort: aSortBlock"

	^ (TimSortSmalltalkSortBlockSorter sortBlock: aSortBlock) sort: aSequenceableCollection
]

{ #category : 'sorting' }
TimSortSmalltalk class >> sort: aSequenceableCollection from: start to: stop by: aSortBlock [
	"Sort the elements of aSequenceableCollection from start to stop by aSortBlock (see #sort:by:) and answer aSequenceableCollection"

	^ (TimSortSmalltalkSortBlockSorter sortBlock: aSortBlock) sort: aSequenceableCollection from: start to: stop
]

{ #category : 'sorting' }
TimSortSmalltalk class >> sort: aSequenceableCollection from: start to: stop lessThan: aBlock [
	"Sort the elements of aSequenceableCollection from start to stop by the strict less-than aBlock (see #sort:lessThan:) and answer aSequenceableCollection"

	^ (TimSortSmalltalkLessThanSorter lessThan: aBlock) sort: aSequenceableCollection from: start to: stop
]

{ #category : 'sorting' }
TimSortSmalltalk class >> sort: aSequenceableCollection lessThan: aBlock [
	"Sort aSequenceableCollection by aBlock, true when its first argument must come before the second ([ :a :b | a < b ]), and answer it.  Elements for which neither is less than the other keep their order"

	^ (TimSortSmalltalkLessThanSorter lessThan: aBlock) sort: aSequenceableCollection
]

{ #category : 'sorting' }
TimSortSmalltalk class >> sortDescending: aSequenceableCollection [
	"Sort aSequenceableCollection by the natural order of its elements (#<), descending, and answer it.  Equal elements keep their order"

	^ TimSortSmalltalkNaturalOrderSorter new
		  beDescending;
		  sort: aSequenceableCollection
]

{ #category : 'sorting' }
TimSortSmalltalk class >> sortDescending: aSequenceableCollection lessThan: aBlock [
	"Sort aSequenceableCollection by the strict less-than aBlock, descending, and answer it.  Elements for which neither is less than the other keep their order"

	^ (TimSortSmalltalkLessThanSorter lessThan: aBlock)
		  beDescending;
		  sort: aSequenceableCollection
]
