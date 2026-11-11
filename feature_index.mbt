///|
/// A stable mapping from feature names to dense integer identifiers.
pub struct FeatureIndex {
  priv ids : Map[String, Int32]
  priv names : Array[String]
}

///|
/// Creates an empty feature index.
pub fn FeatureIndex::new() -> FeatureIndex {
  FeatureIndex::{ ids: Map([]), names: [], }
}

///|
/// Returns the ID for `name`, assigning a new ID on first use.
pub fn FeatureIndex::intern(self : FeatureIndex, name : String) -> Int32 {
  match self.ids.get(name) {
    Some(id) => id
    None => {
      let id = self.names.length()
      self.ids.set(name, id)
      self.names.push(name)
      id
    }
  }
}

///|
/// Looks up an existing feature ID without adding a new one.
pub fn FeatureIndex::get(self : FeatureIndex, name : String) -> Int32? {
  self.ids.get(name)
}

///|
/// Number of distinct features in the index.
pub fn FeatureIndex::len(self : FeatureIndex) -> Int32 {
  self.names.length()
}

///|
/// Resolves an ID back to its feature name.
pub fn FeatureIndex::name(self : FeatureIndex, id : Int32) -> String? {
  self.names.get(id)
}

///|
/// Extracts feature IDs for every token position.
///
/// The feature names are produced by `TemplateSet::extract`, then interned in
/// `index` in first-seen order.
pub fn TemplateSet::extract_ids(
  self : TemplateSet,
  tokens : Array[String],
  index : FeatureIndex,
) -> Array[Array[Int32]] {
  let names = self.extract(tokens)
  let result : Array[Array[Int32]] = []
  for position_features in names {
    let ids : Array[Int32] = []
    for name in position_features {
      ids.push(index.intern(name))
    }
    result.push(ids)
  }
  result
}
