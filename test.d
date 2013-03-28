import std.stdio, std.string, std.algorithm;

// we want to find a newline character that has not been preceeded by a slash.

bool terminatedMacro(string str) {
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

void main() {
	//writeln(matchPartialPrepDirective("#define ALBATROSS 20\\"));
	//writeln(matchPartialPrepDirective("#define SWAP(a, b)  {                   \\ \n
 //                       a ^= b;         \\ \n
 //                       b ^= a;         \\ \n 
 //                       a ^= b;         \\ \n
 //                   }\n"));
	//writeln(terminatedMacro("#define ALBATROSS 20\n"));
	//writeln(terminatedMacro("#define SWAP(a, b)  {                   \\ \n
 //                       a ^= b;         \\ \n
 //                       b ^= a;         \\ \n 
 //                       a ^= b;         \\ \n
 //                   }\n"));
	string[] foo = ["hello", "mcfly"];
	writeln(canFind(foo, "hello"));
	writeln(canFind(foo, "hel"));
}