Extension { #name : #SequenceableCollection }

{ #category : #'*timsort' }
SequenceableCollection >> timsort [

	^ self timsort: [ :a :b | a < b ]
]

{ #category : #'*timsort' }
SequenceableCollection >> timsort: sortBlock [

	| liblua |
	liblua := LibLua uniqueInstance.

	^ liblua withOpenedLibsStateDo: [ :state | 
		  liblua luaL_requiref: state name: 'timsort'.

		  liblua
			  on: state push: #timsort;
			  lua_getfield: state
			  at: -1
			  name: 'sort'
			  remove: true.

		  liblua
			  on: state push: self;
			  on: state push: false.

		  liblua assert: [ 
			  | v |
			  [ v := liblua lua_pcall: state nargs: 2 nresults: 2 ] timeToRun
				  inspect.
			  v ].

		  liblua on: state at: -2
		  " on: state push: #array;" ]
]

{ #category : #'*timsort' }
SequenceableCollection >> timsortraw: sortBlock [

	| liblua intExternalAddress array guilty |
	liblua := LibLua uniqueInstance.

	intExternalAddress := Int32WeightedExternalAddress allocate:
		                      self size.

	liblua withOpenedLibsStateDo: [ :state | 
		"liblua assert: [ :ll | 
			ll luaL_dostring: state chunk: 'timsort = require ""timsort""' ]."

		liblua luaL_requiref: state name: 'timsort'.

		liblua
			on: state push: #timsort;
			lua_getfield: state
			at: -1
			name: 'sortraw'
			remove: true.

		liblua assert: [ 
			liblua
				lua_pcall: state
				valueWithArguments: { 
						intExternalAddress.
						self size.
						false.
						[ :s | 
						| i j isLessThan |
						i := liblua on: s at: -2.
						j := liblua on: s at: -1.
						isLessThan := sortBlock value: (self at: i) value: (self at: j).
						liblua on: s push: isLessThan.
						1 ] }
				lets: #( perm ) ].

		guilty := liblua
			          on: state push: #perm;
			          on: state at: -1 ].

	self assert: guilty isNotNil.

	array := self class new: self size.
	1 to: self size do: [ :i | 
		| j |
		j := intExternalAddress at: i.
		array at: i put: (self at: j) ].

	intExternalAddress free.

	^ array
]
