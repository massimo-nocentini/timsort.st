"
The tests of TimSort: each mode on each backend (the suites under TimSortBackendTestCase run on #plugin and #smalltalk, and TimSort-FFI-Tests runs them on #ffi), against Pharo's own sort with == slot for slot, the per-collection behaviour, the choice of the backend (TimSortSmalltalk by default for the sorts by a sortBlock, the resumable C sorts when named), the facade with a scripted backend, and the raw contract of the primitives.
"
Class {
	#name : 'ManifestTimSortTests',
	#superclass : 'PackageManifest',
	#category : 'TimSort-Tests-Manifest',
	#package : 'TimSort-Tests',
	#tag : 'Manifest'
}
