///|
/// A token sequence with exactly one label per token.
///
/// Sequences are immutable from the outside: construct them with
/// `Sequence::new` and read them through `tokens` and `labels`.
pub struct Sequence {
  priv tokens : Array[String]
  priv labels : Array[String]
}

///|
/// A collection of labeled sequences.
pub struct Dataset {
  priv sequences : Array[Sequence]
}

///|
/// Errors produced while constructing or reading a dataset.
pub suberror DatasetError {
  MissingLabel(Int32)
  TooManyColumns(Int32, Int32)
  LengthMismatch(Int32, Int32)
}

///|
impl Show for DatasetError with fn output(self, logger) {
  match self {
    MissingLabel(line) =>
      logger.write_string(
        "line \{line}: expected `token label`, found only one column",
      )
    TooManyColumns(line, columns) =>
      logger.write_string("line \{line}: expected 2 columns, found \{columns}")
    LengthMismatch(tokens, labels) =>
      logger.write_string("sequence has \{tokens} tokens but \{labels} labels")
  }
}

///|
/// Creates a sequence after checking that `tokens` and `labels` have the same
/// length.
pub fn Sequence::new(
  tokens : Array[String],
  labels : Array[String],
) -> Sequence raise DatasetError {
  if tokens.length() != labels.length() {
    raise LengthMismatch(tokens.length(), labels.length())
  }
  Sequence::{ tokens, labels, }
}

///|
/// Number of tokens in the sequence.
pub fn Sequence::len(self : Sequence) -> Int32 {
  self.tokens.length()
}

///|
/// Tokens in the sequence.
pub fn Sequence::tokens(self : Sequence) -> ArrayView[String] {
  self.tokens[:]
}

///|
/// Labels in the sequence.
pub fn Sequence::labels(self : Sequence) -> ArrayView[String] {
  self.labels[:]
}

///|
/// Number of sequences in the dataset.
pub fn Dataset::len(self : Dataset) -> Int32 {
  self.sequences.length()
}

///|
/// Sequences in the dataset.
pub fn Dataset::sequences(self : Dataset) -> ArrayView[Sequence] {
  self.sequences[:]
}

///|
/// Splits a line on ASCII spaces and tabs, collapsing repeated separators.
fn split_fields(line : StringView) -> Array[StringView] {
  let fields : Array[StringView] = []
  let mut start = -1
  for i, code_unit in line.code_units() {
    let code = code_unit.to_int()
    let is_space = code == 32 || code == 9
    if is_space {
      if start >= 0 {
        fields.push(line.get_view(start~, end=i).unwrap())
        start = -1
      }
    } else if start < 0 {
      start = i
    }
  }
  if start >= 0 {
    fields.push(line.get_view(start~, end=line.length()).unwrap())
  }
  fields
}

///|
/// Parses a CoNLL-style dataset.
///
/// Each non-empty, non-comment line must contain exactly two whitespace-
/// separated columns: `token label`. A blank line ends the current sequence.
/// Lines beginning with `#` are ignored.
pub fn Dataset::from_conll(text : String) -> Dataset raise DatasetError {
  let sequences : Array[Sequence] = []
  let mut tokens : Array[String] = []
  let mut labels : Array[String] = []
  let mut line_no = 0
  for raw in text.split("\n") {
    line_no += 1
    let line = raw.trim()
    if line.length() == 0 {
      if tokens.length() > 0 {
        sequences.push(Sequence::{ tokens, labels, })
        tokens = []
        labels = []
      }
      continue
    }
    if line.has_prefix("#") {
      continue
    }
    let fields = split_fields(line)
    match fields.length() {
      0 | 1 => raise MissingLabel(line_no)
      2 => {
        tokens.push(fields[0].to_owned())
        labels.push(fields[1].to_owned())
      }
      n => raise TooManyColumns(line_no, n)
    }
  }
  if tokens.length() > 0 {
    sequences.push(Sequence::{ tokens, labels, })
  }
  Dataset::{ sequences, }
}
