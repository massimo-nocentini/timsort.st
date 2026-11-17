Extension { #name : 'OrderedCollection' }

{ #category : '*TimSort' }
OrderedCollection >> timSortItemsDo: aBlock [
	"Evaluate aBlock with my internal Array and the offset of my first element in it: TimSort sorts the slots firstIndex to lastIndex of that Array in place, as sort: does"

	^ aBlock value: array value: firstIndex - 1
]
