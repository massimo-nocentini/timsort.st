"
I am a pending run of a `TimSortSmalltalkSorter`: a slice of the collection being sorted, from the index `start` for `length` elements, already in ascending order, waiting to be merged with its neighbours. I am the `struct timsort_slice_s` of timsort.c.

The sorter keeps its pending runs on a stack (an `OrderedCollection`, bottom first), where every run ends just before the next one begins:

```smalltalk
(runs at: i) start + (runs at: i) length = (runs at: i + 1) start
```

`power` is the depth of the boundary between me and the run above me in the conceptual merge tree of the powersort policy (`powerloop` of timsort.c). It is nil while I am the top run, and is set when the run above me is found.
"
Class {
	#name : 'TimSortSmalltalkRun',
	#superclass : 'Object',
	#instVars : [
		'start',
		'length',
		'power'
	],
	#category : 'TimSort-Smalltalk',
	#package : 'TimSort-Smalltalk'
}

{ #category : 'instance creation' }
TimSortSmalltalkRun class >> start: anIndex length: anInteger [

	^ self new setStart: anIndex length: anInteger
]

{ #category : 'accessing' }
TimSortSmalltalkRun >> length [

	^ length
]

{ #category : 'accessing' }
TimSortSmalltalkRun >> length: anInteger [

	length := anInteger
]

{ #category : 'accessing' }
TimSortSmalltalkRun >> power [

	^ power
]

{ #category : 'accessing' }
TimSortSmalltalkRun >> power: anInteger [

	power := anInteger
]

{ #category : 'printing' }
TimSortSmalltalkRun >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		print: start;
		nextPutAll: ' to: ';
		print: self stop;
		nextPutAll: ' power: ';
		print: power;
		nextPut: $)
]

{ #category : 'initialization' }
TimSortSmalltalkRun >> setStart: anIndex length: anInteger [

	start := anIndex.
	length := anInteger
]

{ #category : 'accessing' }
TimSortSmalltalkRun >> start [

	^ start
]

{ #category : 'accessing' }
TimSortSmalltalkRun >> stop [
	"The index of my last element"

	^ start + length - 1
]
