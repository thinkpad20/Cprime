import std.stdio, std.string, std.conv, std.algorithm, cprimeTokenizer, symbolTable;

bool showReports = true;
int next, indentation, ifStatementCount, whileCount, numClassVars, typeNum = 100;
Token[] tokens;
string[] outputLines;
string[] outputC;
SymbolTableStack sts;
string className;
innerType currentIType;
string[] varTypes;
string[string] pointerCasts;
outerType[string] outerTypeDict;
Entry currentEntry;

bool printPush = false;
bool printPop = false;
bool printAdd = false;
bool printStack = false;
bool printVM = true;
bool printIfCount = true;

string constructorTemplate;

outerType[] types;

string[][] lambdaFunctions;

void init() {

}

/* Code generation */
void writeStruct(ref string output, cPrimeClass cls) {
	string statics;
	output ~= "struct " ~ cls.name ~ "{\n";
	foreach(var; cls.vars) {
		if (!var.isStatic) {
			output ~= "    " ~ var.type.cName ~ " " ~ var.name ~ ";\n";
		} else {
			statics ~= var.type.cName ~ " " ~ cls.name ~ "_" ~ var.name ~ ";\n";
		}
	}
	output ~= "};\n";
	output ~= statics;
}

/* /code generation */

void report(string location = "") {
	if (showReports) {
		if (next < tokens.length)
			writefln("%s next = %s, tokens[next] = %s", location, next, tokens[next]);
		else
			writefln("%s next = %s, end of file", location, next);
	}
}

Token demand(string type) {
	Token ret = nextNonWS();
	if (type != ret.type)
		throw new Exception(format("Error: expected type %s", type));
	next++;
	return ret;
}

Token demandOneOf(string[] typeList) {
	Token ret = tokens[next++];
	if (!canFind(typeList, ret.type))
		throw new Exception(format("Error: expected one of types %s", typeList));
	return ret;	
}

///* <FORMATTING FUNCTIONS> */
string indent(string str) {
	string res;
	for (int i=0; i<indentation; ++i)
		res ~= "  ";
	return res ~ str;
}

void writeIndented(string str) {
	outputLines ~= indent(str);
	write(indent(str));
}

void writeCLine(string str) {
	outputC ~= str ~ "\n";
}

void writeCInLine(string str) {
	outputC ~= str;
}

Token writeXML(Token t) {
	writeIndented(t.getXML());
	//writeln(t.getXML());
	return t;
}

///* </FORMATTING FUNCTIONS */

///* <CHECKING FUNCTIONS> */
bool isTerminal(Token t, string type) {
	return t.type == type;
}

bool isTypeName(Token t) {
	return sts.lookupType(t.symbol) !is null;
}

bool isNonPrimitiveTypeName(Token t) {
	cPrimeType cpt = sts.lookupType(t.symbol);
	return cpt !is null && cpt.isPrimitive == false;
}

void compileFunctionHeader() {
	sts.push(); // new symbol table
	if (isFCType(tokens[next])) // check if return type is an f(C) type
		writeCInLine(processType(true) ~ " ");
	else
		writeCInLine(demandOneOf(varTypes).symbol ~ " "); // otherwise write down the original C
	writeCInLine(demand("identifier").symbol); //next is the function name, leave it as-is
	writeCInLine(demand("(").symbol);
	while (!isTerminal(tokens[next], ")")) {
		if (isFCType(tokens[next])) {
			string type = processType(); // scan the arguments list for f(C) types
			writeCInLine(type ~ " "); // the C-version only gets the outer type name
		} else
			writeCInLine(tokens[next++].symbol ~" "); // otherwise just write it down
	}
	writeCInLine(demand(")").symbol);
}

void compileFunctionBody() {
	sts.pop();
}
/*
static const struct Foo;
*/
Token nextNonWS() {
	while(tokens[next].type == "whitespace")
		next++;
	return tokens[next];
}

