#import <Foundation/Foundation.h>
#import <LanguageKit/LanguageKit.h>
@interface PKParser: NSObject
{
	id input;
	id rules;
	id delegate;
}

+ (BOOL)supportsGrammar: (NSString*)grammarName;

+ (NSArray*)loadGrammarsFromBundle: (NSBundle*)bundle;

+ (NSArray*)loadGrammarsFromString: (NSString*)string;

- (id)initWithGrammar: (NSString*)grammarName;

- (void)setDelegate: (id)delegate;

- (id)match: (id)inputStream rule: (NSString*)ruleName;

- (id)getEmptyMatch: (id) list;
@end

@interface PKInputStream : NSObject
{
	id memo;
	id stream;
	id position;
	id positionStack;
	id environmentStack;
}
- (id) position;
- (unsigned long long) length;
- (id) stream;
- (id) lastPosition;
- (id) initWithStream: (id) input;
@end

@interface PKParseFail: NSObject
{
}
- (id) isSuccess;
@end

@interface PKParseMatch : NSObject
{
	id input;
	id range;
	id action;
	id delegate;
}
+ (id) emptyMatch: (id)string;
- (id) sequenceWith: (id) match;
- (id) initWithInput: (id) list length: (id) length;
- (id) isSuccess;
- (id) isFailure;
- (id) isEmpty;
- (id) matchText;
@end

@interface PKParserAbstractGenerator : NSObject
{
	id delegate;
	id specialCharToChar;
}
@end


@interface PKParserASTGenerator : PKParserAbstractGenerator
{
	id externalParsers;
	id inputStreamDeclaration;
	id tempDecl;
	id methodStatements;
	id currentTempsCount;
}
 
- (id)genTemp;
@end

@interface PKEnvironmentStack : NSObject
@end

@interface PKDelayInvocation : NSObject
{
	id selector;
	id args;
	id original;
}
+ (id )invocationWithSelector: (id)aSelector arguments: (id)someArgs originalMatch: (id)match;
- (id) initWithSelector: (id)aSelector arguments: (id)someArgs originalMatch: (id)match;
- (id) reduceOn: (id)target;
- (id) canReduce;
@end

@interface PKParseExpression : NSObject
{
}
- (id) parseInput: (id)list withCurrentParser: (id)parser delegate: (id)delegate ifFailed: (id)aBlock;
- (id) parseInput: (id)list withCurrentParser: (id)parser ifFailed: (id)aBlock;
- (id) parseInput: (id)list withCurrentParser: (id)parser delegate: (id)delegate;
- (id) parseInput: (id)list withCurrentParser: (id)parser;
- (id) parseInput: (id)list;
@end

@interface PKDotExpression : PKParseExpression
@end

@interface PKAlphabeticExpression : PKParseExpression
@end

@interface PKEmptyExpression : PKParseExpression
@end

@interface PKAnythingExpression : PKParseExpression
@end

@interface PKUppercaseExpression : PKParseExpression
@end

@interface PKWhitespaceExpression : PKParseExpression
@end

@interface PKRangeExpression : PKParseExpression
{
}
- (id) initFrom: (id)fromChar to: (id)toChar;
@end

@interface PKNumericExpression : PKParseExpression
@end

@interface PKLowercaseExpression : PKParseExpression
@end
