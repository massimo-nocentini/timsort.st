"
I test TimSort: The choice of the backends: the test hooks, the session, the probe of the library, and where the sorts by a sortBlock run: TimSortSmalltalk by default in every configuration, the resumable C sorts of resumableBackends when sort:with:backend: names them.
"
Class {
	#name : 'TimSortSelectionTests',
	#superclass : 'TestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'running' }
TimSortSelectionTests >> tearDown [
	TimSort
		testHook: #backend value: nil;
		testHook: #pluginMissing value: nil;
		testHook: #fallbackMissing value: nil.
	super tearDown
]

{ #category : 'tests' }
TimSortSelectionTests >> testHookBackend [
	TimSort testHook: #backend value: TimSortPortBackend.
	self assert: TimSort backend equals: #smalltalk.
	self assert: TimSort blockSortBackend equals: #smalltalk.
	self deny: (TimSort resumableBackends includes: #smalltalk).
	self assert: TimSort coroutinesAvailable equals: TimSort resumableBackends notEmpty.
	self assert: #( 3 1 2 ) copy timSort equals: #( 1 2 3 ).
	TimSort testHook: #backend value: nil.
	self assert: (#( #plugin #ffi #smalltalk ) includes: TimSort backend).
	TimSort pluginAvailable ifTrue: [ self assert: TimSort backend equals: #plugin ]
]

{ #category : 'tests' }
TimSortSelectionTests >> testDefaultIsThePortInEveryConfiguration [
	"In every configuration of the hooks, the sorts by a sortBlock run TimSortSmalltalk by default (no resumable sort is live while the block runs, and the block is evaluated by a sorter of the port), and each backend of resumableBackends sorts when it is named, its resumable sort live"

	| configurations |
	configurations := OrderedCollection new.
	configurations
		add: #(  );
		add: { #pluginMissing -> true };
		add: { #pluginMissing -> true. #fallbackMissing -> true };
		add: { #fallbackMissing -> true };
		add: { #backend -> TimSortPortBackend }.
	TimSort pluginAvailable ifTrue: [ configurations add: { #backend -> TimSortPrimitives } ].
	configurations do: [ :hooks |
		| live senders |
		hooks do: [ :each | TimSort testHook: each key value: each value ].
		self assert: TimSort blockSortBackend equals: #smalltalk.
		live := Set new.
		senders := IdentitySet new.
		self
			assert: ((1 to: 200) asArray reversed timSort: [ :a :b |
					 live add: TimSort liveCoroutines.
					 senders add: thisContext sender receiver class.
					 a <= b ])
			equals: (1 to: 200) asArray.
		self assert: live asArray equals: #( 0 ).
		self assert: (senders allSatisfy: [ :each | each includesBehavior: TimSortSmalltalkSorter ]).
		TimSort resumableBackends do: [ :name |
			live := Set new.
			self
				assert: (TimSort sort: (1 to: 200) asArray reversed with: [ :a :b |
						 live add: TimSort liveCoroutines.
						 a <= b ] backend: name)
				equals: (1 to: 200) asArray.
			self assert: live asArray equals: #( 1 ) ].
		self assert: TimSort liveCoroutines equals: 0.
		#( #backend #pluginMissing #fallbackMissing ) do: [ :each | TimSort testHook: each value: nil ] ]
]

{ #category : 'tests' }
TimSortSelectionTests >> testExplicitBackends [
	"sort:with:backend: and sort:from:to:with:backend: sort with each backend of resumableBackends and with #smalltalk; #plugin and #ffi that are not among them, and any other name, signal TimSortBackendUnavailable with the array untouched"

	| array |
	TimSort resumableBackends , #( #smalltalk ) do: [ :name |
		array := #( 5 3 9 1 7 3 ) copy.
		self assert: (TimSort sort: array with: [ :a :b | a >= b ] backend: name) identicalTo: array.
		self assert: array equals: #( 9 7 5 3 3 1 ).
		self assert: (TimSort sort: array from: 2 to: 5 with: [ :a :b | a <= b ] backend: name) identicalTo: array.
		self assert: array equals: #( 9 3 3 5 7 1 ).
		self assert: ((TimSort sort: (OrderedCollection withAll: #( 2 3 1 )) with: [ :a :b | a <= b ] backend: name) asArray) equals: #( 1 2 3 ).
		self assert: TimSort liveCoroutines equals: 0 ].
	(#( #plugin #ffi #quick ) reject: [ :name | TimSort resumableBackends includes: name ]) do: [ :name |
		array := #( 3 1 2 ) copy.
		self should: [ TimSort sort: array with: [ :a :b | a <= b ] backend: name ] raise: TimSortBackendUnavailable.
		self should: [ TimSort sort: array from: 1 to: 3 with: [ :a :b | a <= b ] backend: name ] raise: TimSortBackendUnavailable.
		self assert: array equals: #( 3 1 2 ) ].
	(TimSort pluginAvailable and: [ TimSort pluginInfo at: 5 ]) ifTrue: [
		self assert: TimSort resumableBackend equals: #plugin.
		self assert: TimSort resumableBackends first equals: #plugin ]
]

{ #category : 'tests' }
TimSortSelectionTests >> testLibraryNotProbedWithCoroutinesInThePlugin [
	(TimSort pluginAvailable and: [ TimSort pluginInfo at: 5 ]) ifFalse: [ ^ self skip: 'no TimSortPlugin with coroutines' ].
	TimSort resetBackend.
	#( 3 1 2 ) copy timSort: [ :a :b | a <= b ].
	self assert: (TimSort sort: #( 3 1 2 ) copy with: [ :a :b | a <= b ] backend: #plugin) equals: #( 1 2 3 ).
	self assert: TimSort backend equals: #plugin.
	self assert: TimSort blockSortBackend equals: #smalltalk.
	self assert: TimSort resumableBackend equals: #plugin.
	self assert: TimSort coroutinesAvailable.
	self assert: TimSort liveCoroutines equals: 0.
	self deny: (TimSort classVarNamed: #LibraryProbed)
]

{ #category : 'tests' }
TimSortSelectionTests >> testNeitherPluginNorLibrary [
	TimSort
		testHook: #pluginMissing value: true;
		testHook: #fallbackMissing value: true.
	self assert: TimSort backend equals: #smalltalk.
	self assert: TimSort blockSortBackend equals: #smalltalk.
	self deny: TimSort pluginAvailable.
	self deny: TimSort coroutinesAvailable.
	self assert: TimSort resumableBackends isEmpty.
	self assert: TimSort resumableBackend isNil.
	self assert: TimSort pluginInfo isNil.
	self assert: TimSort liveCoroutines equals: 0.
	self assert: #( 3 1 2 ) copy timSort equals: #( 1 2 3 ).
	self assert: (#( 3 1 2 ) copy timSort: [ :a :b | a >= b ]) equals: #( 3 2 1 ).
	self assert: (TimSort sort: #( 3 1 2 ) copy with: [ :a :b | a >= b ] backend: #smalltalk) equals: #( 3 2 1 ).
	#( #plugin #ffi ) do: [ :name |
		self
			should: [ TimSort sort: #( 3 1 2 ) copy with: [ :a :b | a <= b ] backend: name ]
			raise: TimSortBackendUnavailable
			whoseDescriptionIncludes: 'not loaded'
			description: name ].
	self assert: (Float64Array withAll: #( 2.0 1.0 )) timSort asArray equals: #( 1.0 2.0 )
]

{ #category : 'tests' }
TimSortSelectionTests >> testPluginInfo [
	| info |
	TimSort pluginAvailable ifFalse: [ ^ self skip: 'no TimSortPlugin' ].
	info := TimSort pluginInfo.
	self assert: info first equals: TimSort protocol.
	self assert: TimSort backend equals: #plugin.
	self assert: TimSort coroutinesAvailable equals: ((info at: 5) or: [ TimSort resumableBackends includes: #ffi ]).
	self assert: (TimSort resumableBackends includes: #plugin) equals: (info at: 5).
	self assert: TimSort blockSortBackend equals: #smalltalk.
	(info at: 4) = 'emscripten' ifTrue: [
		self deny: (info at: 5).
		self assert: TimSort resumableBackends isEmpty.
		self
			should: [ TimSort sort: #( 2 1 ) copy with: [ :a :b | a <= b ] backend: #plugin ]
			raise: TimSortBackendUnavailable
			whoseDescriptionIncludes: 'cannot switch C stacks'
			description: 'no resumable sort in WebAssembly' ].
	TimSort testHook: #pluginMissing value: true.
	self deny: TimSort pluginAvailable.
	self deny: TimSort backend equals: #plugin
]

{ #category : 'tests' }
TimSortSelectionTests >> testSessionReset [
	TimSort backend.
	self assert: (TimSort classVarNamed: #SessionToken) identicalTo: Smalltalk session.
	TimSort classVarNamed: #SessionToken put: Object new.
	TimSort classVarNamed: #Primary put: #stale.
	TimSort backend.
	self assert: (TimSort classVarNamed: #SessionToken) identicalTo: Smalltalk session.
	self deny: (TimSort classVarNamed: #Primary) equals: #stale.
	TimSort testHook: #fallbackMissing value: true.
	self assert: (TimSort classVarNamed: #SessionToken) isNil
]

{ #category : 'tests' }
TimSortSelectionTests >> testWithoutThePlugin [
	"Without the plugin: the library when TimSort-FFI is loaded and finds it, else TimSortSmalltalk"

	TimSort testHook: #pluginMissing value: true.
	self deny: TimSort pluginAvailable.
	((Smalltalk globals at: #TimSortLibrary ifAbsent: [ nil ]) ifNil: [ false ] ifNotNil: [ :library | library isAvailable ])
		ifTrue: [ self assert: TimSort backend equals: #ffi ]
		ifFalse: [
			self assert: TimSort backend equals: #smalltalk.
			self assert: TimSort resumableBackends isEmpty ].
	self assert: TimSort blockSortBackend equals: #smalltalk.
	self deny: (TimSort resumableBackends includes: #plugin).
	self assert: #( 'b' 'c' 'a' ) copy timSort equals: #( 'a' 'b' 'c' )
]
