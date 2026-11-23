"
I test `TimSort`: Numeric buffers (mode b), by value with every NaN last (first descending), against Pharo's sort with the equivalent sortBlocks, bit for bit, per backend.
"
Class {
	#name : 'TimSortBufferTests',
	#superclass : 'TimSortBackendTestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortBufferTests >> assertSortsLikePharo: aBuffer [
	"Ascending and descending, whole and on a range, bit for bit"

	| kind n |
	kind := TimSort kindOf: aBuffer.
	self assert: kind notNil.
	self assert: (TimSort sort: aBuffer copy) sameBitsAs: (aBuffer copy sort: (self ascendingFor: kind)).
	self assert: (TimSort sortDescending: aBuffer copy) sameBitsAs: (aBuffer copy sort: (self descendingFor: kind)).
	n := aBuffer size.
	n >= 4 ifTrue: [
		self
			assert: (TimSort sortBuffer: aBuffer copy from: 2 to: n - 1 descending: false)
			sameBitsAs: (aBuffer copy mergeSortFrom: 2 to: n - 1 by: (self ascendingFor: kind); yourself).
		self
			assert: (TimSort sortBuffer: aBuffer copy from: 2 to: n - 1 descending: true)
			sameBitsAs: (aBuffer copy mergeSortFrom: 2 to: n - 1 by: (self descendingFor: kind); yourself) ]
]

