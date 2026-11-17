"
I sort by a strict less-than block, the comparison of timsort.c and of CPython: lessThan value: a value: b answers true when a must come before b, false otherwise (a Boolean, anything else is an error).  Elements for which neither is less than the other keep their order.

	(TimSortSmalltalkLessThanSorter lessThan: [ :a :b | a key < b key ]) sort: associations.

A non-strict block (a <= b) still sorts, but loses stability; for blocks in the style of Pharo's sortBlocks use TimSortSmalltalkSortBlockSorter.
"
Class {
	#name : 'TimSortSmalltalkLessThanSorter',
	#superclass : 'TimSortSmalltalkSorter',
	#instVars : [
		'lessThan'
	],
	#category : 'TimSort-Smalltalk',
	#package : 'TimSort-Smalltalk'
}

{ #category : 'instance creation' }
TimSortSmalltalkLessThanSorter class >> lessThan: aBlock [

	^ self new setLessThan: aBlock
]

{ #category : 'comparing' }
TimSortSmalltalkLessThanSorter >> is: anObject lessThan: anotherObject [

	^ lessThan value: anObject value: anotherObject
]

{ #category : 'accessing' }
TimSortSmalltalkLessThanSorter >> lessThan [

	^ lessThan
]

{ #category : 'initialization' }
TimSortSmalltalkLessThanSorter >> setLessThan: aBlock [

	lessThan := aBlock
]
