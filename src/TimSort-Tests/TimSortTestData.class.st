"
I make the data of the tests of TimSort, on my class side: elements of each family (numbers, strings), edge values, and the orders to compare with.
"
Class {
	#name : 'TimSortTestData',
	#superclass : 'Object',
	#category : 'TimSort-Tests-Support',
	#package : 'TimSort-Tests',
	#tag : 'Support'
}

{ #category : 'numbers' }
TimSortTestData class >> edgeNumbers [
	"Numbers that the plugin compares natively, with equal values of different classes and of the same class (distinct objects), as Pharo's sort compares them on every VM (the SmallIntegers mixed with Floats stay within 2^53, see exactNumbers)"

	| big |
	big := 2 raisedTo: 60.
	^ {
		  0. 0.0. -0.0. 1. 1.0. -1. -1.0. 2. 0.5. -0.5.
		  (2 raisedTo: 53). SmallInteger minVal.
		  big. big + 1. big negated. big negated - 1. (2 raisedTo: 64). (2 raisedTo: 64) negated.
		  (2 raisedTo: 100). (2 raisedTo: 100) + 1. (2 raisedTo: 100) negated.
		  big asFloat. (2 raisedTo: 100) asFloat. (2 raisedTo: 53) asFloat. (2 raisedTo: 53) - 1. (2 raisedTo: 53) negated.
		  Float infinity. Float negativeInfinity. Float fmax. Float fmax negated. Float fminDenormalized. Float fminDenormalized negated. Float fminNormalized.
		  1.0e300. -1.0e300. 1.0e-300. 3. 3.0. 1/2 + 0.0 }
]

{ #category : 'numbers' }
TimSortTestData class >> numbers: n random: random [
	"n numbers drawn from small SmallIntegers (many ties), Floats, LargeIntegers and the edge numbers (copied when they are not immediate, so that equal values are distinct objects)"

	| edges |
	edges := self edgeNumbers.
	^ (1 to: n) collect: [ :i |
		  | r |
		  r := random nextInteger: 6.
		  r = 1 ifTrue: [ (random nextInteger: 41) - 21 ] ifFalse: [
		  r = 2 ifTrue: [ ((random nextInteger: 41) - 21) asFloat / 2 ] ifFalse: [
		  r = 3 ifTrue: [ (random next - 0.5) * (10 raisedTo: (random nextInteger: 30)) ] ifFalse: [
		  r = 4 ifTrue: [ ((2 raisedTo: 60 + (random nextInteger: 40)) + (random nextInteger: 1000)) * (#( 1 -1 ) atRandom: random) ] ifFalse: [
		  r = 5 ifTrue: [ (random nextInteger: 2000) - 1000 ] ifFalse: [
		  (edges atRandom: random) copy ] ] ] ] ] ]
]

{ #category : 'numbers' }
TimSortTestData class >> exactNumbers: n random: random [
	"n numbers around 2^53 to 2^62, SmallIntegers, Floats and LargeIntegers mixed: there the JIT of the native VM compares a SmallInteger with a Float after rounding it, and Pharo's sort differs from the exact order that the plugin and the image code use (exactKey:)"

	^ (1 to: n) collect: [ :i |
		  | e v |
		  e := 52 + (random nextInteger: 10).
		  v := (2 raisedTo: e) + ((random nextInteger: 9) - 5).
		  v := v * (#( 1 -1 ) atRandom: random).
		  (random nextInteger: 3) = 1 ifTrue: [ v asFloat ] ifFalse: [ v ] ]
]

{ #category : 'numbers' }
TimSortTestData class >> exactKey: aNumber [
	"aNumber as an exact rational, the infinities beyond every finite number of the tests"

	aNumber isFloat ifFalse: [ ^ aNumber ].
	aNumber isInfinite ifTrue: [
		^ aNumber > 0
			  ifTrue: [ 2 raisedTo: 2000 ]
			  ifFalse: [ (2 raisedTo: 2000) negated ] ].
	^ aNumber asTrueFraction
]

{ #category : 'strings' }
TimSortTestData class >> strings: n random: random [
	"n strings of the four string classes, short (many equal ones), with code points that are ASCII, Latin-1 (é), BMP (α, €), beyond (U+1F600) and NUL"

	| alphabet |
	alphabet := {
		            $a. $b. $B. $z. $0. $_. Character null. (Character value: 233). (Character value: 945).
		            (Character value: 16r20AC). (Character value: 16r1F600) }.
	^ (1 to: n) collect: [ :i |
		  | size s kind |
		  size := random nextInteger: 4.
		  s := String new: size - 1 streamContents: [ :stream |
			       size - 1 timesRepeat: [ stream nextPut: (alphabet atRandom: random) ] ].
		  kind := random nextInteger: 4.
		  kind = 1 ifTrue: [ s isWideString ifTrue: [ s ] ifFalse: [ s copy ] ] ifFalse: [
		  kind = 2 ifTrue: [ s asSymbol ] ifFalse: [
		  kind = 3 ifTrue: [ s asWideString ] ifFalse: [
		  (s , (String with: (alphabet atRandom: random))) asWideString ] ] ] ]
]

{ #category : 'strings' }
TimSortTestData class >> wideSymbol [
	"A WideSymbol"

	^ (String with: (Character value: 945) with: $a) asSymbol
]

{ #category : 'orders' }
TimSortTestData class >> nanLast [
	"The sortBlock of Pharo's sort for the order of the numeric buffers: by value, every NaN after every number, the NaNs equal"

	^ [ :a :b | b isNaN or: [ a <= b ] ]
]

{ #category : 'orders' }
TimSortTestData class >> nanFirstDescending [
	"The sortBlock of Pharo's sort for the descending order of the numeric buffers: every NaN first, the NaNs equal, then the numbers from the largest"

	^ [ :a :b | a isNaN or: [ b isNaN not and: [ a >= b ] ] ]
]

{ #category : 'shapes' }
TimSortTestData class >> shaped: anArray shape: aSymbol random: random [
	"anArray (sorted when it has to be) rearranged as aSymbol says: #random, #sorted, #reversed, #nearlySorted (a few swaps), #sawtooth"

	| a n |
	a := anArray copy.
	n := a size.
	aSymbol == #random ifTrue: [ ^ a ].
	a := a sort: [ :x :y | x <= y ].
	aSymbol == #sorted ifTrue: [ ^ a ].
	aSymbol == #reversed ifTrue: [ ^ a reverse ].
	aSymbol == #nearlySorted ifTrue: [
		n // 20 + 1 timesRepeat: [
			n > 1 ifTrue: [ a swap: (random nextInteger: n) with: (random nextInteger: n) ] ].
		^ a ].
	aSymbol == #sawtooth ifTrue: [
		^ (1 to: n) collect: [ :i | a at: (i - 1) * 7 \\ n + 1 ] ].
	^ a
]

{ #category : 'shapes' }
TimSortTestData class >> shapes [
	^ #( #random #sorted #reversed #nearlySorted #sawtooth )
]
