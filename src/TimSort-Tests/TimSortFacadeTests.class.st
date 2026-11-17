"
I test TimSort: The facade with a scripted backend: each failure of a backend, the fallback to TimSortPortBackend, and the loop of the resumable sort (its requests, answers, permutation and freeing), which runs only when sort:with:backend: names it: a scripted backend is named #ffi (TimSort backend), and timSort: never touches it.
"
Class {
	#name : 'TimSortFacadeTests',
	#superclass : 'TestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortFacadeTests >> script: aDictionary [
	| backend |
	backend := TimSortScriptedBackend answering: aDictionary.
	TimSort testHook: #backend value: backend.
	^ backend
]

{ #category : 'helpers' }
TimSortFacadeTests >> blockSort: aCollection with: aBlock [
	"Sort explicitly with the resumable sort of the scripted backend, the chosen one, whose name is #ffi"

	^ TimSort sort: aCollection with: aBlock backend: TimSort backend
]

{ #category : 'helpers' }
TimSortFacadeTests >> scriptCoroutines: aDictionary [
	| backend |
	backend := TimSortScriptedBackend answering: aDictionary.
	backend coroutines: true.
	TimSort testHook: #backend value: backend.
	^ backend
]

{ #category : 'running' }
TimSortFacadeTests >> tearDown [
	TimSort
		testHook: #backend value: nil;
		testHook: #pluginMissing value: nil;
		testHook: #fallbackMissing value: nil;
		testHook: #session value: nil.
	super tearDown
]

{ #category : 'tests' }
TimSortFacadeTests >> testBlockSortFailuresRunThePort [
	"Whatever the resumable sort answers but a permutation, TimSortSmalltalk sorts, and the sort is freed once when it was made"

	| backend array |
	{
		{ #blockSortNew: -> { TimSortFailure on: #'inappropriate operation' } }.
		{ #blockSortNew: -> #( 7 ). #blockSortNext: -> #( -2 ) }.
		{ #blockSortNew: -> #( 7 ). #blockSortNext: -> #( -3 ) }.
		{ #blockSortNew: -> #( 7 ). #blockSortNext: -> { 1. TimSortFailure on: #'not found' } }.
		{ #blockSortNew: -> #( 7 ). #blockSortNext: -> #( -1 ). #blockSortPermutation: -> { TimSortFailure on: #'inappropriate operation' } } } do: [ :script |
		backend := self scriptCoroutines: script asDictionary.
		array := #( 3 1 2 ) copy.
		self assert: (self blockSort: array with: [ :a :b | a <= b ]) equals: #( 1 2 3 ).
		(backend callsOf: #blockSortNew:) first first = 3 ifFalse: [ self fail ].
		self assert: (backend callsOf: #blockSortFree:) size equals: ((script includes: #blockSortNew: -> #( 7 )) ifTrue: [ 1 ] ifFalse: [ 0 ]).
		(backend callsOf: #blockSortFree:) do: [ :arguments | self assert: arguments equals: #( 7 ) ] ]
]

{ #category : 'tests' }
TimSortFacadeTests >> testBlockSortFreedOnError [
	| backend |
	backend := self scriptCoroutines: {
			           (#blockSortNew: -> #( 9 )).
			           (#blockSortNext: -> { 1 bitShift: 32 }) } asDictionary.
	self should: [ self blockSort: #( 3 1 2 ) copy with: [ :a :b | 1 / 0 ] ] raise: ZeroDivide.
	self assert: (backend callsOf: #blockSortFree:) equals: (OrderedCollection with: #( 9 ))
]

{ #category : 'tests' }
TimSortFacadeTests >> testBlockSortOfAnotherSession [
	"A Process saved while its sortBlock ran comes back in a new session (hook #session), where the id of its resumable sort is one of an earlier load of the plugin, which names no live sort (#'not found'): TimSortSmalltalk sorts the untouched collection, and the facade does not free that id, which could name a sort of another Process of this session"

	| backend array |
	backend := self scriptCoroutines: {
			           (#blockSortNew: -> #( 7 )).
			           (#blockSortNext: -> {
				            ((1 bitShift: 32) + 0).
				            (TimSortFailure on: #'not found') }).
			           (#blockSortPermutation: -> { #( 2 3 1 ) }) } asDictionary.
	array := #( 3 1 2 ) copy.
	self blockSort: array with: [ :a :b |
		(TimSort testHook: #session) ifNil: [ TimSort testHook: #session value: Object new ].
		a <= b ].
	self assert: array equals: #( 1 2 3 ).
	self assert: (backend callsOf: #blockSortNext:) size equals: 2.
	self assert: (backend callsOf: #blockSortPermutation:) isEmpty.
	self assert: (backend callsOf: #blockSortFree:) isEmpty
]

{ #category : 'tests' }
TimSortFacadeTests >> testBlockSortProtocol [
	"A request (i << 32) | j asks whether element i + 1 must come strictly before element j + 1: the block is asked whether j + 1 may come before i + 1, and 0 answers yes, 1 no.  The permutation (1-based) is applied to the range at the end"

	| backend array asked |
	backend := self scriptCoroutines: {
			           (#blockSortNew: -> #( 5 )).
			           (#blockSortNext: -> { (2 bitShift: 32) + 0. (0 bitShift: 32) + 1. -1 }).
			           (#blockSortPermutation: -> { #( 3 1 2 ) }) } asDictionary.
	array := #( #x #a #b #c #y ) copy.
	asked := OrderedCollection new.
	self assert: TimSort backend equals: #ffi.
	TimSort sort: array from: 2 to: 4 with: [ :a :b |
		asked add: { a. b }.
		a == #a ] backend: #ffi.
	self assert: asked asArray equals: #( #( #a #c ) #( #b #a ) ).
	self assert: ((backend callsOf: #blockSortNext:) collect: [ :each | each last ]) asArray equals: #( 0 0 1 ).
	self assert: (backend callsOf: #blockSortNew:) first equals: #( 3 false ).
	self assert: array equals: #( #x #c #a #b #y ).
	self assert: (backend callsOf: #blockSortFree:) equals: (OrderedCollection with: #( 5 ))
]

{ #category : 'tests' }
TimSortFacadeTests >> testDefaultNeverTouchesTheResumableSort [
	"timSort:, timSorted:, sort:with: and sort:from:to:with: (and sort:with:backend: #smalltalk) run TimSortSmalltalk although the chosen backend has a resumable sort: no blockSort call reaches it"

	| backend |
	backend := self scriptCoroutines: { (#blockSortNew: -> #( 7 )) } asDictionary.
	self assert: TimSort blockSortBackend equals: #smalltalk.
	self assert: (TimSort resumableBackends includes: #ffi).
	self assert: (#( 3 1 2 ) copy timSort: [ :a :b | a <= b ]) equals: #( 1 2 3 ).
	self assert: (#( 3 1 2 ) timSorted: [ :a :b | a >= b ]) equals: #( 3 2 1 ).
	self assert: (TimSort sort: #( 3 1 2 ) copy with: [ :a :b | a <= b ]) equals: #( 1 2 3 ).
	self assert: (TimSort sort: #( 9 3 1 2 9 ) copy from: 2 to: 4 with: [ :a :b | a <= b ]) equals: #( 9 1 2 3 9 ).
	self assert: (TimSort sort: #( 3 1 2 ) copy with: [ :a :b | a <= b ] backend: #smalltalk) equals: #( 1 2 3 ).
	self assert: ((OrderedCollection withAll: #( 3 1 2 )) timSort: [ :a :b | a <= b ]) asArray equals: #( 1 2 3 ).
	self assert: ((#( 3 1 2 ) asSortedCollection: [ :a :b | a >= b ]) timSort: [ :a :b | a <= b ]) asArray equals: #( 1 2 3 ).
	self assert: (backend calls select: [ :each | each key beginsWith: 'blockSort' ]) isEmpty.
	self assert: (self blockSort: #( 3 1 2 ) copy with: [ :a :b | a <= b ]) equals: #( 1 2 3 ).
	self assert: (backend callsOf: #blockSortNew:) equals: (OrderedCollection with: #( 3 false ))
]

{ #category : 'tests' }
TimSortFacadeTests >> testUnavailableBackends [
	"sort:with:backend: of a backend without a resumable sort signals TimSortBackendUnavailable, the collection untouched and no blockSort call made"

	| backend array error |
	backend := self script: Dictionary new.
	array := #( 3 1 2 ) copy.
	error := [ TimSort sort: array with: [ :a :b | a <= b ] backend: #ffi. nil ]
		         on: TimSortBackendUnavailable
		         do: [ :e | e ].
	self assert: error backendName equals: #ffi.
	self assert: (error messageText includesSubstring: '#ffi').
	self assert: array equals: #( 3 1 2 ).
	self assert: (backend calls select: [ :each | each key beginsWith: 'blockSort' ]) isEmpty.
	error := [ TimSort sort: array from: 1 to: 2 with: [ :a :b | a <= b ] backend: #quick. nil ]
		         on: TimSortBackendUnavailable
		         do: [ :e | e ].
	self assert: error backendName equals: #quick.
	self assert: (error messageText includesSubstring: '#smalltalk').
	self assert: array equals: #( 3 1 2 ).
	"(before the read-only check and the range check)"
	array beReadOnlyObject.
	self should: [ TimSort sort: array from: 0 to: 9 with: [ :a :b | a <= b ] backend: #nothing ] raise: TimSortBackendUnavailable.
	array beWritableObject.
	self assert: (TimSort sort: array with: [ :a :b | a <= b ] backend: #smalltalk) equals: #( 1 2 3 )
]

{ #category : 'tests' }
TimSortFacadeTests >> testFailuresRunThePort [
	"A backend that declines or fails leaves the sort to TimSortPortBackend"

	#( #'bad argument' #'insufficient C memory' #'not found' #'unsupported operation' nil ) do: [ :ec |
		| backend |
		backend := self script: {
				           (#sortObjects: -> { TimSortFailure on: ec }).
				           (#sortBuffer: -> { TimSortFailure on: ec }).
				           (#argSort: -> { TimSortFailure on: ec }) } asDictionary.
		self assert: #( 3 1 2 ) copy timSort equals: #( 1 2 3 ).
		self assert: (ByteArray withAll: #( 3 1 2 )) timSort equals: #[ 1 2 3 ].
		self assert: (TimSort argSort: #( 30 10 20 )) equals: #( 2 3 1 ).
		self assert: (backend calls collect: [ :each | each key ]) asArray equals: #( #sortObjects: #sortBuffer: #argSort: ) ]
]

{ #category : 'tests' }
TimSortFacadeTests >> testSignalledFailures [
	self script: { (#sortObjects: -> { TimSortFailure on: #'no modification' }) } asDictionary.
	self should: [ #( 3 1 2 ) copy timSort ] raise: ModificationForbidden.
	self script: { (#sortObjects: -> { TimSortFailure on: #'bad index' }) } asDictionary.
	self should: [ #( 3 1 2 ) copy timSort ] raise: SubscriptOutOfBounds.
	self script: { (#sortBuffer: -> { TimSortFailure on: #'no modification' }) } asDictionary.
	self should: [ (ByteArray withAll: #( 3 1 2 )) timSort ] raise: ModificationForbidden
]

{ #category : 'tests' }
TimSortFacadeTests >> testWhatTheBackendIsGiven [
	| backend |
	backend := self script: Dictionary new.
	#( 3 1 2 ) copy timSortDescending.
	self assert: (backend callsOf: #sortObjects:) first equals: { #( 3 2 1 ). 1. 3. true. TimSort stringClasses }.
	TimSort sortBuffer: (Float32Array withAll: #( 2.0 1.0 3.0 )) from: 2 to: 3 descending: false.
	self assert: ((backend callsOf: #sortBuffer:) first allButFirst) equals: { TimSort kindFloat32. 2. 3. false }.
	TimSort argSort: (IntegerArray withAll: #( 5 4 3 )) from: 1 to: 2 descending: true.
	self assert: ((backend callsOf: #argSort:) first allButFirst: 3) equals: #( 1 2 true ).
	self assert: (backend callsOf: #argSort:) first second equals: TimSort kindInt32.
	(OrderedCollection withAll: #( 0 0 5 4 )) removeFirst: 2; timSort.
	self assert: (backend callsOf: #sortObjects:) last first class identicalTo: Array.
	self assert: ((backend callsOf: #sortObjects:) last in: [ :arguments | (arguments at: 3) - (arguments at: 2) ]) equals: 1.
	#( 'b' 'a' ) copy timSortBy: [ :each | each ].
	self assert: (backend callsOf: #argSort:) last second isNil
]
