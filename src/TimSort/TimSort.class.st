"
I am the API of TimSort, on my class side only: [timsort](https://github.com/massimo-nocentini/timsort.c), the stable and adaptive sort of CPython's lists, for the SequenceableCollections of Pharo, in place. The extension methods (`timSort`, `timSortDescending`, `timSort:`, `timSortBy:`, `timSorted`...) call me.

## The four modes

- **the natural order** (`sort:`, `sortDescending:`, `sort:from:to:descending:`): Arrays of numbers or of strings are sorted by the plugin in C, without running Smalltalk; any other element, or an `Array` that mixes them, is sorted by the sortBlock `[ :a :b | a <= b ]` in Smalltalk. The result is exactly Pharo's `sort` (and `sort: [ :a :b | a >= b ]` descending), since both sorts are stable;

```smalltalk
TimSort sort: #( 3 1 2 ) copy.  ""#(1 2 3)""
```

- **numeric buffers** (the same selectors, or `sortBuffer:`): a `Float64Array`, `Float32Array`, `DoubleWordArray`, `IntegerArray`, `WordArray`, `Bitmap`, `DoubleByteArray` or `ByteArray` by value, every NaN last (first descending);

```smalltalk
TimSort sortDescending: (Float64Array withAll: #( 1.5 -2.0 3.0 )).
```

- **by keys computed once** (`sort:byKey:`, `sortDescending:byKey:`), and `argSort:` which answers the permutation that sorts keys;

```smalltalk
TimSort sort: words byKey: [ :each | each size ].
TimSort argSort: #( 30 10 20 ).  ""#(2 3 1)""
```

- **by any sortBlock** (`sort:with:`), exactly Pharo's `sort: aBlock` for a sortBlock in the style of `[ :a :b | a <= b ]`: `TimSortSmalltalk`, the port of timsort.c, sorts on every VM by default (`blockSortBackend`).

```smalltalk
TimSort sort: people with: [ :a :b | a age <= b age ].
```

The resumable C sort, which runs timsort on a C stack of its own and stops at each comparison for the block to answer in the calling `Process`, is the same algorithm with the same result, but it was slower in every case measured: 1.1 to 6.5 times through the plugin, 3.5 to 17 times through the library (each comparison is a primitive call and two switches of stacks, or a callout): `sort:with:backend:` `#plugin` or `#ffi` runs it explicitly, where `resumableBackends` has it.

```smalltalk
TimSort
	sort: people
	with: [ :a :b | a age <= b age ]
	backend: #plugin.
```

## Backends

Each method calls a backend, which answers as the primitives of the `TimSortPlugin` answer (`docs/TimSort.md`, Primitive contract): `TimSortPrimitives` with the plugin, `TimSortLibrary` (the package `TimSort-FFI`) without it, else `TimSortPortBackend`. A backend declines what it does not sort natively (the plugin: anything but numbers or strings; the library: anything but SmallIntegers and Floats), and `TimSortPortBackend` sorts it. The choice is made once a session (`backend`, `resumableBackends`, `resetBackend`).

## Read-only receivers and ranges

Read-only receivers signal `ModificationForbidden` before anything is touched, on every backend (stricter than Pharo's sort of a `Float32Array`, a `Float64Array` or a read-only `OrderedCollection`), with the retry of Pharo's write barrier: a handler that makes the object writable and sends `retryModification` lets the sort go on.

Ranges are 1-based and inclusive; a range out of bounds signals `SubscriptOutOfBounds`.
"
Class {
	#name : 'TimSort',
	#superclass : 'Object',
	#classVars : [
		'BufferKinds',
		'Library',
		'LibraryProbed',
		'PluginInfo',
		'Primary',
		'SessionToken',
		'TestHooks'
	],
	#category : 'TimSort-Facade',
	#package : 'TimSort',
	#tag : 'Facade'
}

{ #category : 'accessing' }
TimSort class >> protocol [
	"TS_PROTOCOL: the protocol of the primitives (primitiveInfo answers it first) and of the library"

	^ 1
]

{ #category : 'kinds' }
TimSort class >> kindFloat64 [
	"TS_KIND_F64: IEEE binary64, a Float64Array"

	^ 1
]

{ #category : 'kinds' }
TimSort class >> kindFloat32 [
	"TS_KIND_F32: IEEE binary32, a Float32Array"

	^ 2
]

{ #category : 'kinds' }
TimSort class >> kindInt64 [
	"TS_KIND_I64: signed 64-bit integers; no class of Pharo 12 to 15 holds them (the keys of the library)"

	^ 3
]

{ #category : 'kinds' }
TimSort class >> kindUInt64 [
	"TS_KIND_U64: unsigned 64-bit integers, a DoubleWordArray"

	^ 4
]

{ #category : 'kinds' }
TimSort class >> kindInt32 [
	"TS_KIND_I32: signed 32-bit integers, an IntegerArray"

	^ 5
]

{ #category : 'kinds' }
TimSort class >> kindUInt32 [
	"TS_KIND_U32: unsigned 32-bit integers, a WordArray or a Bitmap"

	^ 6
]

{ #category : 'kinds' }
TimSort class >> kindUInt16 [
	"TS_KIND_U16: unsigned 16-bit integers, a DoubleByteArray"

	^ 7
]

{ #category : 'kinds' }
TimSort class >> kindUInt8 [
	"TS_KIND_U8: unsigned bytes, a ByteArray"

	^ 8
]

{ #category : 'kinds' }
TimSort class >> kindOf: aCollection [
	"The kind of the numeric buffer aCollection (an instance of one of the classes of bufferKinds or of a subclass, CompiledCode excepted), or nil"

	| class |
	class := aCollection class.
	(class includesBehavior: CompiledCode) ifTrue: [ ^ nil ].
	[ class isNil ] whileFalse: [
		(self bufferKinds at: class ifAbsent: [ nil ]) ifNotNil: [ :kind | ^ kind ].
		class := class superclass ].
	^ nil
]

{ #category : 'kinds' }
TimSort class >> bufferKinds [
	"The classes of numeric buffers and their kinds; a class absent from the image is left out"

	^ BufferKinds ifNil: [
		  | kinds |
		  kinds := IdentityDictionary new.
		  {
			  (#Float64Array -> self kindFloat64).
			  (#Float32Array -> self kindFloat32).
			  (#DoubleWordArray -> self kindUInt64).
			  (#IntegerArray -> self kindInt32).
			  (#WordArray -> self kindUInt32).
			  (#Bitmap -> self kindUInt32).
			  (#DoubleByteArray -> self kindUInt16).
			  (#ByteArray -> self kindUInt8) } do: [ :each |
			  (self environment at: each key ifAbsent: [ nil ]) ifNotNil: [ :class | kinds at: class put: each value ] ].
		  BufferKinds := kinds ]
]

{ #category : 'kinds' }
TimSort class >> stringClasses [
	"The classes whose instances the plugin compares as strings, by code point: exactly these, not their subclasses, which may compare otherwise"

	^ {
		  ByteString.
		  ByteSymbol.
		  WideString.
		  WideSymbol }
]

{ #category : 'natural order' }
TimSort class >> sort: aCollection [
	"Sort aCollection in place by the natural order of its elements and answer it: Pharo's sort"

	^ self sort: aCollection from: 1 to: aCollection size descending: false
]

{ #category : 'natural order' }
TimSort class >> sortDescending: aCollection [
	"Sort aCollection in place by the natural order of its elements, descending, and answer it: Pharo's sort: [ :a :b | a >= b ], equal elements in their order"

	^ self sort: aCollection from: 1 to: aCollection size descending: true
]

{ #category : 'natural order' }
TimSort class >> sort: aCollection from: start to: stop descending: aBoolean [
	"Sort the elements start to stop of aCollection in place by their natural order, descending when aBoolean, and answer aCollection.
	An Array of numbers or of strings is sorted by the plugin or the library, a numeric buffer by value (NaN last, first descending), anything else by Pharo's sortBlocks in TimSortSmalltalk"

	(self canModify: aCollection) ifFalse: [ ^ aCollection ].
	self check: aCollection from: start to: stop.
	aCollection timSortItemsDo: [ :items :offset |
		self
			sortItems: items
			from: start + offset
			to: stop + offset
			descending: aBoolean ].
	^ aCollection
]

{ #category : 'buffers' }
TimSort class >> sortBuffer: aBuffer [
	"Sort the numeric buffer aBuffer in place by value, NaN last, and answer it"

	^ self sortBuffer: aBuffer from: 1 to: aBuffer size descending: false
]

{ #category : 'buffers' }
TimSort class >> sortBuffer: aBuffer from: start to: stop descending: aBoolean [
	"Sort the elements start to stop of the numeric buffer aBuffer in place by value and answer aBuffer.  Floats: every NaN after every number (before them descending), the NaNs equal to each other, -0.0 equal to 0.0; equal elements keep their order"

	| kind |
	kind := self kindOf: aBuffer.
	kind ifNil: [ ^ self error: aBuffer class name , ' is not a numeric buffer' ].
	(self canModify: aBuffer) ifFalse: [ ^ aBuffer ].
	self check: aBuffer from: start to: stop.
	^ self
		  runSortBuffer: aBuffer
		  kind: kind
		  from: start
		  to: stop
		  descending: aBoolean
]

{ #category : 'keys' }
TimSort class >> argSort: keys [
	"The permutation that sorts keys: an Array of the indices of keys, those of the smaller keys first, equal keys in their order"

	^ self argSort: keys from: 1 to: keys size descending: false
]

{ #category : 'keys' }
TimSort class >> argSortDescending: keys [
	"The permutation that sorts keys descending: those of the larger keys first, equal keys in their order"

	^ self argSort: keys from: 1 to: keys size descending: true
]

{ #category : 'keys' }
TimSort class >> argSort: keys from: start to: stop descending: aBoolean [
	"An Array of the indices start to stop of keys, sorted stably by their keys: (keys at: (result at: 1)) is the smallest key, the largest when aBoolean.  keys is not changed.  An Array of keys is compared as sort: compares, a numeric buffer by value (NaN last)"

	| n perm |
	self check: keys from: start to: stop.
	n := stop - start + 1.
	keys timSortItemsDo: [ :items :offset |
		perm := self
			        argSortItems: items
			        from: start + offset
			        to: stop + offset
			        descending: aBoolean.
		offset = 0 ifFalse: [ 1 to: n do: [ :k | perm at: k put: (perm at: k) - offset ] ] ].
	^ perm
]

{ #category : 'keys' }
TimSort class >> sort: aCollection byKey: keyBlock [
	"Sort aCollection in place by the keys keyBlock answers for its elements, and answer it.  keyBlock is evaluated once per element, in order; the result is that of aCollection sort: [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]"

	^ self sort: aCollection from: 1 to: aCollection size byKey: keyBlock descending: false
]

{ #category : 'keys' }
TimSort class >> sortDescending: aCollection byKey: keyBlock [
	"Sort aCollection in place by the keys keyBlock answers for its elements, the largest first, equal keys in their order, and answer it"

	^ self sort: aCollection from: 1 to: aCollection size byKey: keyBlock descending: true
]

{ #category : 'keys' }
TimSort class >> sort: aCollection from: start to: stop byKey: keyBlock descending: aBoolean [
	"Sort the elements start to stop of aCollection in place by their keys and answer aCollection: the keys (keyBlock value: each), computed once and in order, are sorted by argSort:, and the permutation is applied to the elements"

	| n keys perm |
	(self canModify: aCollection) ifFalse: [ ^ aCollection ].
	self check: aCollection from: start to: stop.
	n := stop - start + 1.
	n < 2 ifTrue: [ ^ aCollection ].
	aCollection timSortItemsDo: [ :items :offset |
		keys := Array new: n.
		1 to: n do: [ :k | keys at: k put: (keyBlock value: (items at: start + offset + k - 1)) ].
		perm := self argSortItems: keys from: 1 to: n descending: aBoolean.
		self permute: items from: start + offset by: perm ].
	^ aCollection
]

{ #category : 'sort blocks' }
TimSort class >> sort: aCollection with: aBlock [
	"Sort aCollection in place by aBlock and answer it: aBlock value: a value: b answers true when a may come before b, as for Pharo's sort:.  For a sortBlock in the style of [ :a :b | a <= b ] the result is exactly that of aCollection sort: aBlock.  TimSortSmalltalk sorts, on every VM (blockSortBackend); sort:with:backend: runs the resumable C sort instead"

	^ self sort: aCollection from: 1 to: aCollection size with: aBlock backend: self blockSortBackend
]

{ #category : 'sort blocks' }
TimSort class >> sort: aCollection from: start to: stop with: aBlock [
	"Sort the elements start to stop of aCollection in place by aBlock and answer aCollection, with TimSortSmalltalk on every VM (blockSortBackend); see sort:from:to:with:backend:"

	^ self sort: aCollection from: start to: stop with: aBlock backend: self blockSortBackend
]

{ #category : 'sort blocks' }
TimSort class >> sort: aCollection with: aBlock backend: aSymbol [
	"Sort aCollection in place by aBlock with the backend aSymbol, #smalltalk, #plugin or #ffi, and answer it; see sort:from:to:with:backend:.
		TimSort sort: people copy with: [ :a :b | a age <= b age ] backend: #plugin"

	^ self sort: aCollection from: 1 to: aCollection size with: aBlock backend: aSymbol
]

{ #category : 'sort blocks' }
TimSort class >> sort: aCollection from: start to: stop with: aBlock backend: aSymbol [
	"Sort the elements start to stop of aCollection in place by aBlock and answer aCollection, with the backend aSymbol:
	- #smalltalk: TimSortSmalltalk, the port of timsort.c (the default of sort:with:, on every VM);
	- #plugin or #ffi: the resumable C sort of the TimSortPlugin or of libTimSortFFI (resumableBackends), which runs timsort over a permutation on a C stack of its own and stops at each comparison for aBlock to answer; when it cannot start or finish (no C memory, 64 sorts live, an id of another session) TimSortSmalltalk sorts instead, with the same result.  A backend without a resumable sort here (absent, WebAssembly, a shadow stack, TimSort-FFI not loaded), or another name, signals TimSortBackendUnavailable before anything is looked at.
	The comparison of timsort is lt(a, b) := (aBlock value: b value: a) not, which keeps equal elements in order for a sortBlock in the style of a <= b; with a strict block (a < b) the result is sorted, but equal elements come in an order of their own (neither stable nor Pharo's), the same on every backend.  aBlock runs in the calling Process: its errors and non-local returns go to the caller, and the collection is then untouched when the C sort runs (it sorts indices), a permutation of its elements otherwise"

	| backend |
	backend := self resumableBackendNamed: aSymbol.
	(self canModify: aCollection) ifFalse: [ ^ aCollection ].
	self check: aCollection from: start to: stop.
	stop - start < 1 ifTrue: [ ^ aCollection ].
	aCollection timSortItemsDo: [ :items :offset |
		self
			blockSort: items
			from: start + offset
			to: stop + offset
			with: aBlock
			backend: backend ].
	^ aCollection
]

{ #category : 'backend' }
TimSort class >> backend [
	"What the natural order, buffers and keys go through: #plugin, #ffi or #smalltalk"

	self checkSession.
	Primary == TimSortPrimitives ifTrue: [ ^ #plugin ].
	Primary == TimSortPortBackend ifTrue: [ ^ #smalltalk ].
	^ #ffi
]

{ #category : 'backend' }
TimSort class >> blockSortBackend [
	"What a sort by a sortBlock goes through by default (sort:with:, timSort:): #smalltalk, TimSortSmalltalk, on every VM.  It is the algorithm of the resumable C sort with the same result for the same block, and it was faster in every case measured (docs/TimSort.md, Benchmarks): 1.1 to 6.5 times faster than the plugin's, 3.5 to 17 times than the library's, natively from 10^3 to 10^6 elements: each comparison of the C sort is a primitive call and two switches of C stacks, or a callout of the library.  sort:with:backend: runs the resumable C sort of resumableBackends"

	^ #smalltalk
]

{ #category : 'backend' }
TimSort class >> resumableBackends [
	"The backends whose resumable C sort works here, for sort:with:backend:, in order of preference: #plugin, #ffi, both or none (WebAssembly, a process with a shadow stack, neither the plugin nor the library).  It probes the library"

	^ #( #plugin #ffi ) select: [ :each | (self resumableBackendFor: each) notNil ]
]

{ #category : 'backend' }
TimSort class >> resumableBackend [
	"The first of resumableBackends, #plugin or #ffi, or nil when there is none; the library is not probed when the plugin has a resumable sort"

	^ #( #plugin #ffi ) detect: [ :each | (self resumableBackendFor: each) notNil ] ifNone: [ nil ]
]

{ #category : 'backend' }
TimSort class >> coroutinesAvailable [
	"Whether a resumable C sort works here (resumableBackend is not nil), natively with the plugin or the library.  The sorts by a sortBlock run in TimSortSmalltalk by default all the same (blockSortBackend)"

	^ self resumableBackend notNil
]

{ #category : 'backend' }
TimSort class >> liveCoroutines [
	"How many resumable C sorts are live (0 between two sorts) in the backends of this session: the chosen one, the plugin, and the library once it was probed"

	| backends |
	self checkSession.
	backends := IdentitySet new.
	Primary coroutinesAvailable ifTrue: [ backends add: Primary ].
	(PluginInfo notNil and: [ TimSortPrimitives coroutinesAvailable ]) ifTrue: [ backends add: TimSortPrimitives ].
	(LibraryProbed == true and: [ Library notNil and: [ Library coroutinesAvailable ] ]) ifTrue: [ backends add: Library ].
	^ backends inject: 0 into: [ :sum :each | sum + each blockSortLive ]
]

{ #category : 'backend' }
TimSort class >> pluginAvailable [
	"Whether the TimSortPlugin is used"

	self checkSession.
	^ PluginInfo notNil
]

{ #category : 'backend' }
TimSort class >> pluginInfo [
	"What primitiveInfo answered, { protocol. pluginVersion. timsortVersion. platform. coroutineSupport. liveCoroutines }, or nil without the plugin"

	self checkSession.
	^ PluginInfo
]

{ #category : 'backend' }
TimSort class >> resetBackend [
	"Forget the choice of the backends and make it again: the hook #backend, else the plugin, else the library (probed only then, or by resumableBackends and sort:with:backend: #ffi), else TimSortPortBackend"

	| info hook |
	SessionToken := self session.
	BufferKinds := nil.
	Library := nil.
	LibraryProbed := false.
	info := (self testHook: #pluginMissing) == true ifFalse: [ TimSortPrimitives primInfo ].
	PluginInfo := (info isArray and: [ info size >= 6 and: [ info first = self protocol ] ]) ifTrue: [ info ].
	hook := self testHook: #backend.
	Primary := hook ifNil: [
		           PluginInfo
			           ifNotNil: [ TimSortPrimitives ]
			           ifNil: [ self library ifNil: [ TimSortPortBackend ] ] ]
]

{ #category : 'test hooks' }
TimSort class >> testHook: aSymbol [
	^ TestHooks ifNotNil: [ :hooks | hooks at: aSymbol ifAbsent: [ nil ] ]
]

{ #category : 'test hooks' }
TimSort class >> testHook: aSymbol value: anObject [
	"Set the test hook aSymbol (#backend, #pluginMissing, #fallbackMissing, #session) to anObject, nil removing it, and forget the choice of the backend.  #backend: an object answering the backend protocol, used for every call of the natural order, the buffers and the keys, and by sort:with:backend: of its name (backend: #plugin for TimSortPrimitives, #smalltalk for TimSortPortBackend, #ffi for any other) when it has coroutines; #pluginMissing (true): as if the plugin were absent; #fallbackMissing (true): as if TimSort-FFI were not loaded; #session: any object, as if the image had been saved and started again (a new session)"

	TestHooks ifNil: [ TestHooks := Dictionary new ].
	anObject
		ifNil: [ TestHooks removeKey: aSymbol ifAbsent: [  ] ]
		ifNotNil: [ TestHooks at: aSymbol put: anObject ].
	TestHooks isEmpty ifTrue: [ TestHooks := nil ].
	SessionToken := nil
]

{ #category : 'private' }
TimSort class >> checkSession [
	SessionToken == self session ifFalse: [ self resetBackend ]
]

{ #category : 'private' }
TimSort class >> session [
	"Smalltalk session, or the test hook #session: the session to which the choice of the backends and the resumable sorts belong"

	^ TestHooks
		  ifNil: [ Smalltalk session ]
		  ifNotNil: [ :hooks | hooks at: #session ifAbsent: [ Smalltalk session ] ]
]

{ #category : 'private' }
TimSort class >> primary [
	"The backend of the natural order, the buffers and the keys"

	self checkSession.
	^ Primary
]

{ #category : 'private' }
TimSort class >> library [
	"TimSortLibrary when it is loaded and available, probed once a session, else nil"

	LibraryProbed == true ifTrue: [ ^ Library ].
	LibraryProbed := true.
	(self testHook: #fallbackMissing) == true ifTrue: [ ^ Library := nil ].
	^ Library := (self environment at: #TimSortLibrary ifAbsent: [ nil ]) ifNotNil: [ :library |
		             library isAvailable ifTrue: [ library ] ]
]

{ #category : 'private' }
TimSort class >> canModify: aCollection [
	"Whether aCollection, and the collection that holds its elements, may be changed.  Each one that is read-only first signals ModificationForbidden (signalReadOnly:): when the handler made it writable and retried (retryModification), the sort goes on; when it is still read-only after the signal (a handler that resumed without changing it, or an object without slots, which signals nothing), answer false: the sort does nothing"

	aCollection timSortItemsDo: [ :items :offset |
		aCollection isReadOnlyObject ifTrue: [
			self signalReadOnly: aCollection.
			aCollection isReadOnlyObject ifTrue: [ ^ false ] ].
		items isReadOnlyObject ifTrue: [
			self signalReadOnly: items.
			items isReadOnlyObject ifTrue: [ ^ false ] ] ].
	^ true
]

{ #category : 'private' }
TimSort class >> signalReadOnly: anObject [
	"Signal ModificationForbidden for the read-only anObject as Pharo's write barrier does, with a retry that stores into a slot of anObject the value it holds (basicAt:put:, or instVarAt:put: without indexed slots), so that a handler may make anObject writable and retry (retryModification), and the sort goes on.  An object without any slot has nothing to change: nothing is signalled"

	anObject basicSize > 0 ifTrue: [
		^ (ModificationForbidden
			   for: anObject
			   at: 1
			   with: (anObject basicAt: 1)
			   retrySelector: #basicAt:put:) signal ].
	anObject class instSize > 0 ifTrue: [
		^ (ModificationForbidden
			   for: anObject
			   at: 1
			   with: (anObject instVarAt: 1)
			   retrySelector: #instVarAt:put:) signal ].
	^ nil
]

{ #category : 'private' }
TimSort class >> check: aCollection from: start to: stop [
	"Signal SubscriptOutOfBounds unless start to stop is a range of aCollection: 1 <= start <= stop + 1 <= size + 1 (start = stop + 1 is empty)"

	(start isInteger and: [ start >= 1 ]) ifFalse: [ ^ aCollection errorSubscriptBounds: start ].
	(stop isInteger and: [ stop <= aCollection size and: [ start <= (stop + 1) ] ]) ifFalse: [
		^ aCollection errorSubscriptBounds: stop ]
]

{ #category : 'private' }
TimSort class >> sortItems: items from: start to: stop descending: aBoolean [
	"Sort the elements start to stop of items, in place: an Array by the backend, a buffer by the backend, anything else by Pharo's sortBlocks in TimSortSmalltalk"

	| kind |
	items isArray ifTrue: [
		^ self
			  resolve: (self primary
					   sortObjects: items
					   from: start
					   to: stop
					   descending: aBoolean
					   stringClasses: self stringClasses)
			  for: items
			  ifDeclined: [
				  TimSortPortBackend
					  sortObjects: items
					  from: start
					  to: stop
					  descending: aBoolean
					  stringClasses: nil ] ].
	kind := self kindOf: items.
	kind ifNotNil: [
		^ self
			  runSortBuffer: items
			  kind: kind
			  from: start
			  to: stop
			  descending: aBoolean ].
	^ TimSortSmalltalk
		  sort: items
		  from: start
		  to: stop
		  by: (TimSortPortBackend sortBlockFor: items from: start to: stop descending: aBoolean)
]

{ #category : 'private' }
TimSort class >> runSortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean [
	^ self
		  resolve: (self primary
				   sortBuffer: aBuffer
				   kind: kind
				   from: start
				   to: stop
				   descending: aBoolean)
		  for: aBuffer
		  ifDeclined: [
			  TimSortPortBackend
				  sortBuffer: aBuffer
				  kind: kind
				  from: start
				  to: stop
				  descending: aBoolean ]
]

{ #category : 'private' }
TimSort class >> argSortItems: keys from: start to: stop descending: aBoolean [
	"A new Array of the indices start to stop of keys, sorted by the backend by their keys.  keys of any class but an Array or a buffer are copied into an Array"

	| n kind values perm |
	n := stop - start + 1.
	kind := self kindOf: keys.
	(keys isArray or: [ kind notNil ]) ifTrue: [
		^ self
			  resolve: (self primary
					   argSort: keys
					   kind: kind
					   into: (Array new: n)
					   from: start
					   to: stop
					   descending: aBoolean
					   stringClasses: self stringClasses)
			  for: keys
			  ifDeclined: [
				  TimSortPortBackend
					  argSort: keys
					  kind: kind
					  into: (Array new: n)
					  from: start
					  to: stop
					  descending: aBoolean
					  stringClasses: nil ] ].
	values := Array new: n.
	1 to: n do: [ :k | values at: k put: (keys at: start + k - 1) ].
	perm := self argSortItems: values from: 1 to: n descending: aBoolean.
	start = 1 ifFalse: [ 1 to: n do: [ :k | perm at: k put: (perm at: k) + start - 1 ] ].
	^ perm
]

{ #category : 'private' }
TimSort class >> blockSort: items from: start to: stop with: aBlock backend: backend [
	"Sort the elements start to stop of items (at least two) by aBlock: with the resumable C sort of backend (resumableBackendNamed:), which sorts the indices and leaves items untouched until the end, else (backend nil, or when it cannot start or finish) with TimSortSmalltalk.
	The C sort belongs to this method from the moment it exists: it is freed on every exit (ensure:), also when aBlock fails or the Process is terminated, and no other Process can run between its opening and the assignment of its id.  The primitive answers the id with no Smalltalk in between; the library's callout runs Smalltalk after the call, where another Process could terminate this one and leave the sort live in C for the rest of the session, so that call runs at the highest priority (raisePriorityOf:, restorePriority:of:).
	The C sort belongs to the session it was opened in.  A Process saved while aBlock ran, and resumed in a new session, holds an id of an earlier load of the plugin or the library: the ids of each load count up from a random base, so the id names no live sort (#'not found'), and TimSortSmalltalk sorts the untouched items; the id is not freed there, nor is its permutation asked for"

	| session id state perm process priority |
	backend ifNotNil: [
		session := self session.
		state := Array new: 1.
		perm := [
		        backend == TimSortPrimitives
			        ifTrue: [ id := backend blockSortNew: stop - start + 1 descending: false ]
			        ifFalse: [
				        process := Processor activeProcess.
				        priority := self raisePriorityOf: process.
				        [ id := backend blockSortNew: stop - start + 1 descending: false ] ensure: [
					        self restorePriority: priority of: process ] ].
		        id isInteger ifTrue: [
			        state at: 1 put: (backend blockSortNext: id answer: 0).
			        self
				        blockSort: items
				        from: start
				        to: stop
				        with: aBlock
				        id: id
				        backend: backend
				        state: state
				        session: session ] ] ensure: [
		        (id isInteger and: [ session == self session ]) ifTrue: [ backend blockSortFree: id ] ].
		perm ifNotNil: [
			self permute: items from: start by: perm.
			^ items ] ].
	^ TimSortSmalltalk
		  sort: items
		  from: start
		  to: stop
		  by: aBlock
]

{ #category : 'private' }
TimSort class >> raisePriorityOf: aProcess [
	"Give aProcess, the active one, the highest priority, so that no other Process runs until restorePriority:of: (unless aProcess waits), and answer its priority.  The slot is written directly: Process>>priority: makes the active Process suspend itself while a forked one resumes it, and a Process terminated meanwhile would be resumed"

	| priority |
	priority := aProcess priority.
	aProcess instVarAt: (Process instVarIndexFor: #priority ifAbsent: [ nil ]) put: Processor highestPriority.
	^ priority
]

{ #category : 'private' }
TimSort class >> restorePriority: anInteger of: aProcess [
	"Give aProcess its priority anInteger again, and let the Processes of a higher priority that became ready meanwhile run first: a Process forked at the highest priority preempts aProcess, which then waits in the queue of its priority (where another Process may terminate it, as anywhere else)"

	aProcess instVarAt: (Process instVarIndexFor: #priority ifAbsent: [ nil ]) put: anInteger.
	[  ] forkAt: Processor highestPriority
]

{ #category : 'private' }
TimSort class >> blockSort: items from: start to: stop with: aBlock id: id backend: backend state: state session: session [
	"Answer the comparisons of the resumable sort id until it is done, and answer its permutation (1-based), or nil when it failed (no memory, an id not found) or the session is not its own.  A request is (i << 32) | j with 0-based indices: must element i come strictly before element j?  The answer is 0 when aBlock says that j may come before i, else 1.
	The request the sort waits for is kept in state, not in this frame: restarting this frame (the Restart of the debugger, from aBlock) evaluates aBlock again on that request"

	| request |
	[
	request := state at: 1.
	request isInteger and: [ request >= 0 ] ] whileTrue: [
		| answer |
		answer := (aBlock
			           value: (items at: start + (request bitAnd: 16rFFFFFFFF))
			           value: (items at: start + (request bitShift: -32)))
			          ifTrue: [ 0 ]
			          ifFalse: [ 1 ].
		state at: 1 put: (backend blockSortNext: id answer: answer) ].
	(request = -1 and: [ session == self session ]) ifFalse: [ ^ nil ].
	^ (backend blockSortPermutation: id into: (Array new: stop - start + 1)) ifNotNil: [ :perm |
		  perm timSortFailed ifFalse: [ perm ] ]
]

{ #category : 'private' }
TimSort class >> resumableBackendFor: aSymbol [
	"The object whose resumable C sort runs for the backend aSymbol (#plugin or #ffi) when it works here, else nil: the chosen backend when aSymbol is its name (the test hook #backend too), else TimSortPrimitives with the plugin for #plugin, and TimSortLibrary when it is available for #ffi"

	| candidate |
	self checkSession.
	candidate := self backend == aSymbol
		             ifTrue: [ Primary ]
		             ifFalse: [
			             aSymbol == #plugin
				             ifTrue: [ PluginInfo ifNotNil: [ TimSortPrimitives ] ]
				             ifFalse: [ aSymbol == #ffi ifTrue: [ self library ] ] ].
	^ (candidate notNil and: [ candidate coroutinesAvailable ]) ifTrue: [ candidate ]
]

{ #category : 'private' }
TimSort class >> resumableBackendNamed: aSymbol [
	"The object whose resumable C sort runs for the backend aSymbol, or nil for #smalltalk (TimSortSmalltalk); TimSortBackendUnavailable when aSymbol has no resumable sort here or is not a backend"

	aSymbol == #smalltalk ifTrue: [ ^ nil ].
	^ (self resumableBackendFor: aSymbol) ifNil: [
		  TimSortBackendUnavailable signalFor: aSymbol reason: (self unavailableReason: aSymbol) ]
]

{ #category : 'private' }
TimSort class >> unavailableReason: aSymbol [
	"Why the backend aSymbol has no resumable C sort here"

	aSymbol == #plugin ifTrue: [
		^ PluginInfo
			  ifNil: [ 'the TimSortPlugin is not loaded' ]
			  ifNotNil: [ 'the TimSortPlugin cannot switch C stacks here (WebAssembly, or a process with a shadow stack)' ] ].
	aSymbol == #ffi ifTrue: [
		^ self library
			  ifNil: [ 'the package TimSort-FFI is not loaded, or libTimSortFFI is not found' ]
			  ifNotNil: [ 'libTimSortFFI cannot switch C stacks here (a process with a shadow stack)' ] ].
	^ 'no such backend: #plugin, #ffi or #smalltalk'
]

{ #category : 'private' }
TimSort class >> permute: items from: start by: perm [
	"Put at start + k - 1 the element that was at start + (perm at: k) - 1, for each k"

	| n copy |
	n := perm size.
	copy := Array new: n.
	1 to: n do: [ :k | copy at: k put: (items at: start + k - 1) ].
	1 to: n do: [ :k | items at: start + k - 1 put: (copy at: (perm at: k)) ]
]

{ #category : 'private' }
TimSort class >> resolve: answer for: aCollection ifDeclined: aBlock [
	"The answer of a backend, or the value of aBlock when it declined or failed (a failure, or nil).  The facade checks read-only collections and ranges before calling a backend, so #'no modification' and #'bad index' are signalled as these checks would (after #'no modification', aBlock sorts when the handler made aCollection writable)"

	(answer isNil or: [ answer timSortFailed ]) ifFalse: [ ^ answer ].
	answer ifNil: [ ^ aBlock value ].
	answer ec == #'no modification' ifTrue: [
		self signalReadOnly: aCollection.
		aCollection isReadOnlyObject ifTrue: [ ^ aCollection ].
		^ aBlock value ].
	answer ec == #'bad index' ifTrue: [ ^ aCollection errorSubscriptBounds: 0 ].
	^ aBlock value
]
