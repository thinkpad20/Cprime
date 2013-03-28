module symbolTable;
import std.stdio, std.string, std.algorithm, std.conv, std.container, cprimeTokenizer;

bool toPrint = false;

// given a symbol, returns the appropriate vm code and type
class SymbolTable {
	Entry[string] table;
	void set(string symbol, cPrimeType cpt) {
		Entry ste = new Entry(symbol, cpt);
		table[symbol] = ste;
	}
	void set(string symbol, cPrimeType cpt, string pType) {
		Entry ste = new Entry(symbol, cpt, pType);
		table[symbol] = ste;
	}

	void set(string symbol, Entry ste) {
		table[symbol] = ste;
	}

	Entry get(string symbol) {
		if (!(symbol in table))
			return null;
		return table[symbol];
	}
	bool contains(string symbol) {
		if (symbol in table) return true;
		return false;
	}
	string toStr() {
		string ret = "";
		foreach(symbol; table.keys) {
			ret ~= table[symbol].toStr();
			ret ~= "\n";
		}
		return ret;
	}
}

struct SymbolTableStack {
	SymbolTableStackNode first;

	void push() {
		if (toPrint) writeln("*******************\nPushing a new SymbolTable\n*******************");
		SymbolTable st = new SymbolTable();
		push(st);
	}

	SymbolTable pop() {
		if (toPrint) writeln("*******************\nPopping a new SymbolTable\n*******************");
		SymbolTable toReturn = first.table;
		first = first.next;
		return toReturn;
	}
	string toString() {
		string res = "********Printing symbol table********\n";
		auto current = first;
		while (current !is null) {
			res ~= current.toStr() ~ "\n";
			current = current.next;
		}
		return res ~ "******** finished printing ********\n";
	}
	SymbolTableStackNode top() {
		return first;
	}
	Entry lookup(string symbol) {
		auto current = first;
		while (current !is null) {
			if (current.table.contains(symbol))
				return current.table.get(symbol);
			current = current.next;
		}
		return null;
	}
	void addSymbol(string symbol, cPrimeType cpt, string pType) {
		if (toPrint) writefln("adding %s: %s (auto = %s) to table", symbol, cpt.typeStr(), pType);
		top().table.set(symbol, cpt, pType);
	}

	void addSymbol(string symbol, cPrimeType cpt) {
		if (toPrint) writefln("adding %s: %s to table", symbol, cpt.typeStr());
		top().table.set(symbol, cpt);
	}

	cPrimeType lookupType(string name) {
		auto current = first;
		while (current !is null) {
			if (current.lookupType(name) !is null)
				return current.lookupType(name);
			current = current.next;
		}
		return null;
	}

	cPrimeType lookupTypeAddIfNotFound(string name) {
		auto current = first;
		while (current !is null) {
			if (current.lookupTypeAddIfNotFound(name) !is null)
				return current.lookupTypeAddIfNotFound(name);
			current = current.next;
		}
		return null;
	}

	cPrimeType addType (string name) {
		return first.addType(name);
	}
}

class SymbolTableStackNode {
	SymbolTable table;
	SymbolTableStackNode next = null;
	cPrimeType[string] typeList;

	this(SymbolTable table) {
		this.table = table;
		foreach (varType; ["long", "short", "signed", "unsigned", "int", "char",
				"void", "bool", "float", "double", "identifier", "auto"]) {
			typeList[varType] = new cPrimeType(varType, cPType.C_SIMPLE, false);
		}
	}
	string toStr() {
		return table.toStr();
	}

	cPrimeType lookupType(string name) {
		if (name in typeList)
			return typeList[name];
		return null;
	}

	cPrimeType lookupTypeAddIfNotFound(string name) {
		if (name in typeList)
			return typeList[name];
		return addType(name);
	}

	cPrimeType addType (string name) {
		cPrimeType newType = new cPrimeType(name);
		if (!(name in typeList)) {
			typeList[name] = newType;
			return newType;
		}
		throw new Exception(name ~ " has already been defined.");
	}
}

