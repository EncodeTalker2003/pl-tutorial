### 1

The answer is in `./1_k/1_lambda/lesson_8/lambda-mu.k`.

### 2

The answer is in `1_k/2_imp/lesson_4/imp-uninit.k`. I use a new `bss` cell in configuration to store uninitialized variables.

### 3

The answer is in `1_k/2_imp/lesson_4/imp-pure.k`.

### 4

The direct definition of `callCC` is in `1_k/3_lambda++/lesson_1/lambda-callCC.k`.

The definition of `callCC` based on `callcc` is in `1_k/3_lambda++/lesson_1/lambda-l2u.k`.

The definition of `callcc` based on `callCC` is in `1_k/3_lambda++/lesson_1/lambda-u2l.k`.

### 5

The answer is in file `1_k/4_imp++/lesson_7/imp-abort.k`. For each thread, I add a `clean` cell to indicate whether the program in its thread has been cleaned up. When this value is `true`, it indicates that a thread executes `abort` statement and all the threads should be terminated. Also, there is a new `abort` cell at the top level configuration to store whether the whole program has been aborted. When this value is `true`, the `clean` cells of all threads should be `true`, and all the statements should only be executed when `abort` is `false`.