"
I am timsort in pure Smalltalk: a port of timsort.c (https://github.com/massimo-nocentini/timsort.c, commit fd70381), which is the sort of CPython's lists (listsort of Objects/listobject.c, CPython 3.13 and 3.14) by Tim Peters, with the powersort merge policy.  I sort a slice of a SequenceableCollection in place, adaptively (natural runs, about one comparison per element on sorted or reversed input), stably, and with as few comparisons as a merge sort on random data.

I am faithful to the C code: given the same input and the same answers of the comparison, I make exactly the same comparisons, with the arguments in the same order, and leave the same permutation; the tests of TimSort-Smalltalk-Tests check the comparison traces against the C library.  The only comparison is a strict less-than, my subclass responsibility #is:lessThan: (ISLT of the C code): TimSortSmalltalkLessThanSorter asks a block, TimSortSmalltalkNaturalOrderSorter sends #<, TimSortSmalltalkSortBlockSorter turns a Pharo sortBlock (a <= b style) into a strict less-than.

Use the class side of TimSortSmalltalk, or one of my subclasses directly:

	(TimSortSmalltalkLessThanSorter lessThan: [ :a :b | a size < b size ]) sort: anArray.
	TimSortSmalltalkNaturalOrderSorter new beDescending; sort: anArray from: 10 to: 20.

An instance sorts one collection at a time and may be reused (it keeps its merge buffer); a comparison that sorts other collections must use other instances.

How the C code maps onto me:
- list_sort_impl: #sort:from:to: (#beDescending is its reverse flag) and #sortRuns.
- count_run: #countRunAt:limit:, #ascendingRunAt:from:limit:, #descendingRunAt:from:limit:.
- binarysort: #binaryInsertionSortAt:count:sorted: and #insertAt:after:.  Only CPython's default variant is ported (binary insertion with the plain branch).  The C code also has an ordinary insertion sort, which makes more comparisons and is never CPython's default, and a branch-free variant of the binary insertion, which is a C code generation trick that makes the same comparisons.
- gallop_left and gallop_right: #gallopLeft:in:from:count:hint: and #gallopRight:in:from:count:hint:, which end with the binary searches #searchLeft:in:from:after:upTo: and #searchRight:in:from:after:upTo:.
- merge_lo and merge_hi: #mergeLowAt:count:with:count: and #mergeHighAt:count:with:count:, split into a straightforward phase (#mergeLowOneAtATime, #mergeHighOneAtATime) and a galloping phase (#mergeLowGalloping, #mergeHighGalloping); their goto Succeed, Fail, CopyA and CopyB are #moveRemainingAFromBuffer, #moveRemainingBFromBuffer, #moveRemainingAThenFirstB and #moveRemainingBThenLastA.
- merge_at, found_new_run, merge_force_collapse: #mergeAt:, #foundNewRunOfLength:, #mergeForceCollapse.
- powerloop and merge_compute_minrun: the class side, #powerOfRunAt:length:nextLength:total: and #minimumRunLengthFor:.  MIN_GALLOP, MAX_MINRUN and MERGESTATE_TEMP_SIZE are #minimumGallop, #maximumMinimumRun and #initialBufferSize there.
- merge_getmem: #ensureBufferCapacity:, which allocates exactly what a merge needs, never less than #initialBufferSize slots, and keeps the buffer between merges and between sorts.  The binary insertion uses the buffer too, to move elements up by one slot with two primitive copies (the C code uses a loop): this changes no comparison.  The copies into the collection are primitive in an Array only, element by element (at:put:) in any other collection (replaceItemsFrom:to:with:startingAt:), whose replaceFrom:to:with:startingAt: may want a replacement of its own class (a Text).

Indices are those of the collection (1-based, absolute) instead of pointers; a pending run is a TimSortSmalltalkRun.  The cursors of the merge in progress are instance variables (target, nextA, nextB, remainingA, remainingB), so that the phases of a merge are small methods and the merge can be undone when it is interrupted:

	merge low (run A, the shorter, is in the buffer):
		the next element of A is buffer at: nextA, the next of B is items at: nextB,
		the next slot to fill is items at: target, upwards, and target + remainingA = nextB
	merge high (run B, the shorter, is in the buffer):
		the last element of A is items at: nextA, the last of B is buffer at: nextB = remainingB,
		the next slot to fill is items at: target, downwards, and target - remainingB = nextA

Exceptions and other non-local exits (a ^ in a block, Process>>terminate) raised by a comparison go to the caller.  Before the unwinding leaves me, the merge in progress copies its buffered elements back into their holes (ifCurtailed:, as the C code does on its Fail path) and a descending sort reverses the slice back (ensure:, as list_sort_impl does), so the collection always holds a permutation of its elements.  An exception handler that runs before the unwinding (on:do: runs its handler block on top of the sort) can still see a hole filled with a duplicate.  A comparison that changes the collection being sorted gets an unspecified order.
"
Class {
	#name : 'TimSortSmalltalkSorter',
	#superclass : 'Object',
	#instVars : [
		'descending',
		'items',
		'first',
		'count',
		'minGallop',
		'runs',
		'buffer',
		'target',
		'nextA',
		'nextB',
		'remainingA',
		'remainingB'
	],
	#category : 'TimSort-Smalltalk',
	#package : 'TimSort-Smalltalk'
}

