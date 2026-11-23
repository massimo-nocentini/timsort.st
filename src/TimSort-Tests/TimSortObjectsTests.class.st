"
I test `TimSort`: The natural order of the elements of Arrays (mode a), against Pharo's `sort` and `sort: [ :a :b | a >= b ]`, `==` slot for slot, per backend.
"
Class {
	#name : 'TimSortObjectsTests',
	#superclass : 'TimSortBackendTestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortObjectsTests >> assertSortsLikePharo: anArray [
	"Ascending and descending, whole and on a range"

	| n |
	self assert: (TimSort sort: anArray copy) sameAs: (anArray copy sort: [ :a :b | a <= b ]).
	self assert: (TimSort sortDescending: anArray copy) sameAs: (anArray copy sort: [ :a :b | a >= b ]).
	n := anArray size.
	n >= 4 ifTrue: [
		self
			assert: (TimSort sort: anArray copy from: 2 to: n - 1 descending: false)
			sameAs: (anArray copy mergeSortFrom: 2 to: n - 1 by: [ :a :b | a <= b ]; yourself).
		self
			assert: (TimSort sort: anArray copy from: 2 to: n - 1 descending: true)
			sameAs: (anArray copy mergeSortFrom: 2 to: n - 1 by: [ :a :b | a >= b ]; yourself) ]
]

