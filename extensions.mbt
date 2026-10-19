///|
// Explicit trait-method exports support MoonBit 0.10.16 without relying on
// deprecated implicit promotion. Operators still use the Eq implementation.
pub extend Event with Eq::{equal, not_equal}

///|
pub extend Event with ToJson::{to_json}

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with ToJson::{to_json}

///|
pub extend Policy with Eq::{equal, not_equal}

///|
pub extend Policy with ToJson::{to_json}

///|
pub extend Taint with Eq::{equal, not_equal}

///|
pub extend Taint with ToJson::{to_json}

///|
pub extend Finding with Eq::{equal, not_equal}

///|
pub extend Finding with ToJson::{to_json}

///|
pub extend Decision with Eq::{equal, not_equal}

///|
pub extend Decision with ToJson::{to_json}

///|
pub extend Report with Eq::{equal, not_equal}

///|
pub extend Report with ToJson::{to_json}

///|
pub extend Change with Eq::{equal, not_equal}

///|
pub extend Change with ToJson::{to_json}

///|
pub extend Comparison with Eq::{equal, not_equal}

///|
pub extend Comparison with ToJson::{to_json}

///|
pub extend InputError with Eq::{equal, not_equal}

///|
pub extend Mismatch with Eq::{equal, not_equal}

///|
pub extend Mismatch with ToJson::{to_json}

///|
pub extend CaseResult with Eq::{equal, not_equal}

///|
pub extend CaseResult with ToJson::{to_json}

///|
pub extend SuiteReport with Eq::{equal, not_equal}

///|
pub extend SuiteReport with ToJson::{to_json}
