///|
/// Error type for stringprep operations.
pub(all) suberror StringprepError {
  ProhibitedCharacter(Char)
  ProhibitedBidirectionalText
  StartsWithCombiningCharacter
  EmptyString
}
