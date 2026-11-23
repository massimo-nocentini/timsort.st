"
I sort by the natural order of the elements, their `#<`: the default ascending order. For elements whose `#<` and `#<=` agree (numbers but NaN, strings, magnitudes), I leave the same permutation as Pharo's `#sort`, that is `sort: [ :a :b | a <= b ]`, and `beDescending` the same as `sort: [ :a :b | a >= b ]`.

```smalltalk
TimSortSmalltalkNaturalOrderSorter new sort: #(3 1 2) copy.
```
"
Class {
	#name : 'TimSortSmalltalkNaturalOrderSorter',
	#superclass : 'TimSortSmalltalkSorter',
	#category : 'TimSort-Smalltalk',
	#package : 'TimSort-Smalltalk'
}

{ #category : 'comparing' }
TimSortSmalltalkNaturalOrderSorter >> is: anObject lessThan: anotherObject [

	^ anObject < anotherObject
]
