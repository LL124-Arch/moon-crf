///|
/// Errors produced while serializing or loading a model bundle.
pub suberror BundleError {
  Version(Int32)
  InvalidField(String)
  InvalidJson(String)
  Template(String)
  Model(String)
}

///|
impl Show for BundleError with fn output(self, logger) {
  match self {
    Version(version) =>
      logger.write_string("unsupported bundle version \{version}")
    InvalidField(name) => logger.write_string("invalid bundle field: \{name}")
    InvalidJson(message) => logger.write_string("invalid JSON: \{message}")
    Template(message) => logger.write_string("invalid templates: \{message}")
    Model(message) => logger.write_string("invalid model: \{message}")
  }
}

///|
/// A trained model together with the feature and label spaces it was built on.
pub struct ModelBundle {
  priv model : CrfModel
  priv templates : TemplateSet
  priv feature_index : FeatureIndex
  priv label_index : LabelIndex
}

///|
/// Packages a trainer's feature space and a trained model.
pub fn CrfTrainer::to_bundle(
  self : CrfTrainer,
  model : CrfModel,
) -> ModelBundle {
  ModelBundle::{
    model,
    templates: self.templates,
    feature_index: self.feature_index,
    label_index: self.label_index,
  }
}

///|
/// Predicts label strings with the bundled model.
pub fn ModelBundle::predict(
  self : ModelBundle,
  tokens : Array[String],
) -> Array[String] raise ModelError {
  let features = self.templates.extract_known_ids(tokens, self.feature_index)
  let result = self.model.viterbi(features)
  let labels : Array[String] = []
  for id in result.labels() {
    match self.label_index.name(id) {
      Some(name) => labels.push(name)
      None => labels.push("")
    }
  }
  labels
}

///|
/// Serializes the bundle as a JSON value.
pub fn ModelBundle::to_json(self : ModelBundle) -> Json {
  let parameters : Array[Json] = []
  for value in self.model.to_parameters() {
    parameters.push(Json::number(value))
  }
  let templates : Array[Json] = []
  for value in self.templates.to_array() {
    templates.push(Json::string(value))
  }
  let labels : Array[Json] = []
  for value in self.label_index.to_array() {
    labels.push(Json::string(value))
  }
  let features : Array[Json] = []
  for value in self.feature_index.to_array() {
    features.push(Json::string(value))
  }
  Json::object({
    "version": Json::number(1.0),
    "templates": Json::array(templates),
    "labels": Json::array(labels),
    "features": Json::array(features),
    "parameters": Json::array(parameters),
  })
}

///|
/// Serializes the bundle as indented JSON text.
pub fn ModelBundle::to_json_string(self : ModelBundle) -> String {
  self.to_json().stringify(indent=2)
}

///|
fn required_field(json : Json, name : String) -> Json raise BundleError {
  match json {
    Object(fields) =>
      match fields.get(name) {
        Some(value) => value
        None => raise InvalidField(name)
      }
    _ => raise InvalidField(name)
  }
}

///|
fn string_array(json : Json, name : String) -> Array[String] raise BundleError {
  let value = required_field(json, name)
  match value {
    Array(items) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(text) => result.push(text)
          _ => raise InvalidField(name)
        }
      }
      result
    }
    _ => raise InvalidField(name)
  }
}

///|
fn number_array(json : Json, name : String) -> Array[Double] raise BundleError {
  let value = required_field(json, name)
  match value {
    Array(items) => {
      let result : Array[Double] = []
      for item in items {
        match item {
          Number(number, ..) => result.push(number)
          _ => raise InvalidField(name)
        }
      }
      result
    }
    _ => raise InvalidField(name)
  }
}

///|
/// Restores a bundle from a JSON value.
pub fn ModelBundle::from_json(json : Json) -> ModelBundle raise BundleError {
  let version = match required_field(json, "version") {
    Number(value, ..) => value.to_int()
    _ => raise InvalidField("version")
  }
  if version != 1 {
    raise Version(version)
  }
  let raw_templates = string_array(json, "templates")
  let templates = TemplateSet::parse(raw_templates) catch {
    err => raise Template(Show::to_string(err))
  }
  let labels = StringIndex::from_array(string_array(json, "labels"))
  let features = StringIndex::from_array(string_array(json, "features"))
  let parameters = number_array(json, "parameters")
  let model = CrfModel::from_parameters(
    parameters,
    labels.len(),
    features.len(),
  ) catch {
    err => raise Model(Show::to_string(err))
  }
  ModelBundle::{
    model,
    templates,
    feature_index: features,
    label_index: labels,
  }
}

///|
/// Restores a bundle from JSON text.
pub fn ModelBundle::from_json_string(
  text : String,
) -> ModelBundle raise BundleError {
  let json = @json.parse(text) catch {
    err => raise InvalidJson(Show::to_string(err))
  }
  ModelBundle::from_json(json)
}
