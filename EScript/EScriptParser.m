#import <EtoileFoundation/EtoileFoundation.h>
#import <LanguageKit/LKToken.h>
#import <LanguageKit/LKAST.h>
#import <LanguageKit/LKMethod.h>
#import <LanguageKit/LKModule.h>
#import "EScriptParser.h"
#include <ctype.h>
#include "escript.h"

typedef unichar(*CIMP)(id, SEL, unsigned);

NSMapTable *keywords;

@implementation EScriptParser
/* From Lemon: */
void *EScriptParseAlloc(void *(*mallocProc)(size_t));
void EScriptParse(void *yyp, int yymajor, id yyminor, EScriptParser* p);
void EScriptParseFree(void *p, void (*freeProc)(void*));

#define CALL_PARSER(token, arg) EScriptParse(parser, TOKEN_##token, arg, self);// NSLog(@"Parsing %@ (%s)", arg, #token)
#define CHAR(x) charAt(s, charSel, x)
#define WORD_TOKEN substr(LKTokenClass, substrSel, NSMakeRange(i, j-i), s)

#define CASE(start, end, function)\
	if(start(c))\
	{\
		for(j=i ; j<sLength-1 && end(c) ; c=CHAR(++j)) {}\
		function\
		i = MAX(i,j-1);\
	}

#define CHARCASE1(char1, token1)\
	case char1:\
		CALL_PARSER(token1, WORD_TOKEN);\
		break;

#define CHARCASE2(char1, char2, token1, token2)\
	case char1:\
		if (i<sLength-1) if (char2 == CHAR(i + 1))\
		{\
			j++; CALL_PARSER(token2, WORD_TOKEN); i++;\
			break;\
		}\
		CALL_PARSER(token1, WORD_TOKEN);\
		break;

#define CHARCASE3(char1, char2, char3, token1, token2, token3)\
	case char1:\
		if (i<sLength-1) if (char2 == CHAR(i + 1))\
		{\
			if (i<sLength-2) if (char3 == CHAR(i + 2))\
			{\
				j+=2; CALL_PARSER(token3, WORD_TOKEN); i+=2;\
				break;\
			}\
			j++; CALL_PARSER(token2, WORD_TOKEN); i++;\
			break;\
		}\
		CALL_PARSER(token1, WORD_TOKEN);\
		break;

#define CHARCASE4(char1, char2, char3, token1, token2, token3)\
	case char1:\
		if (i<sLength-1)\
		{\
			if (char2 == CHAR(i + 1))\
			{\
				j++; CALL_PARSER(token2, WORD_TOKEN); i++;\
				break;\
			}\
			if (char3 == CHAR(i + 1))\
			{\
				j++; CALL_PARSER(token3, WORD_TOKEN); i++;\
				break;\
			}\
		}\
		CALL_PARSER(token1, WORD_TOKEN);\
		break;

