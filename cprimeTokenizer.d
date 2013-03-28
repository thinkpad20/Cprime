module cprimeTokenizer;
import std.stdio, std.string, std.conv, std.algorithm;

enum TokenCat {
	KW, SYM, NUMCONST, STRCONST, IDENT, WS, CHARCONST, PARTIALCHAR,
	NONE, PARTIALSTRING, COMMENT, PARTIALCOMMENT, PREPDIRECTIVE,
	PARTIALPREPDIRECTIVE
}

struct Token {
	string symbol;
	TokenCat category;
	string type;
	int ival;
	real rval;
	string str;
	static string[TokenCat] descriptions;
	this(string sym, TokenCat cat) { // Token struct initializer
		descriptions = [TokenCat.KW:"keyword", TokenCat.IDENT:"identifier", 
				TokenCat.SYM:"symbol", TokenCat.CHARCONST:"charConstant",
				TokenCat.NUMCONST:"numberConstant", TokenCat.STRCONST:"stringConstant",
				TokenCat.PREPDIRECTIVE:"preprocessorDirective", TokenCat.WS:"whiteSpace"];
		symbol = sym;
		category = cat;
		if (cat == TokenCat.NUMCONST) {
			if (canFind(sym, "."))
				rval = to!real(sym);
			else
				ival = to!int(sym);
			type = "numberConstant";
		} else if (cat == TokenCat.STRCONST) {
			str = sym[1..$-1];
			type = "stringConstant";
		} else if (cat == TokenCat.IDENT) {
			type = "identifier";
		} else if (cat == TokenCat.WS) {
			type = "whitespace";
		} else {
			type = symbol;
		}
	}

	string getXML() {
		if (category == TokenCat.STRCONST)
			return format("<%s> %s </%s>\r\n", descriptions[category], str, descriptions[category]);
		if (category == TokenCat.NUMCONST)
			return format("<%s> %s </%s>\r\n", descriptions[category], symbol, descriptions[category]);
		if (symbol == "<")
			return format("<%s> &lt; </%s>\r\n", descriptions[category], descriptions[category]);
		if (symbol == ">")
			return format("<%s> &gt; </%s>\r\n", descriptions[category], descriptions[category]);
		if (symbol == "&")
			return format("<%s> &amp; </%s>\r\n", descriptions[category], descriptions[category]);
		return format("<%s> %s </%s>\r\n", descriptions[category], symbol, descriptions[category]);
	}

	string toString() {
		return symbol ~ " (" ~ type ~ ")";
	}
}

struct Tokenizer {
	int[string] keywords, symbols, prepDirectives;
	int[char] identFirstChar, identOtherChars, numbers;
	int lineNumber, indentAmount;
	string preparedCode;
	Token[] tokens;

	void init() {
		string[] keywordList = ["static", "int", "char", "bool", "void", "true", "false", 
								"if", "else", "while", "for", "switch", "return", "auto", "break", 
								"case", "const", "continue", "default", "do", "double", "enum", "extern", 
								"float", "goto", "long", "register", "short", "signed", "sizeof", "struct",
								"switch", "typedef", "union", "unsigned", "volatile",
								"new", "renew", "delete", "@vars", "@functions"];
		foreach (kw; keywordList) { keywords[kw] = 0; }

		string[] symbolList = ["...", ">>=", "<<=", "+=", "-=", "*=", "/=", "%=", "&=", "^=",
								"|=", ">>", "<<", "++", "--", "->", "&&", "||", "<=", ">=", "==", "!=", ";",
								"{","<%", "}","%>", ",", ":", "=", "(", ")","[","<:", "]",":>",
								".", "&", "!", "~", "-", "+", "*", "/", "%", "<", ">", "^", "|", "?",];
		foreach (sym; symbolList) { symbols[sym] = 0; }

		string[] prepDirectiveList = ["#define", "#error", "#import", "#undef", "#elif", "#if", "#include",
									  "#using", "#else", "#ifdef", "#line", "#endif", "#ifndef", "#pragma"];
		foreach (sym; prepDirectiveList) { prepDirectives[sym] = 0; }
		
		string lowerCase = "abcdefghijklmnopqrstuvwxyz@_";
		string upperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		string digits = "0123456789";
		foreach (ch; lowerCase ~ upperCase)
			identFirstChar[ch] = 0;
		foreach (ch; lowerCase ~ upperCase ~ digits)
			identOtherChars[ch] = 0;
		foreach (ch; digits)
			numbers[ch] = 0;
	}

	bool matchPrepDirective(string str) {
		if (str[0] != '#')
			return false;
		if (str[$-1] != '\n')
			return false;
		long slashIndex = lastIndexOf(str, "\\");
		long newLineIndex = lastIndexOf(str, "\n");
		if (slashIndex == -1 && newLineIndex >= 0) // then we have a \n and no \\
			return true;
		// otherwise, we need to see if we have a continuing macro
		while (slashIndex < newLineIndex) {
			slashIndex++;
			if (slashIndex == newLineIndex) break;
			char c = str[slashIndex];
			if (c != ' ' && c != '\t') // then it's not a continuation
				return true;
		}
		return false;
	}
	bool matchPartialPrepDirective(string str) {
		if (str[0] != '#') return false;
		long slashIndex = lastIndexOf(str, "\\");
		long newLineIndex = lastIndexOf(str, "\n");
		if (slashIndex == -1 && newLineIndex >= 0) // then we have a \n and no \\
			return false;
		// otherwise, we need to see if we have a continuing macro
		while (slashIndex < newLineIndex) {
			slashIndex++;
			if (slashIndex == newLineIndex) break;
			char c = str[slashIndex];
			if (c != ' ' && c != '\t') // then it's not a continuation
				return false;
		}
		return true;
	}

