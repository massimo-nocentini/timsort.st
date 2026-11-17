# timsort.st

Timsort for Pharo 12 to 15: the stable, adaptive sort of CPython's lists, from [timsort.c](https://github.com/massimo-nocentini/timsort.c) (a port of CPython's `listsort`), for Arrays, OrderedCollections, numeric buffers and any SequenceableCollection, in place.

The sorting is done, in order of preference:
- by the TimSortPlugin of the VM of [massimo-nocentini/pharo-vm](https://github.com/massimo-nocentini/pharo-vm) (`plugins/TimSortPlugin`, whose `docs/TimSort.md` is the contract), built into the native VMs and the WebAssembly VMs of that fork;
- by the library `libTimSortFFI` of the same VM, through the FFI (the package `TimSort-FFI`), on a native VM without the plugin;
- in pure Smalltalk, by `TimSortSmalltalk` (the package `TimSort-Smalltalk`), a faithful port of timsort.c: the same comparisons, in the same order, and the same result.

The sorts by any sortBlock (mode d below) are the exception: the port runs them by default on every VM, because it was measured faster than the resumable C sort in every case. The resumable C sort of the plugin or the library is still there, explicitly.

All of them answer the same results. For the natural order and for any sortBlock in the style of `[ :a :b | a <= b ]`, that result is exactly Pharo's own `sort` or `sort:`: both sorts are stable, and a stable sort of a consistent order has one result only. Only the time differs.

The API is explicit and opt-in. It is on the class side of `TimSort` and in extension methods whose selectors all begin with `timSort`. Nothing of Pharo's own sort is replaced or changed.

This repository is the submodule `plugins/TimSortPlugin/timsort.st` of that VM. Its commit is the version of the Smalltalk code that goes with the plugin.

## Requirements

- Pharo 12, 13, 14 or 15, 64-bit.
- For speed, a VM with the TimSortPlugin, or `libTimSortFFI` and the package `TimSort-FFI`. Without either, everything works in pure Smalltalk, at about the speed of Pharo's own sort (see Performance).

## Loading

```smalltalk
Metacello new
	baseline: 'TimSort';
	repository: 'github://massimo-nocentini/timsort.st:master/src';
	load: #( 'Core' )
```

| Group | Packages |
|---|---|
| `Core` | `TimSort` (the facade, the backends, the extension methods) and `TimSort-Smalltalk` (the port) |
| `Tests` | `TimSort-Tests` |
| `FFI` | `TimSort-FFI`: `libTimSortFFI` through the FFI, for a native VM without the plugin |
| `FFITests` | `TimSort-FFI-Tests` |
| `Smalltalk` | `TimSort-Smalltalk` alone: the port, without the facade (`TimSortSmalltalk sort: anArray`) |
| `SmalltalkTests` | `TimSort-Smalltalk-Tests`: the port against traces of the C library |
| `default` | all of them |

From a checkout of the VM, `plugins/TimSortPlugin/tests/load-timsort.st` loads the submodule, and `plugins/TimSortPlugin/tests/run-st-tests.sh` runs the tests.

## API

There are four modes. Each sorts in place and answers the receiver, and each has a copying form, `timSorted…`, as `sorted:` is the copying form of `sort:`.

**(a) The natural order.** An Array of numbers, or an Array of strings, is sorted by the plugin in C, without running any Smalltalk. Any other Array (Characters, Fractions, `nil`, mixed families…) and any other collection is sorted by Pharo's sortBlock `[ :a :b | a <= b ]`, run by the port.

```smalltalk
#( 3 1 2 ) copy timSort.                         "#(1 2 3), as sort"
#( 3 1 2 ) copy timSortDescending.               "#(3 2 1), as sort: [ :a :b | a >= b ]"
#( 'b' #a 'c' ) timSorted.                       "a sorted copy"
TimSort sort: anArray from: 10 to: 20 descending: false.
```

**(b) Numeric buffers**, by value: Float64Array, Float32Array, DoubleWordArray, IntegerArray (signed), WordArray, Bitmap, DoubleByteArray and ByteArray. They are sorted in place, in C, element by element, so the bits are kept.

```smalltalk
(Float64Array withAll: { 3.0. Float nan. -1.0 }) timSort.   "-1.0 3.0 NaN"
TimSort sortBuffer: aByteArray from: 1 to: 100 descending: true.
```

**(c) By keys computed once.** `keyBlock` is evaluated once per element, in order. The plugin then sorts a permutation by the keys (an argsort), and the permutation is applied to the elements. The result is that of `sort: [ :a :b | (keyBlock value: a) <= (keyBlock value: b) ]`, with n evaluations of the block instead of 2 n log n.

```smalltalk
words timSortBy: [ :each | each size ].
people timSortDescendingBy: [ :each | each age ].
TimSort argSort: #( 30 10 20 ).                  "#(2 3 1): the permutation that sorts the keys"
TimSort argSortDescending: aFloat64Array.
```

**(d) Any sortBlock.** The result is exactly `sort: aBlock` for a sortBlock in the style of `[ :a :b | a <= b ]`.

```smalltalk
people timSort: [ :a :b | a name <= b name ].
TimSort sort: anOrderedCollection with: [ :a :b | a priority >= b priority ].
TimSort sort: people with: [ :a :b | a name <= b name ] backend: #plugin.    "the resumable C sort"
TimSort sort: anArray from: 2 to: 9 with: [ :a :b | a >= b ] backend: #ffi.
```

How a sortBlock is run:
- By default (`timSort:`, `timSorted:`, `TimSort sort:with:`), on every VM, by the port `TimSortSmalltalk`. A comparison there is one evaluation of the block, as in Pharo's own `sort:`.
- Explicitly, `TimSort sort: aCollection with: aBlock backend: #plugin` (or `#ffi`, and the `from:to:` form) runs the resumable C sort of the plugin (or of the library): timsort runs on a C stack of its own, a coroutine. At every comparison it stops and hands the two indices to Smalltalk, and the block is evaluated in the calling Process, which then resumes the sort. It is the same algorithm with the same result, but each comparison costs a primitive call and two stack switches (or a callout), so it was slower than the port in every case measured (see Performance). `backend: #smalltalk` is the default.
- A backend that has no resumable sort here signals `TimSortBackendUnavailable` before anything is touched: `#plugin` without the plugin or on WebAssembly, `#ffi` without `TimSort-FFI` or its library, and any other name. `TimSort resumableBackends` answers the ones that work.

There are no FFI callbacks anywhere.

## Semantics

- **Order and stability.**
  - Ascending is exactly Pharo's `sort`. Descending is Pharo's `sort: [ :a :b | a >= b ]`: equal elements keep their order in both directions.
  - Timsort is adaptive. Sorted, reversed and nearly sorted inputs take about one comparison per element. Random input takes about as many comparisons as Pharo's merge sort.
- **Numbers** (mode a, and the keys of mode c) are compared exactly, as Pharo's image code compares them, by every backend.
  - The plugin handles SmallInteger, Float (immediate or boxed) and normalized LargePositiveInteger and LargeNegativeInteger.
  - An Integer and a Float are compared without rounding, as `Number>>adaptToFloat:andCompare:` does. The native JIT compares a SmallInteger beyond 2^53 with a Float after rounding the SmallInteger, so in that zone TimSort's order is the exact one, and Pharo's `sort` may differ. The port uses an exact sortBlock for the ranges that mix Floats with such SmallIntegers, so it answers the plugin's order there too.
  - -0.0, 0.0 and 0 are equal.
  - NaN, Fractions, ScaledDecimals and other numbers are declined by the plugin, and Pharo's comparisons decide, run by the port.
- **Strings** are compared by code point.
  - Only instances of exactly ByteString, ByteSymbol, WideString and WideSymbol (`TimSort stringClasses`) are sorted by the plugin.
  - The comparison is case-sensitive, with no collation, and a prefix comes first. This is what Pharo's `<` does for these classes.
  - A subclass of String, or a mix of strings with anything else, is left to Pharo's comparisons. Strings mixed with numbers raise Pharo's error.
- **Numeric buffers**
  - They are sorted by value, signed or unsigned as the class says.
  - For floats, every NaN comes after every number, whatever its sign or payload, and the NaNs are equal to each other. -0.0 equals 0.0.
  - Descending is the same order reversed, stably, so the NaNs come first.
  - The same order in Pharo is `sort: [ :a :b | b isNaN or: [ a <= b ] ]`, and descending `sort: [ :a :b | a isNaN or: [ b isNaN not and: [ a >= b ] ] ]`.
- **Inconsistent orders** have no single stable result: NaN among objects, a strict block (`a < b`), a block that contradicts itself. For them every backend gives timsort's result, and the C sort and the port give the same one, since they are the same algorithm with the same comparisons. That result is sorted where the order allows, but it is not necessarily Pharo's merge sort's.
  - With a strict block, ties come out in an order of their own.
- **Errors in a sortBlock** go to the caller, as in Pharo, and the block runs in the caller's Process.
  - This covers errors, non-local returns and `Process>>terminate`, also by another Process at any moment. Resumable exceptions such as Warnings, when resumed, let the sort continue.
  - The debugger's Restart of the frame that evaluates the block evaluates it again on the comparison the sort waits for.
  - A non-Boolean answer raises Pharo's `NonBooleanReceiver`.
  - When the resumable C sort runs (`backend: #plugin` or `#ffi`), the collection is untouched until the sort ends, since only indices are sorted. In the port, the default, it holds a permutation of its elements.
  - The resumable sort is freed on every exit. A Process saved in the middle of a sort finishes it in the port after the image is started again.
- **Read-only receivers** signal `ModificationForbidden` before anything is touched, on every backend and in every mode.
  - This is stricter than Pharo, which sorts a read-only Float32Array, Float64Array or OrderedCollection anyway.
  - The exception has the retry of Pharo's write barrier: a handler that makes the object writable and sends `retryModification` lets the sort go on. When the object is still read-only after the handler, nothing is sorted. An empty read-only Array has nothing to change and signals nothing.
- **Collections**
  - Array and its subclasses.
  - OrderedCollection: the slots `firstIndex` to `lastIndex` of its internal Array, in place.
  - SortedCollection: the sort sets the sortBlock, as `sort:` does, so that elements added later go to their place. `timSort` sets it to nil, `timSort: aBlock` to aBlock, `timSortBy: keyBlock` to the matching `<=` block.
  - Interval and Symbol cannot be changed. `timSort…` does what `sort…` does (Pharo's error), and `timSorted…` answers what `sorted…` answers.
  - Strings, Texts and any other SequenceableCollection with `at:put:` are sorted through `at:` and `at:put:`.
- **Ranges** (`from:to:`) are 1-based and inclusive. An empty range is `start = stop + 1`. Anything else out of bounds signals `SubscriptOutOfBounds`. Fewer than two elements are never compared.

## Backends

```smalltalk
TimSort backend.               "#plugin, #ffi or #smalltalk: modes a, b and c"
TimSort blockSortBackend.      "#smalltalk: mode d by default, on every VM"
TimSort resumableBackends.     "#(#plugin #ffi), those whose resumable C sort works here: for sort:with:backend:"
TimSort resumableBackend.      "the first of them, or nil"
TimSort coroutinesAvailable.   "whether there is one"
TimSort pluginInfo.            "#(1 'TimSortPlugin 1.0' 'timsort.c fd70381' 'native' true 0), or nil"
TimSort resetBackend.          "choose again (done by itself at each new session)"
```

- The choice is made once per session: the plugin, else the library, else the port.
- Mode d runs in the port by default, whatever the choice. The resumable C sort is there when it is named (`sort:with:backend:`):
  - on WebAssembly there is no stack switching, so neither `#plugin` nor `#ffi` has one;
  - on a native process with a shadow stack (x86-64 CET, AArch64 GCS) neither the plugin nor the library can switch.
- A backend declines what it does not sort natively, and the port then sorts that call: the plugin declines anything but numbers or strings, the library anything but SmallIntegers and Floats.
- Tests can force a backend with `TimSort testHook: #backend value: TimSortPortBackend`, `#pluginMissing` or `#fallbackMissing`.

## Performance

The plugin and the port (`TimSort testHook: #backend value: TimSortPortBackend`) against Pharo's own `sort` and `sort:`. For mode d, the plugin column is the resumable C sort (`backend: #plugin`) and the port column is the default of `timSort:` (`[ :a :b | a <= b ]`, or `[ :a :b | a key <= b key ]` for mode c), on Pharo 12 (Pharo 15 within a few per cent), with the native CoInterpreter (Cog JIT) VM on one core of a Xeon Gold 6238R.
- Random data are uniform: SmallIntegers in [1, n], Floats in [0, 1000), the decimal strings of integers in [1, 10 n], and Associations with SmallInteger keys in [1, n].
- Each time is the median, in ms, of the sort of a fresh copy (3 runs at 1e6, up to 21 at 1e3).
- The "x" columns are Pharo's time divided by TimSort's: above 1, TimSort is faster. The port's Float64Array rows come from a second run, after an optimisation, with their own Pharo times.

| Input | n | Pharo `sort` | plugin | x | Smalltalk port | x |
|---|---:|---:|---:|---:|---:|---:|
| mode a: SmallIntegers, random | 1e3 | 0.235 | 0.078 | 3.0 | 0.367 | 0.64 |
| mode a: SmallIntegers, sorted | 1e3 | 0.137 | 0.004 | 34 | 0.023 | 6.0 |
| mode a: SmallIntegers, random | 1e4 | 3.08 | 0.988 | 3.1 | 4.57 | 0.67 |
| mode a: SmallIntegers, sorted | 1e4 | 1.68 | 0.031 | 54 | 0.219 | 7.7 |
| mode a: SmallIntegers, random | 1e5 | 38.7 | 12.1 | 3.2 | 56.9 | 0.68 |
| mode a: SmallIntegers, sorted | 1e5 | 20.1 | 0.324 | 62 | 2.16 | 9.3 |
| mode a: SmallIntegers, random | 1e6 | 556 | 145 | 3.8 | 761 | 0.73 |
| mode a: SmallIntegers, sorted | 1e6 | 340 | 3.53 | 96 | 21.8 | 16 |
| mode a: Floats, random | 1e3 | 0.260 | 0.124 | 2.1 | 0.380 | 0.68 |
| mode a: Floats, sorted | 1e3 | 0.143 | 0.011 | 13 | 0.024 | 6.0 |
| mode a: Floats, random | 1e4 | 3.36 | 1.56 | 2.2 | 4.87 | 0.69 |
| mode a: Floats, sorted | 1e4 | 1.81 | 0.103 | 18 | 0.228 | 8.0 |
| mode a: Floats, random | 1e5 | 41.7 | 19.5 | 2.1 | 60.2 | 0.69 |
| mode a: Floats, sorted | 1e5 | 21.4 | 1.07 | 20 | 2.27 | 9.4 |
| mode a: Floats, random | 1e6 | 586 | 232 | 2.5 | 811 | 0.72 |
| mode a: Floats, sorted | 1e6 | 357 | 10.7 | 33 | 22.6 | 16 |
| mode a: Strings, random | 1e3 | 0.402 | 0.250 | 1.6 | 0.516 | 0.78 |
| mode a: Strings, sorted | 1e3 | 0.225 | 0.036 | 6.2 | 0.042 | 5.4 |
| mode a: Strings, random | 1e4 | 5.40 | 3.25 | 1.7 | 6.75 | 0.80 |
| mode a: Strings, sorted | 1e4 | 2.95 | 0.352 | 8.4 | 0.423 | 7.0 |
| mode a: Strings, random | 1e5 | 70.7 | 42.2 | 1.7 | 88.6 | 0.80 |
| mode a: Strings, sorted | 1e5 | 35.2 | 3.65 | 9.7 | 4.27 | 8.3 |
| mode a: Strings, random | 1e6 | 1090 | 559 | 1.9 | 1281 | 0.85 |
| mode a: Strings, sorted | 1e6 | 583 | 55.1 | 11 | 63.9 | 9.1 |
| mode b: Float64Array, random | 1e3 | 0.406 | 0.102 | 4.0 | 0.428 | 0.90 |
| mode b: Float64Array, sorted | 1e3 | 0.348 | 0.014 | 25 | 0.062 | 5.1 |
| mode b: Float64Array, random | 1e4 | 5.41 | 1.23 | 4.4 | 5.38 | 0.91 |
| mode b: Float64Array, sorted | 1e4 | 4.39 | 0.035 | 126 | 0.635 | 6.5 |
| mode b: Float64Array, random | 1e5 | 64.4 | 14.4 | 4.5 | 65.9 | 0.92 |
| mode b: Float64Array, sorted | 1e5 | 50.2 | 0.267 | 188 | 6.31 | 7.8 |
| mode b: Float64Array, random | 1e6 | 828 | 171 | 4.8 | 785 | 0.96 |
| mode b: Float64Array, sorted | 1e6 | 660 | 2.44 | 270 | 121 | 5.3 |
| mode c: timSortBy:, random | 1e3 | 0.254 | 0.145 | 1.8 | 0.488 | 0.52 |
| mode c: timSortBy:, sorted | 1e3 | 0.147 | 0.060 | 2.4 | 0.087 | 1.7 |
| mode c: timSortBy:, random | 1e4 | 3.33 | 1.67 | 2.0 | 5.80 | 0.57 |
| mode c: timSortBy:, sorted | 1e4 | 1.81 | 0.545 | 3.3 | 0.868 | 2.1 |
| mode c: timSortBy:, random | 1e5 | 46.0 | 21.8 | 2.1 | 73.8 | 0.62 |
| mode c: timSortBy:, sorted | 1e5 | 22.8 | 5.69 | 4.0 | 8.69 | 2.6 |
| mode c: timSortBy:, random | 1e6 | 647 | 402 | 1.6 | 1201 | 0.54 |
| mode c: timSortBy:, sorted | 1e6 | 403 | 271 | 1.5 | 301 | 1.3 |
| mode d: timSort: aBlock, random | 1e3 | 0.238 | 1.00 | 0.24 | 0.376 | 0.63 |
| mode d: timSort: aBlock, sorted | 1e3 | 0.134 | 0.149 | 0.90 | 0.033 | 4.1 |
| mode d: timSort: aBlock, random | 1e4 | 3.14 | 14.2 | 0.22 | 4.71 | 0.67 |
| mode d: timSort: aBlock, sorted | 1e4 | 1.69 | 1.45 | 1.2 | 0.231 | 7.3 |
| mode d: timSort: aBlock, random | 1e5 | 38.8 | 181 | 0.21 | 58.4 | 0.67 |
| mode d: timSort: aBlock, sorted | 1e5 | 20.0 | 14.0 | 1.4 | 2.25 | 8.9 |
| mode d: timSort: aBlock, random | 1e6 | 454 | 2161 | 0.21 | 754 | 0.60 |
| mode d: timSort: aBlock, sorted | 1e6 | 313 | 138 | 2.3 | 21.3 | 15 |

What the table shows:
- **Arrays of numbers or strings, and buffers (modes a and b).**
  - On random data the plugin is faster than Pharo by 1.6 to 2 times for strings, 2 to 2.5 times for Floats, 3 to 4 times for SmallIntegers (compared as raw tagged words) and 4 to 5 times for Float64Arrays. Floats and strings cost a few calls into the VM per comparison.
  - On sorted data it is 6 to 270 times faster, since timsort makes n - 1 comparisons there.
- **Keys (mode c)** are 1.5 to 4 times faster than Pharo's `sort:` with the keys computed in the block. The keys and the permutation are handled in Smalltalk, and the comparisons in C.
- **Any sortBlock (mode d)** runs in the port by default, because of these rows. The port makes the same comparisons as the resumable C sort, and costs one block evaluation per comparison. The resumable C sort adds a primitive call and two stack switches to each comparison, about 0.12 µs.
  - With the port, mode d is 1.5 to 1.7 times slower than Pharo's `sort:` on random data with a cheap block, as Pharo's merge sort makes about as many comparisons with less work around them, and 4 to 15 times faster on sorted data.
  - The resumable C sort is 4 to 5 times slower than Pharo's `sort:` on random data, and 2.7 to 6.5 times slower than the port in these rows. The VM's benchmark (`docs/TimSort.md`) has it slower than the port in every case, also through the library, which is slower still.
  - Prefer the natural order or `timSortBy:` whenever they can express the order: their comparisons run in C.
- **The pure-Smalltalk port** makes as many comparisons as Pharo's merge sort on random data, and is 1.05 to 1.9 times slower. On sorted data it is 1.3 to 15 times faster.

`plugins/TimSortPlugin/bench` of the VM has the benchmark scripts. `docs/TimSort.md` has the WebAssembly numbers, where the plugin is 11 to 69 times faster than Pharo's sort in the interpreter on random data of modes a and b (8 times for keys), and up to 1946 times on sorted data.

## Limitations

- **The resumable C sort is native only.** WebAssembly has no stack switching without ASYNCIFY or JSPI, so `backend: #plugin` signals `TimSortBackendUnavailable` there. `timSort: aBlock` runs the port everywhere anyway.
- **A native sort cannot be interrupted.**
  - A sort in the plugin is a single primitive call: the VM, its UI and other Processes, and a web page on WebAssembly, wait until it ends. For example, 1e6 Floats take 0.24 s natively and 0.33 s on WebAssembly.
  - Mode d runs Smalltalk at every comparison, in the port or in the resumable C sort, so it is interruptible.
- **Ties under strict blocks.** A strict sortBlock (`[ :a :b | a < b ]`) is an inconsistent order for a stable sort: the result is sorted, but ties come in an order of their own. Use `<=`.
- **Out of memory.** If the C sort runs out of memory, the port finishes the sort from the permutation the C sort left. The result is sorted, but the order of equal, non-identical elements may then differ from Pharo's.
- **Resumable sorts per process.** 64 resumable C sorts can be live at once in each of the plugin and the library: these are nested explicit sorts, sorts inside sortBlocks. Deeper ones run in the port.
- **64-bit only.**

## Licence

MIT, see `LICENSE`, but for the package `TimSort-Smalltalk`.

timsort.c, which the VM plugin and the library compile, is derived from CPython's `Objects/listobject.c` and is under the PSF License Agreement, version 2 (`plugins/TimSortPlugin/LICENSE.timsort` of the VM). `TimSort-Smalltalk` is a translation of timsort.c to Smalltalk, so it is a derivative work of CPython as well, under the same agreement: `LICENSE.timsort` here has its notice (the agreement, PSF's copyright line, and the changes made, those of timsort.c and of the translation).
