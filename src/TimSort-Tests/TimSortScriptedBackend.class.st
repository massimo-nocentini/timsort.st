"
I am a backend of TimSort for the tests of the facade: each call is recorded (calls) and answers the next scripted answer of its selector, else what TimSortPortBackend answers.  coroutines says whether I claim a resumable sort.
"
Class {
	#name : 'TimSortScriptedBackend',
	#superclass : 'Object',
	#instVars : [
		'answers',
		'calls',
		'coroutines'
	],
	#category : 'TimSort-Tests-Support',
	#package : 'TimSort-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
TimSortScriptedBackend class >> answering: aDictionary [
	"aDictionary: selector -> the answers of its successive calls"

	^ self new setAnswers: aDictionary
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes [
	^ self answer: #argSort: arguments: { keys. kindOrNil. perm. start. stop. aBoolean } default: [
		  TimSortPortBackend argSort: keys kind: kindOrNil into: perm from: start to: stop descending: aBoolean stringClasses: classes ]
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> blockSortFree: id [
	^ self answer: #blockSortFree: arguments: { id } default: [ true ]
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> blockSortLive [
	^ 0
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> blockSortNew: n descending: aBoolean [
	^ self answer: #blockSortNew: arguments: { n. aBoolean } default: [ TimSortFailure on: #'unsupported operation' ]
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> blockSortNext: id answer: anInteger [
	^ self answer: #blockSortNext: arguments: { id. anInteger } default: [ TimSortFailure on: #'unsupported operation' ]
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> blockSortPermutation: id into: perm [
	^ self answer: #blockSortPermutation: arguments: { id. perm } default: [ TimSortFailure on: #'unsupported operation' ]
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> coroutinesAvailable [
	^ coroutines == true
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean [
	^ self answer: #sortBuffer: arguments: { aBuffer. kind. start. stop. aBoolean } default: [
		  TimSortPortBackend sortBuffer: aBuffer kind: kind from: start to: stop descending: aBoolean ]
]

{ #category : 'backend protocol' }
TimSortScriptedBackend >> sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes [
	^ self answer: #sortObjects: arguments: { anArray. start. stop. aBoolean. classes } default: [
		  TimSortPortBackend sortObjects: anArray from: start to: stop descending: aBoolean stringClasses: classes ]
]

{ #category : 'accessing' }
TimSortScriptedBackend >> calls [
	"The calls made, oldest first, as selector -> arguments"

	^ calls
]

{ #category : 'accessing' }
TimSortScriptedBackend >> callsOf: aSelector [
	^ (calls select: [ :each | each key == aSelector ]) collect: [ :each | each value ]
]

{ #category : 'accessing' }
TimSortScriptedBackend >> coroutines: aBoolean [
	coroutines := aBoolean
]

{ #category : 'private' }
TimSortScriptedBackend >> answer: aSelector arguments: anArray default: aBlock [
	| queue |
	calls add: aSelector -> anArray.
	queue := answers at: aSelector ifAbsent: [ nil ].
	(queue isNil or: [ queue isEmpty ]) ifTrue: [ ^ aBlock value ].
	^ queue removeFirst
]

{ #category : 'initialization' }
TimSortScriptedBackend >> setAnswers: aDictionary [
	answers := Dictionary new.
	aDictionary keysAndValuesDo: [ :selector :values | answers at: selector put: values asOrderedCollection ].
	calls := OrderedCollection new.
	coroutines := false
]