	bool matchIdent(string str) {
		if (!str) return false;
		if (!(str[0] in identFirstChar)) { return false; }
		for (int i=1; i<str.length; ++i)
			if (!(str[i] in identOtherChars)) { return false; }
		return true;
	}

	bool matchNum(string str) {
		if (!str) return false;
		int i=0;
		bool sawPoint = false;
		if (str[0] == '-') {
			if (str.length < 2) return false;
			i = 1;
		}
		for (i=i; i<str.length; ++i) {
			if (!(str[i] in numbers)) {
				if (str[i] == '.') {
					if (sawPoint)
						return false;
					else
						sawPoint = true;
				}
				else
					return false;
			}
		}
		return true;
	}

	bool matchPartialCharConstant(string str) {
		//writeln("testing if _", str, "_ is a partial char constant");
		return (str.length < 4 && str[0] == '\'' && str[$-1] != '\'');
	}
	bool matchCharConstant(string str) {
		//writeln("testing if _", str, "_ is a char constant");
		return ((str.length == 3 || (str.length == 4 && str[1] == '\\')) && str[0] == '\'' && str[$-1] == '\'');
	}

	bool matchWhiteSpace(string str) {
		foreach(ch; str)
			if (ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t')
				return false;
		return true;
	}


	TokenCat bestMatch(string token) {
		if (matchPrepDirective(token))
			return TokenCat.PREPDIRECTIVE;
		else if (matchPartialPrepDirective(token))
			return TokenCat.PARTIALPREPDIRECTIVE;
		else if (token in keywords)
			return TokenCat.KW;
		else if (token in symbols)
			return TokenCat.SYM;
		else if (matchNum(token))
			return TokenCat.NUMCONST;
		else if (token[0] == '"' && token[$-1] == '"')
			return TokenCat.STRCONST;
		else if (token[0] == '"' && !canFind(token[1..$-1], '"'))
			return TokenCat.PARTIALSTRING; // this will never be a terminal type
		else if (matchIdent(token))
			return TokenCat.IDENT;
		else if (matchCharConstant(token))
			return TokenCat.CHARCONST;
		else if (matchPartialCharConstant(token))
			return TokenCat.PARTIALCHAR;
		else if (token.length >= 4 && token[0..2] == "/*" && token[$-2..$] == "*/")
			return TokenCat.COMMENT;
		else if (token.length >= 2 && token[0..2] == "/*" && token.split("*/")[0] == token)
			return TokenCat.PARTIALCOMMENT;
		else if (matchWhiteSpace(token))
			return TokenCat.WS;
		else
			return TokenCat.NONE;
	}

	void lex() {
		lex(preparedCode);
	}

	void lex(string line) {
		//write("Tokenizer lexing...");
		tokens = [];
		int cursor; // keeps track of our position in the line
		//writeln("Input:\r\n", line);
		string current = "", prev = "";
		TokenCat bestCat = TokenCat.NONE;
		for (cursor = 0; cursor < line.length; ++cursor) {
			//writeln("current: ", current, " adding char ", line[cursor]);
			char c = line[cursor];
			current ~= c; // append next character onto our working token
			if (bestMatch(current) == TokenCat.NONE) { // then we've encountered an illegal expression
				if (prev == "") // this would mean we started off with something illegal
					throw new Exception(format("Error: illegal input on line %s: %s", lineNumber, current));
				if (matchPartialCharConstant(prev))
					throw new Exception(format("Error line %s: char input %s is malformed 
						 					   (only one character is allowed between two '')", lineNumber, prev));
				if (bestCat != TokenCat.COMMENT) { // skip comments (keep whitespace)
					Token newToken = Token(prev, bestCat);
					tokens ~= newToken;
				}
				current = to!string(c); // start new partial token with just c
				prev = "";
			}
			bestCat = bestMatch(current);
			prev = current;
		}
		// we'll have one character left over, so process it:
		bestCat = bestMatch(current);
		if (bestCat != TokenCat.WS && bestCat != TokenCat.NONE)
			if (bestCat == TokenCat.PARTIALSTRING)
				throw new Exception("Error: unbounded string constant.");
			else if (bestCat == TokenCat.PARTIALCOMMENT)
				throw new Exception("Error: unbounded comment.");
			else if (bestCat == TokenCat.PARTIALPREPDIRECTIVE)
				tokens ~= Token(prev, TokenCat.PREPDIRECTIVE);
			else
				tokens ~= Token(prev, bestCat);
		//writeln("done lexing");
	}

	void prepare(string filename) {
		string noComments;
		auto file = File(filename, "r");
		foreach (line; file.byLine) {
			string[] lines = to!string(line).split("//");
			if (lines.length > 0) {
				string strippedLine = to!string(line).split("//")[0];
				if (strippedLine != "")
					noComments ~= strippedLine ~ "\r\n";
			}
		}
		preparedCode = noComments;
		file.close();
	}

	void writeTokens(string filename) {
		auto file = File(filename, "w");
		file.write("<tokens>\r\n");
		foreach (token; tokens) {
			file.write(token.getXML());
		}
		file.writeln("</tokens>\r\n");
		file.close();
	}

	void prepareLexWrite(string inputFilename, string outputFilename) {
		prepare(inputFilename);
		lex();
		writeTokens(outputFilename);
	}

	Token[] getTokens() {
		//writeln("Tokens: ", tokens);
		return tokens;
	}
}

void main(string args[]) {
	if (args.length < 3) {
		writefln("usage: %s <c input file)> <xml output file>", args[0]);
		return;
	}
	Tokenizer t;
	t.init();
	t.prepareLexWrite(args[1], args[2]);
}