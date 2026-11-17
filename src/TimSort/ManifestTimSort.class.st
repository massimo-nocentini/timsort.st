"
TimSort - timsort (https://github.com/massimo-nocentini/timsort.c, the sort of CPython's lists) for Pharo 12 to 15: in the TimSortPlugin of the VM (plugins/TimSortPlugin and docs/TimSort.md of https://github.com/massimo-nocentini/pharo-vm), in the library libTimSortFFI through the FFI (the package TimSort-FFI), or in pure Smalltalk (the package TimSort-Smalltalk).

The API is explicit, on the class side of TimSort, and opt-in: nothing of Pharo's own sort is replaced or changed, and every extension selector begins with timSort.  Four modes: the natural order of numbers or strings (timSort, timSortDescending), numeric buffers by value (the same selectors on a Float64Array, a ByteArray...), by keys computed once (timSortBy:), and by any sortBlock (timSort:), the last one with TimSortSmalltalk on every VM, or, explicitly (TimSort sort:with:backend:), with the C sort suspended at each comparison while the block runs in Smalltalk.
"
Class {
	#name : 'ManifestTimSort',
	#superclass : 'PackageManifest',
	#category : 'TimSort-Manifest',
	#package : 'TimSort',
	#tag : 'Manifest'
}
