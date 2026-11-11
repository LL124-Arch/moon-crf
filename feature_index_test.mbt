///|
test "interning is stable and deduplicates names" {
  let index = @mooncrf.StringIndex::new()
  let alice = index.intern("t0:Alice")
  let alice_again = index.intern("t0:Alice")
  let bias = index.intern("b")
  assert_eq(alice, 0)
  assert_eq(alice_again, 0)
  assert_eq(bias, 1)
  assert_eq(index.len(), 2)
}

///|
test "ids and names round-trip" {
  let index = @mooncrf.StringIndex::new()
  let id = index.intern("t0:北京")
  assert_eq(index.name(id), Some("t0:北京"))
  assert_eq(index.get("t0:北京"), Some(id))
  assert_eq(index.name(99), None)
  assert_eq(index.get("missing"), None)
}

///|
test "extract_ids matches extract and reuses the bias id" {
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]"])
  let index = @mooncrf.StringIndex::new()
  let ids = templates.extract_ids(["Alice", "met"], index)
  let names = templates.extract(["Alice", "met"])
  assert_eq(ids.length(), 2)
  assert_eq(ids[0].length(), 2)
  assert_eq(index.name(ids[0][0]), Some(names[0][0]))
  assert_eq(index.name(ids[0][1]), Some(names[0][1]))
  assert_eq(index.name(ids[1][0]), Some(names[1][0]))
  assert_eq(ids[0][1], ids[1][1])
}

///|
test "extract_ids handles out-of-range context and empty input" {
  let templates = @mooncrf.TemplateSet::parse(["%x[-1,0]"])
  let index = @mooncrf.StringIndex::new()
  let ids = templates.extract_ids(["Alice"], index)
  assert_eq(ids.length(), 1)
  assert_eq(ids[0].length(), 1)
  assert_eq(index.name(ids[0][0]), Some("b"))
  assert_eq(templates.extract_ids([], index).length(), 0)
}

///|
test "feature and label index aliases share the same implementation" {
  let features : @mooncrf.FeatureIndex = @mooncrf.StringIndex::new()
  let labels : @mooncrf.LabelIndex = @mooncrf.StringIndex::new()
  assert_eq(features.intern("f"), 0)
  assert_eq(labels.intern("X"), 0)
}