{ #category : 'helpers' }
TimSortBufferTests >> ascendingFor: kind [
	^ (self isFloatKind: kind)
		  ifTrue: [ TimSortTestData nanLast ]
		  ifFalse: [ [ :a :b | a <= b ] ]
]

{ #category : 'helpers' }
TimSortBufferTests >> bufferClasses [
	"The classes of numeric buffers of the image"

	^ (#( #Float64Array #Float32Array #DoubleWordArray #IntegerArray #WordArray #Bitmap #DoubleByteArray #ByteArray )
		   collect: [ :each | Smalltalk globals at: each ifAbsent: [ nil ] ]) reject: [ :each | each isNil ]
]

{ #category : 'helpers' }
TimSortBufferTests >> descendingFor: kind [
	^ (self isFloatKind: kind)
		  ifTrue: [ TimSortTestData nanFirstDescending ]
		  ifFalse: [ [ :a :b | a >= b ] ]
]

{ #category : 'helpers' }
TimSortBufferTests >> isFloatKind: kind [
	^ kind = TimSort kindFloat64 or: [ kind = TimSort kindFloat32 ]
]

{ #category : 'helpers' }
TimSortBufferTests >> new: aClass size: n random: random [
	"A buffer of n random elements of the range of its kind, with many ties, and with the extremes, NaN, infinities and -0.0 for the floats"

	| kind buffer max values |
	kind := TimSort kindOf: (aClass new: 0).
	buffer := aClass new: n.
	(self isFloatKind: kind) ifTrue: [
		values := {
			          Float nan.
			          Float infinity.
			          Float negativeInfinity.
			          -0.0.
			          0.0.
			          1.5.
			          -2.25.
			          1.0e30.
			          -1.0e-30 }.
		1 to: n do: [ :i |
			buffer at: i put: ((random nextInteger: 3) = 1
					 ifTrue: [ values atRandom: random ]
					 ifFalse: [ ((random nextInteger: 64) - 32) / 4.0 ]) ].
		^ buffer ].
	max := #( 0 0 0 18446744073709551615 0 4294967295 65535 255 ) at: kind.
	kind = TimSort kindInt32 ifTrue: [
		values := { -2147483648. 2147483647. 0. -1. 1 }.
		1 to: n do: [ :i |
			buffer at: i put: ((random nextInteger: 3) = 1
					 ifTrue: [ values atRandom: random ]
					 ifFalse: [ (random nextInteger: 2001) - 1001 * ((random nextInteger: 2) = 1 ifTrue: [ 1 ] ifFalse: [ 1000000 ]) ]) ].
		^ buffer ].
	values := {
		          0.
		          max.
		          max // 2.
		          max // 2 + 1.
		          1 }.
	1 to: n do: [ :i |
		buffer at: i put: ((random nextInteger: 3) = 1
				 ifTrue: [ values atRandom: random ]
				 ifFalse: [ (random nextInteger: (max min: 1000) + 1) - 1 * ((random nextInteger: 2) = 1 ifTrue: [ 1 ] ifFalse: [ max // 1000 max: 1 ]) ]) ].
	^ buffer
]

{ #category : 'tests' }
TimSortBufferTests >> testEachKind [
	| random |
	random := self random.
	self bufferClasses do: [ :class |
		#( 0 1 2 3 5 16 33 64 65 300 1000 4097 ) do: [ :n | self assertSortsLikePharo: (self new: class size: n random: random) ] ]
]

{ #category : 'tests' }
TimSortBufferTests >> testExtensionSelectors [
	| buffer sorted |
	buffer := Float64Array withAll: #( 3.0 -1.0 2.0 ).
	sorted := buffer timSorted.
	self assert: sorted asArray equals: #( -1.0 2.0 3.0 ).
	self assert: buffer asArray equals: #( 3.0 -1.0 2.0 ).
	self assert: buffer timSortDescending asArray equals: #( 3.0 2.0 -1.0 ).
	self assert: buffer timSort asArray equals: #( -1.0 2.0 3.0 ).
	self assert: (ByteArray withAll: #( 3 1 2 )) timSort equals: #[ 1 2 3 ].
	self assert: (TimSort sortBuffer: (WordArray withAll: #( 4000000000 7 ))) asArray equals: #( 7 4000000000 )
]

{ #category : 'tests' }
TimSortBufferTests >> testFloat32NaNBits [
	"NaNs of any sign and payload come last, in their order, with their bits"

	| buffer nanA nanB expected |
	nanA := 16rFFC00000.
	nanB := 16r7FC00001.
	buffer := Float32Array new: 5.
	buffer at: 1 put: 3.0.
	buffer basicAt: 2 put: nanA.
	buffer at: 3 put: -1.0.
	buffer basicAt: 4 put: nanB.
	buffer at: 5 put: -0.0.
	expected := Float32Array new: 5.
	expected at: 1 put: -1.0.
	expected at: 2 put: -0.0.
	expected at: 3 put: 3.0.
	expected basicAt: 4 put: nanA.
	expected basicAt: 5 put: nanB.
	self assert: (TimSort sort: buffer copy) sameBitsAs: expected.
	expected := Float32Array new: 5.
	expected basicAt: 1 put: nanA.
	expected basicAt: 2 put: nanB.
	expected at: 3 put: 3.0.
	expected at: 4 put: -0.0.
	expected at: 5 put: -1.0.
	self assert: (TimSort sortDescending: buffer copy) sameBitsAs: expected
]

{ #category : 'tests' }
TimSortBufferTests >> testFloat64NaNsAndZeros [
	| buffer expected |
	buffer := Float64Array new: 7.
	buffer at: 1 put: 0.0.
	buffer basicAt: 2 put: 16r7FF0000000000001. "a signalling NaN"
	buffer at: 3 put: -0.0.
	buffer at: 4 put: Float nan.
	buffer at: 5 put: Float negativeInfinity.
	buffer basicAt: 6 put: 16r7FF8000000000005.
	buffer at: 7 put: 0.0.
	expected := Float64Array new: 7.
	expected at: 1 put: Float negativeInfinity.
	expected at: 2 put: 0.0.
	expected at: 3 put: -0.0.
	expected at: 4 put: 0.0.
	expected basicAt: 5 put: 16r7FF0000000000001.
	expected at: 6 put: Float nan.
	expected basicAt: 7 put: 16r7FF8000000000005.
	self assert: (TimSort sort: buffer copy) sameBitsAs: expected
]

{ #category : 'tests' }
TimSortBufferTests >> testKinds [
	self assert: (TimSort kindOf: Float64Array new) equals: TimSort kindFloat64.
	self assert: (TimSort kindOf: Float32Array new) equals: TimSort kindFloat32.
	self assert: (TimSort kindOf: DoubleWordArray new) equals: TimSort kindUInt64.
	self assert: (TimSort kindOf: IntegerArray new) equals: TimSort kindInt32.
	self assert: (TimSort kindOf: WordArray new) equals: TimSort kindUInt32.
	self assert: (TimSort kindOf: Bitmap new) equals: TimSort kindUInt32.
	self assert: (TimSort kindOf: DoubleByteArray new) equals: TimSort kindUInt16.
	self assert: (TimSort kindOf: ByteArray new) equals: TimSort kindUInt8.
	self assert: (TimSort kindOf: Array new) isNil.
	self assert: (TimSort kindOf: 'abc') isNil.
	self assert: (TimSort kindOf: Object >> #printString) isNil.
	self assert: (TimSort kindOf: (2 raisedTo: 100)) isNil
]

{ #category : 'tests' }
TimSortBufferTests >> testNotABuffer [
	self should: [ TimSort sortBuffer: #( 3 1 2 ) copy ] raise: Error.
	self should: [ TimSort sortBuffer: 'cba' copy ] raise: Error
]

{ #category : 'tests' }
TimSortBufferTests >> testRanges [
	| buffer |
	buffer := IntegerArray withAll: #( 9 8 7 6 5 4 ).
	TimSort sortBuffer: buffer from: 2 to: 4 descending: false.
	self assert: buffer asArray equals: #( 9 6 7 8 5 4 ).
	TimSort sortBuffer: buffer from: 3 to: 2 descending: false.
	self assert: buffer asArray equals: #( 9 6 7 8 5 4 ).
	self should: [ TimSort sortBuffer: buffer from: 0 to: 2 descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort sortBuffer: buffer from: 2 to: 7 descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort sortBuffer: buffer from: 4 to: 2 descending: false ] raise: SubscriptOutOfBounds.
	self assert: buffer asArray equals: #( 9 6 7 8 5 4 )
]

{ #category : 'tests' }
TimSortBufferTests >> testReadOnly [
	"Read-only buffers are refused before anything is touched, also a Float64Array, which Pharo's sort changes anyway"

	| buffer |
	buffer := Float64Array withAll: #( 3.0 1.0 2.0 ).
	buffer beReadOnlyObject.
	self should: [ buffer timSort ] raise: ModificationForbidden.
	self should: [ TimSort sortBuffer: buffer ] raise: ModificationForbidden.
	self should: [ buffer timSortDescending ] raise: ModificationForbidden.
	self assert: buffer asArray equals: #( 3.0 1.0 2.0 ).
	self assert: buffer timSorted asArray equals: #( 1.0 2.0 3.0 ).
	buffer beWritableObject
]

{ #category : 'tests' }
TimSortBufferTests >> testUInt64AndInt32Extremes [
	| words ints |
	words := DoubleWordArray new: 4.
	words at: 1 put: (2 raisedTo: 63).
	words at: 2 put: (2 raisedTo: 64) - 1.
	words at: 3 put: 0.
	words at: 4 put: (2 raisedTo: 63) - 1.
	self assert: (TimSort sort: words copy) asArray equals: { 0. (2 raisedTo: 63) - 1. 2 raisedTo: 63. (2 raisedTo: 64) - 1 }.
	ints := IntegerArray withAll: { 2147483647. -2147483648. -1. 0 }.
	self assert: (TimSort sort: ints copy) asArray equals: #( -2147483648 -1 0 2147483647 ).
	self assert: (TimSort sortDescending: ints copy) asArray equals: #( 2147483647 0 -1 -2147483648 )
]
