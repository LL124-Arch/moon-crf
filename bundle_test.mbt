///|
fn expect_bundle_text_error(text : String) -> @mooncrf.BundleError {
  let _ = @mooncrf.ModelBundle::from_json_string(text) catch {
    err => return err
  }
  panic()
}

///|
fn expect_bundle_json_error(json : Json) -> @mooncrf.BundleError {
  let _ = @mooncrf.ModelBundle::from_json(json) catch { err => return err }
  panic()
}

///|
test "bundle round-trip preserves predictions" {
  let dataset = @mooncrf.Dataset::from_conll("a X\nb Y\n\na X\nb Y\n")
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]"])
  let trainer = @mooncrf.CrfTrainer::from_dataset(dataset, templates)
  let result = trainer.train(l2=0.01)
  let bundle = trainer.to_bundle(result.model())
  let text = bundle.to_json_string()
  let loaded = @mooncrf.ModelBundle::from_json_string(text)
  let expected = bundle.predict(["a", "b"])
  let actual = loaded.predict(["a", "b"])
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(actual[i], expected[i])
  }
}

///|
test "rejects malformed json" {
  match expect_bundle_text_error("not json") {
    @mooncrf.BundleError::InvalidJson(_) => ()
    _ => panic()
  }
}

///|
test "rejects unsupported bundle versions" {
  let json = Json::object({ "version": Json::number(2.0) })
  match expect_bundle_json_error(json) {
    @mooncrf.BundleError::Version(version) => assert_eq(version, 2)
    _ => panic()
  }
}

///|
test "rejects missing fields" {
  let json = Json::object({ "version": Json::number(1.0) })
  match expect_bundle_json_error(json) {
    @mooncrf.BundleError::InvalidField(name) => assert_eq(name, "templates")
    _ => panic()
  }
}
