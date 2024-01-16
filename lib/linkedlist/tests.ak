use linkedlist/utils.{div_ceil}

// Test Case 1
// Test when a is divisible by b
test div_ceil_1() {
  div_ceil(10, 5) == 2
}

// Test Case 2
// Test when a is not divisible by b
test div_ceil_2() {
  div_ceil(7, 3) == 3
}

// Test Case 3
// Test when a is 0
test div_ceil_3() {
  div_ceil(0, 5) == 0
}

// Test Case 4
// Test when b is 1
test div_ceil_4() {
  div_ceil(10, 1) == 10
}
