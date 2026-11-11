///|
test "split_fields handles spaces tabs and leading separators" {
  let fields = split_fields("  a\t b  ".to_string_view())
  assert_eq(fields.length(), 2)
  assert_eq(fields[0].to_owned(), "a")
  assert_eq(fields[1].to_owned(), "b")
}

///|
test "split_fields keeps Unicode tokens intact" {
  let fields = split_fields("北京 B-LOC".to_string_view())
  assert_eq(fields.length(), 2)
  assert_eq(fields[0].to_owned(), "北京")
  assert_eq(fields[1].to_owned(), "B-LOC")
}
