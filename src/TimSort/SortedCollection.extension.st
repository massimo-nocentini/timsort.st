Extension { #name : 'SortedCollection' }

{ #category : '*TimSort' }
SortedCollection >> timSort [
	"Sort me by the natural order of my elements and make it my order (sortBlock nil), as sort makes [ :a :b | a <= b ] my sortBlock"

	super timSort.
	sortBlock := nil
]

{ #category : '*TimSort' }
SortedCollection >> timSortDescending [
	"Sort me by the natural order of my elements, the largest first, and make it my order"

	super timSortDescending.
	sortBlock := [ :a :b | a >= b ]
]

{ #category : '*TimSort' }
SortedCollection >> timSort: aSortBlock [
	"Sort me by aSortBlock and make it my sortBlock, as sort: does, so that the elements added later go to their place"

	super timSort: aSortBlock.
	sortBlock := aSortBlock
]

{ #category : '*TimSort' }
SortedCollection >> timSortBy: keyBlock [
	"Sort me by the keys of my elements and make that order my sortBlock"

	super timSortBy: keyBlock.
	sortBlock := [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]
]

{ #category : '*TimSort' }
SortedCollection >> timSortDescendingBy: keyBlock [
	"Sort me by the keys of my elements, the largest first, and make that order my sortBlock"

	super timSortDescendingBy: keyBlock.
	sortBlock := [ :a :b | (keyBlock value: a) >= (keyBlock value: b) ]
]
