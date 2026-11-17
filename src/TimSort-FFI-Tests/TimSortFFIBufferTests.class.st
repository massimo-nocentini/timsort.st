"
I run TimSortBufferTests on the #ffi backend, TimSortLibrary, with the plugin hidden (hook #pluginMissing): the sorts by a sortBlock run on the resumable sort of the library when it has one.
"
Class {
	#name : 'TimSortFFIBufferTests',
	#superclass : 'TimSortBufferTests',
	#category : 'TimSort-FFI-Tests-Tests',
	#package : 'TimSort-FFI-Tests',
	#tag : 'Tests'
}

{ #category : 'testing' }
TimSortFFIBufferTests class >> isAbstract [
	^ false
]

{ #category : 'building suites' }
TimSortFFIBufferTests class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #backendName addOptions: #( #ffi );
		yourself
]

{ #category : 'accessing' }
TimSortFFIBufferTests >> backendObject [
	TimSortLibrary isAvailable ifFalse: [ self skip: 'no libTimSortFFI' ].
	^ TimSortLibrary
]

{ #category : 'running' }
TimSortFFIBufferTests >> setUp [
	TimSort testHook: #pluginMissing value: true.
	super setUp
]
