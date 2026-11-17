"
TimSort-FFI - TimSort without the TimSortPlugin, through the FFI of the image.

On a VM without the plugin, TimSort sorts through TimSortLibrary: libTimSortFFI, the engine and the resumable sort of the plugin built as a library of their own (plugins/TimSortPlugin of https://github.com/massimo-nocentini/pharo-vm), which answers what the primitives answer for numbers: Arrays of SmallIntegers and Floats, the numeric buffers, the permutations by numeric keys, and the resumable sort by a sortBlock of TimSort sort: aCollection with: aBlock backend: #ffi, whose comparisons the caller evaluates between the steps of the sort (no callback; timSort: aBlock runs TimSortSmalltalk by default).  Strings and LargeIntegers go to the Smalltalk backend.  With the plugin, this package is used only for sort:with:backend: #ffi.  The library is native only: WebAssembly has none.

Put the library next to the VM or the image, or give its path:

	TimSortLibrary libraryPath: '/path/to/libTimSortFFI.so'
"
Class {
	#name : 'ManifestTimSortFFI',
	#superclass : 'PackageManifest',
	#category : 'TimSort-FFI-Manifest',
	#package : 'TimSort-FFI',
	#tag : 'Manifest'
}
