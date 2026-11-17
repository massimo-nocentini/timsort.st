"
I am the backend of the TimSortPlugin: the primitives of the plugin, on my class side, answer the backend protocol of TimSort themselves (docs/TimSort.md, Primitive contract).  A failed primitive answers a TimSortFailure with its error code; primInfo answers nil.

The plugin sorts in place, in C, without allocating and without running Smalltalk, so no garbage collection can happen during a sort:
- sortObjects:...: the slots of an Array whose elements are all numbers (SmallInteger, Float but NaN, normalized LargePositiveInteger and LargeNegativeInteger, compared exactly) or all strings of the four classes of stringClasses (compared by code point); anything else is #'bad argument', and the facade runs TimSortPortBackend;
- sortBuffer:...: the elements of a numeric buffer of a kind (TimSort kindFloat64...), NaN last;
- argSort:...: an Array of the indices start to stop, by keys that are an Array (as sortObjects:) or a buffer (as sortBuffer:);
- blockSortNew:... and the three others: the resumable sort of mode d, one comparison at a time (TimSort sort:with:backend: #plugin, through TimSort class>>blockSort:from:to:with:backend:; timSort: aBlock runs TimSortSmalltalk by default), natively; on WebAssembly they fail with #'unsupported operation'.
"
Class {
	#name : 'TimSortPrimitives',
	#superclass : 'Object',
	#category : 'TimSort-Backends',
	#package : 'TimSort',
	#tag : 'Backends'
}

{ #category : 'primitives' }
TimSortPrimitives class >> primInfo [
	"{ protocol. pluginVersion. timsortVersion. platform ('native' or 'emscripten'). coroutineSupport. liveCoroutines }, or nil without the plugin"

	<primitive: 'primitiveInfo' module: 'TimSortPlugin' error: ec>
	^ nil
]

{ #category : 'primitives' }
TimSortPrimitives class >> sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes [
	"anArray, its elements start to stop sorted in place, or a failure"

	<primitive: 'primitiveSortObjects' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'primitives' }
TimSortPrimitives class >> sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean [
	"aBuffer, its elements start to stop sorted in place, or a failure"

	<primitive: 'primitiveSortBuffer' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'primitives' }
TimSortPrimitives class >> argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes [
	"perm, filled with the indices start to stop sorted by keys, or a failure"

	<primitive: 'primitiveArgSort' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'primitives' }
TimSortPrimitives class >> blockSortNew: n descending: aBoolean [
	"The id of a new resumable sort of n elements, or a failure"

	<primitive: 'primitiveBlockSortNew' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'primitives' }
TimSortPrimitives class >> blockSortNext: id answer: anInteger [
	"The next request (i << 32) | j (0-based), -1 done, -2 no memory, -3 aborted, or a failure"

	<primitive: 'primitiveBlockSortNext' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'primitives' }
TimSortPrimitives class >> blockSortPermutation: id into: perm [
	"perm, filled with the 1-based indices of the finished sort, or a failure"

	<primitive: 'primitiveBlockSortPermutation' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'primitives' }
TimSortPrimitives class >> blockSortFree: id [
	"true when the sort was live and is freed, false when it was not, or a failure"

	<primitive: 'primitiveBlockSortFree' module: 'TimSortPlugin' error: ec>
	^ TimSortFailure on: ec
]

{ #category : 'backend protocol' }
TimSortPrimitives class >> coroutinesAvailable [
	"Whether the resumable sort works: natively, unless the process runs with a shadow stack; never on WebAssembly"

	^ self primInfo
		ifNil: [ false ]
		ifNotNil: [ :info | info size >= 5 and: [ (info at: 5) == true ] ]
]

{ #category : 'backend protocol' }
TimSortPrimitives class >> blockSortLive [
	"The number of live resumable sorts of the plugin"

	^ self primInfo
		ifNil: [ 0 ]
		ifNotNil: [ :info | info at: 6 ]
]
