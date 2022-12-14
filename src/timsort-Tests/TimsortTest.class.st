Class {
	#name : #TimsortTest,
	#superclass : #TestCase,
	#category : #'timsort-Tests'
}

{ #category : #tests }
TimsortTest >> testTimsort [

	| array timsorted mergesorted tt ts |
	self timeLimit: 5 minutes.

	array := (1 to: 1e3 asInteger) asArray shuffled.

	tt := [ timsorted := array timsort ] timeToRun.
	ts := [ mergesorted := array sorted ] timeToRun.

	{ 
		tt.
		ts } inspect.

	self assert: timsorted equals: mergesorted
]
