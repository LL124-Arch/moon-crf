///|
fn expect_train_error(
  dataset : @mooncrf.Dataset,
  templates : @mooncrf.TemplateSet,
) -> @mooncrf.TrainError {
  let _ = @mooncrf.CrfTrainer::from_dataset(dataset, templates) catch {
    err => return err
  }
  panic()
}

///|
test "encodes labels and features from a dataset" {
  let dataset = @mooncrf.Dataset::from_conll("a X\nb Y\n\na X\nb Y\n")
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]", "%x[-1,0]/%x[0,0]"])
  let trainer = @mooncrf.CrfTrainer::from_dataset(dataset, templates)
  assert_eq(trainer.num_labels(), 2)
  assert_true(trainer.num_features() > 0)
  assert_eq(trainer.label_name(0), Some("X"))
  assert_eq(trainer.label_name(1), Some("Y"))
  match trainer.feature_name(0) {
    Some(name) => assert_true(name.length() > 0)
    None => panic()
  }
}

///|
test "finite differences match the analytic gradient" {
  let dataset = @mooncrf.Dataset::from_conll("a X\nb Y\n\na X\nb Y\n")
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]", "%x[-1,0]/%x[0,0]"])
  let trainer = @mooncrf.CrfTrainer::from_dataset(dataset, templates)
  let model = @mooncrf.CrfModel::new(
    trainer.num_labels(),
    trainer.num_features(),
  )
  let parameters = model.to_parameters()
  let (_, gradient) = trainer.objective_and_gradient(parameters, l2=0.01)
  let epsilon = 1.0e-5
  for i in 0..<parameters.length() {
    let plus = parameters.copy()
    plus[i] += epsilon
    let (plus_value, _) = trainer.objective_and_gradient(plus, l2=0.01)
    let minus = parameters.copy()
    minus[i] -= epsilon
    let (minus_value, _) = trainer.objective_and_gradient(minus, l2=0.01)
    let numeric = (plus_value - minus_value) / (2.0 * epsilon)
    assert_true((gradient[i] - numeric).abs() < 1.0e-4)
  }
}

///|
test "rejects an empty training dataset" {
  let dataset = @mooncrf.Dataset::from_conll("")
  let templates = @mooncrf.TemplateSet::parse(["%x[0,0]"])
  match expect_train_error(dataset, templates) {
    @mooncrf.TrainError::EmptyDataset => ()
  }
}