#define SET_KEYWORD(key, token) \
	NSMapInsert(keywords, @#key, (void*)(uintptr_t)TOKEN_ ## token)

+ (void) initialize
{
	keywords = NSCreateMapTable(NSObjectMapKeyCallBacks, NSIntMapValueCallBacks, 2);
	SET_KEYWORD(new, NEW);
	SET_KEYWORD(function, FUNCTION);
	SET_KEYWORD(return, RETURN);
	SET_KEYWORD(break, BREAK);
	SET_KEYWORD(continue, CONTINUE);
	SET_KEYWORD(if, IF);
	SET_KEYWORD(else, ELSE);
	SET_KEYWORD(do, DO);
	SET_KEYWORD(while, WHILE);
	SET_KEYWORD(for, FOR);
	SET_KEYWORD(in, IN);
	SET_KEYWORD(var, VAR);
	SET_KEYWORD(true, TRUE);
	SET_KEYWORD(false, FALSE);
	SET_KEYWORD(null, NULL);
}

- (LKAST*) parse:(NSString*)s
{
	unsigned int sLength = [s length];
	/* Cache some IMPs of methods we call a lot */
	SEL charSel = @selector(characterAtIndex:);
	SEL substrSel = @selector(tokenWithRange:inSource:);
	CIMP charAt = (CIMP)[s methodForSelector:charSel];

	IMP substr = [LKToken methodForSelector:substrSel];
	Class LKTokenClass = [LKToken class];
	/* Set up the parser */
	void * parser = EScriptParseAlloc( malloc );

	// EScriptParseTrace(stderr, "LEMON: ");

	// Volatile to ensure that they are preserved over longjmp calls.  This is
	// going to make things a bit slower, so a better solution might be to move
	// them into ivars.
	volatile int line = 1;
	volatile unsigned int j;
	volatile unsigned int i;
	unsigned lineStart = 0;
	NS_DURING
	for (i=0 ; i<sLength ; i++)
	{
		unichar c = CHAR(i);
		CASE(isalpha, isalnum, 
		{
			NSString * word = WORD_TOKEN;
			int token = (int)NSMapGet(keywords, word);
			if (token == 0)
			{
				token = TOKEN_WORD;
			}
			EScriptParse(parser, token, word, self);
		})
		else if (isspace(c))
		{
			for (j=i ; j<sLength-1 && isspace(c) ; c=CHAR(++j))
		   	{
				if ('\n' == c)
				{
					line++;
					lineStart = j + 1;
				}
			}
			i = MAX(i,j-1);
		}
		else if ('"' == c && i<sLength-1)
		{
			c=CHAR(++i);
			for (j=i ; j<sLength-1 && '"' != c ; c=CHAR(++j))
			{
				if ('\n' == c)
				{
					line++;
					lineStart = j + 1;
				}
			}
			CALL_PARSER(STRING, WORD_TOKEN);
			i = j;
		}
		else if ('\'' == c && i<sLength-1)
		{
			c=CHAR(++i);
			for (j=i ; j<sLength-1 && '\'' != c ; c=CHAR(++j))
			{
				if ('\n' == c)
				{
					line++;
					lineStart = j + 1;
				}
			}
			CALL_PARSER(STRING, WORD_TOKEN);
			i = j;
		}
		else if ('/' == c && i<sLength-1)
		{
			c=CHAR(++i);
			if ('/' == c && i<sLength-1)
			{
				c=CHAR(++i);
				for (j=i ; j<sLength-1 && '\n' != c ; c=CHAR(++j)) {}
				if ('\n' == c)
				{
					line++;
					lineStart = j + 1;
				}
				CALL_PARSER(COMMENT, WORD_TOKEN);
				i = j;
			}
			else if ('*' == c && i<sLength-2)
			{
				unichar h = CHAR(++i);
				j = i;
				do {
					c = h;
					h = CHAR(++j);
					if ('\n' == c)
					{
						line++;
						lineStart = j;
					}
				} while (j<sLength-1 && ('*' != c || '/' != h));
				j--;
				CALL_PARSER(COMMENT, WORD_TOKEN);
				i = j + 1;
			}
			else if ('=' == c)
			{
				j = i + 1;
				i--;
				CALL_PARSER(DIVEQ, WORD_TOKEN);
				i++;
			}
			else
			{
				j = i--;
				CALL_PARSER(DIV, WORD_TOKEN);
			}
		}
		else CASE(isdigit, isdigit, {CALL_PARSER(NUMBER, WORD_TOKEN);})
		else
		{
			j = i + 1;
			switch(c)
			{
				CHARCASE1('@', AT)
				CHARCASE1(',', COMMA)
				CHARCASE1(':', COLON)
				CHARCASE1(';', SEMI)
				CHARCASE1('.', DOT)
				CHARCASE4('+', '+', '=', PLUS,  PLUSPLUS,   PLUSEQ)
				CHARCASE4('-', '-', '=', MINUS, MINUSMINUS, MINUSEQ)
				CHARCASE2('*', '=', MUL, MULEQ)
				CHARCASE2('/', '=', DIV, DIVEQ)
				CHARCASE2('%', '=', MOD, MODEQ)
				CHARCASE3('=', '=', '=', EQ, EQEQ, EQEQEQ)
				CHARCASE1('<', LT)
				CHARCASE1('>', GT)
				CHARCASE1('(', LPAREN)
				CHARCASE1(')', RPAREN)
				CHARCASE1('[', LBRACK)
				CHARCASE1(']', RBRACK)
				CHARCASE1('{', LBRACE)
				CHARCASE1('}', RBRACE)
				default:
					NSLog(@"Weird character '%c' found on line %d", c, line);
			}
		}
	}
	NS_HANDLER
		EScriptParseFree(parser, free);
		NSString * errorLine = [s substringFromIndex:lineStart];
		NSRange lineEnd = [errorLine rangeOfString:@"\n"];
		if (lineEnd.location != NSNotFound)
		{
			errorLine = [errorLine substringToIndex:lineEnd.location];
		}
		j = i - lineStart + 1;
		NSString * format = [NSString stringWithFormat:@"\n%%%dc", j];
		errorLine = [errorLine stringByAppendingFormat:format, '^'];
		NSDictionary *userinfo = D(
		                          [NSNumber numberWithInt:line], @"lineNumber",
		                          [NSNumber numberWithInt:j], @"character",
		                          errorLine, @"line");
		[[NSException exceptionWithName:@"ParseError"
		                         reason:@"Unexpected token"
		                       userInfo:userinfo] raise];
	NS_ENDHANDLER
	EScriptParse(parser, 0, nil, self);
	EScriptParseFree(parser, free);
	return ast;
}

- (LKModule*) parseString:(NSString*)source
{
	LKAST *module = [self parse: source];
	if ([module isKindOfClass:[LKModule class]])
	{
		return (LKModule*)module;
	}
	return nil;
}

- (LKMethod*) parseMethod:(NSString*)source
{
	return nil;
}

- (void) setAST:(LKAST*)anAST
{
	ASSIGN(ast, anAST);
}
@end
