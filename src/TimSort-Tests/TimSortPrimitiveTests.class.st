"
I test `TimSort`: The raw contract of the primitives (`docs/TimSort.md`, Primitive contract): answers, declines and failure codes, forwarders, the resumable sort and its table of ids; skipped without the plugin.
"
Class {
	#name : 'TimSortPrimitiveTests',
	#superclass : 'TestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortPrimitiveTests >> coroutines [
	^ TimSortPrimitives primInfo at: 5
]

{ #category : 'helpers' }
TimSortPrimitiveTests >> ec: anObject [
	"The error code of a failed primitive, or #succeeded"

	^ anObject timSortFailed
		  ifTrue: [ anObject ec ]
		  ifFalse: [ #succeeded ]
]

{ #category : 'helpers' }
TimSortPrimitiveTests >> sort: anArray [
	^ TimSortPrimitives sortObjects: anArray from: 1 to: anArray size descending: false stringClasses: TimSort stringClasses
]

{ #category : 'running' }
TimSortPrimitiveTests >> setUp [
	super setUp.
	TimSort pluginAvailable ifFalse: [ self skip: 'no TimSortPlugin' ]
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testArgSort [
	| keys perm |
	keys := #( 30 10 20 ).
	perm := Array new: 3.
	self assert: (TimSortPrimitives argSort: keys kind: nil into: perm from: 1 to: 3 descending: false stringClasses: TimSort stringClasses) identicalTo: perm.
	self assert: perm equals: #( 2 3 1 ).
	self
		assert: (TimSortPrimitives argSort: (Float64Array withAll: #( 2.0 1.0 3.0 )) kind: TimSort kindFloat64 into: (Array new: 2) from: 2 to: 3 descending: true stringClasses: TimSort stringClasses)
		equals: #( 3 2 ).
	self assert: (self ec: (TimSortPrimitives argSort: keys kind: nil into: (Array new: 2) from: 1 to: 3 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives argSort: keys copy kind: nil into: #( 0 0 0 ) from: 1 to: 3 descending: false stringClasses: TimSort stringClasses)) equals: #'no modification'.
	self assert: (self ec: (TimSortPrimitives argSort: keys kind: TimSort kindUInt8 into: (Array new: 3) from: 1 to: 3 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives argSort: { 1. nil } kind: nil into: (Array new: 2) from: 1 to: 2 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'.
	perm := Array new: 3.
	self assert: (self ec: (TimSortPrimitives argSort: perm kind: nil into: perm from: 1 to: 3 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testBlockSort [
	"The resumable sort through the raw primitives: requests, answers, the permutation, the ids"

	| id request answer items perm ids |
	self coroutines ifFalse: [
		self assert: (self ec: (TimSortPrimitives blockSortNew: 3 descending: false)) equals: #'unsupported operation'.
		self assert: (self ec: (TimSortPrimitives blockSortNext: 1 answer: 0)) equals: #'unsupported operation'.
		^ self ].
	items := #( 30 10 20 10 ).
	id := TimSortPrimitives blockSortNew: items size descending: false.
	self assert: id isInteger.
	self assert: TimSortPrimitives blockSortLive equals: 1.
	self assert: (self ec: (TimSortPrimitives blockSortPermutation: id into: (Array new: 4))) equals: #'inappropriate operation'.
	answer := 0.
	[ (request := TimSortPrimitives blockSortNext: id answer: answer) >= 0 ] whileTrue: [
		| i j |
		i := request bitShift: -32.
		j := request bitAnd: 16rFFFFFFFF.
		self assert: (i between: 0 and: 3).
		self assert: (j between: 0 and: 3).
		answer := (items at: j + 1) <= (items at: i + 1) ifTrue: [ 0 ] ifFalse: [ 1 ] ].
	self assert: request equals: -1.
	self assert: (TimSortPrimitives blockSortNext: id answer: 0) equals: -1.
	self assert: (self ec: (TimSortPrimitives blockSortPermutation: id into: (Array new: 3))) equals: #'bad argument'.
	perm := Array new: 4.
	self assert: (TimSortPrimitives blockSortPermutation: id into: perm) identicalTo: perm.
	self assert: perm equals: #( 2 4 3 1 ).
	self assert: (TimSortPrimitives blockSortFree: id) equals: true.
	self assert: (TimSortPrimitives blockSortFree: id) equals: false.
	self assert: (self ec: (TimSortPrimitives blockSortNext: id answer: 0)) equals: #'not found'.
	self assert: (self ec: (TimSortPrimitives blockSortPermutation: id into: perm)) equals: #'not found'.
	self assert: (self ec: (TimSortPrimitives blockSortNew: (2 raisedTo: 28) + 1 descending: false)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives blockSortNew: 3 descending: nil)) equals: #'bad argument'.
	"an abort answers -3, and stays so"
	id := TimSortPrimitives blockSortNew: 3 descending: false.
	self assert: (TimSortPrimitives blockSortNext: id answer: 0) >= 0.
	self assert: (TimSortPrimitives blockSortNext: id answer: -1) equals: -3.
	self assert: (TimSortPrimitives blockSortNext: id answer: 0) equals: -3.
	self assert: (TimSortPrimitives blockSortFree: id).
	"64 live sorts at most; ids are never reused"
	ids := OrderedCollection new.
	[
	[ ids size < 64 ] whileTrue: [
		id := TimSortPrimitives blockSortNew: 2 descending: false.
		self deny: id timSortFailed.
		self deny: (ids includes: id).
		ids add: id ].
	self assert: (self ec: (TimSortPrimitives blockSortNew: 2 descending: false)) equals: #'inappropriate operation' ]
		ensure: [ ids do: [ :each | TimSortPrimitives blockSortFree: each ] ].
	self assert: TimSortPrimitives blockSortLive equals: 0
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testDeclines [
	"The pre-pass declines (#'bad argument', the Array untouched) anything but all numbers or all strings of the four classes"

	| odd |
	odd := LargePositiveInteger new: 8.
	odd at: 1 put: 5.
	{
		{ 2. Float nan. 1 }.
		{ 2. nil. 1 }.
		{ 2. 1/2. 1 }.
		{ 2. 'a'. 1 }.
		{ $b. $a }.
		{ 2. odd. 1 }.
		{ 'b'. 'a' asWideString. 3 }.
		{ 2. 1.5s2. 1 } } do: [ :each |
		| copy |
		copy := each copy.
		self assert: (self ec: (self sort: copy)) equals: #'bad argument'.
		1 to: each size do: [ :i | self assert: (copy at: i) identicalTo: (each at: i) ] ].
	self assert: (self sort: { nil }) equals: { nil }.
	self assert: (self sort: { Float nan. Float nan }) isArray not
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testFailures [
	self assert: (self ec: (self sort: #( 3 1 2 ))) equals: #'no modification'.
	self assert: (self ec: (TimSortPrimitives sortObjects: #( 3 1 2 ) copy from: 0 to: 2 descending: false stringClasses: TimSort stringClasses)) equals: #'bad index'.
	self assert: (self ec: (TimSortPrimitives sortObjects: #( 3 1 2 ) copy from: 2 to: 4 descending: false stringClasses: TimSort stringClasses)) equals: #'bad index'.
	self assert: (self ec: (TimSortPrimitives sortObjects: #( 3 1 2 ) copy from: 1 to: 3 descending: nil stringClasses: TimSort stringClasses)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortObjects: #( 3 1 2 ) copy from: 1 to: 3 descending: false stringClasses: #( 1 2 3 4 ))) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortObjects: #( 3 1 2 ) copy from: 1.0 to: 3 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortObjects: (WeakArray with: 'b' with: 'a') from: 1 to: 2 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortObjects: (OrderedCollection withAll: #( 2 1 )) from: 1 to: 2 descending: false stringClasses: TimSort stringClasses)) equals: #'bad argument'
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testForwarders [
	"A forwarder among the elements fails the pre-pass; the VM follows the forwarders of the slots (accessor depth 1) and runs the primitive again"

	| a b holder large |
	a := 'zz' copy.
	b := 'aa' copy.
	holder := { 'mm' copy. a }.
	a becomeForward: b.
	self assert: (self sort: holder) identicalTo: holder.
	self assert: holder equals: #( 'aa' 'mm' ).
	self assert: (holder at: 1) identicalTo: b.
	large := (2 raisedTo: 70) copy.
	a := (2 raisedTo: 80) copy.
	b := 1.0e300 copy.
	holder := { a. 3. large }.
	a becomeForward: b.
	self assert: (self sort: holder) equals: { 3. large. 1.0e300 }.
	self assert: (holder at: 3) identicalTo: b
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testInfo [
	| info |
	info := TimSortPrimitives primInfo.
	self assert: info size equals: 6.
	self assert: info first equals: 1.
	self assert: (info at: 2) equals: 'TimSortPlugin 1.0'.
	self assert: (info at: 3) equals: 'timsort.c fd70381'.
	self assert: (#( 'native' 'emscripten' ) includes: (info at: 4)).
	self assert: (#( true false ) includes: (info at: 5)).
	(info at: 4) = 'emscripten' ifTrue: [ self deny: (info at: 5) ].
	self assert: (info at: 6) equals: 0.
	self assert: TimSort pluginInfo first equals: 1
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testSortBuffer [
	| buffer |
	buffer := Float64Array withAll: #( 3.0 1.0 2.0 ).
	self assert: (TimSortPrimitives sortBuffer: buffer kind: TimSort kindFloat64 from: 1 to: 3 descending: false) identicalTo: buffer.
	self assert: buffer asArray equals: #( 1.0 2.0 3.0 ).
	self assert: (self ec: (TimSortPrimitives sortBuffer: buffer kind: TimSort kindUInt8 from: 1 to: 3 descending: false)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortBuffer: buffer kind: 9 from: 1 to: 3 descending: false)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortBuffer: buffer kind: TimSort kindFloat64 from: 1 to: 4 descending: false)) equals: #'bad index'.
	self assert: (self ec: (TimSortPrimitives sortBuffer: Object >> #printString kind: TimSort kindUInt8 from: 1 to: 2 descending: false)) equals: #'bad argument'.
	self assert: (self ec: (TimSortPrimitives sortBuffer: 1.0e300 kind: TimSort kindUInt32 from: 1 to: 2 descending: false)) equals: #'bad argument'.
	buffer beReadOnlyObject.
	self assert: (self ec: (TimSortPrimitives sortBuffer: buffer kind: TimSort kindFloat64 from: 1 to: 3 descending: true)) equals: #'no modification'.
	buffer beWritableObject.
	self assert: buffer asArray equals: #( 1.0 2.0 3.0 )
]

{ #category : 'tests' }
TimSortPrimitiveTests >> testSortObjects [
	| array |
	array := { 3. 2 raisedTo: 70. -1.5. 2 }.
	self assert: (self sort: array) identicalTo: array.
	self assert: array equals: { -1.5. 2. 3. 2 raisedTo: 70 }.
	array := { 'b'. #a. 'c' asWideString. TimSortTestData wideSymbol }.
	self assert: (TimSortPrimitives sortObjects: array from: 1 to: 4 descending: true stringClasses: TimSort stringClasses) identicalTo: array.
	self assert: array equals: { TimSortTestData wideSymbol. 'c'. 'b'. #a }.
	self assert: (self sort: {  }) equals: {  }
]
