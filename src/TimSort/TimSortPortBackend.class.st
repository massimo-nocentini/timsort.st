"
I am the `#smalltalk` backend of `TimSort`: I answer the backend protocol (the one of `TimSortPrimitives`) with `TimSortSmalltalk`, the port of timsort.c to Smalltalk (package `TimSort-Smalltalk`), so that every backend runs the same algorithm. I never decline: the facade runs me when the plugin and the library are missing, and for every call that they decline (elements that are not all numbers or all strings, NaN among objects, a failed allocation in C...).

## The orders

- **objects** (`sortObjects:...`, and `argSort:...` of an `Array` of keys) by the sortBlock `[ :a :b | a <= b ]`, descending `[ :a :b | a >= b ]`: exactly Pharo's `sort` and `sort: [ :a :b | a >= b ]`, including what the comparisons do with elements that are not comparable (an error, or NaN anywhere). A `Float` and an `Integer` are compared exactly, as the image code compares them (`is:lessOrEqual:`), also on the JIT of the native VM, whose compiled `Float` comparison rounds a `SmallInteger` beyond 2^53 to a double: so the order of numbers is the plugin's on every VM. Only a range that holds both a `Float` and such a `SmallInteger` needs it (`sortBlockFor:from:to:descending:`), so the others keep Pharo's plain sortBlocks and their speed;
- **numeric buffers** (`sortBuffer:...`, and `argSort:...` of a buffer of keys) by value, every NaN after every number and the NaNs equal to each other, -0.0 equal to 0.0: the order of the C engine (`lessThanForKind:`), descending with the reverse flag of timsort (NaN first). The elements keep their bits, as in C.

## Same results as in C

Since I am the same algorithm as the C sort, I give the same result as the plugin and the library for the same comparison answers, also for inconsistent orders. The resumable sort (`blockSort...`) is not mine: the facade sorts by a sortBlock with `TimSortSmalltalk` directly, by default on every VM (`TimSort blockSortBackend`).
"
Class {
	#name : 'TimSortPortBackend',
	#superclass : 'Object',
	#category : 'TimSort-Backends',
	#package : 'TimSort',
	#tag : 'Backends'
}

