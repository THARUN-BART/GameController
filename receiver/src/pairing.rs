use qrcode::render::unicode::Dense1x2;
use qrcode::QrCode;
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

pub const PROTOCOL_VERSION: u32 = 1;
pub const APP_IDENTIFIER: &str = "lan_gamepad";
pub const DEFAULT_TOKEN_TTL_SECONDS: u64 = 180; // 3 minutes

/// Versioned QR pairing payload matching the Flutter mobile client specification.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct QrPayload {
    pub v: u32,
    pub app: String,
    pub host: String,
    pub port: u16,
    pub token: String,
    pub exp: u64,
    pub name: String,
    pub proto: String,
}

impl QrPayload {
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }
}

pub struct PairingManager {
    host: String,
    port: u16,
    server_name: String,
    current_token: String,
    token_expires_at: u64,
    ttl_seconds: u64,
    active_peer: Option<SocketAddr>,
}

impl PairingManager {
    pub fn new(host: String, port: u16, server_name: String) -> Self {
        let mut manager = Self {
            host,
            port,
            server_name,
            current_token: String::new(),
            token_expires_at: 0,
            ttl_seconds: DEFAULT_TOKEN_TTL_SECONDS,
            active_peer: None,
        };
        manager.refresh_token();
        manager
    }

    /// Attempts to acquire the active gamepad session lock for a peer address.
    /// If another peer is already active from a different IP, returns false to prevent hijacking.
    /// If the same IP reconnects (even on a different dynamic client port), acquisition succeeds.
    pub fn acquire_session(&mut self, peer: SocketAddr) -> bool {
        match self.active_peer {
            Some(existing) if existing.ip() != peer.ip() => false,
            _ => {
                self.active_peer = Some(peer);
                true
            }
        }
    }

    /// Releases the active session lock when a client disconnects.
    pub fn release_session(&mut self, peer: SocketAddr) {
        if let Some(existing) = self.active_peer {
            if existing == peer || existing.ip() == peer.ip() {
                self.active_peer = None;
            }
        }
    }

    /// Returns true if an active gamepad session currently holds the lock.
    pub fn is_session_active(&self) -> bool {
        self.active_peer.is_some()
    }

    /// Returns the currently active peer socket address, if any.
    pub fn active_peer(&self) -> Option<SocketAddr> {
        self.active_peer
    }

    /// Generates a fresh, cryptographically strong UUIDv4 pairing token and expiration.
    pub fn refresh_token(&mut self) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        self.current_token = Uuid::new_v4().to_string()[..8].to_string();
        self.token_expires_at = now + self.ttl_seconds;
    }

    /// Returns the current active QR payload.
    pub fn current_payload(&self) -> QrPayload {
        QrPayload {
            v: PROTOCOL_VERSION,
            app: APP_IDENTIFIER.to_string(),
            host: self.host.clone(),
            port: self.port,
            token: self.current_token.clone(),
            exp: self.token_expires_at,
            name: self.server_name.clone(),
            proto: "ws".to_string(),
        }
    }

    /// Validates an incoming client token and checks expiration.
    pub fn validate_token(&self, incoming_token: &str) -> Result<(), &'static str> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        // 15-second clock skew tolerance
        if now > (self.token_expires_at + 15) {
            return Err("Pairing token has expired. Please rescan QR code on PC.");
        }

        if self.current_token.is_empty() || incoming_token != self.current_token {
            return Err("Invalid pairing token.");
        }

        Ok(())
    }

    /// Remaining seconds before the current pairing token expires.
    pub fn remaining_seconds(&self) -> u64 {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        if self.token_expires_at > now {
            self.token_expires_at - now
        } else {
            0
        }
    }

    /// Renders the QR code directly into an ANSI/Unicode text block for terminal display.
    pub fn render_qr_terminal(&self) -> Result<String, String> {
        let payload = self.current_payload();
        let json_str = payload
            .to_json()
            .map_err(|e| format!("Failed to serialize QR payload: {}", e))?;

        let code = QrCode::new(json_str.as_bytes())
            .map_err(|e| format!("Failed to generate QR code: {}", e))?;

        // Render with dense half-block Unicode characters for high contrast & compact fit
        let qr_string = code
            .render::<Dense1x2>()
            .dark_color(Dense1x2::Dark)
            .light_color(Dense1x2::Light)
            .quiet_zone(false)
            .build();

        Ok(qr_string)
    }

    pub fn host(&self) -> &str {
        &self.host
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    pub fn server_name(&self) -> &str {
        &self.server_name
    }

    pub fn current_token(&self) -> &str {
        &self.current_token
    }
}
