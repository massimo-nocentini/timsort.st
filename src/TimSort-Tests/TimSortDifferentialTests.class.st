"
I test `TimSort`: The plugin against `TimSortPortBackend` (the same algorithm in Smalltalk) on random calls, and the resumable C sorts (`TimSort sort:with:backend: #plugin`, and `#ffi` when the library has one) against `TimSortSmalltalk` with inconsistent sortBlocks (strict, random, lying), which must make the same comparisons and leave the same permutation; skipped without the plugin (and the resumable sorts without coroutines).
"
Class {
	#name : 'TimSortDifferentialTests',
	#superclass : 'TestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'accessing' }
TimSortDifferentialTests class >> defaultTimeLimit [
	^ 120 seconds
]

{ #category : 'helpers' }
TimSortDifferentialTests >> assert: actual sameAs: expected [
	self assert: actual size equals: expected size.
	1 to: expected size do: [ :i |
		(actual at: i) == (expected at: i) ifFalse: [ self fail: 'slot ' , i printString ] ]
]

{ #category : 'helpers' }
TimSortDifferentialTests >> random [
	^ Random seed: 20261118
]

{ #category : 'running' }
TimSortDifferentialTests >> setUp [
	super setUp.
	TimSort pluginAvailable ifFalse: [ self skip: 'no TimSortPlugin' ]
]

{ #category : 'running' }
TimSortDifferentialTests >> tearDown [
	TimSort testHook: #backend value: nil.
	super tearDown
]

{ #category : 'tests' }
TimSortDifferentialTests >> testArgSortsAndBuffers [
	| random classes |
	random := self random.
	classes := { Float64Array. Float32Array. IntegerArray. WordArray. DoubleByteArray. ByteArray. DoubleWordArray }.
	300 timesRepeat: [
		| class kind n buffer start stop descending a b keys |
		class := classes atRandom: random.
		kind := TimSort kindOf: (class new: 0).
		n := random nextInteger: 200.
		buffer := class new: n.
		1 to: n do: [ :i |
			buffer at: i put: ((kind = TimSort kindFloat64 or: [ kind = TimSort kindFloat32 ])
					 ifTrue: [ (random nextInteger: 5) = 1 ifTrue: [ Float nan ] ifFalse: [ ((random nextInteger: 21) - 11) / 2.0 ] ]
					 ifFalse: [ random nextInteger: 50 ]) ].
		start := random nextInteger: n.
		stop := start - 1 + (random nextInteger: n - start + 2) - 1.
		descending := random next < 0.5.
		a := TimSortPrimitives sortBuffer: buffer copy kind: kind from: start to: stop descending: descending.
		b := TimSortPortBackend sortBuffer: buffer copy kind: kind from: start to: stop descending: descending.
		1 to: n do: [ :i | self assert: (a basicAt: i) equals: (b basicAt: i) ].
		a := TimSortPrimitives argSort: buffer kind: kind into: (Array new: stop - start + 1) from: start to: stop descending: descending stringClasses: TimSort stringClasses.
		b := TimSortPortBackend argSort: buffer kind: kind into: (Array new: stop - start + 1) from: start to: stop descending: descending stringClasses: nil.
		self assert: a equals: b.
		keys := TimSortTestData numbers: n random: random.
		a := TimSortPrimitives argSort: keys kind: nil into: (Array new: stop - start + 1) from: start to: stop descending: descending stringClasses: TimSort stringClasses.
		b := TimSortPortBackend argSort: keys kind: nil into: (Array new: stop - start + 1) from: start to: stop descending: descending stringClasses: nil.
		self assert: a equals: b ]
]

{ #category : 'tests' }
TimSortDifferentialTests >> testInconsistentSortBlocks [
	"The resumable C sorts and TimSortSmalltalk are the same algorithm: given the same answers (a function of the two elements, or the next number of two Randoms of one seed) they make the same comparisons and leave the same permutation"

	(TimSort pluginInfo at: 5) ifFalse: [ ^ self skip: 'no resumable sort' ].
	self assert: TimSort resumableBackend equals: #plugin.
	TimSort resumableBackends do: [ :backend | self inconsistentSortBlocksThrough: backend ]
]

{ #category : 'helpers' }
TimSortDifferentialTests >> inconsistentSortBlocksThrough: aBackend [
	| random |
	random := self random.
	#( 2 3 10 33 64 65 100 300 1000 3000 ) do: [ :n |
		| items seed lieA lieB countA countB |
		items := (1 to: n) collect: [ :i | (random nextInteger: n // 4 + 1) -> i ].
		self
			assert: (TimSort sort: items copy with: [ :a :b | a key < b key ] backend: aBackend)
			sameAs: (TimSortSmalltalk sort: items copy by: [ :a :b | a key < b key ]).
		self
			assert: (TimSort sort: items copy with: [ :a :b | (a value * 7919 + (b value * 104729)) \\ 3 ~= 0 ] backend: aBackend)
			sameAs: (TimSortSmalltalk sort: items copy by: [ :a :b | (a value * 7919 + (b value * 104729)) \\ 3 ~= 0 ]).
		seed := random nextInteger: 1000000.
		lieA := Random seed: seed.
		lieB := Random seed: seed.
		countA := countB := 0.
		self
			assert: (TimSort sort: items copy with: [ :a :b | countA := countA + 1. lieA next < 0.5 ] backend: aBackend)
			sameAs: (TimSortSmalltalk sort: items copy by: [ :a :b | countB := countB + 1. lieB next < 0.5 ]).
		self assert: countA equals: countB.
		lieA := Random seed: seed.
		lieB := Random seed: seed.
		self
			assert: (TimSort sort: items copy with: [ :a :b | (lieA nextInteger: 50) = 1 ifTrue: [ a key > b key ] ifFalse: [ a key <= b key ] ] backend: aBackend)
			sameAs: (TimSortSmalltalk sort: items copy by: [ :a :b | (lieB nextInteger: 50) = 1 ifTrue: [ a key > b key ] ifFalse: [ a key <= b key ] ]) ]
]

{ #category : 'tests' }
TimSortDifferentialTests >> testRandomObjects [
	| random |
	random := self random.
	1000 timesRepeat: [
		| n items start stop descending |
		n := random nextInteger: 120.
		items := (random nextInteger: 2) = 1
			         ifTrue: [ TimSortTestData numbers: n random: random ]
			         ifFalse: [ TimSortTestData strings: n random: random ].
		start := random nextInteger: n.
		stop := start - 1 + (random nextInteger: n - start + 2) - 1.
		descending := random next < 0.5.
		self
			assert: (TimSortPrimitives sortObjects: items copy from: start to: stop descending: descending stringClasses: TimSort stringClasses)
			sameAs: (TimSortPortBackend sortObjects: items copy from: start to: stop descending: descending stringClasses: nil) ]
]
