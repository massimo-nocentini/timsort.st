"
I make the inputs of the tests of TimSort-Smalltalk: arrays of integer keys in ten shapes, from a deterministic generator (the minimal standard generator of Park and Miller, seed := seed * 16807 \\ 2147483647).  The C program that computed the comparison traces of TimSortSmalltalkFidelityTest from timsort.c (trace.c, see the class comment there) builds the same keys, shape for shape:

1 random: next random \\ 1000000
2 fewUnique: next random \\ 5
3 sorted: i (keys are numbered from 0)
4 reversed: size - i
5 sawtooth: i \\ 37
6 organPipe: i up to the middle, then size - i
7 nearlySorted: sorted, then size // 20 + 1 swaps of two random positions
8 sortedChunks: ascending chunks of 1 to 200 keys (key base + 3 j), each from a random base
9 descendingSteps: (size - i) // 3, descending runs with equal subruns
10 allEqual: 7
"
Class {
	#name : 'TimSortSmalltalkTestData',
	#superclass : 'Object',
	#instVars : [
		'seed'
	],
	#category : 'TimSort-Smalltalk-Tests',
	#package : 'TimSort-Smalltalk-Tests'
}

{ #category : 'instance creation' }
TimSortSmalltalkTestData class >> seed: anInteger [

	^ self new setSeed: anInteger
]

{ #category : 'keys' }
TimSortSmalltalkTestData class >> keysOfShape: shapeIndex size: size seed: anInteger [
	"The keys of the shape at shapeIndex in #shapes, as trace.c makes them"

	^ (self seed: anInteger) keysOfShape: shapeIndex size: size
]

{ #category : 'keys' }
TimSortSmalltalkTestData class >> shapes [

	^ #( #random #fewUnique #sorted #reversed #sawtooth #organPipe #nearlySorted #sortedChunks #descendingSteps #allEqual )
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> allEqual: size [

	^ Array new: size withAll: 7
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> descendingSteps: size [

	^ (0 to: size - 1) collect: [ :i | size - i // 3 ]
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> fewUnique: size [

	^ (1 to: size) collect: [ :i | self nextRandom \\ 5 ]
]

{ #category : 'keys' }
TimSortSmalltalkTestData >> keysOfShape: shapeIndex size: size [

	^ (self perform: ((self class shapes at: shapeIndex) , ':') asSymbol with: size) asArray
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> nearlySorted: size [

	| keys |
	keys := self sorted: size.
	size > 1 ifTrue: [
		size // 20 + 1 timesRepeat: [
			| a b |
			a := self nextRandom \\ size + 1.
			b := self nextRandom \\ size + 1.
			keys swap: a with: b ] ].
	^ keys
]

{ #category : 'random' }
TimSortSmalltalkTestData >> nextRandom [

	^ seed := seed * 16807 \\ 2147483647
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> organPipe: size [

	^ (0 to: size - 1) collect: [ :i |
		  i < (size // 2)
			  ifTrue: [ i ]
			  ifFalse: [ size - i ] ]
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> random: size [

	^ (1 to: size) collect: [ :i | self nextRandom \\ 1000000 ]
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> reversed: size [

	^ (0 to: size - 1) collect: [ :i | size - i ]
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> sawtooth: size [

	^ (0 to: size - 1) collect: [ :i | i \\ 37 ]
]

{ #category : 'initialization' }
TimSortSmalltalkTestData >> setSeed: anInteger [

	seed := anInteger
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> sorted: size [

	^ (0 to: size - 1) asArray
]

{ #category : 'shapes' }
TimSortSmalltalkTestData >> sortedChunks: size [

	| keys index |
	keys := Array new: size.
	index := 0.
	[ index < size ] whileTrue: [
		| length base |
		length := self nextRandom \\ 200 + 1.
		base := self nextRandom \\ 1000000.
		0 to: (length min: size - index) - 1 do: [ :j | keys at: index + j + 1 put: base + (3 * j) ].
		index := index + length ].
	^ keys
]
