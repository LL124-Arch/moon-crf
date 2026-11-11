///|
test "parse_int_range accepts signed integers" {
  assert_eq(parse_int_range("12".to_string_view(), 0, 2), Some(12))
  assert_eq(parse_int_range("-3".to_string_view(), 0, 2), Some(-3))
  assert_eq(parse_int_range("-".to_string_view(), 0, 1), None)
  assert_eq(parse_int_range("1a".to_string_view(), 0, 2), None)
}

///|
test "parse_template keeps literal-only templates" {
  let template = parse_template(0, "bias")
  let tokens : Array[String] = ["ignored"]
  assert_eq(template.render(tokens, 0), Some("bias"))
}
