"
The baseline of TimSort (https://github.com/massimo-nocentini/timsort.st): timsort, the stable and adaptive sort of CPython, for Pharo 12 to 15, on the TimSortPlugin of the VM, on the library libTimSortFFI through the FFI, or in pure Smalltalk.

Groups: Core (the packages TimSort and TimSort-Smalltalk, which need no other project), Tests (TimSort-Tests), FFI (TimSort-FFI: the library libTimSortFFI through the FFI, on a VM without the plugin), FFITests (TimSort-FFI-Tests), Smalltalk (TimSort-Smalltalk alone: the port of timsort.c, without the facade), SmalltalkTests (TimSort-Smalltalk-Tests); default loads all of them.
"
Class {
	#name : 'BaselineOfTimSort',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfTimSort',
	#package : 'BaselineOfTimSort'
}

{ #category : 'baselines' }
BaselineOfTimSort >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec
			package: 'TimSort-Smalltalk';
			package: 'TimSort' with: [ spec requires: #( 'TimSort-Smalltalk' ) ];
			package: 'TimSort-Tests' with: [ spec requires: #( 'TimSort' ) ];
			package: 'TimSort-Smalltalk-Tests' with: [ spec requires: #( 'TimSort-Smalltalk' ) ];
			package: 'TimSort-FFI' with: [ spec requires: #( 'TimSort' ) ];
			package: 'TimSort-FFI-Tests' with: [ spec requires: #( 'TimSort-FFI' 'TimSort-Tests' ) ].
		spec
			group: 'Core' with: #( 'TimSort' 'TimSort-Smalltalk' );
			group: 'Tests' with: #( 'TimSort-Tests' );
			group: 'FFI' with: #( 'TimSort-FFI' );
			group: 'FFITests' with: #( 'TimSort-FFI-Tests' );
			group: 'Smalltalk' with: #( 'TimSort-Smalltalk' );
			group: 'SmalltalkTests' with: #( 'TimSort-Smalltalk-Tests' );
			group: 'default' with: #( 'Core' 'Tests' 'FFI' 'FFITests' 'Smalltalk' 'SmalltalkTests' ) ]
]
