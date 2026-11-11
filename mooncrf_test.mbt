///|
fn expect_parse_error(text : String) -> @mooncrf.DatasetError {
  let _ = @mooncrf.Dataset::from_conll(text) catch { err => return err }
  panic()
}

///|
fn expect_sequence_error(
  tokens : Array[String],
  labels : Array[String],
) -> @mooncrf.DatasetError {
  let _ = @mooncrf.Sequence::new(tokens, labels) catch { err => return err }
  panic()
}

///|
test "parses two sequences" {
  let dataset = @mooncrf.Dataset::from_conll(
    "Alice B-PER\nmet O\n\nBob B-PER\n",
  )
  assert_eq(dataset.len(), 2)
  assert_eq(dataset.sequences()[0].len(), 2)
  assert_eq(dataset.sequences()[0].tokens()[0], "Alice")
  assert_eq(dataset.sequences()[0].labels()[1], "O")
  assert_eq(dataset.sequences()[1].tokens()[0], "Bob")
}

///|
test "accepts crlf line endings" {
  let dataset = @mooncrf.Dataset::from_conll(
    "Alice B-PER\r\nmet O\r\n\r\nBob B-PER\r\n",
  )
  assert_eq(dataset.len(), 2)
  assert_eq(dataset.sequences()[0].labels()[0], "B-PER")
  assert_eq(dataset.sequences()[1].labels()[0], "B-PER")
}

///|
test "ignores comments and collapses extra whitespace" {
  let dataset = @mooncrf.Dataset::from_conll(
    "# generated fixture\n  Alice \t  B-PER  \n# another comment\nmet   O\n",
  )
  assert_eq(dataset.len(), 1)
  assert_eq(dataset.sequences()[0].tokens()[0], "Alice")
  assert_eq(dataset.sequences()[0].labels()[0], "B-PER")
  assert_eq(dataset.sequences()[0].tokens()[1], "met")
}

///|
test "empty input yields an empty dataset" {
  let dataset = @mooncrf.Dataset::from_conll("")
  assert_eq(dataset.len(), 0)
}

///|
test "flushes the last sequence without a trailing blank line" {
  let dataset = @mooncrf.Dataset::from_conll("Alice B-PER\nmet O")
  assert_eq(dataset.len(), 1)
  assert_eq(dataset.sequences()[0].len(), 2)
}

///|
test "reports a missing label" {
  match expect_parse_error("Alice\n") {
    @mooncrf.DatasetError::MissingLabel(line) => assert_eq(line, 1)
    _ => panic()
  }
}

///|
test "reports too many columns" {
  match expect_parse_error("Alice B-PER extra\n") {
    @mooncrf.DatasetError::TooManyColumns(line, columns) => {
      assert_eq(line, 1)
      assert_eq(columns, 3)
    }
    _ => panic()
  }
}

///|
test "rejects sequences with mismatched token and label counts" {
  match expect_sequence_error(["a", "b"], ["X"]) {
    @mooncrf.DatasetError::LengthMismatch(tokens, labels) => {
      assert_eq(tokens, 2)
      assert_eq(labels, 1)
    }
    _ => panic()
  }
}
