"
I test `TimSort`: Sorts by a sortBlock (mode d), against Pharo's `sort: aBlock`, `==` slot for slot, per backend.

The default (`timSort:`, `sort:with:`) is `TimSortSmalltalk` on every backend (`testDefaultIsThePort`); the other tests sort explicitly with `TimSort sort:with:backend: sortBackend`: the resumable C sort of my backend when it has one (the plugin natively; the library in `TimSortFFIBlockTests`), which asks the block one comparison at a time, else `#smalltalk`.

Errors, non-local returns, terminated Processes (also by another `Process`, at any moment), the Restart of the frame of the block, garbage collections, nested sorts, two Processes and resumed Warnings in the block; every test ends with no resumable sort live.
"
Class {
	#name : 'TimSortBlockTests',
	#superclass : 'TimSortBackendTestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortBlockTests >> assert: aCollection sortsLikePharoWith: aBlock [
	self assert: (self sort: aCollection copy with: aBlock) sameAs: (aCollection copy sort: aBlock)
]

{ #category : 'helpers' }
TimSortBlockTests >> sortBackend [
	"The backend my sorts name explicitly: my backend when it has a resumable sort, else #smalltalk"

	^ (backendName ~~ #smalltalk and: [ self backendObject coroutinesAvailable ])
		  ifTrue: [ backendName ]
		  ifFalse: [ #smalltalk ]
]

{ #category : 'helpers' }
TimSortBlockTests >> sort: aCollection with: aBlock [
	^ TimSort sort: aCollection with: aBlock backend: self sortBackend
]

{ #category : 'helpers' }
TimSortBlockTests >> sort: aCollection from: start to: stop with: aBlock [
	^ TimSort sort: aCollection from: start to: stop with: aBlock backend: self sortBackend
]

{ #category : 'helpers' }
TimSortBlockTests >> nestedSort: anArray depth: depth [
	"Sort anArray with a sortBlock that, at its first comparison, sorts another Array the same way, depth deep: depth sorts are live at once"

	| first |
	first := true.
	^ self sort: anArray with: [ :a :b |
		  (first and: [ depth > 0 ]) ifTrue: [
			  first := false.
			  self assert: (self nestedSort: #( 3 1 2 ) copy depth: depth - 1) equals: #( 1 2 3 ) ].
		  a <= b ]
]

{ #category : 'helpers' }
TimSortBlockTests >> sortReturningFromBlock: anArray [
	self sort: anArray with: [ :a :b | ^ #escaped ].
	^ #sorted
]

{ #category : 'running' }
TimSortBlockTests >> tearDown [
	| live |
	live := TimSort liveCoroutines.
	super tearDown.
	self assert: live equals: 0
]

{ #category : 'tests' }
TimSortBlockTests >> testBackend [
	"The default is #smalltalk whatever the backend; the explicit backend of my sorts is one of resumableBackends, or #smalltalk"

	self assert: TimSort blockSortBackend equals: #smalltalk.
	self sortBackend == #smalltalk ifTrue: [ ^ self ].
	self assert: (TimSort resumableBackends includes: self sortBackend).
	self assert: TimSort coroutinesAvailable
]

{ #category : 'tests' }
TimSortBlockTests >> testDefaultIsThePort [
	"timSort:, timSorted: and sort:with: run TimSortSmalltalk on every backend: the block is evaluated by a sorter of the port, no resumable sort is live meanwhile, and the result is the port's (also for a strict block); the explicit sort of my backend evaluates it from the loop of the facade, its resumable sort live"

	| random array pairs senders live |
	random := self random.
	array := (1 to: 300) collect: [ :i | random nextInteger: 50 ].
	pairs := (1 to: 300) collect: [ :i | (random nextInteger: 5) -> i ].
	senders := IdentitySet new.
	live := Set new.
	{
		[ :c :block | c timSort: block ].
		[ :c :block | c timSorted: block ].
		[ :c :block | TimSort sort: c with: block ].
		[ :c :block | TimSort sort: c from: 1 to: c size with: block ] } do: [ :sort |
		self
			assert: (sort value: array copy value: [ :a :b |
					 senders add: thisContext sender receiver class.
					 live add: TimSort liveCoroutines.
					 a <= b ])
			sameAs: (array copy sort: [ :a :b | a <= b ]).
		self
			assert: (sort value: pairs copy value: [ :a :b | a key < b key ])
			sameAs: (TimSortSmalltalk sort: pairs copy by: [ :a :b | a key < b key ]) ].
	self assert: (senders allSatisfy: [ :each | each includesBehavior: TimSortSmalltalkSorter ]).
	self assert: live asArray equals: #( 0 ).
	self sortBackend == #smalltalk ifTrue: [ ^ self ].
	senders := IdentitySet new.
	live := Set new.
	self sort: array copy with: [ :a :b |
		senders add: thisContext sender receiver.
		live add: TimSort liveCoroutines.
		a <= b ].
	self assert: senders asArray equals: { TimSort }.
	self assert: live asArray equals: #( 1 )
]

{ #category : 'tests' }
TimSortBlockTests >> testCollections [
	| oc buffer string array |
	oc := OrderedCollection withAll: #( 0 0 5 3 4 1 ).
	oc removeFirst: 2.
	self sort: oc with: [ :a :b | a >= b ].
	self assert: oc asArray equals: #( 5 4 3 1 ).
	oc add: 0.
	self assert: oc asArray equals: #( 5 4 3 1 0 ).
	buffer := Float64Array withAll: #( 1.5 -2.0 3.0 ).
	self assert: (self sort: buffer with: [ :a :b | a abs <= b abs ]) asArray equals: #( 1.5 -2.0 3.0 ).
	string := 'hello' copy.
	self assert: (self sort: string with: [ :a :b | a >= b ]) equals: 'ollhe'.
	self assert: (self sort: 'hello' copy asText with: [ :a :b | a >= b ]) string equals: 'ollhe'.
	array := #( 6 5 4 3 2 1 ) copy.
	self sort: array from: 2 to: 5 with: [ :a :b | a <= b ].
	self assert: array equals: #( 6 2 3 4 5 1 ).
	self assert: (#( 3 1 2 ) timSorted: [ :a :b | a <= b ]) equals: #( 1 2 3 )
]

{ #category : 'tests' }
TimSortBlockTests >> testDeepNesting [
	"More nested sorts than the 64 resumable sorts a copy of the C code can hold: the deeper ones run in TimSortSmalltalk"

	self assert: (self nestedSort: #( 9 7 8 ) copy depth: 70) equals: #( 7 8 9 )
]

{ #category : 'tests' }
TimSortBlockTests >> testErrorInTheBlock [
	| array original count |
	original := (1 to: 200) asArray shuffleBy: self random.
	array := original copy.
	count := 0.
	self
		should: [
			self sort: array with: [ :a :b |
				(count := count + 1) = 100 ifTrue: [ 1 / 0 ].
				a <= b ] ]
		raise: ZeroDivide.
	self assert: count equals: 100.
	self assert: array asBag equals: original asBag.
	self sortBackend ~~ #smalltalk ifTrue: [ self assert: array equals: original ].
	self assert: TimSort liveCoroutines equals: 0
]

{ #category : 'tests' }
TimSortBlockTests >> testGarbageCollections [
	| random array count |
	random := self random.
	array := TimSortTestData strings: 2000 random: random.
	count := 0.
	self assert: array sortsLikePharoWith: [ :a :b |
		(count := count + 1) \\ 500 = 0 ifTrue: [ Smalltalk garbageCollect ].
		(count \\ 7 = 0) ifTrue: [ Array new: 1000 ].
		a size <= b size ]
]

{ #category : 'tests' }
TimSortBlockTests >> testLikePharo [
	| random |
	random := self random.
	self sizes do: [ :n |
		| numbers strings pairs |
		numbers := (1 to: n) collect: [ :i | (random nextInteger: n + 1) - 1 ].
		strings := TimSortTestData strings: n random: random.
		pairs := (1 to: n) collect: [ :i | (random nextInteger: 5) -> i ].
		self assert: numbers sortsLikePharoWith: [ :a :b | a <= b ].
		self assert: numbers sortsLikePharoWith: [ :a :b | a >= b ].
		self assert: strings sortsLikePharoWith: [ :a :b | a size <= b size ].
		self assert: strings sortsLikePharoWith: [ :a :b | a <= b ].
		self assert: pairs sortsLikePharoWith: [ :a :b | a key <= b key ].
		self assert: pairs sortsLikePharoWith: [ :a :b | a key >= b key ] ]
]

{ #category : 'tests' }
TimSortBlockTests >> testNestedSorts [
	| random array |
	random := self random.
	array := (1 to: 300) collect: [ :i | random nextInteger: 50 ].
	self assert: array sortsLikePharoWith: [ :a :b |
		self assert: (self sort: #( 3 1 2 ) copy with: [ :x :y | x <= y ]) equals: #( 1 2 3 ).
		a <= b ].
	self assert: (self nestedSort: #( 5 4 3 2 1 ) copy depth: 10) equals: #( 1 2 3 4 5 )
]

{ #category : 'tests' }
TimSortBlockTests >> testNonBooleanAnswer [
	| array |
	array := #( 3 1 2 ) copy.
	self should: [ self sort: array with: [ :a :b | nil ] ] raise: Error.
	self assert: array asBag equals: #( 1 2 3 ) asBag
]

{ #category : 'tests' }
TimSortBlockTests >> testNonLocalReturn [
	self assert: (self sortReturningFromBlock: #( 3 1 2 ) copy) equals: #escaped.
	self assert: TimSort liveCoroutines equals: 0
]

{ #category : 'tests' }
TimSortBlockTests >> testSmallSizes [
	| calls |
	calls := 0.
	self sort: #(  ) copy with: [ :a :b | calls := calls + 1. true ].
	self sort: #( 1 ) copy with: [ :a :b | calls := calls + 1. true ].
	self sort: { nil } with: [ :a :b | calls := calls + 1. true ].
	self assert: calls equals: 0.
	self assert: (self sort: #( 2 1 ) copy with: [ :a :b | calls := calls + 1. a <= b ]) equals: #( 1 2 ).
	self assert: calls equals: 1
]

{ #category : 'tests' }
TimSortBlockTests >> testSortedInputTakesOneComparisonPerElement [
	| calls |
	calls := 0.
	self sort: (1 to: 1000) asArray with: [ :a :b | calls := calls + 1. a <= b ].
	self assert: calls equals: 999.
	calls := 0.
	self sort: (1000 to: 1 by: -1) asArray with: [ :a :b | calls := calls + 1. a <= b ].
	self assert: calls equals: 999
]

{ #category : 'tests' }
TimSortBlockTests >> testStrictBlock [
	"A strict block (a < b) is an inconsistent order for timsort: the result is sorted, the ties in an order of their own, the same as TimSortSmalltalk gives"

	| random pairs sorted |
	random := self random.
	#( 10 100 1000 ) do: [ :n |
		pairs := (1 to: n) collect: [ :i | (random nextInteger: 5) -> i ].
		sorted := self sort: pairs copy with: [ :a :b | a key < b key ].
		self assert: (sorted collect: [ :each | each key ]) equals: ((pairs collect: [ :each | each key ]) sort: [ :a :b | a <= b ]).
		self assert: sorted sameAs: (TimSortSmalltalk sort: pairs copy by: [ :a :b | a key < b key ]) ]
]

{ #category : 'tests' }
TimSortBlockTests >> testTerminatedProcess [
	"A Process terminated while its block waits: the resumable sort is freed by the unwinding"

	| array original semaphore process |
	original := (1 to: 100) asArray shuffleBy: self random.
	array := original copy.
	semaphore := Semaphore new.
	process := [ self sort: array with: [ :a :b | semaphore wait. a <= b ] ] forkAt: Processor activePriority + 1.
	self deny: process isTerminated.
	self sortBackend ~~ #smalltalk ifTrue: [ self assert: TimSort liveCoroutines equals: 1 ].
	process terminate.
	self assert: process isTerminated.
	self assert: TimSort liveCoroutines equals: 0.
	self assert: array asBag equals: original asBag.
	self sortBackend ~~ #smalltalk ifTrue: [ self assert: array equals: original ]
]

{ #category : 'tests' }
TimSortBlockTests >> testTerminatedByAnotherProcessAtAnyMoment [
	"A Process terminated by another one at any moment of its sorts, also between the opening of a resumable sort and the assignment of its id, leaves no resumable sort live"

	300 timesRepeat: [
		| process |
		process := [ [ self sort: #( 2 1 ) copy with: [ :a :b | a <= b ] ] repeat ] forkAt: Processor userBackgroundPriority.
		(Delay forMilliseconds: 1) wait.
		process terminate ].
	self assert: TimSort liveCoroutines equals: 0
]

{ #category : 'tests' }
TimSortBlockTests >> testRestartOfTheFrameOfTheBlock [
	"The Restart of the debugger on the frame that evaluates the sortBlock (the sender of the context of the block) evaluates the block again on the comparison the sort waits for: the result is still Pharo's"

	| input array count frame done process |
	input := #( 5 3 8 1 9 2 7 4 6 10 15 12 11 14 13 ).
	#( 2 6 20 ) do: [ :stop |
		array := input copy.
		count := 0.
		frame := nil.
		done := Semaphore new.
		process := [
		           self sort: array with: [ :a :b |
			           (count := count + 1) = stop ifTrue: [
				           frame := thisContext sender.
				           Processor activeProcess suspend ].
			           a <= b ].
		           done signal ] forkAt: Processor activePriority + 1.
		self assert: process isSuspended.
		process popTo: frame.
		process restartTop.
		process resume.
		self deny: (done waitTimeoutMilliseconds: 5000).
		self assert: array equals: (input copy sort: [ :a :b | a <= b ]) ]
]

{ #category : 'tests' }
TimSortBlockTests >> testTwoProcesses [
	"Two sorts by a sortBlock interleaved, comparison by comparison, in two Processes"

	| random arrays done results |
	random := self random.
	arrays := (1 to: 2) collect: [ :i | (1 to: 500) collect: [ :j | random nextInteger: 100 ] ].
	done := Semaphore new.
	results := Array new: 2.
	1 to: 2 do: [ :i |
		[
		results at: i put: (self sort: (arrays at: i) copy with: [ :a :b |
				 Processor yield.
				 a <= b ]).
		done signal ] forkAt: Processor activePriority - 1 ].
	2 timesRepeat: [ self deny: (done waitTimeoutSeconds: 60) ].
	1 to: 2 do: [ :i | self assert: (results at: i) sameAs: ((arrays at: i) copy sort: [ :a :b | a <= b ]) ]
]

{ #category : 'tests' }
TimSortBlockTests >> testWarningsResumed [
	| random array count result |
	random := self random.
	array := (1 to: 1000) collect: [ :i | random nextInteger: 300 ].
	count := 0.
	result := [
	          self sort: array copy with: [ :a :b |
		          (count := count + 1) \\ 10 = 0 ifTrue: [ Warning signal: 'comparison ' , count printString ].
		          a <= b ] ]
		          on: Warning
		          do: [ :warning | warning resume: nil ].
	self assert: count > 1000.
	self assert: result sameAs: (array copy sort: [ :a :b | a <= b ])
]
