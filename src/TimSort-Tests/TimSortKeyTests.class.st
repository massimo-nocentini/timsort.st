"
I test TimSort: Sorts by keys computed once (mode c) and argSort:, against Pharo's sort: with the keys compared in the sortBlock, == slot for slot, per backend.
"
Class {
	#name : 'TimSortKeyTests',
	#superclass : 'TimSortBackendTestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortKeyTests >> assert: aCollection sortsBy: keyBlock [
	self
		assert: (TimSort sort: aCollection copy byKey: keyBlock)
		sameAs: (aCollection copy sort: [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]).
	self
		assert: (TimSort sortDescending: aCollection copy byKey: keyBlock)
		sameAs: (aCollection copy sort: [ :a :b | (keyBlock value: a) >= (keyBlock value: b) ])
]

{ #category : 'tests' }
TimSortKeyTests >> testArgSortOfAnArray [
	self assert: (TimSort argSort: #( 30 10 20 )) equals: #( 2 3 1 ).
	self assert: (TimSort argSortDescending: #( 30 10 20 )) equals: #( 1 3 2 ).
	self assert: (TimSort argSort: #( 'b' 'a' 'b' 'a' )) equals: #( 2 4 1 3 ).
	self assert: (TimSort argSortDescending: #( 'b' 'a' 'b' 'a' )) equals: #( 1 3 2 4 ).
	self assert: (TimSort argSort: #( 5 4 3 2 1 ) from: 2 to: 4 descending: false) equals: #( 4 3 2 ).
	self assert: (TimSort argSort: #(  )) equals: #(  ).
	self assert: (TimSort argSort: #( 7 )) equals: #( 1 ).
	self assert: (TimSort argSort: { 3. 1/2. 1 }) equals: #( 2 3 1 )
]

{ #category : 'tests' }
TimSortKeyTests >> testArgSortOfBuffers [
	| buffer |
	buffer := Float64Array withAll: { 3.0. Float nan. -1.0. 3.0. -0.0 }.
	self assert: (TimSort argSort: buffer) equals: #( 3 5 1 4 2 ).
	self assert: (TimSort argSortDescending: buffer) equals: #( 2 1 4 5 3 ).
	self assert: (TimSort argSort: (ByteArray withAll: #( 9 8 9 1 )) from: 2 to: 4 descending: false) equals: #( 4 2 3 ).
	self assert: (TimSort argSort: (IntegerArray withAll: #( 1 -1 0 ))) equals: #( 2 3 1 )
]

{ #category : 'tests' }
TimSortKeyTests >> testArgSortOfOtherCollections [
	| oc |
	oc := OrderedCollection withAll: #( 0 0 30 10 20 ).
	oc removeFirst: 2.
	self assert: (TimSort argSort: oc) equals: #( 2 3 1 ).
	self assert: (TimSort argSort: (5 to: 1 by: -1)) equals: #( 5 4 3 2 1 ).
	self assert: (TimSort argSort: 'cab') equals: #( 2 3 1 ).
	self assert: (TimSort argSort: 'dcab' from: 2 to: 4 descending: true) equals: #( 2 4 3 )
]

{ #category : 'tests' }
TimSortKeyTests >> testArgSortRandom [
	"The permutation applied to the keys is Pharo's sort of the keys, ties in their order"

	| random keys perm |
	random := self random.
	#( 2 10 100 1000 ) do: [ :n |
		{
			(TimSortTestData numbers: n random: random).
			(TimSortTestData strings: n random: random) } do: [ :each |
			keys := each.
			perm := TimSort argSort: keys.
			self assert: (perm collect: [ :i | keys at: i ]) sameAs: (keys copy sort: [ :a :b | a <= b ]).
			self assert: perm asSet size equals: n.
			perm := TimSort argSortDescending: keys.
			self assert: (perm collect: [ :i | keys at: i ]) sameAs: (keys copy sort: [ :a :b | a >= b ]) ] ]
]

{ #category : 'tests' }
TimSortKeyTests >> testKeyBlockOncePerElementInOrder [
	| seen words |
	seen := OrderedCollection new.
	words := #( 'ccc' 'a' 'bb' 'dd' ) copy.
	TimSort sort: words byKey: [ :each |
		seen add: each.
		each size ].
	self assert: seen asArray equals: #( 'ccc' 'a' 'bb' 'dd' ).
	self assert: words equals: #( 'a' 'bb' 'dd' 'ccc' ).
	seen removeAll.
	#( 'x' ) copy timSortBy: [ :each | seen add: each ].
	#(  ) copy timSortBy: [ :each | seen add: each ].
	self assert: seen isEmpty
]

{ #category : 'tests' }
TimSortKeyTests >> testKeysOfEachFamily [
	| random |
	random := self random.
	#( 0 1 2 3 33 100 1000 ) do: [ :n |
		self assert: ((1 to: n) collect: [ :i | (random nextInteger: 10) -> i ]) sortsBy: [ :each | each key ].
		self assert: (TimSortTestData strings: n random: random) sortsBy: [ :each | each size ].
		self assert: (TimSortTestData strings: n random: random) sortsBy: [ :each | each reversed ].
		self assert: (TimSortTestData numbers: n random: random) sortsBy: [ :each | each negated ].
		self assert: ((1 to: n) collect: [ :i | i -> ((random nextInteger: 10) / 3) ]) sortsBy: [ :each | each value ] ]
]

{ #category : 'tests' }
TimSortKeyTests >> testRangesAndCollections [
	| array oc |
	array := #( 5 4 3 2 1 ) copy.
	TimSort sort: array from: 2 to: 4 byKey: [ :each | each ] descending: false.
	self assert: array equals: #( 5 2 3 4 1 ).
	oc := OrderedCollection withAll: #( 9 9 'ccc' 'a' 'bb' ).
	oc removeFirst: 2.
	self assert: (oc timSortBy: [ :each | each size ]) asArray equals: #( 'a' 'bb' 'ccc' ).
	self assert: (oc timSortDescendingBy: [ :each | each size ]) asArray equals: #( 'ccc' 'bb' 'a' ).
	self assert: (#( 'ccc' 'a' 'bb' ) timSortedBy: [ :each | each size ]) equals: #( 'a' 'bb' 'ccc' ).
	self assert: ((Float64Array withAll: #( 1.0 -3.0 2.0 )) timSortBy: [ :each | each abs ]) asArray equals: #( 1.0 2.0 -3.0 )
]

{ #category : 'tests' }
TimSortKeyTests >> testUncomparableKeys [
	self should: [ #( 1 2 3 ) copy timSortBy: [ :each | each odd ifTrue: [ 'a' ] ifFalse: [ 1 ] ] ] raise: Error.
	self should: [ #( 1 2 3 ) copy timSortBy: [ :each | nil ] ] raise: Error
]