{ #category : 'backend protocol' }
TimSortPortBackend class >> sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes [
	"As primitiveSortObjects, by the sortBlocks of Pharo's sort (exact between Floats and Integers)"

	^ TimSortSmalltalk
		sort: anArray
		from: start
		to: stop
		by: (self sortBlockFor: anArray from: start to: stop descending: aBoolean)
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean [
	"As primitiveSortBuffer.  The elements are read with at: into an Array, sorted there, and written back with at:put:, which keeps their bits, except in a Float32Array: there at: and at:put: convert between binary32 and binary64, which may change the bits of a NaN, so the permutation of argSort:... is applied to the raw elements (basicAt:)"

	| n values sorter perm raw |
	n := stop - start + 1.
	n < 2 ifTrue: [ ^ aBuffer ].
	kind = TimSort kindFloat32 ifFalse: [
		values := Array new: n.
		1 to: n do: [ :k | values at: k put: (aBuffer at: start + k - 1) ].
		sorter := TimSortSmalltalkLessThanSorter lessThan: (self lessThanForKind: kind).
		aBoolean ifTrue: [ sorter beDescending ].
		sorter sort: values.
		1 to: n do: [ :k | aBuffer at: start + k - 1 put: (values at: k) ].
		^ aBuffer ].
	perm := self argSort: aBuffer kind: kind into: (Array new: n) from: start to: stop descending: aBoolean stringClasses: nil.
	raw := Array new: n.
	1 to: n do: [ :k | raw at: k put: (aBuffer basicAt: start + k - 1) ].
	1 to: n do: [ :k | aBuffer basicAt: start + k - 1 put: (raw at: (perm at: k) - start + 1) ].
	^ aBuffer
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes [
	"As primitiveArgSort: perm holds the indices start to stop, sorted stably by the keys.  The keys of a buffer are read once"

	| n values lessThan sorter |
	n := stop - start + 1.
	1 to: n do: [ :k | perm at: k put: start + k - 1 ].
	n < 2 ifTrue: [ ^ perm ].
	kindOrNil ifNil: [
		(self needsExactOrder: keys from: start to: stop) ifFalse: [
			^ TimSortSmalltalk sort: perm by: (aBoolean
					   ifTrue: [ [ :i :j | (keys at: i) >= (keys at: j) ] ]
					   ifFalse: [ [ :i :j | (keys at: i) <= (keys at: j) ] ]) ].
		^ TimSortSmalltalk sort: perm by: (aBoolean
				   ifTrue: [
					   [ :i :j |
					   | a b |
					   a := keys at: i.
					   b := keys at: j.
					   a class == b class
						   ifTrue: [ a >= b ]
						   ifFalse: [ self is: a greaterOrEqual: b ] ] ]
				   ifFalse: [
					   [ :i :j |
					   | a b |
					   a := keys at: i.
					   b := keys at: j.
					   a class == b class
						   ifTrue: [ a <= b ]
						   ifFalse: [ self is: a lessOrEqual: b ] ] ]) ].
	values := Array new: n.
	1 to: n do: [ :k | values at: k put: (keys at: start + k - 1) ].
	lessThan := self lessThanForKind: kindOrNil.
	sorter := TimSortSmalltalkLessThanSorter lessThan: [ :i :j |
		lessThan value: (values at: i - start + 1) value: (values at: j - start + 1) ].
	aBoolean ifTrue: [ sorter beDescending ].
	^ sorter sort: perm
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> coroutinesAvailable [
	"No: the facade sorts by a sortBlock with TimSortSmalltalk directly (sort:with:backend: #smalltalk, the default)"

	^ false
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> blockSortNew: n descending: aBoolean [
	^ TimSortFailure on: #'unsupported operation'
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> blockSortNext: id answer: anInteger [
	^ TimSortFailure on: #'unsupported operation'
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> blockSortPermutation: id into: perm [
	^ TimSortFailure on: #'unsupported operation'
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> blockSortFree: id [
	^ TimSortFailure on: #'unsupported operation'
]

{ #category : 'backend protocol' }
TimSortPortBackend class >> blockSortLive [
	^ 0
]

{ #category : 'orders' }
TimSortPortBackend class >> lessThanForKind: kind [
	"The strict order of the C engine for the elements of a buffer of kind kind: by value; for the float kinds, every NaN after every number and the NaNs equal to each other (a < b is false whenever a NaN is involved, and -0.0 < 0.0 is false)"

	(kind = TimSort kindFloat64 or: [ kind = TimSort kindFloat32 ]) ifTrue: [
		^ [ :a :b | a < b or: [ b isNaN and: [ a isNaN not ] ] ] ].
	^ [ :a :b | a < b ]
]

{ #category : 'orders' }
TimSortPortBackend class >> sortBlockFor: aCollection from: start to: stop descending: aBoolean [
	"The sortBlock of Pharo's sort, or of sort: [ :a :b | a >= b ] when aBoolean, for the elements start to stop of aCollection: the exact one (exactSortBlockDescending:) when they mix Floats with SmallIntegers beyond 2^53, else Pharo's own (sortBlockDescending:), which then answers the same"

	^ (self needsExactOrder: aCollection from: start to: stop)
		  ifTrue: [ self exactSortBlockDescending: aBoolean ]
		  ifFalse: [ self sortBlockDescending: aBoolean ]
]

{ #category : 'orders' }
TimSortPortBackend class >> sortBlockDescending: aBoolean [
	"The sortBlock of Pharo's sort, or of sort: [ :a :b | a >= b ] when aBoolean"

	^ aBoolean
		  ifTrue: [ [ :a :b | a >= b ] ]
		  ifFalse: [ [ :a :b | a <= b ] ]
]

{ #category : 'orders' }
TimSortPortBackend class >> exactSortBlockDescending: aBoolean [
	"The sortBlock of Pharo's sort, or of sort: [ :a :b | a >= b ] when aBoolean, but exact between a Float and an Integer on every VM (is:lessOrEqual:).  Elements of one class are compared by their own <= (>=) directly"

	^ aBoolean
		  ifTrue: [ [ :a :b | a class == b class ifTrue: [ a >= b ] ifFalse: [ self is: a greaterOrEqual: b ] ] ]
		  ifFalse: [ [ :a :b | a class == b class ifTrue: [ a <= b ] ifFalse: [ self is: a lessOrEqual: b ] ] ]
]

{ #category : 'orders' }
TimSortPortBackend class >> needsExactOrder: aCollection from: start to: stop [
	"Whether the elements start to stop of aCollection hold a Float and a SmallInteger beyond 2^53 in magnitude, which the JIT-compiled Float comparisons of the native VM round to a double: only there do Pharo's comparisons and the exact ones differ"

	| float big |
	float := false.
	big := false.
	start to: stop do: [ :k |
		| each |
		each := aCollection at: k.
		each isFloat
			ifTrue: [ float := true ]
			ifFalse: [
				(each class == SmallInteger and: [ (each between: -9007199254740992 and: 9007199254740992) not ]) ifTrue: [
					big := true ] ].
		(float and: [ big ]) ifTrue: [ ^ true ] ].
	^ false
]

{ #category : 'orders' }
TimSortPortBackend class >> is: a lessOrEqual: b [
	"a <= b as the image code compares a Float with an Integer, exactly (Number>>adaptToFloat:andCompare:, with NaN never less or equal), not as the JIT-compiled Float>><= of the native VM, which rounds a SmallInteger beyond 2^53 to a double; anything else by a <= b itself"

	(a isFloat and: [ b isInteger ]) ifTrue: [ ^ b adaptToFloat: a andCompare: #<= ].
	(a isInteger and: [ b isFloat ]) ifTrue: [ ^ a adaptToFloat: b andCompare: #>= ].
	^ a <= b
]

{ #category : 'orders' }
TimSortPortBackend class >> is: a greaterOrEqual: b [
	"a >= b, exactly between a Float and an Integer (is:lessOrEqual:)"

	(a isFloat and: [ b isInteger ]) ifTrue: [ ^ b adaptToFloat: a andCompare: #>= ].
	(a isInteger and: [ b isFloat ]) ifTrue: [ ^ a adaptToFloat: b andCompare: #<= ].
	^ a >= b
]
