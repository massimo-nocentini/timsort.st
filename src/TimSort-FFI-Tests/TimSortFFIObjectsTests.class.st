"
I run TimSortObjectsTests on the #ffi backend, TimSortLibrary, with the plugin hidden (hook #pluginMissing): the sorts by a sortBlock run on the resumable sort of the library when it has one.
"
Class {
	#name : 'TimSortFFIObjectsTests',
	#superclass : 'TimSortObjectsTests',
	#category : 'TimSort-FFI-Tests-Tests',
	#package : 'TimSort-FFI-Tests',
	#tag : 'Tests'
}

{ #category : 'testing' }
TimSortFFIObjectsTests class >> isAbstract [
	^ false
]

{ #category : 'building suites' }
TimSortFFIObjectsTests class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #backendName addOptions: #( #ffi );
		yourself
]

{ #category : 'accessing' }
TimSortFFIObjectsTests >> backendObject [
	TimSortLibrary isAvailable ifFalse: [ self skip: 'no libTimSortFFI' ].
	^ TimSortLibrary
]

{ #category : 'running' }
TimSortFFIObjectsTests >> setUp [
	TimSort testHook: #pluginMissing value: true.
	super setUp
]
