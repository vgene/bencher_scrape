use std::str;
use std::fmt;
use std::string::ToString;

/// ticket id representation
#[derive(Debug, Copy, Clone, Default)]
pub struct ID {
    raw: [u8; ::RAW_LEN]
}


impl fmt::Display for ID {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", encode(*self))
    }
}


impl PartialEq for ID {
    fn eq(&self, other: &ID) -> bool {
        self.raw == other.raw
    }
}


impl ID {
    pub fn new(raw: [u8; ::RAW_LEN]) -> Self {
        ID {
            raw
        }
    }

    /// covert ID to u8 array
    pub fn as_bytes(self) -> [u8; ::RAW_LEN] {
        self.raw
    }
}



/// base32 encode
pub fn encode(id: ID) -> String {
    let encoding = ::ENCODING.as_bytes();
    let raw = id.as_bytes();
    let mut result = [0u8; ::ENCODED_LEN];
    result[0]  = encoding[( raw[0]  >> 3) as usize];
    result[1]  = encoding[((raw[1]  >> 6) & 0x1F | (raw[0] << 2) & 0x1F) as usize];
    result[2]  = encoding[((raw[1]  >> 1) & 0x1F) as usize];
    result[3]  = encoding[((raw[2]  >> 4) & 0x1F | (raw[1] << 4) & 0x1F) as usize];
    result[4]  = encoding[((raw[3]  >> 7) | (raw[2] << 1) & 0x1F) as usize];
    result[5]  = encoding[((raw[3]  >> 2) & 0x1F) as usize];
    result[6]  = encoding[((raw[4]  >> 5) | (raw[3] << 3) & 0x1F) as usize];
    result[7]  = encoding[( raw[4]  &  0x1F) as usize];
    result[8]  = encoding[( raw[5]  >> 3) as usize];
    result[9]  = encoding[((raw[6]  >> 6) & 0x1F | (raw[5] << 2) & 0x1F) as usize];
    result[10] = encoding[((raw[6]  >> 1) & 0x1F ) as usize];
    result[11] = encoding[((raw[7]  >> 4) & 0x1F | (raw[6] << 4 ) & 0x1F) as usize];
    result[12] = encoding[((raw[8]  >> 7) | (raw[7] << 1) & 0x1F) as usize];
    result[13] = encoding[((raw[8]  >> 2) & 0x1F) as usize];
    result[14] = encoding[((raw[9]  >> 5) | (raw[8] << 3) & 0x1F) as usize];
    result[15] = encoding[( raw[9]  &  0x1F) as usize];
    result[16] = encoding[( raw[10] >> 3) as usize];
    result[17] = encoding[((raw[11] >> 6) & 0x1F | (raw[10] << 2) & 0x1F) as usize];
    result[18] = encoding[((raw[11] >> 1) & 0x1F) as usize];
    result[19] = encoding[((raw[11] << 4) & 0x1F) as usize];

    str::from_utf8(&result).unwrap().to_string()
}


/// base32 decode
pub fn decode(s: &str) -> ID {
    let dec = *::DECODING;
    let s = s.as_bytes();
    let mut raw = [0u8; ::RAW_LEN];
    raw[0]  = dec[s[0]  as usize] << 3 | dec[s[1]  as usize] >> 2;
    raw[1]  = dec[s[1]  as usize] << 6 | dec[s[2]  as usize] << 1 | dec[s[3]  as usize] >> 4;
    raw[2]  = dec[s[3]  as usize] << 4 | dec[s[4]  as usize] >> 1;
    raw[3]  = dec[s[4]  as usize] << 7 | dec[s[5]  as usize] << 2 | dec[s[6]  as usize] >> 3;
    raw[4]  = dec[s[6]  as usize] << 5 | dec[s[7]  as usize];
    raw[5]  = dec[s[8]  as usize] << 3 | dec[s[9]  as usize] >> 2;
    raw[6]  = dec[s[9]  as usize] << 6 | dec[s[10] as usize] << 1 | dec[s[11] as usize] >> 4;
    raw[7]  = dec[s[11] as usize] << 4 | dec[s[12] as usize] >> 1;
    raw[8]  = dec[s[12] as usize] << 7 | dec[s[13] as usize] << 2 | dec[s[14] as usize] >> 3;
    raw[9]  = dec[s[14] as usize] << 5 | dec[s[15] as usize];
    raw[10] = dec[s[16] as usize] << 3 | dec[s[17] as usize] >> 2;
    raw[11] = dec[s[17] as usize] << 6 | dec[s[18] as usize] << 1 | dec[s[19] as usize] >> 4;

    ID::new(raw)
}
