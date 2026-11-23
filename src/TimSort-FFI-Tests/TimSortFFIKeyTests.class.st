"
I run `TimSortKeyTests` on the `#ffi` backend, `TimSortLibrary`, with the plugin hidden (hook `#pluginMissing`): the sorts by a sortBlock run on the resumable sort of the library when it has one.
"
Class {
	#name : 'TimSortFFIKeyTests',
	#superclass : 'TimSortKeyTests',
	#category : 'TimSort-FFI-Tests-Tests',
	#package : 'TimSort-FFI-Tests',
	#tag : 'Tests'
}

{ #category : 'testing' }
TimSortFFIKeyTests class >> isAbstract [
	^ false
]

{ #category : 'building suites' }
TimSortFFIKeyTests class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #backendName addOptions: #( #ffi );
		yourself
]

{ #category : 'accessing' }
TimSortFFIKeyTests >> backendObject [
	TimSortLibrary isAvailable ifFalse: [ self skip: 'no libTimSortFFI' ].
	^ TimSortLibrary
]

{ #category : 'running' }
TimSortFFIKeyTests >> setUp [
	TimSort testHook: #pluginMissing value: true.
	super setUp
]
