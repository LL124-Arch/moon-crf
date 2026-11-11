///|
/// A stable mapping from strings to dense integer identifiers.
pub struct StringIndex {
  priv ids : Map[String, Int32]
  priv names : Array[String]
}

///|
/// Creates an empty string index.
pub fn StringIndex::new() -> StringIndex {
  StringIndex::{ ids: Map([]), names: [], }
}

///|
/// Returns the ID for `name`, assigning a new ID on first use.
pub fn StringIndex::intern(self : StringIndex, name : String) -> Int32 {
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
/// Looks up an existing ID without adding a new one.
pub fn StringIndex::get(self : StringIndex, name : String) -> Int32? {
  self.ids.get(name)
}

///|
/// Number of distinct strings in the index.
pub fn StringIndex::len(self : StringIndex) -> Int32 {
  self.names.length()
}

///|
/// Resolves an ID back to its original string.
pub fn StringIndex::name(self : StringIndex, id : Int32) -> String? {
  self.names.get(id)
}

///|
/// Original strings in ID order.
pub fn StringIndex::to_array(self : StringIndex) -> Array[String] {
  self.names.copy()
}

///|
/// Rebuilds an index from strings in ID order.
pub fn StringIndex::from_array(names : Array[String]) -> StringIndex {
  let index = StringIndex::new()
  for name in names {
    let _ = index.intern(name)
  }
  index
}

///|
/// Extracts feature IDs for every token position.
///
/// The feature names are produced by `TemplateSet::extract`, then interned in
/// `index` in first-seen order.
pub fn TemplateSet::extract_ids(
  self : TemplateSet,
  tokens : Array[String],
  index : StringIndex,
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

///|
/// String index used for observation features.
pub type FeatureIndex = StringIndex

///|
/// String index used for labels.
pub type LabelIndex = StringIndex
