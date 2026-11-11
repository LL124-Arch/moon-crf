///|
fn expect_template_error(templates : Array[String]) -> @mooncrf.TemplateError {
  let _ = @mooncrf.TemplateSet::parse(templates) catch { err => return err }
  panic()
}

///|
test "extracts unigram and bigram templates" {
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]", "%x[-1,0]/%x[0,0]"])
  let features = templates.extract(["Alice", "met", "Bob"])
  assert_eq(features.length(), 3)
  assert_eq(features[0][0], "t0:Alice")
  assert_true(!features[0].contains("t1:Alice/met"))
  assert_eq(features[1][1], "t1:Alice/met")
  assert_eq(features[2][0], "t0:Bob")
  assert_eq(features[2][1], "t1:met/Bob")
}

///|
test "skips templates whose context is out of range" {
  let templates = @mooncrf.TemplateSet::parse(["%x[1,0]"])
  let features = templates.extract(["Alice", "met"])
  assert_eq(features[0][0], "t0:met")
  assert_eq(features[1].length(), 1)
  assert_eq(features[1][0], "b")
}

///|
test "supports literal text and escaped percent" {
  let templates = @mooncrf.TemplateSet::parse(["p=%x[0,0]", "100%%"])
  let features = templates.extract(["Alice"])
  assert_eq(features[0][0], "t0:p=Alice")
  assert_eq(features[0][1], "t1:100%")
  assert_eq(features[0][2], "b")
}

///|
test "empty template list yields bias only" {
  let templates = @mooncrf.TemplateSet::parse([])
  let features = templates.extract(["Alice"])
  assert_eq(features.length(), 1)
  assert_eq(features[0].length(), 1)
  assert_eq(features[0][0], "b")
}

///|
test "empty token list yields no positions" {
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]"])
  assert_eq(templates.extract([]).length(), 0)
}

///|
test "preserves Unicode tokens" {
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]", "%x[-1,0]/%x[0,0]"])
  let features = templates.extract(["北京", "欢迎"])
  assert_eq(features[0][0], "t0:北京")
  assert_eq(features[1][1], "t1:北京/欢迎")
}

///|
test "rejects empty templates" {
  match expect_template_error([""]) {
    @mooncrf.TemplateError::EmptyTemplate(index) => assert_eq(index, 0)
    _ => panic()
  }
}

///|
test "rejects unclosed fields" {
  match expect_template_error(["%x[0,0"]) {
    @mooncrf.TemplateError::UnclosedField(index, _) => assert_eq(index, 0)
    _ => panic()
  }
}

///|
test "rejects non-numeric offsets" {
  match expect_template_error(["%x[a,0]"]) {
    @mooncrf.TemplateError::InvalidNumber(index, _) => assert_eq(index, 0)
    _ => panic()
  }
}

///|
test "rejects unsupported columns" {
  match expect_template_error(["%x[0,1]"]) {
    @mooncrf.TemplateError::UnsupportedColumn(index, column) => {
      assert_eq(index, 0)
      assert_eq(column, 1)
    }
    _ => panic()
  }
}

///|
test "rejects unknown template directives" {
  match expect_template_error(["%y"]) {
    @mooncrf.TemplateError::UnexpectedToken(index, _) => assert_eq(index, 0)
    _ => panic()
  }
}
