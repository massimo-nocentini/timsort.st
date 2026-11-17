Extension { #name : 'Interval' }

{ #category : '*TimSort' }
Interval >> timSort [
	"An Interval cannot be changed: I do what sort does (ShouldNotImplement)"

	self sort
]

{ #category : '*TimSort' }
Interval >> timSortDescending [
	"An Interval cannot be changed: I do what sort does (ShouldNotImplement)"

	self sort: [ :a :b | a >= b ]
]

{ #category : '*TimSort' }
Interval >> timSort: aSortBlock [
	"An Interval cannot be changed: I do what sort does (ShouldNotImplement)"

	self sort: aSortBlock
]

{ #category : '*TimSort' }
Interval >> timSortBy: keyBlock [
	"An Interval cannot be changed: I do what sort does (ShouldNotImplement)"

	self sort: [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]
]

{ #category : '*TimSort' }
Interval >> timSortDescendingBy: keyBlock [
	"An Interval cannot be changed: I do what sort does (ShouldNotImplement)"

	self sort: [ :a :b | (keyBlock value: a) >= (keyBlock value: b) ]
]

{ #category : '*TimSort' }
Interval >> timSorted [
	"My elements sorted, as sorted does (an Interval)"

	^ self sorted
]

{ #category : '*TimSort' }
Interval >> timSorted: aSortBlock [
	"An Array of my elements sorted by aSortBlock, as sorted: aSortBlock does"

	^ self asArray timSort: aSortBlock
]

{ #category : '*TimSort' }
Interval >> timSortedBy: keyBlock [
	"An Array of my elements sorted by their keys"

	^ self asArray timSortBy: keyBlock
]
