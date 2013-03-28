C' (C prime) - a minimal extension to C
=======================================

C is great and all, but sometimes you just want to have some of the conveniences of C++. However, C++ in its full-fledged form is so complicated as to often be inconvenient. This language represents an attempt at something half-way. Initially, I'll only take only the following from C++:

* Classes with static and instance methods/variables
* Constructors
* Destructors

I will probably follow this up with generics, operator overloading, public/private variables, inheritance and a few others.

Basic Syntax: C' classes
========================

Let's have a look at some C' syntax and its equivalent in C. For the time being, there are no "classes," only structs. This is partly to attempt to add as few keywords as possible.

```
struct Foo {
	@vars {
		int i;
		static int j = 1;
	}
	@functions {
		int Bar(int k) {
			return i + k;
		}
		static void Foozaliza() {
			for (int i=0; i < j; ++i) {
				printf("Aaaaaaaaaaaawww yah\n");
			}
		}
	}
}

int main() {
	Foo f;
	f.i = 4;
	f.Bar(3);
	Foo.Foozaliza();
	return 0;
}
```

We see here a static variable, static method, instance variable and instance method. The keywords @vars and @functions are admittedly ugly: they're there to make parsing easier, but I may remove them. Anyway, the conversion to C is exactly how you would expect:

```c
struct Foo {
	int i;
};

int Foo_Bar(struct Foo *foo, int k) {
	return foo->i + k;
}

static int Foo_j;

static void Foo_Foozaliza() {
	for (int i=0; i < Foo_j; ++i) {
		printf("Aaaaaaaaaaaawww yah\n");
	}
}

int main() {
	struct Foo f;
	f.i = 4;
	Foo_Bar(&f, 3);
	Foo_Foozaliza();
	return 0;
}
```

Note that the C-versions of instance methods will always take a pointer to the `struct`, so when we have a stack-allocated object we'll pass in its address.

Constructors and Destructors
============================

Now let's add constructors and destructors into the mix. Once again, this will be fairly straightforward.

```
struct Foo {
	@vars {
		int i;
		int *ptr;
		static int j = 1;
	}

	@functions {
		Foo(int p) {
			i = p;
			ptr = new(int);
			*ptr = 2*p;
		}

		~Foo() {
			delete(ptr);
		}

		int Bar(int k) {
			*ptr = i + k;
			if (*ptr > 12)
				return 4;
			else
				return 1;
		}

		static void Foozaliza() {
			for (int i=0; i < j; ++i) {
				printf("Aaaaaaaaaaaawww yah\n");
			}
		}
	}
}

int main() {
	Foo f(4);
	f.Bar(3);
	Foo.Foozaliza();
	return 0;
}
```

Into C:

```c
struct Foo {
	int i;
	int *ptr;
};

void Foo_init(struct Foo *foo, int p) {
	foo->i = p;
	foo->ptr = (int *)Malloc(sizeof(int));
	*foo->ptr = 2*p;
}

void Foo_delete(Foo *foo) {
	free(foo->ptr);
}

int Foo_Bar(Foo *foo, int k) {
	*foo->ptr = foo->i + k;
	if (*foo->ptr > 12)
		return 4;
	else
		return 1;
}

static int Foo_j;

static void Foo_Foozaliza() {
	for (int i=0; i < Foo_j; ++i) {
		printf("Aaaaaaaaaaaawww yah\n");
	}
}

int main() {
	struct Foo f;
	Foo_init(&f, 4);
	Foo_Bar(&f, 3);
	Foo_Foozaliza();
	Foo_delete(&f);
	return 0;
}
```

Note that `Malloc` is an error-checked version of `malloc` which may also involve a garbage collector at some point. Our compiler will automatically call Foo_destructor before the last return statement if f is stack allocated. Let's see how it's different when f is heap-allocated:

```
int main() {
	Foo *f = new(Foo(4));
	f->Bar(3);
	Foo.Foozaliza();
	delete(f);
	return 0;
}
```

This will compile to:

```
int main() {
	Foo *f;
	f = Malloc(sizeof(Foo));
	Foo_init(f,4);
	Foo_Bar(f, 3);
	Foo_Foozaliza();
	Foo_delete(f);
	free(f);
	return 0;
}
```

As we can see, `delete` has slightly different behavior depending on whether the variable being deleted is a primitive or not (we don't call a destructor for a primitive).

Arrays
======

Let's see how we can implement an array-based int vector type:

```
struct IntVector {
	@vars {
		size_t size;
		size_t maxSize;
		int *array;
	}

	@functions {
		IntVector(unsigned long size) {
			size = 0;
			maxSize = size;
			array = new(int, size);
		}

		~IntVector() {
			delete(array);
		}

		void insert(size_t index, int val) {
			if (index < size)
				array[index] = val;
			else {
				fprintf(stderr, "Error: array index %d out of bounds\n", index);
				exit(1);
			}
		}

		int get(size_t index) {
			if (index < size)
				return array[index];
			else {
				fprintf(stderr, "Error: array index %d out of bounds\n", index);
				exit(1);
			}
		}

		int pop_back() {
			int retval = array[size-1];
			size--;
			if (size <= maxSize/2)
				resize(maxSize/2);
			return retval;
		}

		void push_back(int val) {
			if (size == maxSize)
				resize(maxSize * 2);
			array[size] = val;
			size++;
		}

		void resize(size_t newSize) {
			int *temp = renew(array, newSize);
			if (!temp) {
				fprintf(stderr, "Error: memory allocation failure\n");
				exit(1);
			}
			array = temp;
			maxSize = size;
		}
	}
}
```

```c
struct IntVector {
	size_t size;
	size_t maxSize;
	int *array;
};

void IntVector_init(struct IntVector *s, size_t size) {
	s->size = 0;
	s->maxSize = size;
	s->array = Malloc(sizeof(int) * size);
	if (!s->array) {
		fprintf(stderr, "Error: memory allocation failure\n");
		exit(1);
	}
}

void IntVector_insert(struct IntVector *s, size_t index, int val) {
	if (index < s->size)
		s->array[index] = val;
	else {
		fprintf(stderr, "Error: array index %d out of bounds\n", index);
		exit(1);
	}
}

int IntVector_get(struct IntVector *s, size_t index) {
	if (index < s->size)
		return s->array[index];
	else {
		fprintf(stderr, "Error: array index %d out of bounds\n", index);
		exit(1);
	}
}

int IntVector_pop_back(struct IntVector *s) {
	int retval = s->array[s->size-1];
	s->size--;
	if (s->size <= s->maxSize/2)
		IntVector_resize(s, s->maxSize/2);
	return retval;
}

void IntVector_push_back(struct IntVector *s, int val) {
	if (s->size == s->maxSize)
		IntVector_resize(s, s->maxSize * 2);
	s->array[s->size] = val;
	s->size++;
}

void IntVector_resize(struct IntVector *s, size_t size) {
	int *temp = realloc(s->array, sizeof(int) * size);
	if (!temp) {
		fprintf(stderr, "Error: memory allocation failure\n");
		exit(1);
	}
	s->array = temp;
	s->maxSize = size;
}

void IntVector_delete(struct IntVector *s) {
	free(s->array);
}
```