struct cPrimeFunction {
	bool isMethod;
	string declaration;
	string body;
}

class Entry {
	bool isStatic, isArray;
	cPrimeType type = null;
	string name;
	int pointerCount, arrayCount;
	string arrayText; // can be a number or an expression... we don't care
	string[] modifiers;
	this(string name, cPrimeType cpt) {
		this.name = name;
		this.type = cpt;
	}
	this(string symbol, cPrimeType cpt, string pType) {
		this(symbol, cpt);
	}
	string toStr() {
		return symbol ~ ": type " ~ cpt.typeStr();
	}
	void merge(Entry other) {
		foreach(mod; other.modifiers) {
			if (!canFind(modifiers, mod))
				modifiers ~= mod;
		}
		this.type = other.type;
		this.arrayCount = other.arrayCount;
	}
	void check() {
		//here the entry checks if its type is null, and if so, it ensures that it
		// has been given either long, long long, or short, so that it can make its
		// type int.
		string validMods;
		foreach(mod; modifiers) {
			if (mod == "long" || mod == "short") {
				validMods ~= mod ~ " ";
			}
		}
		if (type is null) {
			if (validMods != "")
				type = new cPrimeType("int", cPType.C_SIMPLE, false);
			else
				throw new Exception("Variable " ~ name ~ " has not been assigned a type.");
		}

		// it also ensures that it is not a void type with no pointer... that would be bad
		if (type.name == "void")
			if (pointerCount == 0)
				throw new Exception("The void type must be a pointer.");
	}
}

enum cPType {C_SIMPLE, C_STRUCT, C_ENUM, C_UNION, CP_STRUCT};

struct enumOpt {
	string name;
	bool hasVal = false;
	int val;
	this(string name, int val, bool hasVal = false) {
		this.name = name;
		this.hasVal = hasVal;
		if (hasVal)
			this.val = val;
	}
}

class cPrimeType {
	string name;
	cPType t;
	bool isC, isExplicit;
	Entry[] vars;
	enumOpt[] enumOpts;
	cPrimeFunction[] funcs;
	string cName;
	void addVariable(Entry var) {
		vars ~= var;
	}
	void addEnumOpt(string name, int val = 0, bool hasVal) {
		enumOpts ~= enumOpt(name, val, hasVal);
	}
	string getCName() {
		if (!isExplicit)
			return cName;
		else {
			string cn = cName ~ " {\n";
			if (t == cPType.C_ENUM) {
				bool first = true;
				foreach(eopt; enumOpts) {
					if (first) {
						cn ~= "    " ~ eopt.cName;
						first = false;
					}
					cn ~= ",\n    " ~ eopt.cName;
				}
				cn ~= "\n}";
			} else {
				foreach (var; vars) {
					cn ~= "    " ~ var.type.getCName() ~ " " ~ var.name ~ ";\n";
				}
				cn ~= "}";
			}
			return cn;
		}
	}
	/*

	isExplicit refers to an explicitly-defined struct/union/enum. For example:

	struct { 
		int i;
		int j;
	} jimbob;

	here "jimbob" is of type "struct { int i; int j; }". In other words, the struct
	is explicitly defined rather than refered to by name, as in:

	struct Foo jimbob;

	Now jimbob is of type "struct Foo". Finally, we could write:

	struct Foo {
		int i;
		int j;
	} jimbob;

	This has no real meaning though; it's the same as the first example, so an
	explicit struct.
	*/
	this(string name, cPType t, isExplicit = false) {
		this.name = name;
		switch (t) {
			case C_SIMPLE:
				isC = true;
				this.cName = name;
				break;
			case C_STRUCT:
				isC = true;
				this.cName = "struct " ~ name;
				break;
			case C_ENUM:
				isC = true;
				this.cName = "enum " ~ name;
				break;
			case C_UNION:
				isC = true;
				this.cName = "union " ~ name;
				break;
			default:
				isC = false;
		}
		this.t = t;
	}
	void setCName (string name) {
		cName = name;
	}
	bool equals(cPrimeType other) {
		return name == other.name;
	}
}