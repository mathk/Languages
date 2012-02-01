"
============================================================================
  ParserKit.st -- OMeta like parser implementation

  Copyright (C) 2011 Mathieu Suen <mathieu@nebu.li>

  The parser have the same syntax that the OMeta one. Although the semantic 
  could differ. For the time being to write expression use the 
  PKParseExpression class. See example at the bottom of the file.

  ChangeLogs
    2011/09/21 Beginning of the expression tree
      - Get the expression tree implementation inspire from OMGrammar
 
    2011/10/20 Beginning of the OMeta implementation
      - Adding the PKParserBase PKRules class

 

============================================================================
"

NSString extend [

"	head [
		^self head: 1
	]
	
	head: size [
		TODO fix it with NSMakeRange
		^size > self count 
			  ifTrue: [ self ]
			  ifFalse: [ self substringWithRange: (NSValue rangeWithLocation: 0 length: size)]
	]

	tail [
		^self tailFrom: 1
	]

	tailFrom: position [
		^self substringWithRange: (NSValue rangeWithLocation: position length: (self count - position))
	]"
	
	concat: other [
		^self stringByAppendingString: other
	]

	asInputStream [
		^PKInputStream alloc initWithStream: self
	]

	matchSize [ ^self length ]
	count [ ^self length]
	isEmpty [^self length = 0]
	isNotEmpty [^self length > 0 ]
]

NSObject extend [
	matchSize [ ^1 ]
]