void takeCContainer() {
	// This function will process a C-style struct. It serves two functions:
	// 1. To add a new symbol to the symbol table; e.g. the introduction of
	//    a new variable
	// 2. To define a struct/union which is internal to another struct/union
	// The function returns an Entry, which is an object used both for the
	// symbol table, to keep track of the current namespace, and also by
	// other structs, which use Entries to keep lists of their fields.

	// We don't allow nested C' structures, so the internal structs must be C.
	// however, the internal structs may contain C' variables in them.
	// we don't allow anonymous structs, so we must have at least two things:
	// Case 1:
	// objType {...} objName; EX: struct {int i;} fooStruct;
	//OR Case 2:
	// objType objTypeName {...} objName; EX: struct fooStruct { int i; } foo;
	//OR Case 3:
	// objType objTypeName objName; EX: struct fooStruct foo;
	//OR Case 4:
	// a block-specific struct definition with no variable declaration:
	// objType objTypeName {...}; EX: struct Baxter {double d;};
	// these are our four possibilities.

	//disallow anonymous structs:
	//if (varDec[$-1].symbol == "}") 
	//	throw new Exception("Anonymous structs are not allowed in C'");
	Entry newCContainer = new Entry(); // this might not be used, if no variable is declared.
	string objType; //struct, union or enum
	string objTypeName; // name of the struct
	string objName; // name of the variable

	objType = demandOneOf(["struct", "union", "enum"]).symbol;
	if (isTerminal(tokens[next], "identifier")) { // then we're in case 2, 3 or 4
		if (objType != "enum") {
			objTypeName = demand("identifier").symbol;
			next++;
			cPrimeType cpt = sts.lookupType(objType ~ " " ~ objTypeName);
			if (cpt !is null) { // then this type exists, so we have case 3
				newCContainer.type = cpt;
				// then the next token had better be an identifier
				objName = demand("identifier").symbol;
				newCContainer.name = objName;
				sts.addSymbol(objName, cpt);
				return newCContainer;
			}
		} else {
			throw new Exception("Enums must be defined explicitly.");
		}
	}
	// if we've made it this far, we're in case 1, 2 or 4, which means we have
	// another struct/enum/union definition! yay.
	// we're going to recurse on this, but first we want to set it up.
	cPType t; // holds the type of the struct/union/enum about to be defined
	switch (objType) {
		case "struct":
			t = cPType.C_STRUCT;
			break;
		case "enum":
			t = cPType.C_ENUM;
			break;
		case "union":
			t = cPType.C_UNION;
			break;
		default:
	}
	if (objTypeName != "") objType ~= " " ~ objTypeName;
	newCContainer.type = new cPrimeType(objType, t, true); // true -> explicitly defined
	demand("{")
		int braceCount = 1;
		while (true) {
			string s = nextNonWS().symbol;
			if (s == "}") {
				braceCount--; 
				if (braceCount == 0) break;
			}
			switch (t) {
				case C_STRUCT:
				case C_UNION:
					if (s == "{") {braceCount++;}
					newCContainer.type.addVariable(getVariable());
					next++;
					break;
				case C_ENUM:
					if (isTerminal(nextNonWS(), "identifier")) {
						string enumOptName = demand("identifier").symbol;
						if (isTerminal(nextNonWS(), "=")) {
							next++;
							int val = demand("numberConstant").ival;
							newCContainer.type.addEnumOpt(enumOptName, val, true);
							demand(",");
						} else {
							newCContainer.type.addEnumOpt(enumOptName, 0, false);
							if (isTerminal(nextNonWS(),","))
								next++;
						}
					}
					else
						throw new Exception("Improper enum specification.");

			}
		}
	return newCContainer;
}

