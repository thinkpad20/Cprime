#include <stdio.h>
#include <stdlib.h>

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