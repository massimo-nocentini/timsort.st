"
I test `TimSort`: The extension methods on each kind of collection (`OrderedCollection`, `SortedCollection`, `Interval`, `String`, `Symbol`, `Text`, `Array` subclasses), the copies of `timSorted`, read-only collections (and the retry of a handler of `ModificationForbidden`) and ranges, per backend.
"
Class {
	#name : 'TimSortCollectionTests',
	#superclass : 'TimSortBackendTestCase',
	#category : 'TimSort-Tests-Tests',
	#package : 'TimSort-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
TimSortCollectionTests >> errorOf: aBlock [
	"The class and the text of the error aBlock signals"

	^ [ aBlock value. nil ]
		  on: Error
		  do: [ :error | error class -> error messageText ]
]

{ #category : 'tests' }
TimSortCollectionTests >> testArraySubclasses [
	| weak strings |
	strings := { 'b' copy. 'c' copy. 'a' copy }.
	weak := WeakArray withAll: strings.
	weak timSort.
	self assert: (Array withAll: weak) equals: #( 'a' 'b' 'c' ).
	self assert: ((Array withAll: weak) collect: [ :each | strings includes: each ]) equals: #( true true true )
]

{ #category : 'tests' }
TimSortCollectionTests >> testInterval [
	"An Interval cannot be sorted in place: the error of Pharo's sort; its sorted copies as Pharo's"

	| interval |
	interval := 5 to: 1 by: -2.
	self assert: (self errorOf: [ interval timSort ]) equals: (self errorOf: [ interval sort ]).
	self assert: (self errorOf: [ interval timSort ]) notNil.
	self assert: (self errorOf: [ interval timSort: [ :a :b | a <= b ] ]) equals: (self errorOf: [ interval sort: [ :a :b | a <= b ] ]).
	self assert: (self errorOf: [ interval timSortDescending ]) notNil.
	self assert: (self errorOf: [ interval timSortBy: [ :each | each ] ]) notNil.
	self assert: (self errorOf: [ interval timSortDescendingBy: [ :each | each ] ]) notNil.
	self assert: interval timSorted equals: interval sorted.
	self assert: (interval timSorted: [ :a :b | a >= b ]) equals: #( 5 3 1 ).
	self assert: (interval timSortedBy: [ :each | each ]) equals: #( 1 3 5 ).
	self assert: (1 to: 0) timSorted equals: (1 to: 0) sorted
]

{ #category : 'tests' }
TimSortCollectionTests >> testOrderedCollection [
	"The slots firstIndex to lastIndex of the internal Array are sorted in place; the collection stays usable"

	| random oc expected |
	random := self random.
	#( 0 1 2 10 100 1000 ) do: [ :n |
		oc := OrderedCollection new: n * 2 + 10.
		oc addAll: (TimSortTestData numbers: n + 7 random: random).
		oc removeFirst: 7.
		oc addFirst: 0.5.
		expected := oc copy sort: [ :a :b | a <= b ].
		self assert: oc copy timSort asArray sameAs: expected asArray.
		expected := oc copy sort: [ :a :b | a >= b ].
		self assert: oc copy timSortDescending asArray sameAs: expected asArray.
		oc timSort.
		oc addFirst: -1000000; addLast: 1000000.
		self assert: oc first equals: -1000000.
		self assert: oc last equals: 1000000.
		self assert: oc size equals: n + 3 ]
]

{ #category : 'tests' }
TimSortCollectionTests >> testReadOnly [
	"Read-only receivers signal ModificationForbidden before anything is touched, on every mode, also when Pharo's sort would not complain (a read-only OrderedCollection)"

	| array oc |
	array := #( 3 1 2 ).
	self assert: array isReadOnlyObject.
	self should: [ array timSort ] raise: ModificationForbidden.
	self should: [ array timSortDescending ] raise: ModificationForbidden.
	self should: [ array timSort: [ :a :b | a <= b ] ] raise: ModificationForbidden.
	self should: [ array timSortBy: [ :each | each ] ] raise: ModificationForbidden.
	self should: [ TimSort sort: array from: 1 to: 1 descending: false ] raise: ModificationForbidden.
	self assert: array equals: #( 3 1 2 ).
	self assert: array timSorted equals: #( 1 2 3 ).
	self assert: (TimSort argSort: array) equals: #( 2 3 1 ).
	oc := OrderedCollection withAll: #( 3 1 2 ).
	oc beReadOnlyObject.
	self should: [ oc timSort ] raise: ModificationForbidden.
	oc beWritableObject.
	self assert: oc asArray equals: #( 3 1 2 ).
	self assert: ([ array timSort ] on: ModificationForbidden do: [ :error | error return: #refused ]) equals: #refused.
	self deny: ([ array timSort ] on: ModificationForbidden do: [ :error | error isResumable ]).
	self assert: array equals: #( 3 1 2 )
]

{ #category : 'tests' }
TimSortCollectionTests >> testRanges [
	| array |
	array := #( 6 5 4 3 2 1 ) copy.
	TimSort sort: array from: 2 to: 5 descending: false.
	self assert: array equals: #( 6 2 3 4 5 1 ).
	TimSort sort: array from: 7 to: 6 descending: false.
	TimSort sort: array from: 1 to: 0 descending: false.
	self should: [ TimSort sort: array from: 0 to: 3 descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort sort: array from: 1 to: 7 descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort sort: array from: 4 to: 2 descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort sort: array from: 1 to: nil descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort argSort: array from: 2 to: 9 descending: false ] raise: SubscriptOutOfBounds.
	self should: [ TimSort sort: array from: 2 to: 9 with: [ :a :b | a <= b ] ] raise: SubscriptOutOfBounds.
	self assert: array equals: #( 6 2 3 4 5 1 )
]

{ #category : 'tests' }
TimSortCollectionTests >> testSortedCollection [
	"As sort: does, the sort sets the sortBlock, so that the elements added later go to their place"

	| sc |
	sc := #( 3 1 2 ) asSortedCollection: [ :a :b | a >= b ].
	sc timSort.
	self assert: sc asArray equals: #( 1 2 3 ).
	self assert: sc sortBlock isNil.
	sc add: 0; add: 5.
	self assert: sc asArray equals: #( 0 1 2 3 5 ).
	sc timSortDescending.
	sc add: 4.
	self assert: sc asArray equals: #( 5 4 3 2 1 0 ).
	sc timSort: [ :a :b | a odd or: [ b even ] ].
	sc add: 7; add: 6.
	self assert: (sc asArray collect: [ :each | each odd ]) equals: #( true true true true false false false false ).
	sc timSortBy: [ :each | each negated ].
	sc add: 8.
	self assert: sc asArray equals: #( 8 7 6 5 4 3 2 1 0 ).
	sc timSortDescendingBy: [ :each | each negated ].
	sc add: -1.
	self assert: sc asArray equals: #( -1 0 1 2 3 4 5 6 7 8 ).
	self assert: (sc timSorted: [ :a :b | a >= b ]) asArray equals: #( 8 7 6 5 4 3 2 1 0 -1 ).
	self assert: sc asArray equals: #( -1 0 1 2 3 4 5 6 7 8 )
]

{ #category : 'tests' }
TimSortCollectionTests >> testSortedCollectionEqualElements [
	"The sortBlocks the sorts set are not strict (<=, >=), as those of sort: are: an element added later goes after the elements equal to it"

	| sc |
	sc := SortedCollection new.
	sc add: 2 -> #a; add: 1 -> #b.
	sc timSortBy: [ :each | each key ].
	sc add: 1 -> #c.
	self assert: (sc asArray collect: [ :each | each value ]) equals: #( #b #c #a ).
	sc timSortDescendingBy: [ :each | each key ].
	sc add: 1 -> #d.
	self assert: (sc asArray collect: [ :each | each value ]) equals: #( #a #b #c #d ).
	sc timSortDescending.
	sc add: 2 -> #e.
	self assert: (sc asArray collect: [ :each | each value ]) equals: #( #a #e #b #c #d ).
	sc timSort.
	sc add: 1 -> #f.
	self assert: (sc asArray collect: [ :each | each value ]) equals: #( #b #c #d #f #a #e )
]

{ #category : 'tests' }
TimSortCollectionTests >> testStrings [
	| string wide |
	string := 'hello world' copy.
	self assert: string timSort equals: 'hello world' copy sort.
	self assert: string timSortDescending equals: ('hello world' copy sort: [ :a :b | a >= b ]).
	wide := 'aα€b' asWideString.
	self assert: wide timSorted equals: wide copy sort.
	self assert: 'cba' timSorted equals: 'abc'
]

{ #category : 'tests' }
TimSortCollectionTests >> testText [
	"A Text is sorted through at: and at:put: (its replaceFrom:to:with:startingAt: takes only a Text), as Pharo sorts it"

	| random string |
	random := self random.
	#( 2 3 5 40 300 ) do: [ :n |
		string := String new: n.
		1 to: n do: [ :k | string at: k put: (Character value: 96 + (random nextInteger: 26)) ].
		self assert: string asText timSort string equals: string copy sort.
		self assert: string asText timSortDescending string equals: (string copy sort: [ :a :b | a >= b ]).
		self assert: string asText timSorted string equals: string copy sort.
		self assert: (string asText timSort: [ :a :b | a >= b ]) string equals: (string copy sort: [ :a :b | a >= b ]).
		self assert: (string asText timSortBy: [ :each | each asInteger negated ]) string equals: (string copy sort: [ :a :b | a >= b ]) ]
]

{ #category : 'tests' }
TimSortCollectionTests >> testReadOnlyRetried [
	"A handler of ModificationForbidden that makes the object writable and retries, as for Pharo's write barrier, lets the sort go on, on every mode; a handler that resumes the read-only object leaves it unsorted; an empty read-only collection has nothing to change, as for Pharo's sort"

	| retry array oc buffer |
	retry := [ :sortBlock |
	         sortBlock
		         on: ModificationForbidden
		         do: [ :error |
			         error object beWritableObject.
			         error retryModification ] ].
	{
		([ :each | each timSort ] -> #( 1 2 3 )).
		([ :each | each timSortDescending ] -> #( 3 2 1 )).
		([ :each | each timSort: [ :a :b | a <= b ] ] -> #( 1 2 3 )).
		([ :each | each timSortBy: [ :x | x ] ] -> #( 1 2 3 )) } do: [ :sortAndResult |
		array := #( 3 1 2 ) copy beReadOnlyObject; yourself.
		retry value: [ sortAndResult key value: array ].
		self assert: array equals: sortAndResult value.
		self deny: array isReadOnlyObject ].
	oc := OrderedCollection withAll: #( 3 1 2 ).
	oc beReadOnlyObject.
	(oc instVarNamed: 'array') beReadOnlyObject.
	retry value: [ oc timSort ].
	self assert: oc asArray equals: #( 1 2 3 ).
	self deny: (oc isReadOnlyObject or: [ (oc instVarNamed: 'array') isReadOnlyObject ]).
	buffer := (ByteArray withAll: #( 3 1 2 )) beReadOnlyObject; yourself.
	retry value: [ buffer timSort ].
	self assert: buffer equals: #[ 1 2 3 ].
	buffer := (Float64Array withAll: #( 3.0 1.0 2.0 )) beReadOnlyObject; yourself.
	retry value: [ TimSort sortBuffer: buffer ].
	self assert: buffer asArray equals: #( 1.0 2.0 3.0 ).
	array := #( 3 1 2 ) copy beReadOnlyObject; yourself.
	self assert: ([ array timSort ] on: ModificationForbidden do: [ :error | error resumeUnchecked: nil ]) identicalTo: array.
	self assert: array equals: #( 3 1 2 ).
	self assert: array isReadOnlyObject.
	self assert: #(  ) isReadOnlyObject.
	self assert: #(  ) timSort equals: #(  ).
	self assert: (#(  ) timSort: [ :a :b | a <= b ]) equals: #(  )
]

{ #category : 'tests' }
TimSortCollectionTests >> testSymbols [
	"A Symbol cannot be changed: the error of Pharo's sort; its sorted copies are Arrays, as Pharo's"

	self assert: (self errorOf: [ #cba timSort ]) equals: (self errorOf: [ #cba sort ]).
	self assert: (self errorOf: [ #cba timSort ]) notNil.
	self assert: (self errorOf: [ #cba timSort: [ :a :b | a <= b ] ]) equals: (self errorOf: [ #cba sort: [ :a :b | a <= b ] ]).
	self assert: (self errorOf: [ #abc timSortDescending ]) notNil.
	self assert: (self errorOf: [ #abc timSortBy: [ :each | each ] ]) notNil.
	self assert: #cba timSorted equals: #cba sorted.
	self assert: (#cba timSorted: [ :a :b | a >= b ]) equals: (#cba sorted: [ :a :b | a >= b ]).
	self assert: (#cba timSortedBy: [ :each | each ]) equals: #( $a $b $c )
]

{ #category : 'tests' }
TimSortCollectionTests >> testTimSortedCopies [
	| array sorted |
	array := #( 3 1 2 ) copy.
	sorted := array timSorted.
	self assert: sorted equals: #( 1 2 3 ).
	self assert: array equals: #( 3 1 2 ).
	self deny: sorted == array.
	self assert: (array timSorted: [ :a :b | a >= b ]) equals: #( 3 2 1 ).
	self assert: (array timSortedBy: [ :each | each negated ]) equals: #( 3 2 1 ).
	self assert: array equals: #( 3 1 2 ).
	self assert: array timSort == array.
	self assert: (array timSort: [ :a :b | a >= b ]) == array.
	self assert: (array timSortBy: [ :each | each ]) == array.
	self assert: array timSortDescending == array
]
