"
I test TimSortLibrary itself: the identity of the library, the checks and failures of each call in the order of the primitives, the Arrays it sorts (SmallIntegers by value, Floats and small SmallIntegers by a permutation that keeps identity) and those it declines, every kind of buffer and every argSort against TimSortPortBackend (bits for bits, == per slot), the resumable sort and its ids, the private pinned buffers (the objects of the caller are never pinned), no lock across callouts (nested sorts, two Processes), libraryPath:, the session, the choice of the library by TimSort, and the same answers as the plugin on random calls when the VM has it.  Skipped when the library is not found.
"
Class {
	#name : 'TimSortLibraryTests',
	#superclass : 'TestCase',
	#category : 'TimSort-FFI-Tests-Tests',
	#package : 'TimSort-FFI-Tests',
	#tag : 'Tests'
}

{ #category : 'accessing' }
TimSortLibraryTests class >> calls [
	"The random calls of each selector of the backend protocol in testSameAnswersAsThePlugin"

	^ 3000
]

{ #category : 'accessing' }
TimSortLibraryTests class >> defaultTimeLimit [
	"The random calls of testSameAnswersAsThePlugin and the sorts of 1e5 elements take a few seconds here, more on a slower machine"

	^ 120 seconds
]

{ #category : 'running' }
TimSortLibraryTests >> setUp [
	super setUp.
	TimSortLibrary isAvailable ifFalse: [ self skip: 'no libTimSortFFI' ]
]

{ #category : 'running' }
TimSortLibraryTests >> tearDown [
	TimSort
		testHook: #backend value: nil;
		testHook: #pluginMissing value: nil;
		testHook: #fallbackMissing value: nil.
	super tearDown
]

{ #category : 'helpers' }
TimSortLibraryTests >> random [
	"A Random with a fixed seed, so that a failure can be replayed"

	^ Random seed: 20261117
]

{ #category : 'helpers' }
TimSortLibraryTests >> classes [
	^ TimSort stringClasses
]

{ #category : 'helpers' }
TimSortLibraryTests >> assert: actual same: expected [
	"The same size, and the same object in each slot"

	self assert: actual size equals: expected size.
	1 to: expected size do: [ :k |
		(actual at: k) == (expected at: k) ifFalse: [
			self fail: 'slot ' , k printString , ': ' , (actual at: k) printString , ' is not ' , (expected at: k) printString ] ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> bitsOf: aBuffer [
	^ (1 to: aBuffer basicSize) collect: [ :k | aBuffer basicAt: k ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> assertFailure: answer ec: aSymbol [
	self assert: answer timSortFailed description: 'not a failure: ' , answer printString.
	self assert: answer ec equals: aSymbol
]

{ #category : 'helpers' }
TimSortLibraryTests >> integers: n random: random [
	"n SmallIntegers: small, large, negative, duplicates, the extremes"

	| edges |
	edges := { SmallInteger minVal. SmallInteger maxVal. 0. -1. 1. 9007199254740993. -9007199254740993. 1 bitShift: 59 }.
	^ (1 to: n) collect: [ :k |
		| roll |
		roll := random nextInteger: 10.
		roll = 1
			ifTrue: [ edges at: (random nextInteger: edges size) ]
			ifFalse: [
				roll <= 4
					ifTrue: [ (random nextInteger: 21) - 11 ]
					ifFalse: [ (random nextInteger: 1 << 40) - (1 << 39) * (random nextInteger: 1 << 19) ] ] ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> floats: n random: random [
	"n Floats (not NaN) and SmallIntegers of at most 2^53: -0.0, 0.0 and 0, infinities, boxed and immediate Floats, the smallest subnormal, equal values that are distinct objects, few distinct values now and then"

	| edges boxed |
	boxed := 1.0e300 * 3.
	edges := {
		-0.0. 0.0. 0. Float infinity. Float negativeInfinity. Float fminDenormalized. Float fminDenormalized negated.
		1.0e300. -1.0e300. boxed. 9007199254740992. -9007199254740992. 9007199254740992.0. 0.5. 1/2 asFloat }.
	^ (1 to: n) collect: [ :k |
		| roll |
		roll := random nextInteger: 10.
		roll <= 2
			ifTrue: [ edges at: (random nextInteger: edges size) ]
			ifFalse: [
				roll <= 4
					ifTrue: [ (random nextInteger: 11) - 6 ]
					ifFalse: [
						roll <= 6
							ifTrue: [ ((random nextInteger: 7) - 4) / 2.0 ]
							ifFalse: [ (random next - 0.5) * (10 raisedTo: (random nextInteger: 600) - 300) ] ] ] ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> port: anArray from: start to: stop descending: aBoolean [
	"What TimSortPortBackend makes of a copy of anArray: Pharo's sort, by [ :a :b | a <= b ] or [ :a :b | a >= b ]"

	^ TimSortPortBackend sortObjects: anArray copy from: start to: stop descending: aBoolean stringClasses: nil
]

{ #category : 'helpers' }
TimSortLibraryTests >> bufferClasses [
	"The classes of numeric buffers of the image, with their kinds"

	^ TimSort bufferKinds associations asSortedCollection: [ :a :b | a key name <= b key name ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> buffer: aClass size: n random: random [
	"A new aClass of n elements of random bits: for the floats, NaNs of both signs with payloads, -0.0 and 0.0, infinities and subnormals among them; few distinct values now and then"

	| buffer bytes few spec |
	buffer := aClass new: n.
	spec := aClass instSpec.
	bytes := spec = 9
		ifTrue: [ 8 ]
		ifFalse: [
			spec <= 11
				ifTrue: [ 4 ]
				ifFalse: [ spec <= 15 ifTrue: [ 2 ] ifFalse: [ 1 ] ] ].
	few := (random nextInteger: 3) = 1.
	1 to: n do: [ :k |
		| bits |
		bits := few
			ifTrue: [ random nextInteger: 4 ]
			ifFalse: [ (random nextInteger: (1 bitShift: bytes * 8)) - 1 ].
		(random nextInteger: 8) = 1 ifTrue: [ bits := self specialBits: bytes random: random ].
		buffer basicAt: k put: bits ].
	^ buffer
]

{ #category : 'helpers' }
TimSortLibraryTests >> specialBits: bytes random: random [
	"The bits of an edge element of bytes bytes: the floats' NaNs, zeros, infinities and subnormals are also the integers' extremes"

	| values |
	values := bytes = 8
		ifTrue: [ #( 16r7FF8000000000000 16rFFF8000000000000 16r7FF0000000000001 16rFFF4000000000005 16r8000000000000000 0 16r7FF0000000000000 16rFFF0000000000000 1 16r800FFFFFFFFFFFFF 16r7FFFFFFFFFFFFFFF 16rFFFFFFFFFFFFFFFF ) ]
		ifFalse: [
			bytes = 4
				ifTrue: [ #( 16r7FC00000 16rFFC00000 16r7F800001 16rFFA00007 16r80000000 0 16r7F800000 16rFF800000 1 16r807FFFFF 16r7FFFFFFF 16rFFFFFFFF ) ]
				ifFalse: [
					bytes = 2
						ifTrue: [ #( 0 1 16r7FFF 16r8000 16rFFFF ) ]
						ifFalse: [ #( 0 1 16r7F 16r80 16rFF ) ] ] ].
	^ values at: (random nextInteger: values size)
]

{ #category : 'helpers' }
TimSortLibraryTests >> drive: aCollection with: aBlock descending: aBoolean [
	"aCollection sorted (a new Array) by the resumable sort of the library and aBlock, the comparisons answered here, the sort freed on every exit; or the end the library answered (-2, -3)"

	| n id request answer perm |
	n := aCollection size.
	id := TimSortLibrary blockSortNew: n descending: aBoolean.
	self deny: id timSortFailed.
	[
		answer := 0.
		[ (request := TimSortLibrary blockSortNext: id answer: answer) >= 0 ] whileTrue: [
			answer := (aBlock value: (aCollection at: (request bitAnd: 16rFFFFFFFF) + 1) value: (aCollection at: (request bitShift: -32) + 1))
				ifTrue: [ 0 ]
				ifFalse: [ 1 ] ].
		request = -1 ifFalse: [ ^ request ].
		perm := TimSortLibrary blockSortPermutation: id into: (Array new: n) ]
			ensure: [ TimSortLibrary blockSortFree: id ].
	^ perm collect: [ :k | aCollection at: k ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> requireCoroutines [
	TimSortLibrary coroutinesAvailable ifFalse: [ self skip: 'the library has no resumable sort here' ]
]

{ #category : 'tests' }
TimSortLibraryTests >> testIdentity [
	"The library speaks protocol 1 and is the engine of the plugin, 'TimSortPlugin 1.0' on timsort.c fd70381"

	self assert: TimSortLibrary protocol equals: 1.
	self assert: TimSortLibrary uniqueInstance primProtocol equals: 1.
	self assert: TimSortLibrary version equals: 'TimSortPlugin 1.0'.
	self assert: TimSortLibrary timsortVersion equals: 'fd70381'.
	self assert: (#( 'asm-x86_64-sysv' 'asm-aarch64' 'fibers' 'stub' 'none' ) includes: TimSortLibrary coroutineImplementation).
	self
		assert: TimSortLibrary coroutinesAvailable
		equals: (TimSortLibrary uniqueInstance primCoroSupported = 1).
	(TimSortLibrary coroutineImplementation = 'stub' or: [ TimSortLibrary coroutineImplementation = 'none' ])
		ifTrue: [ self deny: TimSortLibrary coroutinesAvailable ].
	TimSortPrimitives primInfo ifNotNil: [ :info |
		self assert: (info at: 2) equals: TimSortLibrary version.
		self assert: (info at: 3) equals: 'timsort.c ' , TimSortLibrary timsortVersion ]
]

{ #category : 'tests' }
TimSortLibraryTests >> testStatusesOfTheLibrary [
	"The library refuses NULL and n < 0 itself (-4), which the checks in Smalltalk make impossible; the statuses are failures of the primitives"

	| library |
	library := TimSortLibrary uniqueInstance.
	self assert: (library primSortF64: ExternalAddress null count: 2 descending: 0) equals: -4.
	self assert: (library primSortU8: ExternalAddress null count: -1 descending: 0) equals: -4.
	self assert: (library primSortI64: ExternalAddress null count: 0 descending: 0) equals: 0.
	self assert: (library primArgSortF64: ExternalAddress null into: ExternalAddress null count: 3 descending: 1) equals: -4.
	self assertFailure: (library failureFor: -2) ec: #'insufficient C memory'.
	self assertFailure: (library failureFor: -4) ec: #'bad argument'.
	self assertFailure: (library failureFor: -5) ec: #'unsupported operation'
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortIntegers [
	"Arrays of SmallIntegers, sorted by value as int64: the result of Pharo's sort (and of sort: [ :a :b | a >= b ]), the extremes of SmallInteger included, in any range, the slots outside it untouched"

	| random |
	random := self random.
	#( 2 3 7 64 65 1000 20000 ) do: [ :n |
		{ self integers: n random: random. (1 to: n) asArray. (n to: 1 by: -1) asArray. (1 to: n) collect: [ :k | k \\ 3 ] } do: [ :input |
			#( false true ) do: [ :descending |
				| start stop sorted |
				sorted := input copy.
				self assert: (TimSortLibrary sortObjects: sorted from: 1 to: n descending: descending stringClasses: self classes) identicalTo: sorted.
				self assert: sorted same: (self port: input from: 1 to: n descending: descending).
				self assert: sorted same: (input copy sort: (descending ifTrue: [ [ :a :b | a >= b ] ] ifFalse: [ [ :a :b | a <= b ] ])).
				start := random nextInteger: n.
				stop := (start - 1 + (random nextInteger: n - start + 2)) - 1.
				sorted := input copy.
				TimSortLibrary sortObjects: sorted from: start to: stop descending: descending stringClasses: self classes.
				self assert: sorted same: (self port: input from: start to: stop descending: descending) ] ] ]
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortFloatsKeepsIdentity [
	"Floats and SmallIntegers of at most 2^53, sorted by a permutation: every element keeps its identity, equal ones (-0.0, 0.0 and 0; equal BoxedFloat64s that are distinct objects) keep their order, as Pharo's sort leaves them"

	| random twins input sorted |
	random := self random.
	#( 2 3 10 100 1000 20000 ) do: [ :n |
		input := self floats: n random: random.
		#( false true ) do: [ :descending |
			sorted := input copy.
			TimSortLibrary sortObjects: sorted from: 1 to: n descending: descending stringClasses: self classes.
			self assert: sorted same: (self port: input from: 1 to: n descending: descending).
			self assert: sorted same: (input copy sort: (descending ifTrue: [ [ :a :b | a >= b ] ] ifFalse: [ [ :a :b | a <= b ] ])) ] ].
	twins := (1 to: 6) collect: [ :k | 1.0e300 * 2 ].
	self assert: (twins collect: [ :each | each class ]) asSet asArray equals: { BoxedFloat64 }.
	input := { twins first. 1. twins second. -0.0. twins third. 0. 0.0. twins fourth. 1.0e-310. twins fifth. -1. twins sixth }.
	sorted := input copy.
	TimSortLibrary sortObjects: sorted from: 1 to: input size descending: false stringClasses: self classes.
	self assert: sorted same: { -1. -0.0. 0. 0.0. 1.0e-310. 1. twins first. twins second. twins third. twins fourth. twins fifth. twins sixth }.
	sorted := input copy.
	TimSortLibrary sortObjects: sorted from: 1 to: input size descending: true stringClasses: self classes.
	self assert: sorted same: { twins first. twins second. twins third. twins fourth. twins fifth. twins sixth. 1. 1.0e-310. -0.0. 0. 0.0. -1 }
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortObjectsDeclines [
	"Anything but SmallIntegers, or Floats and SmallIntegers that a double holds, is #'bad argument', the Array untouched; TimSortPortBackend sorts it.  Fewer than two elements are not looked at"

	{
		#( 'b' 'a' ).
		{ 1 bitShift: 70. 1 }.
		{ (1 bitShift: 70) negated. 1 }.
		{ 1.0. Float nan }.
		{ Float nan. 2 }.
		{ 1/2. 1 }.
		{ nil. 1 }.
		{ $a. 1 }.
		{ 1. 'a' }.
		{ 1.0. 9007199254740993 }.
		{ 9007199254740993. 1.0 }.
		{ 2. -9007199254740993. 3. 1.5 }.
		{ 1.5. 2. SmallInteger maxVal } } do: [ :input |
			| array |
			array := input copy.
			self
				assertFailure: (TimSortLibrary sortObjects: array from: 1 to: array size descending: false stringClasses: self classes)
				ec: #'bad argument'.
			self assert: array same: input ].
	self assert: (TimSortLibrary sortObjects: { 9007199254740992. 1.0. -9007199254740992 } from: 1 to: 3 descending: false stringClasses: self classes) equals: { -9007199254740992. 1.0. 9007199254740992 }.
	self assert: (TimSortLibrary sortObjects: { 'x'. 3. 1 } from: 2 to: 3 descending: false stringClasses: self classes) equals: { 'x'. 1. 3 }.
	self assert: (TimSortLibrary sortObjects: { 'x'. Float nan } from: 1 to: 1 descending: false stringClasses: self classes) first equals: 'x'.
	self assert: (TimSortLibrary sortObjects: { 'x'. Float nan } from: 2 to: 1 descending: false stringClasses: self classes) first equals: 'x'
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortObjectsChecks [
	"The failures of primitiveSortObjects, in its order: the kinds of the arguments, read-only, the range"

	| array readOnly |
	array := #( 3 1 2 ) copy.
	readOnly := #( 3 1 2 ) copy beReadOnlyObject; yourself.
	{
		[ TimSortLibrary sortObjects: 'abc' copy from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: (WeakArray with: 3 with: 1) from: 1 to: 2 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: (OrderedCollection with: 3 with: 1) from: 1 to: 2 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: array from: 1.0 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: array from: 1 to: (1 bitShift: 70) descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: array from: 1 to: 3 descending: nil stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: array from: 1 to: 3 descending: false stringClasses: nil ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: array from: 1 to: 3 descending: false stringClasses: #( 1 2 3 4 ) ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: array from: 1 to: 3 descending: false stringClasses: self classes allButLast ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: readOnly from: 1 to: 3 descending: nil stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary sortObjects: readOnly from: 0 to: 3 descending: false stringClasses: self classes ] -> #'no modification'.
		[ TimSortLibrary sortObjects: readOnly from: 1 to: 1 descending: false stringClasses: self classes ] -> #'no modification'.
		[ TimSortLibrary sortObjects: array from: 0 to: 3 descending: false stringClasses: self classes ] -> #'bad index'.
		[ TimSortLibrary sortObjects: array from: 1 to: 4 descending: false stringClasses: self classes ] -> #'bad index'.
		[ TimSortLibrary sortObjects: array from: 3 to: 1 descending: false stringClasses: self classes ] -> #'bad index' }
			do: [ :each | self assertFailure: each key value ec: each value ].
	self assert: array equals: #( 3 1 2 ).
	self assert: readOnly equals: #( 3 1 2 ).
	self assert: (TimSortLibrary sortObjects: array from: 4 to: 3 descending: false stringClasses: self classes) identicalTo: array.
	self assert: (TimSortLibrary sortObjects: array from: 1 to: 0 descending: false stringClasses: self classes) identicalTo: array.
	self assert: array equals: #( 3 1 2 )
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortBuffers [
	"Every kind of buffer, every range, both directions: bit for bit what TimSortPortBackend makes of a copy (by value, every NaN last, -0.0 equal to 0.0, stable), the elements outside the range untouched"

	| random |
	random := self random.
	self bufferClasses do: [ :each |
		#( 2 3 5 64 65 1000 10000 ) do: [ :n |
			| input |
			input := self buffer: each key size: n random: random.
			#( false true ) do: [ :descending |
				| start stop sorted expected |
				start := (random nextInteger: 4) = 1 ifTrue: [ random nextInteger: n ] ifFalse: [ 1 ].
				stop := (random nextInteger: 4) = 1 ifTrue: [ (start - 1 + (random nextInteger: n - start + 2)) - 1 ] ifFalse: [ n ].
				sorted := input copy.
				expected := input copy.
				self assert: (TimSortLibrary sortBuffer: sorted kind: each value from: start to: stop descending: descending) identicalTo: sorted.
				TimSortPortBackend sortBuffer: expected kind: each value from: start to: stop descending: descending.
				self
					assert: (self bitsOf: sorted) = (self bitsOf: expected)
					description: each key name , ' n=' , n printString , ' ' , start printString , '-' , stop printString , ' descending ' , descending printString ] ] ]
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortBufferAsOtherKinds [
	"The kind, not the class, says how the bits are compared, as for the primitive: a Float64Array sorted as int64 and uint64, an IntegerArray as uint32, a WordArray as int32 and float32, a ByteString as bytes"

	| doubles words string |
	doubles := Float64Array withAll: #( -1.0 2.0 -0.0 1.0 ).
	TimSortLibrary sortBuffer: doubles kind: TimSort kindInt64 from: 1 to: 4 descending: false.
	self assert: (self bitsOf: doubles) equals: ((self bitsOf: (Float64Array withAll: #( -1.0 -0.0 1.0 2.0 ))) asSortedCollection: [ :a :b |
		(a >= 16r8000000000000000 ifTrue: [ a - (1 bitShift: 64) ] ifFalse: [ a ]) <= (b >= 16r8000000000000000 ifTrue: [ b - (1 bitShift: 64) ] ifFalse: [ b ]) ]) asArray.
	doubles := Float64Array withAll: #( -1.0 2.0 -0.0 1.0 ).
	TimSortLibrary sortBuffer: doubles kind: TimSort kindUInt64 from: 1 to: 4 descending: false.
	self assert: (self bitsOf: doubles) equals: (self bitsOf: (Float64Array withAll: #( -1.0 2.0 -0.0 1.0 ))) asSortedCollection asArray.
	words := IntegerArray withAll: #( -1 5 -7 0 ).
	TimSortLibrary sortBuffer: words kind: TimSort kindUInt32 from: 1 to: 4 descending: false.
	self assert: words asArray equals: #( 0 5 -7 -1 ).
	words := WordArray withAll: #( 16rFFFFFFFF 5 16r80000000 0 ).
	TimSortLibrary sortBuffer: words kind: TimSort kindInt32 from: 1 to: 4 descending: false.
	self assert: words asArray equals: #( 16r80000000 16rFFFFFFFF 0 5 ).
	words := WordArray withAll: #( 16r7FC00000 16r3F800000 16rBF800000 16r80000000 ).
	TimSortLibrary sortBuffer: words kind: TimSort kindFloat32 from: 1 to: 4 descending: false.
	self assert: words asArray equals: #( 16rBF800000 16r80000000 16r3F800000 16r7FC00000 ).
	string := 'hello world' copy.
	TimSortLibrary sortBuffer: string kind: TimSort kindUInt8 from: 1 to: string size descending: false.
	self assert: string equals: ' dehllloorw'
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortBufferChecks [
	"The failures of primitiveSortBuffer, in its order: the kind, the format of the buffer for the kind (never a CompiledMethod, a BoxedFloat64 or a LargeInteger), the other arguments, read-only, the range"

	| buffer readOnly method bytecodes |
	buffer := Float64Array withAll: #( 3.0 1.0 2.0 ).
	readOnly := (Float64Array withAll: #( 3.0 1.0 2.0 )) beReadOnlyObject; yourself.
	method := Object >> #printString.
	bytecodes := (method initialPC to: method endPC) collect: [ :k | method at: k ].
	{
		[ TimSortLibrary sortBuffer: buffer kind: 0 from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: buffer kind: 9 from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: buffer kind: nil from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat32 from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindUInt8 from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: #( 3 1 2 ) copy kind: TimSort kindUInt64 from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: nil kind: TimSort kindUInt64 from: 1 to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: 42 kind: TimSort kindUInt64 from: 1 to: 1 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: method kind: TimSort kindUInt8 from: method initialPC to: method endPC descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: 1.0e300 * 2 kind: TimSort kindUInt32 from: 1 to: 2 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: (1 bitShift: 100) kind: TimSort kindUInt8 from: 1 to: 2 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat64 from: 1 to: 3 descending: 1 ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat64 from: nil to: 3 descending: false ] -> #'bad argument'.
		[ TimSortLibrary sortBuffer: readOnly kind: TimSort kindFloat64 from: 1 to: 9 descending: false ] -> #'no modification'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat64 from: 1 to: 4 descending: false ] -> #'bad index'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat64 from: 0 to: 2 descending: false ] -> #'bad index'.
		[ TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat64 from: 3 to: 1 descending: false ] -> #'bad index' }
			do: [ :each | self assertFailure: each key value ec: each value ].
	self assert: buffer asArray equals: #( 3.0 1.0 2.0 ).
	self assert: readOnly asArray equals: #( 3.0 1.0 2.0 ).
	self assert: ((method initialPC to: method endPC) collect: [ :k | method at: k ]) equals: bytecodes.
	self deny: method isPinnedInMemory
]

{ #category : 'tests' }
TimSortLibraryTests >> testArgSort [
	"The permutations of Arrays of SmallIntegers and of Floats, and of every kind of buffer, in any range and both directions: the ones of TimSortPortBackend (stable); the keys untouched"

	| random |
	random := self random.
	#( 1 2 3 64 1000 10000 ) do: [ :n |
		{ self integers: n random: random. self floats: n random: random } do: [ :keys |
			#( false true ) do: [ :descending |
				| start stop perm expected copy |
				start := (random nextInteger: 3) = 1 ifTrue: [ random nextInteger: n ] ifFalse: [ 1 ].
				stop := n.
				copy := keys copy.
				perm := TimSortLibrary argSort: copy kind: nil into: (Array new: stop - start + 1) from: start to: stop descending: descending stringClasses: self classes.
				expected := TimSortPortBackend argSort: keys kind: nil into: (Array new: stop - start + 1) from: start to: stop descending: descending stringClasses: nil.
				self assert: perm equals: expected.
				self assert: copy same: keys ] ] ].
	self bufferClasses do: [ :each |
		#( 1 2 3 65 1000 10000 ) do: [ :n |
			| keys |
			keys := self buffer: each key size: n random: random.
			#( false true ) do: [ :descending |
				| start perm expected bits |
				start := (random nextInteger: 3) = 1 ifTrue: [ random nextInteger: n ] ifFalse: [ 1 ].
				bits := self bitsOf: keys.
				perm := TimSortLibrary argSort: keys kind: each value into: (Array new: n - start + 1) from: start to: n descending: descending stringClasses: self classes.
				expected := TimSortPortBackend argSort: keys kind: each value into: (Array new: n - start + 1) from: start to: n descending: descending stringClasses: nil.
				self assert: perm = expected description: each key name , ' n=' , n printString , ' from ' , start printString , ' descending ' , descending printString.
				self assert: (self bitsOf: keys) equals: bits ] ] ]
]

{ #category : 'tests' }
TimSortLibraryTests >> testArgSortNarrowKindsAsOtherClasses [
	"The keys of a buffer are read from their bits as the kind says, whatever their class: an IntegerArray and a WordArray as int32 alike, a WordArray as float32"

	self
		assert: (TimSortLibrary argSort: (IntegerArray withAll: #( 5 -1 0 -7 )) kind: TimSort kindInt32 into: (Array new: 4) from: 1 to: 4 descending: false stringClasses: self classes)
		equals: #( 4 2 3 1 ).
	self
		assert: (TimSortLibrary argSort: (WordArray withAll: #( 5 16rFFFFFFFF 0 16rFFFFFFF9 )) kind: TimSort kindInt32 into: (Array new: 4) from: 1 to: 4 descending: false stringClasses: self classes)
		equals: #( 4 2 3 1 ).
	self
		assert: (TimSortLibrary argSort: (IntegerArray withAll: #( 5 -1 0 -7 )) kind: TimSort kindUInt32 into: (Array new: 4) from: 1 to: 4 descending: false stringClasses: self classes)
		equals: #( 3 1 4 2 ).
	self
		assert: (TimSortLibrary argSort: (WordArray withAll: #( 16r7FC00000 16r3F800000 16rBF800000 16r80000000 16r00000000 )) kind: TimSort kindFloat32 into: (Array new: 5) from: 1 to: 5 descending: false stringClasses: self classes)
		equals: #( 3 4 5 2 1 ).
	self
		assert: (TimSortLibrary argSort: (WordArray withAll: #( 16r7FC00000 16r3F800000 16rBF800000 16r80000000 16r00000000 )) kind: TimSort kindFloat32 into: (Array new: 5) from: 1 to: 5 descending: true stringClasses: self classes)
		equals: #( 1 2 4 5 3 )
]

{ #category : 'tests' }
TimSortLibraryTests >> testArgSortChecks [
	"The failures of primitiveArgSort, in its order: the keys for the kind, perm and the other arguments, perm read-only, the range over the keys, the size of perm (and perm is not the keys), the elements of an Array of keys"

	| keys readOnly |
	keys := #( 3 1 2 ) copy.
	readOnly := (Array new: 3) beReadOnlyObject; yourself.
	{
		[ TimSortLibrary argSort: (Float64Array new: 3) kind: nil into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: TimSort kindFloat64 into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: (ByteArray new: 3) kind: TimSort kindUInt16 into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: 0 into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: nil into: (OrderedCollection new: 3) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: nil into: (Array new: 3) from: 1 to: 3 descending: 0 stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: nil into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: #() ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: nil into: readOnly from: 1 to: 9 descending: false stringClasses: self classes ] -> #'no modification'.
		[ TimSortLibrary argSort: keys kind: nil into: (Array new: 3) from: 1 to: 4 descending: false stringClasses: self classes ] -> #'bad index'.
		[ TimSortLibrary argSort: keys kind: nil into: (Array new: 3) from: 0 to: 2 descending: false stringClasses: self classes ] -> #'bad index'.
		[ TimSortLibrary argSort: keys kind: nil into: (Array new: 2) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: keys kind: nil into: keys from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: #( 'b' 'a' 'c' ) kind: nil into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: #( 'b' ) kind: nil into: (Array new: 1) from: 1 to: 1 descending: false stringClasses: self classes ] -> #'bad argument'.
		[ TimSortLibrary argSort: { 1.0. Float nan } kind: nil into: (Array new: 2) from: 1 to: 2 descending: false stringClasses: self classes ] -> #'bad argument' }
			do: [ :each | self assertFailure: each key value ec: each value ].
	self assert: keys equals: #( 3 1 2 ).
	self assert: (TimSortLibrary argSort: keys kind: nil into: (Array new: 0) from: 2 to: 1 descending: false stringClasses: self classes) equals: #().
	self assert: (TimSortLibrary argSort: #( 'b' 'a' ) kind: nil into: (Array new: 0) from: 3 to: 2 descending: false stringClasses: self classes) equals: #().
	self assert: (TimSortLibrary argSort: keys kind: nil into: (Array new: 1) from: 2 to: 2 descending: false stringClasses: self classes) equals: #( 2 )
]

{ #category : 'tests' }
TimSortLibraryTests >> testObjectsOfTheCallerNeverPinned [
	"The library reads and writes private pinned copies: the Arrays, buffers and perms of the caller are left unpinned, and one that was pinned stays pinned (and is sorted)"

	| array floats buffer pinned perm |
	array := (1000 to: 1 by: -1) asArray.
	floats := (1 to: 1000) collect: [ :k | 1000.5 - k ].
	buffer := Float64Array withAll: floats.
	pinned := (DoubleWordArray withAll: (1000 to: 1 by: -1)) pinInMemory; yourself.
	TimSortLibrary sortObjects: array from: 1 to: 1000 descending: false stringClasses: self classes.
	TimSortLibrary sortObjects: floats from: 1 to: 1000 descending: false stringClasses: self classes.
	TimSortLibrary sortBuffer: buffer kind: TimSort kindFloat64 from: 1 to: 1000 descending: false.
	TimSortLibrary sortBuffer: pinned kind: TimSort kindUInt64 from: 1 to: 1000 descending: false.
	perm := TimSortLibrary argSort: buffer kind: TimSort kindFloat64 into: (Array new: 1000) from: 1 to: 1000 descending: true stringClasses: self classes.
	self assert: array equals: (1 to: 1000) asArray.
	self assert: floats first equals: 0.5.
	self assert: buffer first equals: 0.5.
	self assert: pinned asArray equals: (1 to: 1000) asArray.
	self assert: perm equals: (1000 to: 1 by: -1) asArray.
	{ array. floats. buffer. perm } do: [ :each | self deny: each isPinnedInMemory ].
	self assert: pinned isPinnedInMemory.
	pinned unpinInMemory
]

{ #category : 'tests' }
TimSortLibraryTests >> testResumableSort [
	"A sortBlock answered here, a comparison at a time: the result of Pharo's sort: for [ :a :b | a <= b ] and its descending flag the one of sort: [ :a :b | a >= b ], stable (Associations of few keys compared by identity); fewer than two elements done at once"

	| random assocs block live |
	self requireCoroutines.
	live := TimSortLibrary blockSortLive.
	random := self random.
	block := [ :a :b | a key <= b key ].
	#( 0 1 2 3 10 100 1000 10000 ) do: [ :n |
		assocs := (1 to: n) collect: [ :k | (random nextInteger: 5) -> k ].
		self assert: (self drive: assocs with: block descending: false) same: (assocs copy sort: block).
		self assert: (self drive: assocs with: block descending: true) same: (assocs copy sort: [ :a :b | a key >= b key ]) ].
	self assert: TimSortLibrary blockSortLive equals: live
]

{ #category : 'tests' }
TimSortLibraryTests >> testResumableSortContract [
	"The ids and the failures of the four calls, as the primitives answer them: stale ids #'not found', a second free false, the permutation before the end #'inappropriate operation', of a wrong size #'bad argument', into a read-only Array #'no modification'; an abort is -3 and leaves no permutation"

	| live id request readOnly |
	self requireCoroutines.
	live := TimSortLibrary blockSortLive.
	self assertFailure: (TimSortLibrary blockSortNew: -1 descending: false) ec: #'bad argument'.
	self assertFailure: (TimSortLibrary blockSortNew: (1 bitShift: 31) descending: false) ec: #'bad argument'.
	self assertFailure: (TimSortLibrary blockSortNew: 3 descending: nil) ec: #'bad argument'.
	self assertFailure: (TimSortLibrary blockSortNew: 3.0 descending: false) ec: #'bad argument'.
	id := TimSortLibrary blockSortNew: 3 descending: false.
	self assert: (id isKindOf: SmallInteger).
	self assert: id >= 1.
	self assert: TimSortLibrary blockSortLive equals: live + 1.
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: (Array new: 3)) ec: #'inappropriate operation'.
	request := TimSortLibrary blockSortNext: id answer: 0.
	self assert: request >= 0.
	self assert: ((request bitShift: -32) between: 0 and: 2).
	self assert: ((request bitAnd: 16rFFFFFFFF) between: 0 and: 2).
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: (Array new: 3)) ec: #'inappropriate operation'.
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: (Array new: 2)) ec: #'bad argument'.
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: 'abc' copy) ec: #'bad argument'.
	self assertFailure: (TimSortLibrary blockSortNext: id answer: nil) ec: #'bad argument'.
	[ (request := TimSortLibrary blockSortNext: id answer: 1) >= 0 ] whileTrue.
	self assert: request equals: -1.
	self assert: (TimSortLibrary blockSortNext: id answer: 1) equals: -1.
	readOnly := (Array new: 3) beReadOnlyObject; yourself.
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: readOnly) ec: #'no modification'.
	self assert: (TimSortLibrary blockSortPermutation: id into: (Array new: 3)) asSet equals: #( 1 2 3 ) asSet.
	self assert: (TimSortLibrary blockSortFree: id).
	self deny: (TimSortLibrary blockSortFree: id).
	self assertFailure: (TimSortLibrary blockSortNext: id answer: 0) ec: #'not found'.
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: (Array new: 3)) ec: #'not found'.
	self assertFailure: (TimSortLibrary blockSortFree: nil) ec: #'bad argument'.
	"an abort"
	id := TimSortLibrary blockSortNew: 100 descending: true.
	self assert: (TimSortLibrary blockSortNext: id answer: 0) >= 0.
	self assert: (TimSortLibrary blockSortNext: id answer: -1) equals: -3.
	self assert: (TimSortLibrary blockSortNext: id answer: 0) equals: -3.
	self assertFailure: (TimSortLibrary blockSortPermutation: id into: (Array new: 100)) ec: #'inappropriate operation'.
	self assert: (TimSortLibrary blockSortFree: id).
	"empty and singleton sorts"
	#( 0 1 ) do: [ :n |
		id := TimSortLibrary blockSortNew: n descending: false.
		self assert: (TimSortLibrary blockSortNext: id answer: 0) equals: -1.
		self assert: (TimSortLibrary blockSortPermutation: id into: (Array new: n)) equals: ((1 to: n) asArray).
		self assert: (TimSortLibrary blockSortFree: id) ].
	self assert: TimSortLibrary blockSortLive equals: live
]

{ #category : 'tests' }
TimSortLibraryTests >> testResumableSortTable [
	"64 sorts of the library may be live, the 65th is #'inappropriate operation' until one is freed; ids are never given twice"

	| live ids extra |
	self requireCoroutines.
	live := TimSortLibrary blockSortLive.
	ids := OrderedCollection new.
	[
		[ ids size + live < 64 ] whileTrue: [ ids add: (TimSortLibrary blockSortNew: 10 descending: false) ].
		ids do: [ :each | self assert: (TimSortLibrary blockSortNext: each answer: 0) >= 0 ].
		self assertFailure: (TimSortLibrary blockSortNew: 10 descending: false) ec: #'inappropriate operation'.
		self assert: (TimSortLibrary blockSortFree: ids removeFirst).
		extra := TimSortLibrary blockSortNew: 10 descending: false.
		self deny: extra timSortFailed.
		self assert: extra > ids last.
		ids add: extra ]
			ensure: [ ids do: [ :each | TimSortLibrary blockSortFree: each ] ].
	self assert: TimSortLibrary blockSortLive equals: live
]

{ #category : 'tests' }
TimSortLibraryTests >> testNoLockAcrossCallouts [
	"Nothing is held across a callout: a sortBlock that sorts with the library (objects, buffers, another resumable sort) runs its sorts between two steps of the outer one, and two Processes drive sorts of their own, interleaved at each comparison"

	| random data inner sorted done results trace live |
	self requireCoroutines.
	live := TimSortLibrary blockSortLive.
	random := self random.
	data := (1 to: 300) collect: [ :k | random nextInteger: 1000 ].
	inner := 0.
	sorted := self drive: data with: [ :a :b |
		(inner := inner + 1) \\ 50 = 0 ifTrue: [
			self assert: (TimSortLibrary sortObjects: #( 3 1 2 ) copy from: 1 to: 3 descending: false stringClasses: self classes) equals: #( 1 2 3 ).
			self assert: (TimSortLibrary sortBuffer: (Float64Array withAll: #( 2.0 1.0 )) kind: TimSort kindFloat64 from: 1 to: 2 descending: false) asArray equals: #( 1.0 2.0 ).
			self assert: (self drive: #( 5 4 3 2 1 ) with: [ :x :y | x <= y ] descending: false) equals: #( 1 2 3 4 5 ) ].
		a <= b ] descending: false.
	self assert: sorted equals: data asSortedCollection asArray.
	self assert: inner > 1000.
	done := Semaphore new.
	results := Array new: 2.
	trace := OrderedCollection new.
	1 to: 2 do: [ :p |
		[
			[ results at: p put: (self drive: (p = 1 ifTrue: [ data ] ifFalse: [ data reversed ]) with: [ :a :b |
					trace add: p.
					Processor yield.
					a <= b ] descending: false) ]
				ensure: [ done signal ] ] forkAt: Processor activePriority ].
	done wait; wait.
	self assert: results first equals: sorted.
	self assert: results second equals: sorted.
	self assert: ((2 to: trace size) count: [ :k | (trace at: k) ~= (trace at: k - 1) ]) > 100.
	self assert: TimSortLibrary blockSortLive equals: live
]

{ #category : 'tests' }
TimSortLibraryTests >> testSortsOfTheSession [
	"The library knows the size of a live sort (ts_ffi_coro_size), not after it is freed; the image keeps no table of them.  A new session probes the library again"

	| id saved |
	self requireCoroutines.
	id := TimSortLibrary blockSortNew: 7 descending: false.
	self assert: (TimSortLibrary uniqueInstance primCoroSize: id) equals: 7.
	TimSortLibrary blockSortFree: id.
	self assert: (TimSortLibrary uniqueInstance primCoroSize: id) equals: -4.
	self assert: (TimSortLibrary classVarNames includesAny: #( #Sorts #SortsLock )) not.
	saved := TimSortLibrary classVarNamed: #Availability.
	[
		TimSortLibrary classVarNamed: #Availability put: { Object new. false. false }.
		self assert: TimSortLibrary isAvailable.
		self assert: (TimSortLibrary classVarNamed: #Availability) first identicalTo: Smalltalk session ]
		ensure: [ TimSortLibrary classVarNamed: #Availability put: saved ]
]

{ #category : 'tests' }
TimSortLibraryTests >> testLibraryPath [
	"libraryPath: takes effect at once: the callouts made so far are reset (made again for the new name at their next call), the availability is asked again, and TimSort chooses its backends again.  (A path where no library is cannot be tested here: the functions of the library loaded already are found in the process)"

	| saved path callout |
	saved := TimSortLibrary libraryPath.
	path := TimSortLibrary uniqueInstance libraryName.
	TimSort testHook: #pluginMissing value: true.
	self assert: TimSort backend equals: #ffi.
	self assert: TimSortLibrary uniqueInstance primProtocol equals: 1.
	callout := TimSortLibrary >> #primProtocol.
	[
		TimSortLibrary libraryPath: path.
		self assert: TimSortLibrary libraryPath equals: path.
		self assert: TimSortLibrary uniqueInstance libraryName equals: path.
		self deny: (TimSortLibrary >> #primProtocol) identicalTo: callout.
		self assert: TimSortLibrary isAvailable.
		self assert: TimSort backend equals: #ffi.
		self assert: (TimSort sort: #( 3 1 2 ) copy) equals: #( 1 2 3 ) ]
			ensure: [ TimSortLibrary libraryPath: saved ].
	self assert: TimSortLibrary libraryPath equals: saved.
	self assert: TimSortLibrary isAvailable
]

{ #category : 'tests' }
TimSortLibraryTests >> testTimSortTakesTheLibrary [
	"Without the plugin, TimSort sorts through the library, and its resumable sort is the backend #ffi of sort:with:backend: when the library has one (timSort: aBlock still runs TimSortSmalltalk); without TimSort-FFI either, in Smalltalk"

	| people |
	TimSort testHook: #pluginMissing value: true.
	self assert: TimSort backend equals: #ffi.
	self deny: TimSort pluginAvailable.
	self assert: TimSort coroutinesAvailable equals: TimSortLibrary coroutinesAvailable.
	self assert: TimSort blockSortBackend equals: #smalltalk.
	self assert: TimSort resumableBackend equals: (TimSortLibrary coroutinesAvailable ifTrue: [ #ffi ] ifFalse: [ nil ]).
	self assert: (TimSort sort: #( 3 1.5 2 ) copy) equals: #( 1.5 2 3 ).
	self assert: (TimSort sort: #( 'b' 'a' ) copy) equals: #( 'a' 'b' ).
	self assert: (TimSort sortDescending: (Float64Array withAll: #( 1.0 3.0 2.0 ))) asArray equals: #( 3.0 2.0 1.0 ).
	self assert: (TimSort argSort: #( 30 10 20 )) equals: #( 2 3 1 ).
	people := #( 40 20 30 10 ) collect: [ :age | age -> age printString ].
	self assert: ((TimSort sort: people copy with: [ :a :b | a key <= b key ]) collect: [ :each | each key ]) equals: #( 10 20 30 40 ).
	TimSortLibrary coroutinesAvailable ifTrue: [
		self assert: ((TimSort sort: people copy with: [ :a :b | a key <= b key ] backend: #ffi) collect: [ :each | each key ]) equals: #( 10 20 30 40 ) ].
	self assert: TimSort liveCoroutines equals: 0.
	TimSort testHook: #fallbackMissing value: true.
	self assert: TimSort backend equals: #smalltalk.
	self deny: TimSort coroutinesAvailable.
	self should: [ TimSort sort: people copy with: [ :a :b | a key <= b key ] backend: #ffi ] raise: TimSortBackendUnavailable.
	self assert: (TimSort sort: #( 3 1.5 2 ) copy) equals: #( 1.5 2 3 )
]

{ #category : 'tests' }
TimSortLibraryTests >> testNotFoundTakesTheLibrary [
	"On a VM without the plugin, its primitives fail with #'not found' and TimSort takes the library"

	TimSort pluginAvailable ifTrue: [ ^ self skip: 'the VM has the TimSortPlugin' ].
	self assert: TimSortPrimitives primInfo isNil.
	self assert: (TimSortPrimitives sortObjects: #( 2 1 ) copy from: 1 to: 2 descending: false stringClasses: self classes) isNotFound.
	TimSort resetBackend.
	self assert: TimSort backend equals: #ffi.
	self assert: (TimSort sort: (1000 to: 1 by: -1) asArray) equals: (1 to: 1000) asArray
]

{ #category : 'tests' }
TimSortLibraryTests >> testSameAnswersAsThePlugin [
	"Random calls of sortObjects:, sortBuffer: and argSort:, valid or not: where the library sorts, the plugin gives the same result (== per slot, bit for bit); where the library fails, the plugin fails with the same error code, unless the library declines elements the plugin sorts (strings, LargeIntegers)"

	| random |
	TimSortPrimitives primInfo ifNil: [ ^ self skip: 'no TimSortPlugin' ].
	random := self random.
	self class calls timesRepeat: [
		| roll |
		roll := random nextInteger: 3.
		roll = 1 ifTrue: [ self sameSortObjects: random ].
		roll = 2 ifTrue: [ self sameSortBuffer: random ].
		roll = 3 ifTrue: [ self sameArgSort: random ] ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> randomRangeFor: size random: random [
	"A random range of size elements, out of bounds now and then"

	| start stop |
	start := random nextInteger: size + 1.
	stop := start - 1 + (random nextInteger: size - start + 2) - 1.
	(random nextInteger: 30) = 1 ifTrue: [ start := start - 1 ].
	(random nextInteger: 30) = 1 ifTrue: [ stop := stop + 1 ].
	(random nextInteger: 60) = 1 ifTrue: [ start := stop + 2 ].
	^ start -> stop
]

{ #category : 'helpers' }
TimSortLibraryTests >> randomElements: n random: random [
	"An Array of n elements: SmallIntegers, Floats, now and then strings, LargeIntegers, NaN or nil"

	| elements roll |
	roll := random nextInteger: 6.
	elements := roll <= 2
		ifTrue: [ self integers: n random: random ]
		ifFalse: [ self floats: n random: random ].
	(roll = 3 and: [ n > 0 ]) ifTrue: [
		elements at: (random nextInteger: n) put: ({ 'a'. #b. 1 bitShift: 70. (1 bitShift: 70) negated. Float nan. nil. 1/3 } at: (random nextInteger: 7)) ].
	roll = 4 ifTrue: [ elements := elements collect: [ :each | each printString ] ].
	^ elements
]

{ #category : 'helpers' }
TimSortLibraryTests >> library: libraryAnswer plugin: pluginAnswer [
	"Compare the answers of the library and the plugin to one call (the results were checked for equality by the caller)"

	libraryAnswer timSortFailed ifFalse: [
		self deny: pluginAnswer timSortFailed description: 'the plugin failed where the library did not: ' , pluginAnswer printString.
		^ true ].
	(libraryAnswer ec == #'bad argument' and: [ pluginAnswer timSortFailed not ]) ifTrue: [ ^ false ].
	self assert: pluginAnswer timSortFailed description: 'the library failed where the plugin did not: ' , libraryAnswer printString.
	self assert: libraryAnswer ec equals: pluginAnswer ec.
	^ false
]

{ #category : 'helpers' }
TimSortLibraryTests >> sameSortObjects: random [
	| n elements range descending a b ra rb |
	n := random nextInteger: 40.
	elements := self randomElements: n random: random.
	range := self randomRangeFor: n random: random.
	descending := (random nextInteger: 40) = 1 ifTrue: [ nil ] ifFalse: [ random next < 0.5 ].
	a := elements copy.
	b := elements copy.
	(random nextInteger: 30) = 1 ifTrue: [ a beReadOnlyObject. b beReadOnlyObject ].
	ra := TimSortLibrary sortObjects: a from: range key to: range value descending: descending stringClasses: self classes.
	rb := TimSortPrimitives sortObjects: b from: range key to: range value descending: descending stringClasses: self classes.
	(self library: ra plugin: rb)
		ifTrue: [ self assert: a same: b ]
		ifFalse: [ self assert: a same: elements ]
]

{ #category : 'helpers' }
TimSortLibraryTests >> sameSortBuffer: random [
	| classes class kind n buffer range descending a b ra rb |
	classes := self bufferClasses.
	class := (classes at: (random nextInteger: classes size)) key.
	kind := (random nextInteger: 6) = 1
		ifTrue: [ random nextInteger: 9 ]
		ifFalse: [ TimSort kindOf: (class new: 0) ].
	n := random nextInteger: 40.
	buffer := self buffer: class size: n random: random.
	range := self randomRangeFor: n random: random.
	descending := random next < 0.5.
	a := buffer copy.
	b := buffer copy.
	(random nextInteger: 30) = 1 ifTrue: [ a beReadOnlyObject. b beReadOnlyObject ].
	ra := TimSortLibrary sortBuffer: a kind: kind from: range key to: range value descending: descending.
	rb := TimSortPrimitives sortBuffer: b kind: kind from: range key to: range value descending: descending.
	self library: ra plugin: rb.
	self assert: (self bitsOf: a) equals: (self bitsOf: b)
]

{ #category : 'helpers' }
TimSortLibraryTests >> sameArgSort: random [
	| n keys kind range descending size ra rb |
	n := random nextInteger: 40.
	(random nextInteger: 2) = 1
		ifTrue: [
			keys := self randomElements: n random: random.
			kind := nil ]
		ifFalse: [
			| classes class |
			classes := self bufferClasses.
			class := (classes at: (random nextInteger: classes size)) key.
			keys := self buffer: class size: n random: random.
			kind := TimSort kindOf: keys ].
	range := self randomRangeFor: n random: random.
	descending := random next < 0.5.
	size := (range value - range key + 1) max: 0.
	(random nextInteger: 30) = 1 ifTrue: [ size := size + 1 ].
	ra := TimSortLibrary argSort: keys kind: kind into: (Array new: size) from: range key to: range value descending: descending stringClasses: self classes.
	rb := TimSortPrimitives argSort: keys kind: kind into: (Array new: size) from: range key to: range value descending: descending stringClasses: self classes.
	(self library: ra plugin: rb) ifTrue: [ self assert: ra equals: rb ]
]
