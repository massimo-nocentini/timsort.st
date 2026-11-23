"
I am signalled by `TimSort class>>sort:with:backend:` and `sort:from:to:with:backend:` when the backend they name has no resumable C sort here, before the collection is looked at:

- `#plugin` without the `TimSortPlugin`, or with a plugin that cannot switch C stacks (WebAssembly, a process with a shadow stack);
- `#ffi` without the package `TimSort-FFI` or `libTimSortFFI`, or with a library that cannot switch C stacks;
- or a name other than `#plugin`, `#ffi` and `#smalltalk`.

`backendName` is that name, and `messageText` says why. `TimSort resumableBackends` answers the names that work.
"
Class {
	#name : 'TimSortBackendUnavailable',
	#superclass : 'Error',
	#instVars : [
		'backendName'
	],
	#category : 'TimSort-Facade',
	#package : 'TimSort',
	#tag : 'Facade'
}

{ #category : 'signalling' }
TimSortBackendUnavailable class >> signalFor: aSymbol reason: aString [
	^ self new
		  backendName: aSymbol;
		  signal: 'TimSort: no resumable sort through ' , aSymbol printString , ': ' , aString
]

{ #category : 'accessing' }
TimSortBackendUnavailable >> backendName [
	"The backend that was asked for"

	^ backendName
]

{ #category : 'accessing' }
TimSortBackendUnavailable >> backendName: aSymbol [
	backendName := aSymbol
]
