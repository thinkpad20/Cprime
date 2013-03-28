#include <stdio.h>

struct Foo {
	struct {
		int i;
		int j;
	} fooStruct;
};

struct Bar {
	struct Foo fizz;
};

enum wazzup { HEY, HO } hi = HO;
int yo = HEY;
enum wazzup hididily = HEY;

int main() {
	struct Foo foo;
	struct Bar bar;
	struct Baz {
		int i; int j;
	};
	struct Baz bb;
	bb.i = 3;
	foo.fooStruct.i = 1;
	bar.fizz.fooStruct.i = 1;
	printf("%d\n", bar.fizz.fooStruct.i);
	return 0;
}