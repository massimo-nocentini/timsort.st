Extension { #name : 'Symbol' }

{ #category : '*TimSort' }
Symbol >> timSort [
	"A Symbol cannot be changed: I do what sort does (an Error)"

	self sort
]

{ #category : '*TimSort' }
Symbol >> timSortDescending [
	"A Symbol cannot be changed: I do what sort does (an Error)"

	self sort: [ :a :b | a >= b ]
]

{ #category : '*TimSort' }
Symbol >> timSort: aSortBlock [
	"A Symbol cannot be changed: I do what sort does (an Error)"

	self sort: aSortBlock
]

{ #category : '*TimSort' }
Symbol >> timSortBy: keyBlock [
	"A Symbol cannot be changed: I do what sort does (an Error)"

	self sort: [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]
]

{ #category : '*TimSort' }
Symbol >> timSortDescendingBy: keyBlock [
	"A Symbol cannot be changed: I do what sort does (an Error)"

	self sort: [ :a :b | (keyBlock value: a) >= (keyBlock value: b) ]
]

{ #category : '*TimSort' }
Symbol >> timSorted [
	"My elements sorted, an Array, as sorted does"

	^ self asArray timSort
]

{ #category : '*TimSort' }
Symbol >> timSorted: aSortBlock [
	"An Array of my elements sorted by aSortBlock, as sorted: aSortBlock does"

	^ self asArray timSort: aSortBlock
]

{ #category : '*TimSort' }
Symbol >> timSortedBy: keyBlock [
	"An Array of my elements sorted by their keys"

	^ self asArray timSortBy: keyBlock
]
