"
I sort by a sortBlock in the style of Pharo's #sort: and SortedCollection: sortBlock value: a value: b answers true when a may come before b, as [ :a :b | a <= b ] does (a SortFunction works as well).  The strict less-than of the algorithm is then

	a < b  :=  (sortBlock value: b value: a) not

which keeps equal elements in their order, so that I leave the same permutation as aCollection sort: sortBlock (Pharo's stable merge sort), with fewer comparisons on most inputs.

	(TimSortSmalltalkSortBlockSorter sortBlock: [ :a :b | a size >= b size ]) sort: strings.
"
Class {
	#name : 'TimSortSmalltalkSortBlockSorter',
	#superclass : 'TimSortSmalltalkSorter',
	#instVars : [
		'sortBlock'
	],
	#category : 'TimSort-Smalltalk',
	#package : 'TimSort-Smalltalk'
}

{ #category : 'instance creation' }
TimSortSmalltalkSortBlockSorter class >> sortBlock: aBlock [

	^ self new setSortBlock: aBlock
]

{ #category : 'comparing' }
TimSortSmalltalkSortBlockSorter >> is: anObject lessThan: anotherObject [
	"anObject must come before anotherObject when anotherObject may not come before it"

	^ (sortBlock value: anotherObject value: anObject) ifTrue: [ false ] ifFalse: [ true ]
]

{ #category : 'initialization' }
TimSortSmalltalkSortBlockSorter >> setSortBlock: aBlock [

	sortBlock := aBlock
]

{ #category : 'accessing' }
TimSortSmalltalkSortBlockSorter >> sortBlock [

	^ sortBlock
]