{ #category : 'constants' }
TimSortSmalltalkSorter class >> initialBufferSize [
	"MERGESTATE_TEMP_SIZE: the smallest merge buffer.  timsort.c has a buffer of this size on the C stack and allocates a bigger one only when a merge needs it"

	^ 256
]

{ #category : 'testing' }
TimSortSmalltalkSorter class >> isAbstract [

	^ self == TimSortSmalltalkSorter
]

{ #category : 'constants' }
TimSortSmalltalkSorter class >> maximumMinimumRun [
	"MAX_MINRUN: the largest minimum run length, a power of 2"

	^ 64
]

{ #category : 'policy' }
TimSortSmalltalkSorter class >> minimumGallop [
	"MIN_GALLOP: a merge enters galloping mode after one run wins this many times in a row (the adaptive minGallop of a sort starts here), and leaves it when both runs win fewer than this many elements at a time"

	^ 7
]

{ #category : 'policy' }
TimSortSmalltalkSorter class >> minimumRunLengthFor: anInteger [
	"merge_compute_minrun.  The length to which short natural runs are extended by binary insertion: anInteger itself when it is less than #maximumMinimumRun, else a k between half #maximumMinimumRun and #maximumMinimumRun such that anInteger / k is close to, but strictly less than, a power of 2 (half #maximumMinimumRun for powers of 2)"

	| n shiftedOutOnes |
	n := anInteger.
	shiftedOutOnes := 0.
	[ n >= self maximumMinimumRun ] whileTrue: [
		shiftedOutOnes := shiftedOutOnes bitOr: (n bitAnd: 1).
		n := n bitShift: -1 ].
	^ n + shiftedOutOnes
]

{ #category : 'policy' }
TimSortSmalltalkSorter class >> powerOfRunAt: offset length: length nextLength: nextLength total: total [
	"powerloop.  The power of the boundary between a run that begins offset elements after the start of a slice of total elements and is length elements long, and the next run, nextLength elements long: the depth of the boundary in the binary merge tree of the slice, that is, the number of leading bits that the binary expansions of the midpoints of the two runs, as fractions of total, have in common, plus 1.

	The midpoints are offset + (length / 2) and offset + length + (nextLength / 2); their doubles, which are integers, are expanded one bit at a time, as in long division by total"

	| power a b |
	power := 0.
	a := 2 * offset + length.
	b := a + length + nextLength.
	[
	power := power + 1.
	a >= total
		ifTrue: [ "both bits are 1"
			a := a - total.
			b := b - total ]
		ifFalse: [ "the bit of a is 0: the expansions differ if the bit of b is 1"
			b >= total ifTrue: [ ^ power ] ].
	a := a * 2.
	b := b * 2 ] repeat
]

{ #category : 'configuring' }
TimSortSmalltalkSorter >> beAscending [

	descending := false
]

{ #category : 'configuring' }
TimSortSmalltalkSorter >> beDescending [
	"Sort into descending order, stably: elements that are equal keep their order, as in CPython's reverse=True (the slice is reversed, sorted ascending, and reversed back)"

	descending := true
]

{ #category : 'private - merging' }
TimSortSmalltalkSorter >> ensureBufferCapacity: anInteger [
	"merge_getmem: make the buffer hold at least anInteger elements.  As in C, a buffer that is too small is replaced (its content does not matter), not grown"

	(buffer notNil and: [ anInteger <= buffer size ]) ifTrue: [ ^ self ].
	buffer := Array new: (anInteger max: self class initialBufferSize)
]

{ #category : 'initialization' }
TimSortSmalltalkSorter >> initialize [

	super initialize.
	descending := false
]

{ #category : 'testing' }
TimSortSmalltalkSorter >> isDescending [

	^ descending
]

{ #category : 'comparing' }
TimSortSmalltalkSorter >> is: anObject lessThan: anotherObject [
	"ISLT: the strict order of the sort.  Answer true when anObject must come before anotherObject, false otherwise"

	^ self subclassResponsibility
]

{ #category : 'sorting' }
TimSortSmalltalkSorter >> sort: aSequenceableCollection [
	"Sort aSequenceableCollection in place and answer it"

	^ self sort: aSequenceableCollection from: 1 to: aSequenceableCollection size
]

{ #category : 'sorting' }
TimSortSmalltalkSorter >> sort: aSequenceableCollection from: start to: stop [
	"list_sort_impl.  Sort the elements of aSequenceableCollection from start to stop in place and answer aSequenceableCollection.  Slices of fewer than 2 elements are not looked at"

	| size |
	size := stop - start + 1.
	size < 2 ifTrue: [ ^ aSequenceableCollection ].
	(start >= 1 and: [ stop <= aSequenceableCollection size ]) ifFalse: [
		^ aSequenceableCollection errorSubscriptBounds: (start < 1
				   ifTrue: [ start ]
				   ifFalse: [ stop ]) ].
	self setUpSorting: aSequenceableCollection from: start count: size.
	descending ifFalse: [
		self sortRuns.
		^ aSequenceableCollection ].
	self reverseFrom: start to: stop.
	[ self sortRuns ] ensure: [ self reverseFrom: start to: stop ].
	^ aSequenceableCollection
]

{ #category : 'private - sorting' }
TimSortSmalltalkSorter >> setUpSorting: aSequenceableCollection from: start count: size [
	"merge_init"

	items := aSequenceableCollection.
	first := start.
	count := size.
	minGallop := self class minimumGallop.
	runs := OrderedCollection new
]

{ #category : 'private - sorting' }
TimSortSmalltalkSorter >> sortRuns [
	"The loop of list_sort_impl: march over the slice once, left to right, finding the natural runs, extending the short ones to the minimum run length, and merging them as the powersort policy says; then merge what is left"

	| start remaining minimumRun |
	start := first.
	remaining := count.
	minimumRun := self class minimumRunLengthFor: count.
	[
	| length |
	length := self countRunAt: start limit: remaining.
	length < minimumRun ifTrue: [
		| forced |
		forced := remaining min: minimumRun.
		self binaryInsertionSortAt: start count: forced sorted: length.
		length := forced ].
	self foundNewRunOfLength: length.
	runs addLast: (TimSortSmalltalkRun start: start length: length).
	start := start + length.
	(remaining := remaining - length) > 0 ] whileTrue.
	self mergeForceCollapse
]

{ #category : 'private - runs' }
TimSortSmalltalkSorter >> ascendingRunAt: start from: length limit: limit [
	"Extend the ascending (non-descending) run of length elements at start, by the elements that are not less than their predecessor, up to limit elements.  Answer its new length"

	| n |
	n := length.
	[ n < limit ] whileTrue: [
		(self is: (items at: start + n) lessThan: (items at: start + n - 1)) ifTrue: [ ^ n ].
		n := n + 1 ].
	^ n
]

{ #category : 'private - runs' }
TimSortSmalltalkSorter >> countRunAt: start limit: limit [
	"count_run.  Answer the length of the natural run at start, of at most limit (> 0) elements.  The run is ascending (each element not less than its predecessor) or descending (each element not greater than its predecessor); a descending run is reversed in place, stably: the elements of each subrun of equal elements keep their order"

	| n |
	n := self ascendingRunAt: start from: 1 limit: limit.
	n = limit ifTrue: [ ^ n ].
	"items at: start + n is strictly less than its predecessor"
	n > 1 ifTrue: [
		"If the first element is less than the last of the ascending run, the run is over.  Else all its elements are equal, and they begin a descending run: reverse them, as the descending run does with its subruns of equal elements"
		(self is: (items at: start) lessThan: (items at: start + n - 1)) ifTrue: [ ^ n ].
		self reverseFrom: start to: start + n - 1 ].
	n := self descendingRunAt: start from: n + 1 limit: limit.
	self reverseFrom: start to: start + n - 1.
	"The reversed run may go on ascending: [3, 2, 3, 4, 1] gives the run [2, 3, 3, 4]"
	^ self ascendingRunAt: start from: n limit: limit
]

{ #category : 'private - runs' }
TimSortSmalltalkSorter >> descendingRunAt: start from: length limit: limit [
	"Extend the descending (non-ascending) run of length elements at start, up to limit elements, and answer its new length.  Every subrun of equal elements found on the way is reversed in place (REVERSE_LAST_NEQ), so that the reversal of the whole run restores their order"

	| n equals |
	n := length.
	equals := 0. "the last equals + 1 elements are equal"
	[ n < limit ] whileTrue: [
		(self is: (items at: start + n) lessThan: (items at: start + n - 1))
			ifTrue: [
				self reverseLast: equals + 1 before: start + n.
				equals := 0 ]
			ifFalse: [
				(self is: (items at: start + n - 1) lessThan: (items at: start + n)) ifTrue: [
					self reverseLast: equals + 1 before: start + n.
					^ n ].
				"neither is less than the other: they are equal"
				equals := equals + 1 ].
		n := n + 1 ].
	self reverseLast: equals + 1 before: start + n.
	^ n
]

{ #category : 'private - runs' }
TimSortSmalltalkSorter >> reverseFrom: start to: stop [
	"reverse_slice"

	| low high |
	low := start.
	high := stop.
	[ low < high ] whileTrue: [
		items swap: low with: high.
		low := low + 1.
		high := high - 1 ]
]

{ #category : 'private - runs' }
TimSortSmalltalkSorter >> reverseLast: anInteger before: anIndex [
	"Reverse the anInteger elements before anIndex"

	anInteger > 1 ifTrue: [ self reverseFrom: anIndex - anInteger to: anIndex - 1 ]
]

{ #category : 'private - insertion' }
TimSortSmalltalkSorter >> binaryInsertionSortAt: start count: size sorted: sortedSize [
	"binarysort.  Sort the size elements at start, of which the first sortedSize are already sorted, by stable binary insertion: few comparisons, and moves of elements that are cheap for runs of at most #maximumMinimumRun elements"

	self ensureBufferCapacity: size.
	start + (sortedSize max: 1) to: start + size - 1 do: [ :index | self insertAt: index after: start ]
]

{ #category : 'private - insertion' }
TimSortSmalltalkSorter >> insertAt: index after: start [
	"Move the element at index into the sorted elements from start to index - 1, after those that are not greater than it.  The binary search keeps

		elements from start to left - 1 <= pivot < elements from right to index - 1

	(the midpoint is the one of the C code, whose indices are relative to start, since start + start is even).  The elements after left move up by one slot through the buffer, since replaceFrom:to:with:startingAt: copies upwards: two primitive copies are faster than a loop of at:put: (in an Array; other collections copy element by element, replaceItemsFrom:to:with:startingAt:)"

	| pivot left right |
	pivot := items at: index.
	left := start.
	right := index.
	[
	| middle |
	middle := (left + right) // 2.
	(self is: pivot lessThan: (items at: middle))
		ifTrue: [ right := middle ]
		ifFalse: [ left := middle + 1 ].
	left < right ] whileTrue.
	buffer replaceFrom: 1 to: index - left with: items startingAt: left.
	self replaceItemsFrom: left + 1 to: index with: buffer startingAt: 1.
	items at: left put: pivot
]

{ #category : 'private - galloping' }
TimSortSmalltalkSorter >> gallopLeft: key in: array from: base count: size hint: hint [
	"gallop_left.  The elements of array from base, size (> 0) of them, are sorted.  Answer the offset k, 0 <= k <= size, at which key belongs among them, before the elements equal to it:

		array[base + k - 1] < key <= array[base + k]

	pretending that array[base - 1] is minus infinity and array[base + size] plus infinity.  The search starts at the offset hint (0 <= hint < size), with offsets that grow as 1, 3, 7, 15... (galloping) to bracket k, and ends with a binary search; the closer hint is to k, the fewer comparisons"

	| anchor lastOffset offset maxOffset |
	anchor := base + hint.
	lastOffset := 0.
	offset := 1.
	(self is: (array at: anchor) lessThan: key) ifTrue: [
		"gallop right, until array[anchor + lastOffset] < key <= array[anchor + offset]"
		maxOffset := size - hint.
		[ offset < maxOffset and: [ self is: (array at: anchor + offset) lessThan: key ] ] whileTrue: [
			lastOffset := offset.
			offset := offset * 2 + 1 ].
		^ self
			  searchLeft: key
			  in: array
			  from: base
			  after: hint + lastOffset
			  upTo: hint + (offset min: maxOffset) ].
	"key <= array[anchor]: gallop left, until array[anchor - offset] < key <= array[anchor - lastOffset]"
	maxOffset := hint + 1.
	[ offset >= maxOffset or: [ self is: (array at: anchor - offset) lessThan: key ] ] whileFalse: [
		lastOffset := offset.
		offset := offset * 2 + 1 ].
	^ self
		  searchLeft: key
		  in: array
		  from: base
		  after: hint - (offset min: maxOffset)
		  upTo: hint - lastOffset
]

{ #category : 'private - galloping' }
TimSortSmalltalkSorter >> gallopRight: key in: array from: base count: size hint: hint [
	"gallop_right.  Like #gallopLeft:in:from:count:hint:, but answer the offset k after the elements equal to key:

		array[base + k - 1] <= key < array[base + k]"

	| anchor lastOffset offset maxOffset |
	anchor := base + hint.
	lastOffset := 0.
	offset := 1.
	(self is: key lessThan: (array at: anchor)) ifTrue: [
		"gallop left, until array[anchor - offset] <= key < array[anchor - lastOffset]"
		maxOffset := hint + 1.
		[ offset < maxOffset and: [ self is: key lessThan: (array at: anchor - offset) ] ] whileTrue: [
			lastOffset := offset.
			offset := offset * 2 + 1 ].
		^ self
			  searchRight: key
			  in: array
			  from: base
			  after: hint - (offset min: maxOffset)
			  upTo: hint - lastOffset ].
	"array[anchor] <= key: gallop right, until array[anchor + lastOffset] <= key < array[anchor + offset]"
	maxOffset := size - hint.
	[ offset >= maxOffset or: [ self is: key lessThan: (array at: anchor + offset) ] ] whileFalse: [
		lastOffset := offset.
		offset := offset * 2 + 1 ].
	^ self
		  searchRight: key
		  in: array
		  from: base
		  after: hint + lastOffset
		  upTo: hint + (offset min: maxOffset)
]

{ #category : 'private - galloping' }
TimSortSmalltalkSorter >> searchLeft: key in: array from: base after: lower upTo: upper [
	"The binary search that ends gallop_left: given array[base + lower] < key <= array[base + upper] (lower may be -1), answer the offset k such that array[base + k - 1] < key <= array[base + k]"

	| low high |
	low := lower + 1.
	high := upper.
	[ low < high ] whileTrue: [
		| middle |
		middle := low + ((high - low) // 2).
		(self is: (array at: base + middle) lessThan: key)
			ifTrue: [ low := middle + 1 ]
			ifFalse: [ high := middle ] ].
	^ high
]

{ #category : 'private - galloping' }
TimSortSmalltalkSorter >> searchRight: key in: array from: base after: lower upTo: upper [
	"The binary search that ends gallop_right: given array[base + lower] <= key < array[base + upper] (lower may be -1), answer the offset k such that array[base + k - 1] <= key < array[base + k]"

	| low high |
	low := lower + 1.
	high := upper.
	[ low < high ] whileTrue: [
		| middle |
		middle := low + ((high - low) // 2).
		(self is: key lessThan: (array at: base + middle))
			ifTrue: [ high := middle ]
			ifFalse: [ low := middle + 1 ] ].
	^ high
]

{ #category : 'private - merging' }
TimSortSmalltalkSorter >> foundNewRunOfLength: length [
	"found_new_run.  A new run of length elements follows the top run of the stack (the caller pushes it afterwards).  Compute the power of the boundary between the two, and merge the runs below whose boundaries have a greater power (powersort)"

	| top power |
	runs isEmpty ifTrue: [ ^ self ].
	top := runs last.
	power := self class
		         powerOfRunAt: top start - first
		         length: top length
		         nextLength: length
		         total: count.
	[ runs size > 1 and: [ (runs at: runs size - 1) power > power ] ] whileTrue: [ self mergeAt: runs size - 1 ].
	runs last power: power
]

{ #category : 'private - merging' }
TimSortSmalltalkSorter >> mergeAt: index [
	"merge_at.  Merge the runs at index and index + 1 of the stack, which is the second or third from the top, into one run at index.  The elements at the start of the first run that are not greater than the first element of the second run are already in place, and so are the elements at the end of the second run that are not less than the last element of the first; the rest is merged through a buffer as long as the shorter of the two"

	| runA runB startA sizeA startB sizeB placed |
	runA := runs at: index.
	runB := runs at: index + 1.
	startA := runA start.
	sizeA := runA length.
	startB := runB start.
	sizeB := runB length.
	runA length: sizeA + sizeB.
	runs removeAt: index + 1.
	placed := self gallopRight: (items at: startB) in: items from: startA count: sizeA hint: 0.
	startA := startA + placed.
	sizeA := sizeA - placed.
	sizeA = 0 ifTrue: [ ^ self ].
	sizeB := self gallopLeft: (items at: startA + sizeA - 1) in: items from: startB count: sizeB hint: sizeB - 1.
	sizeB = 0 ifTrue: [ ^ self ].
	sizeA <= sizeB
		ifTrue: [ self mergeLowAt: startA count: sizeA with: startB count: sizeB ]
		ifFalse: [ self mergeHighAt: startA count: sizeA with: startB count: sizeB ]
]

{ #category : 'private - merging' }
TimSortSmalltalkSorter >> mergeForceCollapse [
	"merge_force_collapse.  Merge all the runs of the stack into one, at the end of the sort"

	[ runs size > 1 ] whileTrue: [
		| index |
		index := runs size - 1.
		(index > 1 and: [ (runs at: index - 1) length < (runs at: index + 1) length ]) ifTrue: [ index := index - 1 ].
		self mergeAt: index ]
]

{ #category : 'private - merging' }
TimSortSmalltalkSorter >> replaceItemsFrom: start to: stop with: aCollection startingAt: index [
	"items replaceFrom: start to: stop with: aCollection startingAt: index, upwards, where aCollection is the buffer (an Array) or items itself.  An Array copies with the primitive; any other collection element by element (at:, at:put:), since its replaceFrom:to:with:startingAt: may want a replacement of its own class (a Text wants a Text, and an Array has no asText)"

	items isArray ifTrue: [ ^ items replaceFrom: start to: stop with: aCollection startingAt: index ].
	0 to: stop - start do: [ :k | items at: start + k put: (aCollection at: index + k) ]
]

{ #category : 'private - merging' }
TimSortSmalltalkSorter >> moveItemsFrom: source to: destination count: size [
	"memmove within the collection: the two ranges may overlap"

	destination < source ifTrue: [
		"replaceFrom:to:with:startingAt: copies upwards"
		^ self replaceItemsFrom: destination to: destination + size - 1 with: items startingAt: source ].
	size - 1 to: 0 by: -1 do: [ :offset | items at: destination + offset put: (items at: source + offset) ]
]

{ #category : 'private - merging low' }
TimSortSmalltalkSorter >> mergeLow [
	"The body of merge_lo, after the setup.  The first element of B is the first of the merge"

	items at: target put: (items at: nextB).
	target := target + 1.
	nextB := nextB + 1.
	(remainingB := remainingB - 1) = 0 ifTrue: [ ^ self moveRemainingAFromBuffer ].
	remainingA = 1 ifTrue: [ ^ self moveRemainingBThenLastA ].
	[ self mergeLowOneAtATime or: [ self mergeLowGalloping ] ] whileFalse
]

{ #category : 'private - merging low' }
TimSortSmalltalkSorter >> mergeLowAt: startA count: sizeA with: startB count: sizeB [
	"merge_lo.  Merge, stably and in place, the run A of sizeA elements at startA with the run B of sizeB elements that follows it, when sizeA <= sizeB: A is moved into the buffer, and the merge fills the collection upwards from startA.  The last element of A is the last of the merge, the first of B the first"

	self ensureBufferCapacity: sizeA.
	buffer replaceFrom: 1 to: sizeA with: items startingAt: startA.
	target := startA.
	nextA := 1.
	remainingA := sizeA.
	nextB := startB.
	remainingB := sizeB.
	[ self mergeLow ] ifCurtailed: [ self moveRemainingAFromBuffer ]
]

{ #category : 'private - merging low' }
TimSortSmalltalkSorter >> mergeLowGalloping [
	"The galloping phase of merge_lo: search where the next element of each run goes in the other, and move whole slices at a time, while the slices are long enough.  Each time galloping goes on, minGallop drops (galloping becomes easier to enter); when it stops, minGallop goes up by 1.  Answer whether the merge is complete"

	| winsA winsB |
	minGallop := minGallop + 1.
	[
	minGallop > 1 ifTrue: [ minGallop := minGallop - 1 ].
	winsA := self gallopRight: (items at: nextB) in: buffer from: nextA count: remainingA hint: 0.
	winsA > 0 ifTrue: [
		self replaceItemsFrom: target to: target + winsA - 1 with: buffer startingAt: nextA.
		target := target + winsA.
		nextA := nextA + winsA.
		(remainingA := remainingA - winsA) = 1 ifTrue: [
			self moveRemainingBThenLastA.
			^ true ].
		"A is exhausted only if the comparison is inconsistent"
		remainingA = 0 ifTrue: [ ^ true ] ].
	items at: target put: (items at: nextB).
	target := target + 1.
	nextB := nextB + 1.
	(remainingB := remainingB - 1) = 0 ifTrue: [
		self moveRemainingAFromBuffer.
		^ true ].
	winsB := self gallopLeft: (buffer at: nextA) in: items from: nextB count: remainingB hint: 0.
	winsB > 0 ifTrue: [
		self moveItemsFrom: nextB to: target count: winsB.
		target := target + winsB.
		nextB := nextB + winsB.
		(remainingB := remainingB - winsB) = 0 ifTrue: [
			self moveRemainingAFromBuffer.
			^ true ] ].
	items at: target put: (buffer at: nextA).
	target := target + 1.
	nextA := nextA + 1.
	(remainingA := remainingA - 1) = 1 ifTrue: [
		self moveRemainingBThenLastA.
		^ true ].
	winsA >= self class minimumGallop or: [ winsB >= self class minimumGallop ] ] whileTrue.
	"penalize leaving galloping mode"
	minGallop := minGallop + 1.
	^ false
]

{ #category : 'private - merging low' }
TimSortSmalltalkSorter >> mergeLowOneAtATime [
	"The straightforward phase of merge_lo: move the lesser of the next elements of A and B (A when they are equal), until one run wins minGallop times in a row (answer false: go galloping) or the merge is complete (answer true)"

	| winsA winsB headA headB |
	winsA := 0.
	winsB := 0.
	[
	headA := buffer at: nextA.
	headB := items at: nextB.
	(self is: headB lessThan: headA)
		ifTrue: [
			items at: target put: headB.
			target := target + 1.
			nextB := nextB + 1.
			winsB := winsB + 1.
			winsA := 0.
			(remainingB := remainingB - 1) = 0 ifTrue: [
				self moveRemainingAFromBuffer.
				^ true ].
			winsB >= minGallop ifTrue: [ ^ false ] ]
		ifFalse: [
			items at: target put: headA.
			target := target + 1.
			nextA := nextA + 1.
			winsA := winsA + 1.
			winsB := 0.
			(remainingA := remainingA - 1) = 1 ifTrue: [
				self moveRemainingBThenLastA.
				^ true ].
			winsA >= minGallop ifTrue: [ ^ false ] ] ] repeat
]

{ #category : 'private - merging low' }
TimSortSmalltalkSorter >> moveRemainingAFromBuffer [
	"The end of merge_lo (Succeed and Fail): the elements of A left in the buffer fill the hole that ends where the rest of B begins"

	self replaceItemsFrom: target to: target + remainingA - 1 with: buffer startingAt: nextA
]

{ #category : 'private - merging low' }
TimSortSmalltalkSorter >> moveRemainingBThenLastA [
	"CopyB of merge_lo: the one element left of A is the last of the merge, after the rest of B"

	self moveItemsFrom: nextB to: target count: remainingB.
	items at: target + remainingB put: (buffer at: nextA)
]

{ #category : 'private - merging high' }
TimSortSmalltalkSorter >> mergeHigh [
	"The body of merge_hi, after the setup.  The last element of A is the last of the merge"

	items at: target put: (items at: nextA).
	target := target - 1.
	nextA := nextA - 1.
	(remainingA := remainingA - 1) = 0 ifTrue: [ ^ self moveRemainingBFromBuffer ].
	remainingB = 1 ifTrue: [ ^ self moveRemainingAThenFirstB ].
	[ self mergeHighOneAtATime or: [ self mergeHighGalloping ] ] whileFalse
]

{ #category : 'private - merging high' }
TimSortSmalltalkSorter >> mergeHighAt: startA count: sizeA with: startB count: sizeB [
	"merge_hi.  Merge, stably and in place, the run A of sizeA elements at startA with the run B of sizeB elements that follows it, when sizeA > sizeB: B is moved into the buffer, and the merge fills the collection downwards from its end.  The last element of A is the last of the merge, the first of B the first"

	self ensureBufferCapacity: sizeB.
	buffer replaceFrom: 1 to: sizeB with: items startingAt: startB.
	target := startB + sizeB - 1.
	nextA := startA + sizeA - 1.
	remainingA := sizeA.
	nextB := sizeB.
	remainingB := sizeB.
	[ self mergeHigh ] ifCurtailed: [ self moveRemainingBFromBuffer ]
]

{ #category : 'private - merging high' }
TimSortSmalltalkSorter >> mergeHighGalloping [
	"The galloping phase of merge_hi, the mirror of #mergeLowGalloping: the searches start from the ends of the runs.  Answer whether the merge is complete"

	| winsA winsB |
	minGallop := minGallop + 1.
	[
	minGallop > 1 ifTrue: [ minGallop := minGallop - 1 ].
	winsA := remainingA - (self
		          gallopRight: (buffer at: nextB)
		          in: items
		          from: nextA - remainingA + 1
		          count: remainingA
		          hint: remainingA - 1).
	winsA > 0 ifTrue: [
		target := target - winsA.
		nextA := nextA - winsA.
		self moveItemsFrom: nextA + 1 to: target + 1 count: winsA.
		(remainingA := remainingA - winsA) = 0 ifTrue: [
			self moveRemainingBFromBuffer.
			^ true ] ].
	items at: target put: (buffer at: nextB).
	target := target - 1.
	nextB := nextB - 1.
	(remainingB := remainingB - 1) = 1 ifTrue: [
		self moveRemainingAThenFirstB.
		^ true ].
	winsB := remainingB - (self
		          gallopLeft: (items at: nextA)
		          in: buffer
		          from: 1
		          count: remainingB
		          hint: remainingB - 1).
	winsB > 0 ifTrue: [
		target := target - winsB.
		nextB := nextB - winsB.
		self replaceItemsFrom: target + 1 to: target + winsB with: buffer startingAt: nextB + 1.
		(remainingB := remainingB - winsB) = 1 ifTrue: [
			self moveRemainingAThenFirstB.
			^ true ].
		"B is exhausted only if the comparison is inconsistent"
		remainingB = 0 ifTrue: [ ^ true ] ].
	items at: target put: (items at: nextA).
	target := target - 1.
	nextA := nextA - 1.
	(remainingA := remainingA - 1) = 0 ifTrue: [
		self moveRemainingBFromBuffer.
		^ true ].
	winsA >= self class minimumGallop or: [ winsB >= self class minimumGallop ] ] whileTrue.
	"penalize leaving galloping mode"
	minGallop := minGallop + 1.
	^ false
]

{ #category : 'private - merging high' }
TimSortSmalltalkSorter >> mergeHighOneAtATime [
	"The straightforward phase of merge_hi: move the greater of the last elements of A and B (B when they are equal) to the end, until one run wins minGallop times in a row (answer false: go galloping) or the merge is complete (answer true)"

	| winsA winsB headA headB |
	winsA := 0.
	winsB := 0.
	[
	headA := items at: nextA.
	headB := buffer at: nextB.
	(self is: headB lessThan: headA)
		ifTrue: [
			items at: target put: headA.
			target := target - 1.
			nextA := nextA - 1.
			winsA := winsA + 1.
			winsB := 0.
			(remainingA := remainingA - 1) = 0 ifTrue: [
				self moveRemainingBFromBuffer.
				^ true ].
			winsA >= minGallop ifTrue: [ ^ false ] ]
		ifFalse: [
			items at: target put: headB.
			target := target - 1.
			nextB := nextB - 1.
			winsB := winsB + 1.
			winsA := 0.
			(remainingB := remainingB - 1) = 1 ifTrue: [
				self moveRemainingAThenFirstB.
				^ true ].
			winsB >= minGallop ifTrue: [ ^ false ] ] ] repeat
]

{ #category : 'private - merging high' }
TimSortSmalltalkSorter >> moveRemainingAThenFirstB [
	"CopyA of merge_hi: the one element left of B is the first of the merge, before the rest of A"

	self moveItemsFrom: nextA - remainingA + 1 to: target - remainingA + 1 count: remainingA.
	items at: target - remainingA put: (buffer at: nextB)
]

{ #category : 'private - merging high' }
TimSortSmalltalkSorter >> moveRemainingBFromBuffer [
	"The end of merge_hi (Succeed and Fail): the elements of B left in the buffer, its first remainingB, fill the hole that begins after the rest of A"

	self replaceItemsFrom: target - remainingB + 1 to: target with: buffer startingAt: 1
]
