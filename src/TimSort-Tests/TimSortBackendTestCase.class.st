"
I am the abstract test of a backend of `TimSort`: each subclass runs once per backend, hook `#backend` set to `backendObject` (`TimSort sort:with:backend:` of its name then runs its resumable sort when it has one; the sorts by a sortBlock run in `TimSortSmalltalk` by default).
"
Class {
	#name : 'TimSortBackendTestCase',
	#superclass : 'ParametrizedTestCase',
	#instVars : [
		'backendName'
	],
	#category : 'TimSort-Tests-Support',
	#package : 'TimSort-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
TimSortBackendTestCase class >> defaultTimeLimit [
	"The differential tests sort thousands of collections, and the sorts in Smalltalk take ten to forty times as long on the WebAssembly VMs: the default limit of 10 s is too short"

	^ 120 seconds
]

{ #category : 'testing' }
TimSortBackendTestCase class >> isAbstract [
	^ self == TimSortBackendTestCase
]

{ #category : 'building suites' }
TimSortBackendTestCase class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #backendName addOptions: #( #plugin #smalltalk );
		yourself
]

{ #category : 'accessing' }
TimSortBackendTestCase >> backendName [
	^ backendName
]

{ #category : 'accessing' }
TimSortBackendTestCase >> backendName: aSymbol [
	backendName := aSymbol
]

{ #category : 'accessing' }
TimSortBackendTestCase >> backendObject [
	"The object that answers the backend protocol for backendName"

	backendName == #plugin ifTrue: [
		TimSort pluginAvailable ifFalse: [ self skip: 'no TimSortPlugin' ].
		^ TimSortPrimitives ].
	^ TimSortPortBackend
]

{ #category : 'running' }
TimSortBackendTestCase >> setUp [
	super setUp.
	TimSort testHook: #backend value: self backendObject
]

{ #category : 'running' }
TimSortBackendTestCase >> tearDown [
	TimSort
		testHook: #backend value: nil;
		testHook: #pluginMissing value: nil;
		testHook: #fallbackMissing value: nil.
	super tearDown
]

{ #category : 'helpers' }
TimSortBackendTestCase >> assert: actual sameAs: expected [
	"actual holds the same objects as expected (==) in the same slots: equal elements in the same order"

	self assert: actual size equals: expected size.
	1 to: expected size do: [ :i |
		(actual at: i) == (expected at: i) ifFalse: [
			self fail: 'slot ' , i printString , ': ' , (actual at: i) printString , ' instead of ' , (expected at: i) printString ] ]
]

{ #category : 'helpers' }
TimSortBackendTestCase >> assert: actual sameBitsAs: expected [
	"The buffers hold the same bits (basicAt:), so that NaNs and -0.0 are told apart"

	self assert: actual class equals: expected class.
	self assert: actual size equals: expected size.
	1 to: expected size do: [ :i |
		(actual basicAt: i) = (expected basicAt: i) ifFalse: [
			self fail: 'element ' , i printString , ': ' , (actual at: i) printString , ' instead of ' , (expected at: i) printString ] ]
]

{ #category : 'helpers' }
TimSortBackendTestCase >> random [
	"A Random with a fixed seed, so that a failure can be replayed"

	^ Random seed: 20261117
]

{ #category : 'helpers' }
TimSortBackendTestCase >> sizes [
	"The sizes of the differential tests: the small ones (binary insertion), around the minimum run (32 to 64) and the merges"

	^ #( 0 1 2 3 4 5 7 8 15 16 17 31 32 33 63 64 65 100 127 128 129 255 256 257 600 1000 2049 5000 )
]
