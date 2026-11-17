Extension { #name : 'SequenceableCollection' }

{ #category : '*TimSort' }
SequenceableCollection >> timSort [
	"Sort me in place by the natural order of my elements, with TimSort: the result of sort.  Arrays of numbers or of strings and numeric buffers are sorted in C"

	TimSort sort: self
]

{ #category : '*TimSort' }
SequenceableCollection >> timSortDescending [
	"Sort me in place by the natural order of my elements, the largest first, equal elements in their order: the result of sort: [ :a :b | a >= b ].  Numeric buffers put NaN first"

	TimSort sortDescending: self
]

{ #category : '*TimSort' }
SequenceableCollection >> timSort: aSortBlock [
	"Sort me in place by aSortBlock, with TimSort: the result of sort: aSortBlock for a sortBlock in the style of [ :a :b | a <= b ].  TimSortSmalltalk sorts, on every VM (TimSort blockSortBackend); TimSort sort: self with: aSortBlock backend: #plugin (or #ffi) runs the resumable C sort instead, which asks aSortBlock one comparison at a time"

	TimSort sort: self with: aSortBlock
]

{ #category : '*TimSort' }
SequenceableCollection >> timSortBy: keyBlock [
	"Sort me in place by the keys keyBlock answers for my elements, computed once per element: the result of sort: [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]"

	TimSort sort: self byKey: keyBlock
]

{ #category : '*TimSort' }
SequenceableCollection >> timSortDescendingBy: keyBlock [
	"Sort me in place by the keys keyBlock answers for my elements, the largest first, equal keys in their order"

	TimSort sortDescending: self byKey: keyBlock
]

{ #category : '*TimSort' }
SequenceableCollection >> timSorted [
	"A copy of me sorted by timSort, as sorted"

	^ self copy timSort
]

{ #category : '*TimSort' }
SequenceableCollection >> timSorted: aSortBlock [
	"A copy of me sorted by timSort: aSortBlock, as sorted: aSortBlock"

	^ self copy timSort: aSortBlock
]

{ #category : '*TimSort' }
SequenceableCollection >> timSortedBy: keyBlock [
	"A copy of me sorted by timSortBy: keyBlock"

	^ self copy timSortBy: keyBlock
]

{ #category : '*TimSort' }
SequenceableCollection >> timSortItemsDo: aBlock [
	"Evaluate aBlock with the collection whose slots hold my elements and the offset of my first element in it, so that TimSort sorts that collection: myself and 0"

	^ aBlock value: self value: 0
]
