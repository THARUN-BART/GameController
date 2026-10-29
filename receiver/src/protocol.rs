use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u32 = 1;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    Pair {
        token: String,
        client_name: String,
        client_version: u32,
    },
    Input {
        seq: u64,
        ts: u64,
        #[serde(default)]
        left_stick: Option<StickPayload>,
        #[serde(default)]
        right_stick: Option<StickPayload>,
        #[serde(default)]
        buttons: Vec<String>,
    },
    Ping {
        ts: u64,
    },
    Disconnect {
        reason: Option<String>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct StickPayload {
    pub x: f32,
    pub y: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    PairAck {
        success: bool,
        message: String,
        server_name: String,
        version: u32,
    },
    Pong {
        client_ts: u64,
        server_ts: u64,
    },
    StateAck {
        seq: u64,
    },
    Error {
        code: u16,
        message: String,
    },
}