Entry getCEnum() {
	Entry newEnum = new Entry(); // this might not be returned, if no variable is declared
	string enumTypeName;
	string enumName; // name of the variable
	cPrimeType cpt;
	demand("enum");

	if (!isTerminal(nextNonWS(), "identifier")) { // then we have an anonymous enum
		cpt = getEnumOpts();
	} else { // a named enum.
		enumTypeName = demand("identifier").symbol;
		cpt = sts.lookupType("enum " ~ enumTypeName);
		if (cpt !is null) { // then this type exists
			newEnum.type = cpt;
			// so the next token had better be an identifier
			newEnum.name = demand("identifier").symbol; // assign this enum type to this variable
			sts.addSymbol(newEnum.name, cpt); // and add it to the symbol table
			return newEnum;
		} else { // then we're defining this enum right now
			cpt = getEnumOpts();
		}
	}
	// if we're still here, we've defined an enum. Now we could have a variable or not.
	if (isTerminal(nextNonWS(), "identifier")) { // then we do.
		newEnum.name = demand("identifier").symbol;
		sts.addSymbol(newEnum.name, cpt);
		return newEnum;
	} else { // then we don't.
		if (!isTerminal(nextNonWS(), ";"))
			throw new Exception("Missing semicolon after enum " ~ newEnum.name);
		return null; // don't return a variable... since there wasn't any
	}
}

cPrimeType getEnumOpts() {
	cPrimeType cpt = new cPrimeType(enumTypeName, cPType.C_ENUM, true);
	demand("{");
	while (nextNonWS().symbol != "}") {
		if (isTerminal(nextNonWS(), "identifier")) {
			string enumOptName = demand("identifier").symbol;
			if (isTerminal(nextNonWS(), "=")) {
				next++;
				int val = demand("numberConstant").ival;
				cpt.addEnumOpt(enumOptName, val, true);
			} else {
				cpt.addEnumOpt(enumOptName, 0, false);
			}
			if (isTerminal(nextNonWS(),","))
				next++;
		}
		else
			throw new Exception("Improper enum specification.");
	}
	demand("}");
	return cpt;
}

Entry getVariable() {
	Entry newEntry = new Entry;
	string s = tokens[next].symbol;
	while (true) {
		switch (s) {
			case "const":
			case "extern":
			case "signed":
			case "unsigned":
			case "long":
			case "short":
			case "volatile":
				newEntry.modifiers ~= tokens[next++].symbol;
				break;
			case "struct":
			case "enum":
			case "union":
				if (newEntry.type is null)
					newEntry.merge(takeCContainer());
				else
					throw new Exception("Entry has already been assigned a type.");
				break;
			case "*":
				newEntry.pointerCount++;
				break;
			case "[":
				string sym = tokens[++next].type;
				if (sym == "]")
					newEntry.pointerCount++; // just treat it like a pointer...
				else {
					while (sym != "]") {
						newEntry.arrayText ~= sym;
						sym = tokens[++next];
					}
					demand("]");
				}
				break;
			case ";": // then we're done grabbing a variable.
				next++;
				newEntry.check();
				writeln("Created new entry " ~ newEntry);
				return newEntry;
			default: // at this point what we're looking at could be an identifier or some
					 // user-specified symbol (object or type).
				if (isTypeName(token[next])) {
					newEntry.type = sts.lookupType(s);
					next++;
				}
				else if (isTerminal(tokens[next], "identifier")) {
					string varName = demand(identifier).symbol;
					if (newEntry.name == "")
						newEntry.name = varName;
					else
						throw new Exception("The object " ~ newEntry.name ~ " has already been named.");
				} 
				else if (isTerminal(tokens[next], "whitespace")) // can be ignored
					break;
				else {
					throw new Exception("Symbol '"~ s ~ "' encountered. Is this ok?");
				}
		}
	}
}

void compileVars() {
	demand("{");
	int braceCount = 1;
	while (braceCount > 0) {
		// get next variable, load it into varDec
		Token[] varDec;
		Entry var;
		while (true) {
			if (tokens[next].symbol == ";" && braceCount == 1)
				break;
			if (tokens[next].symbol == "{") {braceCount++;}
			if (tokens[next].symbol == "}") {braceCount--;}
			if (tokens[next].type != "whitespace")
				varDec ~= tokens[next];
			next++;
		}
		// varDec is a list of strings that identify a type
		for(int i=0; i<varDec.length; ++i) {
			if (varDec[i].symbol == "static")
				var.isStatic = true;
			else if (varDec[i].symbol == "struct" || varDec[i].symbol == "enum" 
				        || varDec[i].symbol == "union") {
				takeCObject(varDec, i, var);
			} else 


		}
		if (tokens[next].type == "identifier" && !)
	}
}

