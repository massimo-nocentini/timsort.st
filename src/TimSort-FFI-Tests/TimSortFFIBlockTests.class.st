"
I run `TimSortBlockTests` on the `#ffi` backend, `TimSortLibrary`, with the plugin hidden (hook `#pluginMissing`): the explicit sorts (`TimSort sort:with:backend: #ffi`) run on the resumable sort of the library when it has one, and the default (`timSort:`) on `TimSortSmalltalk`.
"
Class {
	#name : 'TimSortFFIBlockTests',
	#superclass : 'TimSortBlockTests',
	#category : 'TimSort-FFI-Tests-Tests',
	#package : 'TimSort-FFI-Tests',
	#tag : 'Tests'
}

{ #category : 'testing' }
TimSortFFIBlockTests class >> isAbstract [
	^ false
]

{ #category : 'building suites' }
TimSortFFIBlockTests class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #backendName addOptions: #( #ffi );
		yourself
]

{ #category : 'accessing' }
TimSortFFIBlockTests >> backendObject [
	TimSortLibrary isAvailable ifFalse: [ self skip: 'no libTimSortFFI' ].
	^ TimSortLibrary
]

{ #category : 'running' }
TimSortFFIBlockTests >> setUp [
	TimSort testHook: #pluginMissing value: true.
	super setUp
]
