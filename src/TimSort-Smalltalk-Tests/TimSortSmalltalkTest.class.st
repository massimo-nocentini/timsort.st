"
I test the behaviour of TimSort-Smalltalk:

- the permutations equal, slot for slot (`==`), those of Pharo's stable merge sort (`sort:` with a `<=` or `>=` sortBlock) on the shapes of `TimSortSmalltalkTestData` and many sizes;
- stability, also descending;
- slices;
- collections other than `Array`;
- the API of `TimSortSmalltalk`;
- and the guarantee that exceptions and other non-local exits of the comparison reach the caller and leave a permutation of the elements.
"
Class {
	#name : 'TimSortSmalltalkTest',
	#superclass : 'TestCase',
	#category : 'TimSort-Smalltalk-Tests',
	#package : 'TimSort-Smalltalk-Tests'
}

{ #category : 'helpers' }
TimSortSmalltalkTest >> assert: sorted isPermutationOf: original [
	"The elements are Associations whose values are their positions in original"

	| byPosition |
	self assert: sorted size equals: original size.
	byPosition := Array new: original size.
	sorted do: [ :each |
		self assert: (byPosition at: each value) isNil.
		byPosition at: each value put: each ].
	byPosition withIndexDo: [ :each :index | self assert: each identicalTo: (original at: index) ]
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> assert: actual isIdenticalTo: expected [

	self assert: actual size equals: expected size.
	actual with: expected do: [ :a :b | self assert: a identicalTo: b ]
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> associationsOfShape: shapeIndex size: size [
	"key -> position: the positions show the stability"

	| keys |
	keys := TimSortSmalltalkTestData keysOfShape: shapeIndex size: size seed: 42.
	^ (1 to: size) collect: [ :i | (keys at: i) -> i ]
]

{ #category : 'running' }
TimSortSmalltalkTest >> defaultTimeLimit [

	^ 120 seconds
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> differentialSizes [

	^ #( 0 1 2 3 4 5 6 7 8 31 32 33 63 64 65 127 128 129 256 257 512 513 1000 10000 )
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> failingAfter: anInteger comparisons: aBlock [
	"A less-than that answers aBlock until its comparison number anInteger, which signals an Error"

	| count |
	count := 0.
	^ [ :a :b |
	  (count := count + 1) = anInteger ifTrue: [ self error: 'comparison ' , anInteger printString ].
	  aBlock value: a value: b ]
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> keyLessThan [

	^ [ :a :b | a key < b key ]
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> numberOfComparisonsSorting: aCollection [

	| count |
	count := 0.
	TimSortSmalltalk sort: aCollection copy lessThan: [ :a :b |
		count := count + 1.
		a < b ].
	^ count
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> numberOfComparisonsSorting: associations descending: aBoolean [

	| count sorter |
	count := 0.
	sorter := TimSortSmalltalkLessThanSorter lessThan: [ :a :b |
		          count := count + 1.
		          a key < b key ].
	aBoolean ifTrue: [ sorter beDescending ].
	sorter sort: associations copy.
	^ count
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> shapesAndSizesDo: aBlock [

	1 to: TimSortSmalltalkTestData shapes size do: [ :shape | self differentialSizes do: [ :size | aBlock value: shape value: size ] ]
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> sortReturning: anArray afterComparisons: anInteger [
	"Sort anArray with a comparison that returns from this method at its comparison number anInteger"

	| count |
	count := 0.
	TimSortSmalltalk sort: anArray lessThan: [ :a :b |
		(count := count + 1) = anInteger ifTrue: [ ^ #returned ].
		a key < b key ].
	^ #completed
]

{ #category : 'helpers' }
TimSortSmalltalkTest >> stringsOfShape: shapeIndex size: size [
	"Distinct strings, equal for equal keys: their identities show the stability"

	^ (TimSortSmalltalkTestData keysOfShape: shapeIndex size: size seed: 42) collect: [ :each | each printPaddedWith: $0 to: 7 ]
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testAnswersTheCollection [

	| array |
	array := #( 3 1 2 ) copy.
	self assert: (TimSortSmalltalk sort: array) identicalTo: array.
	self assert: (TimSortSmalltalk sortDescending: array) identicalTo: array.
	self assert: (TimSortSmalltalk sort: array by: [ :a :b | a <= b ]) identicalTo: array.
	self assert: (TimSortSmalltalk sort: array lessThan: [ :a :b | a < b ]) identicalTo: array.
	self assert: (TimSortSmalltalk sort: array from: 1 to: 2 lessThan: [ :a :b | a < b ]) identicalTo: array
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testAscendingAndDescendingSorter [

	| sorter |
	sorter := TimSortSmalltalkNaturalOrderSorter new.
	self deny: sorter isDescending.
	sorter beDescending.
	self assert: sorter isDescending.
	self assert: (sorter sort: #( 2 3 1 ) copy) equals: #( 3 2 1 ).
	sorter beAscending.
	self deny: sorter isDescending.
	self assert: (sorter sort: #( 2 3 1 ) copy) equals: #( 1 2 3 )
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testText [
	"A Text, whose replaceFrom:to:with:startingAt: takes only a Text (an Array has no asText), is sorted through at: and at:put:, merges and binary insertions included"

	| random string |
	random := Random seed: 20261117.
	#( 2 3 40 64 300 3000 ) do: [ :n |
		string := String new: n.
		1 to: n do: [ :k | string at: k put: (Character value: 96 + (random nextInteger: 26)) ].
		self assert: (TimSortSmalltalk sort: string asText) string equals: string copy sort.
		self assert: (TimSortSmalltalk sortDescending: string asText) string equals: (string copy sort: [ :a :b | a >= b ]).
		self assert: (TimSortSmalltalk sort: string asText by: [ :a :b | a >= b ]) string equals: (string copy sort: [ :a :b | a >= b ]).
		self assert: (TimSortSmalltalk sort: string asText lessThan: [ :a :b | a < b ]) string equals: string copy sort ]
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testCharactersOfAString [

	self assert: (TimSortSmalltalk sort: 'timsort' copy) equals: 'imorstt'.
	self assert: (TimSortSmalltalk sortDescending: 'timsort' copy) equals: 'ttsromi'
]

{ #category : 'tests - comparisons' }
TimSortSmalltalkTest >> testComparisonsOfSortedAndReversedInput [
	"A natural run costs one comparison per element"

	#( 2 10 1000 100000 ) do: [ :size |
		self assert: (self numberOfComparisonsSorting: (1 to: size) asArray) equals: size - 1.
		self assert: (self numberOfComparisonsSorting: (size to: 1 by: -1) asArray) equals: size - 1 ]
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testDescendingLessThan [

	| associations |
	associations := self associationsOfShape: 2 size: 1000.
	self
		assert: (TimSortSmalltalk sortDescending: associations copy lessThan: self keyLessThan)
		isIdenticalTo: (associations copy sort: [ :a :b | a key >= b key ])
]

{ #category : 'tests - stability' }
TimSortSmalltalkTest >> testDescendingStability [
	"Equal keys keep their order in a descending sort too: it is not an ascending sort reversed"

	| associations sorted |
	associations := self associationsOfShape: 2 size: 5000.
	sorted := (TimSortSmalltalkLessThanSorter lessThan: self keyLessThan)
		          beDescending;
		          sort: associations copy.
	sorted overlappingPairsDo: [ :a :b |
		self assert: a key >= b key.
		a key = b key ifTrue: [ self assert: a value < b value ] ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testExceptionInEveryComparison [
	"Make the comparison fail at each of its calls in turn: the error reaches the caller, and the collection holds a permutation of its elements, wherever the sort was (runs, insertion, merges low and high, galloping)"

	#( #( 1 300 ) #( 8 300 ) #( 2 300 ) #( 9 120 ) ) do: [ :shapeAndSize |
		| associations |
		associations := self associationsOfShape: shapeAndSize first size: shapeAndSize second.
		#( false true ) do: [ :descending |
			1 to: (self numberOfComparisonsSorting: associations descending: descending) do: [ :failure |
				| sorted sorter |
				sorted := associations copy.
				sorter := TimSortSmalltalkLessThanSorter lessThan: (self failingAfter: failure comparisons: self keyLessThan).
				descending ifTrue: [ sorter beDescending ].
				self should: [ sorter sort: sorted ] raise: Error.
				self assert: sorted isPermutationOf: associations ] ] ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testExceptionInDescendingSortReversesBack [
	"A descending sort reverses the slice, sorts it ascending and reverses it back (the reverse flag of list_sort_impl), also when a comparison raises (ensure:): the slice is then the reverse of what the ascending sort of the reversed slice leaves when it raises at the same comparison"

	#( #( 1 300 ) #( 2 300 ) #( 8 300 ) #( 9 120 ) ) do: [ :shapeAndSize |
		| associations total |
		associations := self associationsOfShape: shapeAndSize first size: shapeAndSize second.
		total := self numberOfComparisonsSorting: associations descending: true.
		{ 1. total // 4. total // 2. total - 1 } do: [ :failure |
			| descending ascending |
			descending := associations copy.
			ascending := associations reversed.
			self
				should: [ TimSortSmalltalk sortDescending: descending lessThan: (self failingAfter: failure comparisons: self keyLessThan) ]
				raise: Error.
			self
				should: [ TimSortSmalltalk sort: ascending lessThan: (self failingAfter: failure comparisons: self keyLessThan) ]
				raise: Error.
			self assert: descending isIdenticalTo: ascending reversed ] ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testExceptionInLargeMerges [

	#( 1 8 ) do: [ :shape |
		| associations total |
		associations := self associationsOfShape: shape size: 20000.
		total := self numberOfComparisonsSorting: associations descending: false.
		#( 1 3 10 30 50 70 90 99 ) do: [ :percent |
			| sorted |
			sorted := associations copy.
			self
				should: [ TimSortSmalltalk sort: sorted lessThan: (self failingAfter: total * percent // 100 comparisons: self keyLessThan) ]
				raise: Error.
			self assert: sorted isPermutationOf: associations ] ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testExceptionReachesTheCaller [

	| caught |
	caught := [
	          TimSortSmalltalk sort: #( 3 1 2 ) copy lessThan: [ :a :b | ZeroDivide new signal: 'compare' ].
	          nil ]
		          on: ZeroDivide
		          do: [ :error | error messageText ].
	self assert: caught equals: 'compare'
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testExceptionReturnsTheHandlerValue [

	| array |
	array := self associationsOfShape: 1 size: 500.
	self
		assert: ([ TimSortSmalltalk sort: array copy lessThan: (self failingAfter: 2000 comparisons: self keyLessThan) ]
				 on: Error
				 do: [ :error | error return: #handled ])
		equals: #handled
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testFewerThanTwoElementsAreNotCompared [

	| never |
	never := [ :a :b | self fail: 'compared' ].
	#( #( ) #( 1 ) ) do: [ :each |
		self assert: (TimSortSmalltalk sort: each copy lessThan: never) equals: each.
		self assert: (TimSortSmalltalk sortDescending: each copy lessThan: never) equals: each.
		self assert: (TimSortSmalltalk sort: each copy by: never) equals: each ].
	self assert: (TimSortSmalltalk sort: #( 2 1 3 ) copy from: 2 to: 2 lessThan: never) equals: #( 2 1 3 ).
	self assert: (TimSortSmalltalk sort: #( 2 1 3 ) copy from: 3 to: 2 lessThan: never) equals: #( 2 1 3 )
]

{ #category : 'tests - differential' }
TimSortSmalltalkTest >> testLargeInputs [

	#( 1 2 7 8 ) do: [ :shape |
		| associations |
		associations := self associationsOfShape: shape size: 100000.
		self
			assert: (TimSortSmalltalk sort: associations copy by: [ :a :b | a key <= b key ])
			isIdenticalTo: (associations copy sort: [ :a :b | a key <= b key ]).
		self
			assert: (TimSortSmalltalk sortDescending: associations copy lessThan: self keyLessThan)
			isIdenticalTo: (associations copy sort: [ :a :b | a key >= b key ]) ]
]

{ #category : 'tests - differential' }
TimSortSmalltalkTest >> testLessThanMatchesPharoSort [

	self shapesAndSizesDo: [ :shape :size |
		| associations |
		associations := self associationsOfShape: shape size: size.
		self
			assert: (TimSortSmalltalk sort: associations copy lessThan: self keyLessThan)
			isIdenticalTo: (associations copy sort: [ :a :b | a key <= b key ]).
		self
			assert: (TimSortSmalltalk sortDescending: associations copy lessThan: self keyLessThan)
			isIdenticalTo: (associations copy sort: [ :a :b | a key >= b key ]) ]
]

{ #category : 'tests - differential' }
TimSortSmalltalkTest >> testNaturalOrderMatchesPharoSort [

	self shapesAndSizesDo: [ :shape :size |
		| strings |
		strings := self stringsOfShape: shape size: size.
		self assert: (TimSortSmalltalk sort: strings copy) isIdenticalTo: strings copy sort.
		self assert: (TimSortSmalltalk sortDescending: strings copy) isIdenticalTo: (strings copy sort: [ :a :b | a >= b ]) ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testNonLocalReturnKeepsAPermutation [

	| associations |
	associations := self associationsOfShape: 1 size: 1000.
	#( 1 500 3000 8000 ) do: [ :failure |
		| sorted |
		sorted := associations copy.
		self assert: (self sortReturning: sorted afterComparisons: failure) equals: #returned.
		self assert: sorted isPermutationOf: associations ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testNotificationsAreResumed [
	"A resumable exception that nobody handles does not stop the sort"

	| associations |
	associations := self associationsOfShape: 1 size: 300.
	self
		assert: (TimSortSmalltalk sort: associations copy lessThan: [ :a :b |
				 Notification signal.
				 a key < b key ])
		isIdenticalTo: (associations copy sort: [ :a :b | a key <= b key ])
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testOrderedCollection [

	| associations collection |
	associations := self associationsOfShape: 8 size: 3000.
	collection := OrderedCollection new.
	collection addAll: #( 1 2 3 ).
	collection addAll: associations.
	collection removeFirst: 3.
	TimSortSmalltalk sort: collection by: [ :a :b | a key <= b key ].
	self assert: collection asArray isIdenticalTo: (associations copy sort: [ :a :b | a key <= b key ])
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testOutOfBoundsSlices [

	self should: [ TimSortSmalltalk sort: #( 3 2 1 ) copy from: 0 to: 2 lessThan: [ :a :b | a < b ] ] raise: Error.
	self should: [ TimSortSmalltalk sort: #( 3 2 1 ) copy from: 2 to: 4 lessThan: [ :a :b | a < b ] ] raise: Error
]

{ #category : 'tests - nesting' }
TimSortSmalltalkTest >> testReentrantComparison [
	"A comparison may sort other collections"

	| words |
	words := #( 'pear' 'fig' 'apple' 'kiwi' 'banana' ) collect: [ :each | each copy ].
	TimSortSmalltalk sort: words lessThan: [ :a :b | (TimSortSmalltalk sort: a copy) < (TimSortSmalltalk sort: b copy) ].
	self assert: words asArray equals: #( 'banana' 'apple' 'pear' 'fig' 'kiwi' )
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testReusedSorter [

	| sorter first second |
	sorter := TimSortSmalltalkSortBlockSorter sortBlock: [ :a :b | a key <= b key ].
	first := self associationsOfShape: 1 size: 2000.
	second := self associationsOfShape: 8 size: 3000.
	self assert: (sorter sort: first copy) isIdenticalTo: (first copy sort: [ :a :b | a key <= b key ]).
	self assert: (sorter sort: second copy) isIdenticalTo: (second copy sort: [ :a :b | a key <= b key ]).
	self assert: (sorter sort: first copy) isIdenticalTo: (first copy sort: [ :a :b | a key <= b key ])
]

{ #category : 'tests - differential' }
TimSortSmalltalkTest >> testSlices [

	#( #( 1 1000 ) #( 2 999 ) #( 300 700 ) #( 999 1000 ) #( 101 101 ) #( 64 65 ) #( 1 1010 ) ) do: [ :each |
		#( 1 2 8 ) do: [ :shape |
			| associations start stop expected sorted |
			start := each first.
			stop := each second.
			associations := self associationsOfShape: shape size: 1010.
			expected := associations copy.
			expected mergeSortFrom: start to: stop by: [ :a :b | a key <= b key ].
			sorted := TimSortSmalltalk sort: associations copy from: start to: stop by: [ :a :b | a key <= b key ].
			self assert: sorted isIdenticalTo: expected.
			sorted := TimSortSmalltalk sort: associations copy from: start to: stop lessThan: self keyLessThan.
			self assert: sorted isIdenticalTo: expected ] ]
]

{ #category : 'tests - differential' }
TimSortSmalltalkTest >> testSortBlockMatchesPharoSort [

	self shapesAndSizesDo: [ :shape :size |
		| associations |
		associations := self associationsOfShape: shape size: size.
		#( #<= #>= ) do: [ :operator |
			| sortBlock |
			sortBlock := [ :a :b | a key perform: operator with: b key ].
			self
				assert: (TimSortSmalltalk sort: associations copy by: sortBlock)
				isIdenticalTo: (associations copy sort: sortBlock) ] ]
]

{ #category : 'tests - API' }
TimSortSmalltalkTest >> testSortFunction [

	| strings |
	strings := self stringsOfShape: 8 size: 500.
	self
		assert: (TimSortSmalltalk sort: strings copy by: #size ascending , #yourself descending)
		isIdenticalTo: (strings copy sort: #size ascending , #yourself descending)
]

{ #category : 'tests - stability' }
TimSortSmalltalkTest >> testStability [

	| associations sorted |
	associations := self associationsOfShape: 2 size: 5000.
	sorted := TimSortSmalltalk sort: associations copy lessThan: self keyLessThan.
	sorted overlappingPairsDo: [ :a :b |
		self assert: a key <= b key.
		a key = b key ifTrue: [ self assert: a value < b value ] ]
]

{ #category : 'tests - exceptions' }
TimSortSmalltalkTest >> testTerminationKeepsAPermutation [
	"A process terminated while it waits in a comparison unwinds the sort, which restores a permutation"

	| associations |
	associations := self associationsOfShape: 1 size: 2000.
	#( 10 1500 9000 15000 ) do: [ :failure |
		#( false true ) do: [ :descending |
			| sorted semaphore process count sorter |
			sorted := associations copy.
			semaphore := Semaphore new.
			count := 0.
			sorter := TimSortSmalltalkLessThanSorter lessThan: [ :a :b |
				          (count := count + 1) = failure ifTrue: [
					          semaphore signal.
					          Processor activeProcess suspend ].
				          a key < b key ].
			descending ifTrue: [ sorter beDescending ].
			process := [ sorter sort: sorted ] newProcess.
			process resume.
			self deny: (semaphore waitTimeoutMilliseconds: 10000).
			process terminate.
			self assert: process isTerminated.
			self assert: sorted isPermutationOf: associations ] ]
]