/* <HIGHEST-LEVEL STRUCTURES> */
void compileStruct() {
	demand("struct");
	string structName = demand("identifier");
	newclass = sts.addType(structName);
	demand("{");
	while (!isTerminal(tokens[next], "}")) {
		if (tokens[next].symbol == )
		if (isTypeName(tokens[next])) {
			//get the full name of the type
			//check for pointer symbols
			int pointerCount = 0;

			while (true) {
				if (tokens[next])
				pointerCount++;
				next++;
			}

			cPrimeType t = sts.lookupType(tokens[next++].symbol);
			if (t.equals(newclass) && pointerCount == 0) {
				throw new Exception("Classes cannot be defined in terms of themselves");
			}
		}
	}
	demand("}");
}

void compileStrucInfo() {
	if ()
	string dataInfo = demand("identifier").symbol; // get datatype name
	outerType t = new outerType(dataInfo, typeNum++);
	if (isTerminal(tokens[next], "!")) { // if parameterized
		t.isParametric = true;
		demand("!");
		string typ = demandOneOf(varTypes).symbol; //this will only be auto for now
		if (typ != "auto")
			throw new Exception("Parametric types must be declared with auto.");
	}
	if (!skip) {
		types ~= t;
		outerTypeDict[dataInfo] = t; // add it to the type dictionary
		varTypes ~= dataInfo; // add it to the type list
	}
}

void compileConstructorDec(bool skip = false) {
	//if (!skip) writeIndented("<constructorDec>\r\n");
	innerType newInner;
	string iType = demand("identifier").symbol; // name of the constructor
	if (!skip) newInner = types[$-1].addInnerType(iType, typeNum++);
	// get the parameters
	demand("(");
	compileParameters(newInner, skip);
	demand(")");
	demand(";"); // sadly, semicolons are probably necessary for now
}

/* </HIGHEST-LEVEL STRUCTURES> */

void reset() {
	ifStatementCount = whileCount = 0;
	outputLines = [];
	outputC = [];
	next = 0;
	numClassVars = 0;
}

void writeDeclarations() {
	writeCLine("#include \"c/datatype.h\"\n");
	foreach(type; types) {
		writeCLine(format("#define %s_T %s", type.type, type.num));
		foreach(iType; type.innerTypes) {
			writeCLine(format("#define %s_%s_T %s", type.type, iType.type, iType.num));
		}
		writeCLine("\n");
		writeCLine(format("typedef struct datatype %s;\n", type.type));
		foreach(iType; type.innerTypes) {
			writeStruct(type, iType);
		}
	}

	foreach(type; types) {
		foreach(iType; type.innerTypes)
			writeConstructor(type, iType);
	}
}

void compileDataDecs() {
	int save = next;
	int dataDecCount = 0;
	while (next < tokens.length) {
		if (isTerminal(tokens[next], "@data")) {
			compileData();
			dataDecCount++;
		}
		else
			next++;
	}
	writeDeclarations();
	next = save;
	//writefln("Found and compiled %s datatypes", dataDecCount);
}

void compileFunctions() {
	int save = next;
	int funcCount;
	while (next < tokens.length) {
		if (isTerminal(tokens[next], "@data"))
			compileData(true); //skip over it
		else if (isType(tokens[next])) {
			compileFunctionHeader();
			compileFunctionBody();
			funcCount++;
		}
		else
			next++;
	}
	next = save;
}

void main(string[] args) {
	init();
	Tokenizer t;
	t.init();
	for (int i=1; i<args.length; ++i) {
		string filenameRoot = args[i].split(".")[$-2];
		t.prepare(args[i]);
		t.lex();
		tokens = t.getTokens();
		reset();
		compileDataDecs();
		compileFunctions();
		auto outputFile = File(filenameRoot ~ ".c", "w");
		//foreach(type; types) {
		//	write(type);
		//}
		foreach(ln; outputC) {
			outputFile.write(ln);
		}
		//foreach(line; outputVM)
		//	outputFile.writeln(line);
		outputFile.close();
	}
}