{ #category : 'tests' }
TimSortObjectsTests >> testCharacters [
	"Characters are no family of the plugin: the sortBlock of Pharo's sort"

	| random |
	random := self random.
	self assertSortsLikePharo: ((1 to: 300) collect: [ :i | Character value: (random nextInteger: 300) ])
]

{ #category : 'tests' }
TimSortObjectsTests >> testEdgeNumbers [
	| edges random |
	edges := TimSortTestData edgeNumbers.
	self assertSortsLikePharo: edges.
	self assertSortsLikePharo: edges reversed.
	random := self random.
	10 timesRepeat: [ self assertSortsLikePharo: (edges shuffleBy: random) ]
]

{ #category : 'tests' }
TimSortObjectsTests >> testEqualStringsOfEachClass [
	"Equal strings of the four classes keep their order, as in Pharo"

	| strings |
	strings := {
		           'abc'.
		           #abc.
		           'abc' asWideString.
		           #abd.
		           'abc' copy.
		           TimSortTestData wideSymbol.
		           'ab'.
		           'abc' asWideString.
		           'a' , (String with: (Character value: 945)) }.
	self assertSortsLikePharo: strings.
	self assertSortsLikePharo: strings reversed
]

{ #category : 'tests' }
TimSortObjectsTests >> testExactOrderBeyond2To53 [
	"SmallIntegers, Floats and LargeIntegers beyond 2^53 are compared exactly by every backend, as the image code compares them (Number>>adaptToFloat:andCompare:), not as the JIT of the native VM does after rounding the SmallInteger: the plugin in C, TimSortPortBackend (the #smalltalk backend, and what the library declines) with TimSortPortBackend class>>is:lessOrEqual:.  So are the keys of argSort:"

	| random numbers expected |
	random := self random.
	#( 10 100 1000 ) do: [ :n |
		numbers := TimSortTestData exactNumbers: n random: random.
		expected := numbers copy sort: [ :a :b | (TimSortTestData exactKey: a) <= (TimSortTestData exactKey: b) ].
		self assert: (TimSort sort: numbers copy) sameAs: expected.
		self assert: ((TimSort argSort: numbers) collect: [ :i | numbers at: i ]) sameAs: expected.
		expected := numbers copy sort: [ :a :b | (TimSortTestData exactKey: a) >= (TimSortTestData exactKey: b) ].
		self assert: (TimSort sortDescending: numbers copy) sameAs: expected.
		self assert: ((TimSort argSortDescending: numbers) collect: [ :i | numbers at: i ]) sameAs: expected ]
]

{ #category : 'tests' }
TimSortObjectsTests >> testFractionsAndScaledDecimals [
	| random |
	random := self random.
	self assertSortsLikePharo: ((1 to: 500) collect: [ :i |
			 | r |
			 r := random nextInteger: 4.
			 r = 1
				 ifTrue: [ (random nextInteger: 20) / (random nextInteger: 7) ]
				 ifFalse: [
					 r = 2
						 ifTrue: [ ((random nextInteger: 2000) / 100) asScaledDecimal: 2 ]
						 ifFalse: [ (random nextInteger: 20) - 10 ] ] ])
]

{ #category : 'tests' }
TimSortObjectsTests >> testMixedStringsAndNumbers [
	"The plugin declines them; the comparisons then fail as in Pharo"

	| expected |
	expected := [ { 3. 'a'. 1 } sort. nil ] on: Error do: [ :error | error class ].
	self assert: expected notNil.
	self should: [ TimSort sort: { 3. 'a'. 1 } ] raise: expected.
	self should: [ TimSort sort: { 'b'. 3. 'a' } ] raise: Error
]

{ #category : 'tests' }
TimSortObjectsTests >> testNaN [
	"NaN among objects: the plugin declines, and the sortBlock of Pharo's sort gives the timsort of that inconsistent order (not Pharo's merge sort), the same on every backend"

	| nan array |
	nan := Float nan.
	array := { 3. nan. 1. 2. nan. 0.5 }.
	self
		assert: (TimSort sort: array copy)
		sameAs: (TimSortSmalltalk sort: array copy by: [ :a :b | a <= b ]).
	self
		assert: (TimSort sortDescending: array copy)
		sameAs: (TimSortSmalltalk sort: array copy by: [ :a :b | a >= b ])
]

{ #category : 'tests' }
TimSortObjectsTests >> testNilAndMixedFamilies [
	self should: [ TimSort sort: { 2. nil. 1 } ] raise: Error.
	self assert: (TimSort sort: { nil }) sameAs: { nil }.
	self assert: (TimSort sort: {  }) sameAs: {  }
]

{ #category : 'tests' }
TimSortObjectsTests >> testNonNormalizedLargeIntegers [
	"A LargePositiveInteger that holds a SmallInteger value (or zero) compares as Pharo's image code compares it: the plugin declines"

	| odd array |
	odd := LargePositiveInteger new: 8.
	odd at: 1 put: 5.
	array := { 7. odd. 3. 6 }.
	self assert: (TimSort sort: array copy) sameAs: (TimSortSmalltalk sort: array copy by: [ :a :b | a <= b ])
]

{ #category : 'tests' }
TimSortObjectsTests >> testRandomNumbers [
	| random |
	random := self random.
	self sizes do: [ :n |
		TimSortTestData shapes do: [ :shape |
			self assertSortsLikePharo: (TimSortTestData
					 shaped: (TimSortTestData numbers: n random: random)
					 shape: shape
					 random: random) ] ]
]

{ #category : 'tests' }
TimSortObjectsTests >> testRandomSmallIntegers [
	| random |
	random := self random.
	self sizes do: [ :n |
		TimSortTestData shapes do: [ :shape |
			self assertSortsLikePharo: (TimSortTestData
					 shaped: ((1 to: n) collect: [ :i | (random nextInteger: n // 3 + 2) - (n // 6) ])
					 shape: shape
					 random: random) ] ].
	self assertSortsLikePharo: { SmallInteger maxVal. SmallInteger minVal. 0. -1. SmallInteger maxVal. 1 }
]

{ #category : 'tests' }
TimSortObjectsTests >> testRandomStrings [
	| random |
	random := self random.
	self sizes do: [ :n |
		TimSortTestData shapes do: [ :shape |
			self assertSortsLikePharo: (TimSortTestData
					 shaped: (TimSortTestData strings: n random: random)
					 shape: shape
					 random: random) ] ]
]

{ #category : 'tests' }
TimSortObjectsTests >> testStringSubclassIsNotAStringClass [
	"Only the four classes of TimSort stringClasses are compared by the plugin: a subclass may define its own order"

	self deny: (TimSort stringClasses includes: Symbol).
	self assert: TimSort stringClasses size equals: 4.
	self assertSortsLikePharo: { 'b'. #a. 'c' asWideString. #b }
]
