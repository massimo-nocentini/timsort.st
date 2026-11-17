"
I am the error code of a failed primitive of the TimSortPlugin, or of a backend call that fails as the primitive would (ec: a Symbol, such as #'bad argument', or nil when the module is missing).  The facade signals for #'no modification' and #'bad index' (which it checks itself first) and runs TimSortPortBackend for any other failure.
"
Class {
	#name : 'TimSortFailure',
	#superclass : 'Object',
	#instVars : [
		'ec'
	],
	#category : 'TimSort-Backends',
	#package : 'TimSort',
	#tag : 'Backends'
}

{ #category : 'instance creation' }
TimSortFailure class >> on: errorCode [
	"The error code of a failed primitive of the plugin (nil when the plugin is missing)"

	^ self new
		ec: errorCode;
		yourself
]

{ #category : 'accessing' }
TimSortFailure >> ec [
	^ ec
]

{ #category : 'accessing' }
TimSortFailure >> ec: errorCode [
	ec := errorCode
]

{ #category : 'testing' }
TimSortFailure >> isNotFound [
	"The module could not be loaded, or it has no such primitive"

	^ ec isNil or: [ ec == #'not found' ]
]

{ #category : 'printing' }
TimSortFailure >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; print: ec; nextPut: $)
]

{ #category : 'testing' }
TimSortFailure >> timSortFailed [
	"Whether a backend call failed: I am a failure"

	^ true
]