NSObject subclass: PKParseMatch [
	| input range |

	+emptyMatch: input [
        ^self new initWithInput: input length: 0; 
			yourself
	]

	initWithInput: list length: length [
		super init.
		input := list.
		range := (NSValue rangeWithLocation: input position length: length) 
	]

	sequenceWith: match [
		(range location + range length) = match range location
			ifFalse: [| e | 
						e := NSException alloc  initWithName: 'PKParseMatch' reason: 'Can not add the range, it is not contigus' userInfo: nil.  
						ETTranscript show:e callStackSymbols; cr. 
						e raise.].
		range := NSValue rangeWithLocation: range location length: (range length + match  range length).
		ETTranscript show: range.
	]

	tail [ ^input tail ]
	match  [ ^input fromRange: range ]
	isEmpty [ ^range length = 0]
	isSuccess [ ^true ]
	isFailure [ ^false ]
	range [^range]
	description [ 
		^'PKMatchSuccess  ( Recognized: ''', (input fromRange: range), ''')\n' 
	]
]

NSObject subclass: PKParseFail [
	| input failedPosition describ |

	initWithInput: list description: string [
		super init.
		describ := string.
		input := list.
		failedPosition := input position.
		list popPosition
	]
	
	isFailure [ ^true ]
	isSuccess [ ^false ]

	description [ 
		^'PKMatchFailure  ( At: ''',  input fromRange: (NSValue rangeWithLocation: failedPosition length: input length - failedPosition ), ''') ', describ, '\n' 
	]
]


NSObject subclass: PKParseExpression [

	or: exp [
		^PKAlternateExpression alloc initWithExp: self or: exp.
	]

	or: exp1 or: exp2 [
		^(self or: exp1) or: exp2
	]

	or: exp1 or: exp2 or: exp3 [
		^((self or: exp1) or: exp2) or: exp3
	]

	repeat [
		^PKRepetitionExpression alloc initWithExpression: self canBeEmpty: true
	]

	repeatOneLeast [
		^PKRepetitionExpression alloc initWithExpression: self canBeEmpty: false
	]
	
	seq: exp [
		^PKSequenceExpression alloc initWithFirst: self second: exp
	]

	seq: exp1 seq: exp2 [
		^(self seq: exp1) seq: exp2
	]

	seq: exp1 seq: exp2 seq: exp3 [
		^(self seq: exp1 seq: exp2) seq: exp3
	]

	parseInput: sequence [
		^self subclassResponsibility
	]
		
	parseInput: list ifFailed: aBlock [
		| match |
		match := (self parseList: list).
		^match isFailure ifTrue: [aBlock value]
						 ifFalse: [ match ]
	]
	
]

PKParseExpression subclass: PKAlphabeticExpression [
	
	parseInput: list [
		list head isEmpty ifTrue: [^PKParseFail alloc initWithInput: list description: 'Expected alphabetic character'].
		
		^(list head characterAtIndex: 0) isAlphabetic
			ifTrue: [PKParseMatch alloc initWithInput: list length: list head length]
			ifFalse: [PKParseFail alloc initWithInput: list description: 'Expected alphabetic character']
	]

	description [
		^'[a-zA-Z]'
	]
]

PKParseExpression subclass: PKNumericExpression [

	parseInput: list [
		list head isEmpty ifTrue: [^PKParseFail alloc initWithInput: list description: 'Expected digit character'].
		^(list head characterAtIndex: 0) isDigit
			ifTrue: [PKParseMatch alloc initWithInput: list length: list head length]
			ifFalse: [PKParseFail alloc initWithInput: list description: 'Expected digit character']

	]

	description [
		^'[0-9]'
	]
]

"Abstract class for composing expression"
PKParseExpression subclass: PKComposeExpression [
	| exp |

	description [
		^exp description	
	]

	parseInput: list [
	    ^exp parseInput: list	
	]
]

PKComposeExpression subclass: PKNamedExpression [
	| name |
	initWithName: string exp: expression [
		super init.
		exp := expression.
		name := string
	]

	parseInput: list  [
		| match |
		match := list matchRule: name.
		match isNul ifTrue: [
			match := exp parseInput: list.
			list  addMatch: match at: list position named: name.
		].
		^match
	]
]

PKComposeExpression subclass: PKAlphanumericExpression [

	init [
		exp :=  PKAlphabeticExpression new or: PKNumericExpression new
	]
]

PKParseExpression subclass: PKTokenExpression [
	| match |

	initWithPattern: matchPattern [
		super init.
		match := matchPattern
	]
	
	parseInput: list [
		| return |
		((list head: match matchSize) isEqual: match) ifTrue: [ 
			return := PKParseMatch alloc initWithInput: list
								length: match matchSize.
		] ifFalse: [
			return := PKParseFail alloc initWithInput: list description: 'Unexpected token'
		].
		^return
	]

	description [
		^ match description
	]
]

PKParseExpression subclass: PKEmptyExpression [
	| +instance |

	+initialize [
        instance := self new.
	]

	+uniqueInstance [
        ^instance
	]

	parseInput: list [
		^list atEnd
            ifTrue: [PKParseMatch alloc initWithInput: list length: 0]
			ifFalse: [PKParseFail alloc initWithInput: list description:  'Expected an empty string'] 
	]

	description [
		^ '$ '
	]
]

PKParseExpression subclass: PKSequenceExpression [
 	| e1 e2 |

	initWithFirst: exp1 second: exp2 [
		e1 := exp1.
		e2 := exp2
	] 

	parseInput: list [
		| match1 |
		match1 := e1 parseInput: list.
		^match1 isSuccess ifTrue: [
			| match2 |
			match2 := (e2 parseInput: match1 tail).
			match2 isSuccess 
                ifTrue: [ match1 sequenceWith: match2 ]
				ifFalse: [ match2 ]
		] ifFalse: [ match1 ]
	]

	description [
		^e1 description, e2 description
	]
]

PKParseExpression subclass: PKAlternateExpression [
     | first second |

	initWithExp: exp1 or: exp2 [
		first := exp1.
		second := exp2
	]

	 parseInput: list [
		 ^first parseInput: list ifFailed: [
			 | match |
			 match := second parseInput: list.
			 ETTranscript show: match; cr.
			 match isFailure 
                 ifTrue:[ PKParseFail alloc initWithTail: list description: 'Expected ', self description]
				 ifFalse: [match]
		 ]		
	 ]

	description [
		^'(', first description, ' or ', second description, ')'
	]
]

PKParseExpression subclass: PKRepetitionExpression [
	| e canBeEmpty |

	initWithExpression: exp canBeEmpty: aBool [
		super init.
		e := exp.
		canBeEmpty := aBool
	]
	
	parseInput: list [
		| match currentMatch |
		match := PKParseMatch emptyMatch: list.
		[
			currentMatch := (e parseInput: (match tail)).
			currentMatch isSuccess
		] whileTrue: [match sequenceWith: currentMatch].
		^(match isEmpty and: canBeEmpty not) 
            ifTrue: [PKParseFail new initWithTail: list description: 'Unexpected token, expected ...']
			ifFalse: [match]
	]

	description [
		^e description , (canBeEmpty ifTrue: ['*'] ifFalse: ['+'])
	]
]

"--- Ecursive Extend ---"
NSString extend [
	asExp [
		^PKTokenExpression new initWithPattern: self
	]
]

NSObject subclass: PKInputStream [
    | memo stream position positionStack positionStack |

    initWithStream: input [
        stream := input.
        memo := NSMutableDictionary new.
		positionStack := NSMutableArray new.
		position := 0
	]

    addMatch: parserMatch at: position named: aString [
		| matchList |
		(memo objectForKey: position)
			isNil ifTrue: [memo setValue: NSMutableDictionary new forKey: position].
		matchList := memo objectForKey: position.
		matchList setValue: parserMatch forKey: aString
	]

	matchRule: string [
		^self matchAt: position rule: string
	]

	matchAt: position rule: aString [
		| matchList |
		matchList := memo objectForKey: position.
		^matchList isNil 
            ifTrue: [nil]
			ifFalse: [matchList objectForKey: aString]
	]

	pushPosition: anInt [
		position := anInt .
		positionStack addObject: anInt
	]

	popPosition [
		position := positionStack removeLastObject
	]

    stream [
        ^stream tailFrom: position
	]

	fromRange: range [
		^stream substringWithRange: range
	]

	head [
		^self head: 1
	]
	
	head: size [
		^stream  substringWithRange: (NSValue rangeWithLocation: position length: size)
	]

	tail [
		self tailFrom: 1
	]

	tailFrom: pos [
		self pushPosition: (stream length min: (position + pos)).
	]

	position [
		^position
	]

	length [
		^stream length	
	]

	atEnd [
		^self position = stream length
	]
]

NSOBject subclass: PKRules [
	| parent rules name |

	initWithName: string [
		super init.
		name := string.
		parent := nil.
		rules := NSMutableDictionary new.
	 	
	]

	addRule: name expression: exp [
		| rule |
		rule := PKNamedExpression alloc initWithName: name exp: exp.
		rules setValue: rule forKey: name
	]

	lookup: rule ifFaild: aBlock [
		| return |
		return := rules objectForKey: rule.
		return == nil ifTrue:[
			return := parent.
			return == nil
                ifTrue: aBlock
				ifFalse: [	
					return := parent lookup: rule ifFaild: aBlock
				]
		].
		^return	
	]
		
	initWithParent: pkRules name: string [
		self initWithName: string.
		parent := pkRules
	]
		
	subgrammar: string [
		^self class alloc initWithParent: self
	]
]


NSObject subclass: PKParserBase [
	| input +rulesRepo rules  |

	+derivate: parent subgrammar: name [
		| rule |
		rule := rulesRepo objectForKey: parent.
		rule == nil ifTrue: [
			^ETTranscript show: 'Can not found parent grammar ''', parent, ''''; cr
		].
		rules setValue: (rule subgrammar: name) forKey: name
	]

	+getGrammar: name [
		^rulesRepo objectForKey: name
	]
	

    initWithGrammar: name [
		rules := self class getGrammar: name.
	]
	
	apply: rule [
		| exp return |
		return := input objectForKey: rule.
		return == nil ifTrue: [
"			input setValue: PKParseFail alloc initWithTail forKey: rule."
			exp := rules lookup: rule ifNotFound: [
				ETTranscript show: 'Invalid rule'
			].
		    return := exp parseInput: input.
			input setValue: return forKey: rule.
		].
		^return
	]
	
	match: inputStream rule: rule [
		input := PKInputStream alloc initWithStream: inputStream.
		self apply: rule
	]
   
]

NSObject subclass: SmalltalkTool [
	
	run [
		| dict parser abStar abStar b c tExp alphaNumeric |

	"	ETTranscript show: (dict objectForKey: 'foo' ); cr.
		ETTranscript show: (dict objectForKey: 5 ); cr."
		abStar := PKRepetitionExpression alloc
					 initWithExpression: 'ab' asExp
					 canBeEmpty: false; yourself.

		parser := abStar or: 'a' asExp.

		parser := ('c' asExp repeat) seq: parser seq: PKEmptyExpression uniqueInstance.

	"	alphaNumeric  := PKAlphanumericExpression new repeat."

	"	ETTranscript show: 'This is a test\n'.
		ETTranscript show: true; cr.
		ETTranscript show: NSObject alloc; cr."
		ETTranscript show: ( 'f' substringWithRange: (NSValue rangeWithLocation: 1 length: 0)); cr.
		ETTranscript show:  (NSValue rangeWithLocation: 1 length: 0) rangeValue location; cr.
		ETTranscript show: (parser parseInput: 'ccccccccabaab' asInputStream); cr.
		"ETTranscript show: alphaNumeric; cr.
		ETTranscript show: (alphaNumeric parseInput: 'Good34'); cr.
		ETTranscript show: parser;cr.
		ETTranscript show: (parser parseInput: 'c'); cr."

		"ETTranscript show: (C sqrt: 4)."
	    "ETTranscript show: (C NSMakeRange: {0 . 1})"
	]
]