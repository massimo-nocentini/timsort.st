"
I am `libTimSortFFI`, the engine and the resumable sort of the `TimSortPlugin` built as a library of their own, which I call through the FFI of the image (`plugins/TimSortPlugin/include/ffi/tsFFI.h` of [pharo-vm](https://github.com/massimo-nocentini/pharo-vm) has the contract). `TimSort` uses me on a VM without the plugin.

## What I sort

My class side answers the backend protocol of `TimSort` as the primitives answer it (`docs/TimSort.md`, Primitive contract): the same results, and a `TimSortFailure` where a primitive fails, after the same checks in the same order. What I sort natively:

- an `Array` (and its subclasses) whose elements in the range are all SmallIntegers: their values are sorted as int64 (`ts_ffi_sort_i64`) and stored back, since equal SmallIntegers are the same object;
- an `Array` whose elements are Floats (not NaN) and SmallIntegers of at most 2^53 in magnitude (each one exactly a double): the doubles are the keys of a permutation (`ts_ffi_argsort_f64`), which puts the elements themselves back in their new order, so that every element keeps its identity (a `BoxedFloat64` is an object) and equal elements keep their order;
- the numeric buffers of the eight kinds of `TimSort` (`TimSort kindFloat64`...), sorted in place by value (`ts_ffi_sort_f64`...), the floats with every NaN last;
- the permutation that sorts such keys (`argSort:...`), stably, the Arrays of keys as above, the buffers of narrow kinds widened to 8-byte keys first;
- the resumable sort of any sortBlock (`blockSortNew:descending:` and the like, `ts_ffi_coro_*`), where the library has a stack switch for this machine (`coroutinesAvailable`), for `TimSort sort:with:backend: #ffi` (`TimSort` sorts by a sortBlock with `TimSortSmalltalk` by default). I keep nothing of the sorts: the library knows their sizes (`ts_ffi_coro_size`), and the id that `blockSortNew:descending:` answers belongs to its caller at once.

Anything else, Strings, LargeIntegers, NaN in an `Array`, Fractions, a mix of SmallIntegers beyond 2^53 and Floats..., is `#'bad argument'`, on which `TimSort` sorts with its Smalltalk backend: the primitive declines the same way the strings and the LargeIntegers excepted, which it sorts.

## Memory

The library sees addresses, not objects. Each call copies what the library reads or writes into buffers of its own, made pinned in old space (`basicNewPinned:`) for that call only and unpinned when it returns, and copies the result back. These buffers are never shared, so no lock is needed (there is none) and no process can unpin what another one still reads; the objects of the caller are never pinned. A buffer of the caller is copied by primitive 105 (the bits as they are: NaN payloads, signed zeros), so it is left untouched when the library fails.

## Threads

Callouts use the default same-thread runner (`FFILibrary>>runner`): the resumable sorts of the library must all be driven from one thread, and the comparisons of a sortBlock are evaluated by the caller, in its own `Process`, between two callouts: the library never calls back.

## Where the library is

I look for the library in the directories of the VM, the image and the system (`FFIUnix64LibraryFinder` and the like), as `libTimSortFFI.so`, `libTimSortFFI.dylib`, `TimSortFFI.dll` or `libTimSortFFI.dll`; `libraryPath:` names it instead.
"
Class {
	#name : 'TimSortLibrary',
	#superclass : 'FFILibrary',
	#classVars : [
		'Availability',
		'LibraryPath'
	],
	#category : 'TimSort-FFI-Library',
	#package : 'TimSort-FFI',
	#tag : 'Library'
}

{ #category : 'backend protocol' }
TimSortLibrary class >> sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes [
	"As primitiveSortObjects"

	^ self uniqueInstance sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes
]

{ #category : 'backend protocol' }
TimSortLibrary class >> sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean [
	"As primitiveSortBuffer"

	^ self uniqueInstance sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean
]

{ #category : 'backend protocol' }
TimSortLibrary class >> argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes [
	"As primitiveArgSort"

	^ self uniqueInstance argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes
]

{ #category : 'backend protocol' }
TimSortLibrary class >> coroutinesAvailable [
	"Whether the library runs resumable sorts on this machine (ts_ffi_coro_supported), asked once a session: the four blockSort selectors work"

	^ self isAvailable and: [ Availability at: 3 ]
]

{ #category : 'backend protocol' }
TimSortLibrary class >> blockSortNew: n descending: aBoolean [
	"As primitiveBlockSortNew"

	^ self uniqueInstance blockSortNew: n descending: aBoolean
]

{ #category : 'backend protocol' }
TimSortLibrary class >> blockSortNext: id answer: anInteger [
	"As primitiveBlockSortNext"

	^ self uniqueInstance blockSortNext: id answer: anInteger
]

{ #category : 'backend protocol' }
TimSortLibrary class >> blockSortPermutation: id into: perm [
	"As primitiveBlockSortPermutation"

	^ self uniqueInstance blockSortPermutation: id into: perm
]

{ #category : 'backend protocol' }
TimSortLibrary class >> blockSortFree: id [
	"As primitiveBlockSortFree"

	^ self uniqueInstance blockSortFree: id
]

{ #category : 'backend protocol' }
TimSortLibrary class >> blockSortLive [
	"The resumable sorts of the library that are not freed yet (ts_ffi_coro_live), as slot 6 of primitiveInfo"

	self coroutinesAvailable ifFalse: [ ^ 0 ].
	^ self uniqueInstance primCoroLive
]

{ #category : 'accessing' }
TimSortLibrary class >> protocol [
	"The version of tsFFI.h that I speak (TS_FFI_PROTOCOL); a library that answers another one is not used"

	^ 1
]

{ #category : 'accessing' }
TimSortLibrary class >> coroutineSupportLimit [
	"The largest n of a resumable sort of the library, 2^31 - 1 (the plugin takes at most 2^28)"

	^ 2147483647
]

{ #category : 'testing' }
TimSortLibrary class >> isAvailable [
	"Whether the library is found and speaks my protocol, asked once a session, with whether it runs resumable sorts"

	(Availability notNil and: [ Availability first == Smalltalk session ]) ifTrue: [ ^ Availability second ].
	Availability := [
		self uniqueInstance primProtocol = self protocol
			ifTrue: [ { Smalltalk session. true. self uniqueInstance primCoroSupported = 1 } ]
			ifFalse: [ { Smalltalk session. false. false } ] ]
		on: Error
		do: [ :error | error return: { Smalltalk session. false. false } ].
	^ Availability second
]

{ #category : 'accessing' }
TimSortLibrary class >> libraryPath [
	"The path of the library, or nil when it is looked for"

	^ LibraryPath
]

{ #category : 'accessing' }
TimSortLibrary class >> libraryPath: aStringOrNil [
	"Use the library at aStringOrNil, or look for it when nil.  The callouts made so far keep the library they found until they are reset, which is done here, and TimSort chooses its backend again.  Once a library is loaded its functions stay in the process: a callout whose library is not found finds them there, until the image is started again.  The resumable sorts of the library that was used are not freed"

	LibraryPath := aStringOrNil.
	Availability := nil.
	self resetCallouts.
	TimSort resetBackend
]

{ #category : 'private' }
TimSortLibrary class >> resetCallouts [
	"Put back the methods of my callouts as written, so that each one is made again, for the library named now, at its next call.  Not FFIMethodRegistry>>resetSingleClass:, which removes the methods from its set while it walks the set: a removal can move a method of mine to a slot already walked, and that callout keeps the library it found"

	| registry methods |
	registry := FFIMethodRegistry uniqueInstance.
	methods := (registry compiledMethods select: [ :each | each methodClass == self ]) asArray.
	methods do: [ :each |
		registry resetMethod: each.
		registry compiledMethods remove: each ifAbsent: [ nil ] ]
]

{ #category : 'accessing' }
TimSortLibrary class >> version [
	"The engine of the library, 'TimSortPlugin 1.0', as slot 2 of primitiveInfo"

	^ self uniqueInstance primVersion
]

{ #category : 'accessing' }
TimSortLibrary class >> timsortVersion [
	"The commit of timsort.c in the library, 'fd70381'"

	^ self uniqueInstance primTimsortVersion
]

{ #category : 'accessing' }
TimSortLibrary class >> coroutineImplementation [
	"The stack switch of the resumable sorts of the library: 'asm-x86_64-sysv', 'asm-aarch64', 'fibers', 'stub' or 'none'"

	^ self uniqueInstance primCoroImpl
]

{ #category : 'backend protocol' }
TimSortLibrary >> sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes [
	"As primitiveSortObjects: the checks of the primitive, then the elements of the range sorted when they are all SmallIntegers (by their values) or Floats and small SmallIntegers (by a permutation of the elements); anything else is #'bad argument'"

	| n family |
	((self isArray: anArray) and: [ self isRange: start to: stop descending: aBoolean ])
		ifFalse: [ ^ self failure: #'bad argument' ].
	(self isStringClasses: classes) ifFalse: [ ^ self failure: #'bad argument' ].
	anArray isReadOnlyObject ifTrue: [ ^ self failure: #'no modification' ].
	(self is: start to: stop in: anArray basicSize) ifFalse: [ ^ self failure: #'bad index' ].
	n := stop - start + 1.
	n < 2 ifTrue: [ ^ anArray ].
	family := self familyOf: anArray from: start to: stop.
	family == #integers ifTrue: [ ^ self sortIntegers: anArray from: start count: n descending: aBoolean ].
	family == #floats ifFalse: [ ^ self failure: #'bad argument' ].
	^ self withFloatKeysOf: anArray from: start count: n do: [ :keys |
		self argSortKeys: keys kind: 1 count: n descending: aBoolean do: [ :indices |
			self permute: anArray from: start count: n by: indices ] ]
]

{ #category : 'backend protocol' }
TimSortLibrary >> sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean [
	"As primitiveSortBuffer: a pinned copy of the range sorted by ts_ffi_sort_<kind>, then copied back into aBuffer"

	| n size |
	(self isKind: kind of: aBuffer) ifFalse: [ ^ self failure: #'bad argument' ].
	(self isRange: start to: stop descending: aBoolean) ifFalse: [ ^ self failure: #'bad argument' ].
	aBuffer isReadOnlyObject ifTrue: [ ^ self failure: #'no modification' ].
	(self is: start to: stop in: aBuffer basicSize) ifFalse: [ ^ self failure: #'bad index' ].
	n := stop - start + 1.
	n < 2 ifTrue: [ ^ aBuffer ].
	size := self bytesOfKind: kind.
	^ self pinned: (self bufferClassFor: size) size: n during: [ :copy :address |
		| status |
		self copyBits: aBuffer from: start count: n into: copy at: 1.
		status := self sort: address count: n kind: kind descending: aBoolean.
		status = 0
			ifTrue: [
				self copyBits: copy from: 1 count: n into: aBuffer at: start.
				aBuffer ]
			ifFalse: [ self failureFor: status ] ]
]

{ #category : 'backend protocol' }
TimSortLibrary >> argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes [
	"As primitiveArgSort: perm, of stop - start + 1 slots, filled with start to stop in the order that sorts the keys (stable): the keys of an Array as in sortObjects:..., the keys of a buffer by their value, those narrower than 8 bytes widened first"

	| n |
	kindOrNil
		ifNil: [ (self isArray: keys) ifFalse: [ ^ self failure: #'bad argument' ] ]
		ifNotNil: [ (self isKind: kindOrNil of: keys) ifFalse: [ ^ self failure: #'bad argument' ] ].
	((self isArray: perm) and: [ self isRange: start to: stop descending: aBoolean ])
		ifFalse: [ ^ self failure: #'bad argument' ].
	(self isStringClasses: classes) ifFalse: [ ^ self failure: #'bad argument' ].
	perm isReadOnlyObject ifTrue: [ ^ self failure: #'no modification' ].
	(self is: start to: stop in: keys basicSize) ifFalse: [ ^ self failure: #'bad index' ].
	n := stop - start + 1.
	(perm basicSize = n and: [ perm ~~ keys ]) ifFalse: [ ^ self failure: #'bad argument' ].
	^ kindOrNil
		ifNil: [ self argSortArray: keys into: perm from: start count: n descending: aBoolean ]
		ifNotNil: [ self argSortBuffer: keys kind: kindOrNil into: perm from: start count: n descending: aBoolean ]
]

{ #category : 'backend protocol' }
TimSortLibrary >> blockSortNew: n descending: aBoolean [
	"As primitiveBlockSortNew: the id of a new resumable sort of n elements (ts_ffi_coro_new); the library takes up to 2^31 - 1 elements, the plugin 2^28.  Nothing is kept here: the id goes straight back to the caller (TimSort class>>blockSort:from:to:with: owns it from then on)"

	| id |
	((n isKindOf: SmallInteger) and: [ (n between: 0 and: self class coroutineSupportLimit) and: [ self isBoolean: aBoolean ] ])
		ifFalse: [ ^ self failure: #'bad argument' ].
	self class coroutinesAvailable ifFalse: [ ^ self failure: #'unsupported operation' ].
	id := self primCoroNew: n descending: (aBoolean ifTrue: [ 1 ] ifFalse: [ 0 ]).
	id > 0 ifTrue: [ ^ id ].
	id = -6 ifTrue: [ ^ self failure: #'inappropriate operation' ].
	^ self failureFor: id
]

{ #category : 'backend protocol' }
TimSortLibrary >> blockSortNext: id answer: anInteger [
	"As primitiveBlockSortNext: the next request of the sort id, (i << 32) | j (0-based), or -1 (done), -2 (no memory), -3 (aborted); #'not found' for an id that is not live"

	| request |
	(id class == SmallInteger and: [ anInteger class == SmallInteger ]) ifFalse: [ ^ self failure: #'bad argument' ].
	"called once a comparison: the library answers -5 itself when it has no resumable sort"
	request := self primCoroNext: id answer: anInteger.
	request = -4 ifTrue: [ ^ self failure: #'not found' ].
	request = -5 ifTrue: [ ^ self failure: #'unsupported operation' ].
	^ request
]

{ #category : 'backend protocol' }
TimSortLibrary >> blockSortPermutation: id into: perm [
	"As primitiveBlockSortPermutation: perm filled with the 1-based indices of the elements in their sorted order, after the checks of the primitive in its order.  The library answers -4 alike for an id that is not live, a wrong size and a sort that is not done, so the size of the sort (ts_ffi_coro_size, -4 when it is not live) tells the first two apart"

	| n |
	((id isKindOf: SmallInteger) and: [ self isArray: perm ]) ifFalse: [ ^ self failure: #'bad argument' ].
	self class coroutinesAvailable ifFalse: [ ^ self failure: #'unsupported operation' ].
	n := self primCoroSize: id.
	n < 0 ifTrue: [ ^ n = -4 ifTrue: [ self failure: #'not found' ] ifFalse: [ self failureFor: n ] ].
	perm basicSize = n ifFalse: [ ^ self failure: #'bad argument' ].
	perm isReadOnlyObject ifTrue: [ ^ self failure: #'no modification' ].
	^ self pinned: ByteArray size: n * 8 during: [ :indices :address |
		| status |
		status := self primCoroPermutation: id into: address count: n.
		status = 0
			ifTrue: [
				0 to: n - 1 do: [ :k | perm at: k + 1 put: (indices int64AtOffset: k * 8) + 1 ].
				perm ]
			ifFalse: [
				status = -4
					ifTrue: [ self failure: #'inappropriate operation' ]
					ifFalse: [ self failureFor: status ] ] ]
]

{ #category : 'backend protocol' }
TimSortLibrary >> blockSortFree: id [
	"As primitiveBlockSortFree: true when the sort id was live and is freed now, false when it was not (freeing twice is no error)"

	| status |
	(id isKindOf: SmallInteger) ifFalse: [ ^ self failure: #'bad argument' ].
	self class coroutinesAvailable ifFalse: [ ^ self failure: #'unsupported operation' ].
	status := self primCoroFree: id.
	status = -5 ifTrue: [ ^ self failure: #'unsupported operation' ].
	^ status = 0
]

{ #category : 'private - checks' }
TimSortLibrary >> isArray: anObject [
	"Whether anObject is an Array or an instance of a subclass of the same format, as the primitives take it (isArray, format 2: not a WeakArray)"

	^ anObject isArray and: [ anObject class instSpec = 2 ]
]

{ #category : 'private - checks' }
TimSortLibrary >> isBoolean: anObject [
	^ anObject == true or: [ anObject == false ]
]

{ #category : 'private - checks' }
TimSortLibrary >> isRange: start to: stop descending: aBoolean [
	"Whether start and stop are SmallIntegers and aBoolean is a Boolean, as the primitives check them"

	^ (start isKindOf: SmallInteger) and: [ (stop isKindOf: SmallInteger) and: [ self isBoolean: aBoolean ] ]
]

{ #category : 'private - checks' }
TimSortLibrary >> is: start to: stop in: size [
	"Whether start to stop is a range of 1 to size, possibly empty (start = stop + 1)"

	^ start >= 1 and: [ stop <= size and: [ start <= (stop + 1) ] ]
]

{ #category : 'private - checks' }
TimSortLibrary >> isStringClasses: classes [
	"Whether classes is as the primitives take it: an Array of 4 classes, TimSort stringClasses; I sort no string, so its classes are not used"

	^ classes isArray and: [ classes size = 4 and: [ classes allSatisfy: [ :each | each isClass ] ] ]
]

{ #category : 'private - checks' }
TimSortLibrary >> isKind: kind of: aBuffer [
	"Whether kind is one of the eight kinds of TimSort and aBuffer an object of its element size, as primitiveSortBuffer checks it: the format of its class, not the class itself (a Float64Array is a buffer of 8-byte integers too), never a CompiledMethod, a BoxedFloat64 or a LargeInteger"

	| spec size |
	((kind isKindOf: SmallInteger) and: [ kind between: 1 and: 8 ]) ifFalse: [ ^ false ].
	(aBuffer isNil or: [ aBuffer class isImmediateClass ]) ifTrue: [ ^ false ].
	(aBuffer isFloat or: [ aBuffer isInteger ]) ifTrue: [ ^ false ].
	spec := aBuffer class instSpec.
	size := self bytesOfKind: kind.
	size = 8 ifTrue: [ ^ spec = 9 ].
	size = 4 ifTrue: [ ^ spec between: 10 and: 11 ].
	size = 2 ifTrue: [ ^ spec between: 12 and: 15 ].
	^ spec between: 16 and: 23
]

{ #category : 'private - checks' }
TimSortLibrary >> familyOf: anArray from: start to: stop [
	"#integers when every element from start to stop is a SmallInteger; #floats when each is a Float that is not NaN, or a SmallInteger that a double holds exactly (at most 2^53 in magnitude), and one at least is a Float; else nil.  The classes are compared exactly, as the plugin does"

	| floats |
	floats := false.
	start to: stop do: [ :index |
		| each class |
		each := anArray at: index.
		class := each class.
		class == SmallInteger
			ifTrue: [ (each between: -9007199254740992 and: 9007199254740992) ifFalse: [ floats ifTrue: [ ^ nil ] ] ]
			ifFalse: [
				((class == SmallFloat64 or: [ class == BoxedFloat64 ]) and: [ each isNaN not ]) ifFalse: [ ^ nil ].
				floats ifFalse: [
					floats := true.
					"a SmallInteger seen before may be beyond 2^53"
					(start to: index - 1) do: [ :before |
						((anArray at: before) between: -9007199254740992 and: 9007199254740992) ifFalse: [ ^ nil ] ] ] ] ].
	^ floats
		ifTrue: [ #floats ]
		ifFalse: [ #integers ]
]

{ #category : 'private - kinds' }
TimSortLibrary >> bytesOfKind: kind [
	"The bytes of an element of kind (TimSort kindFloat64 is 1 ... kindUInt8 8)"

	^ #( 8 4 8 8 4 4 2 1 ) at: kind
]

{ #category : 'private - kinds' }
TimSortLibrary >> bufferClassFor: bytes [
	"The class of my private copies of a buffer of elements of bytes bytes: primitive 105 copies between objects of the same element size, whatever their class"

	bytes = 8 ifTrue: [ ^ DoubleWordArray ].
	bytes = 4 ifTrue: [ ^ WordArray ].
	bytes = 2 ifTrue: [ ^ DoubleByteArray ].
	^ ByteArray
]

{ #category : 'private' }
TimSortLibrary >> sort: address count: n kind: kind descending: aBoolean [
	"The status of ts_ffi_sort_<kind> on the n elements at address"

	| d |
	d := aBoolean ifTrue: [ 1 ] ifFalse: [ 0 ].
	kind = 1 ifTrue: [ ^ self primSortF64: address count: n descending: d ].
	kind = 2 ifTrue: [ ^ self primSortF32: address count: n descending: d ].
	kind = 3 ifTrue: [ ^ self primSortI64: address count: n descending: d ].
	kind = 4 ifTrue: [ ^ self primSortU64: address count: n descending: d ].
	kind = 5 ifTrue: [ ^ self primSortI32: address count: n descending: d ].
	kind = 6 ifTrue: [ ^ self primSortU32: address count: n descending: d ].
	kind = 7 ifTrue: [ ^ self primSortU16: address count: n descending: d ].
	^ self primSortU8: address count: n descending: d
]

{ #category : 'private' }
TimSortLibrary >> sortIntegers: anArray from: start count: n descending: aBoolean [
	"The SmallIntegers of anArray from start sorted as int64 values in a pinned buffer of mine (ts_ffi_sort_i64) and stored back: they are immediate, so equal ones are the same object.  int64AtOffset: and int64AtOffset:put: are exact for SmallIntegers (not beyond, a bug of their primitives in the VM)"

	^ self pinned: ByteArray size: n * 8 during: [ :values :address |
		| status |
		0 to: n - 1 do: [ :k | values int64AtOffset: k * 8 put: (anArray at: start + k) ].
		status := self primSortI64: address count: n descending: (aBoolean ifTrue: [ 1 ] ifFalse: [ 0 ]).
		status = 0
			ifTrue: [
				0 to: n - 1 do: [ :k | anArray at: start + k put: (values int64AtOffset: k * 8) ].
				anArray ]
			ifFalse: [ self failureFor: status ] ]
]

{ #category : 'private' }
TimSortLibrary >> withFloatKeysOf: anArray from: start count: n do: aBlock [
	"The answer of aBlock for the address of a pinned Float64Array of mine holding the n elements of anArray from start as doubles (exactly: Floats, and SmallIntegers of at most 2^53)"

	^ self pinned: Float64Array size: n during: [ :keys :address |
		0 to: n - 1 do: [ :k | keys at: k + 1 put: (anArray at: start + k) asFloat ].
		aBlock value: address ]
]

{ #category : 'private' }
TimSortLibrary >> argSortKeys: keysAddress kind: kind count: n descending: aBoolean do: aBlock [
	"The answer of aBlock for a pinned ByteArray of mine holding the n int64 indices 0 to n - 1 that sort the 8-byte keys at keysAddress (ts_ffi_argsort_<kind>: 1 f64, 3 i64, 4 u64), else the failure for the status of the library"

	^ self pinned: ByteArray size: n * 8 during: [ :indices :address |
		| d status |
		d := aBoolean ifTrue: [ 1 ] ifFalse: [ 0 ].
		status := kind = 1
			ifTrue: [ self primArgSortF64: keysAddress into: address count: n descending: d ]
			ifFalse: [
				kind = 3
					ifTrue: [ self primArgSortI64: keysAddress into: address count: n descending: d ]
					ifFalse: [ self primArgSortU64: keysAddress into: address count: n descending: d ] ].
		status = 0
			ifTrue: [ aBlock value: indices ]
			ifFalse: [ self failureFor: status ] ]
]

{ #category : 'private' }
TimSortLibrary >> permute: anArray from: start count: n by: indices [
	"Put in anArray from start the elements it held there in the order of indices (0-based int64s): element indices[k] goes to position k, kept by identity"

	| elements |
	elements := Array new: n.
	elements replaceFrom: 1 to: n with: anArray startingAt: start.
	0 to: n - 1 do: [ :k | anArray at: start + k put: (elements at: (indices int64AtOffset: k * 8) + 1) ].
	^ anArray
]

{ #category : 'private' }
TimSortLibrary >> argSortArray: keys into: perm from: start count: n descending: aBoolean [
	"perm sorted by the elements of the Array keys from start: by their values when they are all SmallIntegers, as doubles when they are Floats and small SmallIntegers, else #'bad argument'"

	| family |
	n = 0 ifTrue: [ ^ perm ].
	family := self familyOf: keys from: start to: start + n - 1.
	family == #integers ifTrue: [
		^ self pinned: ByteArray size: n * 8 during: [ :values :address |
			0 to: n - 1 do: [ :k | values int64AtOffset: k * 8 put: (keys at: start + k) ].
			self argSortKeys: address kind: 3 count: n descending: aBoolean do: [ :indices |
				self fill: perm from: start by: indices ] ] ].
	family == #floats ifFalse: [ ^ self failure: #'bad argument' ].
	^ self withFloatKeysOf: keys from: start count: n do: [ :address |
		self argSortKeys: address kind: 1 count: n descending: aBoolean do: [ :indices |
			self fill: perm from: start by: indices ] ]
]

{ #category : 'private' }
TimSortLibrary >> argSortBuffer: keys kind: kind into: perm from: start count: n descending: aBoolean [
	"perm sorted by the elements of the buffer keys from start: a copy of the 8-byte kinds, sorted by their own function; the floats of 4 bytes widened to doubles (exactly, NaN still NaN), the integers of 4, 2 and 1 bytes to int64"

	n = 0 ifTrue: [ ^ perm ].
	(self bytesOfKind: kind) = 8 ifTrue: [
		^ self pinned: DoubleWordArray size: n during: [ :copy :address |
			self copyBits: keys from: start count: n into: copy at: 1.
			self argSortKeys: address kind: kind count: n descending: aBoolean do: [ :indices |
				self fill: perm from: start by: indices ] ] ].
	kind = 2 ifTrue: [
		^ self pinned: Float64Array size: n during: [ :copy :address |
			0 to: n - 1 do: [ :k | copy at: k + 1 put: (Float fromIEEE32Bit: (keys basicAt: start + k)) ].
			self argSortKeys: address kind: 1 count: n descending: aBoolean do: [ :indices |
				self fill: perm from: start by: indices ] ] ].
	^ self pinned: ByteArray size: n * 8 during: [ :copy :address |
		kind = 5
			ifTrue: [
				"basicAt: answers the bits unsigned, whatever the class: an IntegerArray and a WordArray given as kind 5 are both read as signed"
				0 to: n - 1 do: [ :k |
					| bits |
					bits := keys basicAt: start + k.
					copy int64AtOffset: k * 8 put: (bits >= 16r80000000
						ifTrue: [ bits - 16r100000000 ]
						ifFalse: [ bits ]) ] ]
			ifFalse: [ 0 to: n - 1 do: [ :k | copy int64AtOffset: k * 8 put: (keys basicAt: start + k) ] ].
		self argSortKeys: address kind: 3 count: n descending: aBoolean do: [ :indices |
			self fill: perm from: start by: indices ] ]
]

{ #category : 'private' }
TimSortLibrary >> fill: perm from: start by: indices [
	"perm at: k + 1 put: start + indices[k], the 1-based indices of the keys in their sorted order"

	0 to: perm basicSize - 1 do: [ :k | perm at: k + 1 put: start + (indices int64AtOffset: k * 8) ].
	^ perm
]

{ #category : 'private' }
TimSortLibrary >> copyBits: source from: start count: n into: destination at: index [
	"Copy n elements of source from start into destination from index, as bits, by primitive 105 (the elements are of one size, whatever the classes: Float64Array and IntegerArray have no primitive replaceFrom:to:with:startingAt:, which at:put: would make slow)"

	| answer |
	n = 0 ifTrue: [ ^ destination ].
	answer := destination tryPrimitive: 105 withArgs: { index. index + n - 1. source. start }.
	answer == destination ifFalse: [
		self error: 'TimSortLibrary: primitive 105 failed on a ' , source class name , ' and a ' , destination class name ].
	^ destination
]

{ #category : 'private' }
TimSortLibrary >> pinned: aClass size: n during: aBlock [
	"The answer of aBlock for a new instance of aClass of n elements, made pinned in old space, and the address of its first element; unpinned once aBlock returns.  The instance is mine only, so no other process pins or unpins it meanwhile"

	| buffer |
	buffer := aClass basicNewPinned: n.
	^ [ aBlock value: buffer value: (PointerUtils oopForObject: buffer) ]
		ensure: [ buffer unpinInMemory ]
]

{ #category : 'private - failures' }
TimSortLibrary >> failure: aSymbol [
	"What a primitive answers when it fails with the error code aSymbol"

	^ TimSortFailure on: aSymbol
]

{ #category : 'private - failures' }
TimSortLibrary >> failureFor: status [
	"The failure of the primitive for a status of the library (tsFFI.h): no memory is #'insufficient C memory', as the plugin's PrimErrNoCMemory; the others, which the checks in Smalltalk make impossible, #'bad argument'"

	status = -2 ifTrue: [ ^ self failure: #'insufficient C memory' ].
	status = -5 ifTrue: [ ^ self failure: #'unsupported operation' ].
	^ self failure: #'bad argument'
]

{ #category : 'accessing - platform' }
TimSortLibrary >> libraryNamed: aString finder: aFinderClass [
	^ LibraryPath ifNil: [ aFinderClass findLibrary: aString ]
]

{ #category : 'accessing - platform' }
TimSortLibrary >> macLibraryName [
	^ self libraryNamed: 'libTimSortFFI.dylib' finder: FFIMacLibraryFinder
]

{ #category : 'accessing - platform' }
TimSortLibrary >> unix64LibraryName [
	^ self unixLibraryName
]

{ #category : 'accessing - platform' }
TimSortLibrary >> unixLibraryName [
	^ self libraryNamed: 'libTimSortFFI.so' finder: FFIUnix64LibraryFinder
]

{ #category : 'accessing - platform' }
TimSortLibrary >> win32LibraryName [
	^ LibraryPath ifNil: [ FFIWindowsLibraryFinder findAnyLibrary: #( 'TimSortFFI.dll' 'libTimSortFFI.dll' ) ]
]

{ #category : 'primitives' }
TimSortLibrary >> primProtocol [
	^ self ffiCall: #( int64 ts_ffi_protocol ( ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primVersion [
	^ self ffiCall: #( String ts_ffi_version ( ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primTimsortVersion [
	^ self ffiCall: #( String ts_ffi_timsort_version ( ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortF64: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_f64 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortF32: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_f32 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortI64: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_i64 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortU64: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_u64 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortI32: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_i32 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortU32: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_u32 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortU16: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_u16 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primSortU8: base count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_sort_u8 ( void * base , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primArgSortI64: keys into: idx count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_argsort_i64 ( void * keys , void * idx , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primArgSortU64: keys into: idx count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_argsort_u64 ( void * keys , void * idx , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primArgSortF64: keys into: idx count: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_argsort_f64 ( void * keys , void * idx , int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroSupported [
	^ self ffiCall: #( int64 ts_ffi_coro_supported ( ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroImpl [
	^ self ffiCall: #( String ts_ffi_coro_impl ( ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroNew: n descending: d [
	^ self ffiCall: #( int64 ts_ffi_coro_new ( int64 n , int64 d ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroNext: id answer: answer [
	^ self ffiCall: #( int64 ts_ffi_coro_next ( int64 id , int64 answer ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroPermutation: id into: dst count: n [
	^ self ffiCall: #( int64 ts_ffi_coro_permutation ( int64 id , void * dst , int64 n ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroFree: id [
	^ self ffiCall: #( int64 ts_ffi_coro_free ( int64 id ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroLive [
	^ self ffiCall: #( int64 ts_ffi_coro_live ( ) )
]

{ #category : 'primitives' }
TimSortLibrary >> primCoroSize: id [
	^ self ffiCall: #( int64 ts_ffi_coro_size ( int64 id ) )
]
