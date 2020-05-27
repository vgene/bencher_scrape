use std::collections::{HashMap,HashSet};

pub struct Bayesic {
  classifications: HashSet<String>,
  by_token: HashMap<String, HashSet<String>>,
}

impl Bayesic {
  pub fn new() -> Bayesic {
    Bayesic {
      classifications: HashSet::new(),
      by_token: HashMap::new(),
    }
  }

  pub fn classify(& self, tokens: Vec<String>) -> HashMap<String, f64> {
    let mut probabilities = HashMap::new();
    let num_classes = self.classifications.len() as f64;
    for token in &tokens {
      if self.by_token.contains_key(token) {
        let possible_classes = self.by_token.get(token).unwrap();
        for class in possible_classes {
          let prior = 1.0 / num_classes;
          let mut p_klass: f64 = *probabilities.get(class).unwrap_or(&prior);
          let p_not_klass: f64 = 1.0 - p_klass;
          let p_token_given_klass: f64 = 1.0;
          let num_potential_classes: f64 = self.by_token[token].len() as f64;
          let p_token_given_not_klass: f64 = (num_potential_classes - 1.0) / num_classes;
          p_klass = (p_token_given_klass * p_klass) / ((p_token_given_klass * p_klass) + (p_token_given_not_klass * p_not_klass));
          probabilities.insert(class.clone(), p_klass);
        }
      }
    }
    return probabilities;
  }

  pub fn prune(&mut self, threshold: f64) {
    let max_classes = ((self.classifications.len() as f64) * threshold).round() as usize;
    self.by_token.retain(|_k, set| set.len() <= max_classes );
  }

  pub fn train(&mut self, class: String, tokens: Vec<String>) {
    self.classifications.insert(class.clone());
    for token in tokens {
      self.by_token.entry(token).or_insert(HashSet::new()).insert(class.clone());
    }
  }
}

#[cfg(test)]
mod tests {
  extern crate pretty_assertions;

  use super::*;
  use std::path::Path;
  use lazy_static::lazy_static;
  use regex::Regex;

  lazy_static! {
    static ref WORDS: Regex = Regex::new(r"\b\w+\b").unwrap();
  }

  lazy_static! {
    static ref TRAINED: Bayesic = trained();
  }

  fn path_to_words(path_str: &str) -> Vec<String> {
    let path = Path::new(path_str).to_path_buf();
    let bin = std::fs::read(path).ok().unwrap();
    let s = String::from_utf8(bin).ok().unwrap();
    let words: Vec<String> = WORDS.find_iter(&s).map(|m: regex::Match| String::from(m.as_str()) ).collect();
    return words;
  }

  fn trained() -> Bayesic {
    let mut bayesic = Bayesic::new();
    bayesic.train("jojo".to_string(), path_to_words("priv/training/jojo_rabbit"));
    bayesic.train("jurassic_park".to_string(), path_to_words("priv/training/jurassic_park"));
    bayesic.train("jurassic_park_ii".to_string(), path_to_words("priv/training/jurassic_park_ii"));
    bayesic.train("jurassic_park_iii".to_string(), path_to_words("priv/training/jurassic_park_iii"));
    bayesic.train("kpax".to_string(), path_to_words("priv/training/kpax"));
    return bayesic;
  }

  #[test]
  fn parsing_file_words() {
    let strs = vec!("A", "young", "boy", "in", "Hitler", "s", "army", "finds", "out", "his", "mother", "is", "hiding", "a", "Jewish", "girl", "in", "their", "home");
    let expected: Vec<String> = strs.iter().map(|s| s.to_string()).collect();
    assert_eq!(path_to_words("priv/training/jojo_rabbit"), expected)
  }

  #[test]
  fn empty_classification() {
    let classification = TRAINED.classify(vec!());
    assert_eq!(classification.len(), 0);
  }

  #[test]
  fn key_word_classification() {
    let classification = TRAINED.classify(vec!("Hitler".to_string()));
    assert!(classification["jojo"] > 0.9);
    assert_eq!(classification.len(), 1);
  }

  #[test]
  fn generic_word_classification() {
    let classification = TRAINED.classify(vec!("a".to_string()));
    // three of our movie descriptions have "a", so it's not as strong of an indicator
    assert_eq!(classification.len(), 3);
    assert!(classification["jojo"] > 0.35);
    assert!(classification["jurassic_park"] > 0.35);
    assert!(classification["kpax"] > 0.35);
  }

  #[test]
  fn multiple_generics() {
    let classification = TRAINED.classify(vec!("a".to_string(), "the".to_string(), "with".to_string()));
    // only jurassic_park has all of these fairly generic words
    assert!(classification["jurassic_park"] > 0.75);
    assert!(classification["jurassic_park"] > classification["jurassic_park_ii"]);
    // Other movies have just one of these words so they only get a small boost to probability
    assert!(classification["kpax"] < 0.4);
    assert!(classification["jojo"] < 0.4);
  }

  #[test]
  fn multiple_generics_after_pruning() {
    let mut pruned = trained();
    pruned.prune(0.3333);
    let classification = pruned.classify(vec!("a".to_string(), "the".to_string(), "with".to_string()));
    assert_eq!(classification.keys().len(), 0);
  }

  #[test]
  fn key_word_classification_after_pruning() {
    let mut pruned = trained();
    pruned.prune(0.3333);
    let classification = pruned.classify(vec!("Hitler".to_string()));
    assert!(classification["jojo"] > 0.9);
    assert_eq!(classification.len(), 1);
  }

  #[test]
  fn un_indexed_tokens() {
    let classification = TRAINED.classify(vec!("zzz".to_string(), "yyy".to_string()));
    assert_eq!(classification.keys().len(), 0);
  }
}
