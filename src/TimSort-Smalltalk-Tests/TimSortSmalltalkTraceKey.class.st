"
I am an element for tracing the natural order (`#<`) of `TimSortSmalltalkNaturalOrderSorter`: my `#<` records the positions of the two operands in a `TimSortSmalltalkTrace` and compares the keys.
"
Class {
	#name : 'TimSortSmalltalkTraceKey',
	#superclass : 'Object',
	#instVars : [
		'position',
		'key',
		'trace'
	],
	#category : 'TimSort-Smalltalk-Tests',
	#package : 'TimSort-Smalltalk-Tests'
}

{ #category : 'instance creation' }
TimSortSmalltalkTraceKey class >> position: anInteger key: aKey trace: aTrace [

	^ self new setPosition: anInteger key: aKey trace: aTrace
]

{ #category : 'comparing' }
TimSortSmalltalkTraceKey >> < aTraceKey [

	trace record: position with: aTraceKey position.
	^ key < aTraceKey key
]

{ #category : 'accessing' }
TimSortSmalltalkTraceKey >> key [

	^ key
]

{ #category : 'accessing' }
TimSortSmalltalkTraceKey >> position [

	^ position
]

{ #category : 'initialization' }
TimSortSmalltalkTraceKey >> setPosition: anInteger key: aKey trace: aTrace [

	position := anInteger.
	key := aKey.
	trace := aTrace
]
