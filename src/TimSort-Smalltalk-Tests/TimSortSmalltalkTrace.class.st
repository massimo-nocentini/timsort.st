"
I record the comparisons of a sort, as the C program trace.c does for timsort.c (see TimSortSmalltalkFidelityTest): their count and a hash of the sequence of compared pairs (i, j), where i and j are the positions of the two elements in the input (numbered from 0) and i is the left operand of the strict less-than.

	traceHash := (traceHash * 1000003 + i) \\ 1000000007, then the same with j

traceHash is the hash; the same fold over a sorted array of positions is #hashOf:.  The values stay SmallIntegers.
"
Class {
	#name : 'TimSortSmalltalkTrace',
	#superclass : 'Object',
	#instVars : [
		'count',
		'traceHash'
	],
	#category : 'TimSort-Smalltalk-Tests',
	#package : 'TimSort-Smalltalk-Tests'
}

{ #category : 'hashing' }
TimSortSmalltalkTrace class >> fold: anInteger into: aHash [

	^ aHash * 1000003 + anInteger \\ 1000000007
]

{ #category : 'hashing' }
TimSortSmalltalkTrace class >> hashOf: positions [

	^ positions inject: 0 into: [ :hash :each | self fold: each into: hash ]
]

{ #category : 'accessing' }
TimSortSmalltalkTrace >> count [

	^ count
]

{ #category : 'accessing' }
TimSortSmalltalkTrace >> traceHash [

	^ traceHash
]

{ #category : 'initialization' }
TimSortSmalltalkTrace >> initialize [

	super initialize.
	count := 0.
	traceHash := 0
]

{ #category : 'recording' }
TimSortSmalltalkTrace >> record: leftPosition with: rightPosition [

	count := count + 1.
	traceHash := self class fold: rightPosition into: (self class fold: leftPosition into: traceHash)
]
