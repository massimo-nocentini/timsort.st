"
I run `TimSortCollectionTests` on the `#ffi` backend, `TimSortLibrary`, with the plugin hidden (hook `#pluginMissing`): the sorts by a sortBlock run on the resumable sort of the library when it has one.
"
Class {
	#name : 'TimSortFFICollectionTests',
	#superclass : 'TimSortCollectionTests',
	#category : 'TimSort-FFI-Tests-Tests',
	#package : 'TimSort-FFI-Tests',
	#tag : 'Tests'
}

{ #category : 'testing' }
TimSortFFICollectionTests class >> isAbstract [
	^ false
]

{ #category : 'building suites' }
TimSortFFICollectionTests class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #backendName addOptions: #( #ffi );
		yourself
]

{ #category : 'accessing' }
TimSortFFICollectionTests >> backendObject [
	TimSortLibrary isAvailable ifFalse: [ self skip: 'no libTimSortFFI' ].
	^ TimSortLibrary
]

{ #category : 'running' }
TimSortFFICollectionTests >> setUp [
	TimSort testHook: #pluginMissing value: true.
	super setUp
]
