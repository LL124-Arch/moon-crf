///|
/// One component of a feature template: literal text or a token lookup.
priv enum TemplatePart {
  Literal(String)
  Field(Int32)
}

///|
/// A parsed feature template.
priv struct FeatureTemplate {
  parts : Array[TemplatePart]
}

///|
/// A reusable set of feature templates.
pub struct TemplateSet {
  priv templates : Array[FeatureTemplate]
  priv raw : Array[String]
}

///|
/// Errors produced while parsing feature templates.
pub suberror TemplateError {
  EmptyTemplate(Int32)
  UnclosedField(Int32, Int32)
  UnexpectedToken(Int32, Int32)
  InvalidNumber(Int32, Int32)
  UnsupportedColumn(Int32, Int32)
}

///|
impl Show for TemplateError with fn output(self, logger) {
  match self {
    EmptyTemplate(index) =>
      logger.write_string("template \{index}: template is empty")
    UnclosedField(index, position) =>
      logger.write_string(
        "template \{index}: unclosed field starting at position \{position}",
      )
    UnexpectedToken(index, position) =>
      logger.write_string(
        "template \{index}: unexpected token at position \{position}",
      )
    InvalidNumber(index, position) =>
      logger.write_string(
        "template \{index}: expected an integer at position \{position}",
      )
    UnsupportedColumn(index, column) =>
      logger.write_string(
        "template \{index}: column \{column} is not supported; use column 0",
      )
  }
}

///|
/// Parses an optionally signed decimal integer from a view.
fn parse_int_range(view : StringView, start : Int32, end : Int32) -> Int32? {
  if start >= end {
    return None
  }
  let mut i = start
  let mut sign = 1
  if view.get_char(i) == Some('-') {
    sign = -1
    i += 1
  }
  if i >= end {
    return None
  }
  let mut value = 0
  while i < end {
    let c = view.get_char(i).unwrap()
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i += 1
  }
  Some(sign * value)
}

///|
/// Parses one template string.
fn parse_template(
  index : Int32,
  raw : String,
) -> FeatureTemplate raise TemplateError {
  let view = raw[:]
  let parts : Array[TemplatePart] = []
  let mut i = 0
  let mut literal_start = 0
  while i < view.length() {
    if view.get_char(i) == Some('%') {
      if i > literal_start {
        parts.push(
          Literal(view.get_view(start=literal_start, end=i).unwrap().to_owned()),
        )
      }
      if i + 1 >= view.length() {
        raise UnclosedField(index, i)
      }
      match view.get_char(i + 1) {
        Some('%') => {
          parts.push(Literal("%"))
          i += 2
          literal_start = i
        }
        Some('x') => {
          if i + 2 >= view.length() || view.get_char(i + 2) != Some('[') {
            raise UnexpectedToken(index, i + 2)
          }
          let mut j = i + 3
          let row_start = j
          while j < view.length() && view.get_char(j) != Some(',') {
            j += 1
          }
          if j >= view.length() {
            raise UnclosedField(index, i)
          }
          let row = match parse_int_range(view, row_start, j) {
            Some(value) => value
            None => raise InvalidNumber(index, row_start)
          }
          j += 1
          let column_start = j
          while j < view.length() && view.get_char(j) != Some(']') {
            j += 1
          }
          if j >= view.length() {
            raise UnclosedField(index, i)
          }
          let column = match parse_int_range(view, column_start, j) {
            Some(value) => value
            None => raise InvalidNumber(index, column_start)
          }
          if column != 0 {
            raise UnsupportedColumn(index, column)
          }
          parts.push(Field(row))
          i = j + 1
          literal_start = i
        }
        _ => raise UnexpectedToken(index, i + 1)
      }
    } else {
      i += 1
    }
  }
  if literal_start < view.length() {
    parts.push(
      Literal(
        view
        .get_view(start=literal_start, end=view.length())
        .unwrap()
        .to_owned(),
      ),
    )
  }
  if parts.length() == 0 {
    raise EmptyTemplate(index)
  }
  FeatureTemplate::{ parts, }
}

///|
/// Renders one template at a token position, or returns `None` when a
/// referenced token is outside the sequence.
fn FeatureTemplate::render(
  self : FeatureTemplate,
  tokens : Array[String],
  position : Int32,
) -> String? {
  let builder = StringBuilder()
  for part in self.parts {
    match part {
      Literal(text) => builder.write_string(text)
      Field(row) => {
        let index = position + row
        if index < 0 || index >= tokens.length() {
          return None
        }
        builder.write_string(tokens[index])
      }
    }
  }
  Some(builder.to_string())
}

///|
/// Parses a list of feature templates.
pub fn TemplateSet::parse(
  templates : Array[String],
) -> TemplateSet raise TemplateError {
  let parsed : Array[FeatureTemplate] = []
  for index, raw in templates {
    parsed.push(parse_template(index, raw))
  }
  TemplateSet::{ templates: parsed, raw: templates.copy(), }
}

///|
/// Original template strings in declaration order.
pub fn TemplateSet::to_array(self : TemplateSet) -> Array[String] {
  self.raw.copy()
}

///|
/// Number of templates in the set.
pub fn TemplateSet::len(self : TemplateSet) -> Int32 {
  self.templates.length()
}

///|
/// Extracts feature names for every token position.
///
/// Each feature name is prefixed with its template index (`t0:`, `t1:`, ...)
/// so identical rendered strings from different templates remain distinct.
/// A bias feature `b` is appended to every position.
pub fn TemplateSet::extract(
  self : TemplateSet,
  tokens : Array[String],
) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  for position in 0..<tokens.length() {
    let features : Array[String] = []
    for index, template in self.templates {
      if template.render(tokens, position) is Some(value) {
        features.push("t\{index}:\{value}")
      }
    }
    features.push("b")
    result.push(features)
  }
  result
}

///|
/// Extracts only feature IDs already present in `index`.
///
/// Unknown features are skipped, which lets prediction reuse a training-time
/// feature space without silently growing it.
pub fn TemplateSet::extract_known_ids(
  self : TemplateSet,
  tokens : Array[String],
  index : FeatureIndex,
) -> Array[Array[Int32]] {
  let names = self.extract(tokens)
  let result : Array[Array[Int32]] = []
  for position_features in names {
    let ids : Array[Int32] = []
    for name in position_features {
      match index.get(name) {
        Some(id) => ids.push(id)
        None => ()
      }
    }
    result.push(ids)
  }
  result
}
