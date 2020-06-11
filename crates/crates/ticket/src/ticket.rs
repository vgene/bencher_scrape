use rand;
use time;
use md5;
use machine_uid;
use id::{ID};
use std::process;
use std::sync::atomic::{AtomicUsize, Ordering};


lazy_static! {
    /// current machine id
    static ref MACHINE_ID: String = machine_uid::get()
        .unwrap_or_else(|_| panic!("could not get machine id."));
}


/// ticket id generator
pub struct Ticketing {
    object_id_counter: AtomicUsize,
    machine_id: md5::Digest,
    pid: u32,
}

impl Default for Ticketing {
    fn default() -> Self {
        Self::new()
    }
}

impl Ticketing {

    pub fn new() -> Self {
        let object_id_counter = AtomicUsize::new(rand::random::<usize>());
        let machine_id = md5::compute(MACHINE_ID.as_bytes());
        let pid = process::id();
        Ticketing {
            object_id_counter,
            machine_id,
            pid,
        }

    }

    /// generate a new id
    pub fn gen(&mut self) -> ID {
        let sec = time::now_utc().to_timespec().sec as u32;
        // wraps around on overflow
        let count = self.object_id_counter.fetch_add(1, Ordering::SeqCst) as u32;

        let mut raw = [0u8; ::RAW_LEN];
        raw[0]  = ((sec >> 24)   & 0xFF) as u8;
        raw[1]  = ((sec >> 16)   & 0xFF) as u8;
        raw[2]  = ((sec >> 8)    & 0xFF) as u8;
        raw[3]  = (sec           & 0xFF) as u8;
        raw[4]  = self.machine_id[0];
        raw[5]  = self.machine_id[1];
        raw[6]  = self.machine_id[2];
        raw[7]  = (self.pid >> 8 & 0xFF) as u8;
        raw[8]  = (self.pid      & 0xFF) as u8;
        raw[9]  = (count >> 16   & 0xFF) as u8;
        raw[10] = (count >> 8    & 0xFF) as u8;
        raw[11] = (count         & 0xFF) as u8;

        ID::new(raw)
    }
}
