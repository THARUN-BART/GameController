use serde::{Deserialize, Serialize};
use std::collections::HashSet;

/// Supported canonical button identifiers across PlayStation and Xbox profiles.
pub const VALID_BUTTONS: &[&str] = &[
    "CROSS", "CIRCLE", "TRIANGLE", "SQUARE",
    "DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT",
    "L1", "L2", "R1", "R2",
    "L3", "R3",
    "SHARE", "OPTIONS", "GUIDE",
];

/// Canonicalizes incoming button labels to standardized keys
pub fn canonicalize_button(raw: &str) -> Option<&'static str> {
    match raw.to_ascii_uppercase().as_str() {
        // Face Buttons (PS & Xbox aliases)
        "CROSS" | "A" => Some("CROSS"),
        "CIRCLE" | "B" => Some("CIRCLE"),
        "TRIANGLE" | "Y" => Some("TRIANGLE"),
        "SQUARE" | "X" => Some("SQUARE"),

        // D-Pad
        "DPAD_UP" | "UP" => Some("DPAD_UP"),
        "DPAD_DOWN" | "DOWN" => Some("DPAD_DOWN"),
        "DPAD_LEFT" | "LEFT" => Some("DPAD_LEFT"),
        "DPAD_RIGHT" | "RIGHT" => Some("DPAD_RIGHT"),

        // Shoulders & Triggers
        "L1" | "LB" => Some("L1"),
        "L2" | "LT" => Some("L2"),
        "R1" | "RB" => Some("R1"),
        "R2" | "RT" => Some("R2"),

        // Thumbstick Clicks
        "L3" | "LEFT_STICK" | "THUMB_L" => Some("L3"),
        "R3" | "RIGHT_STICK" | "THUMB_R" => Some("R3"),

        // System Buttons
        "SHARE" | "VIEW" | "SELECT" | "BACK" => Some("SHARE"),
        "OPTIONS" | "MENU" | "START" => Some("OPTIONS"),
        "GUIDE" | "PS" | "HOME" => Some("GUIDE"),

        _ => None,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ControllerState {
    pub left_stick_x: f32,
    pub left_stick_y: f32,
    pub right_stick_x: f32,
    pub right_stick_y: f32,
    pub pressed_buttons: HashSet<String>,
    pub sequence_number: u64,
    pub timestamp_ms: u64,
}

impl Default for ControllerState {
    fn default() -> Self {
        Self::neutral()
    }
}

impl ControllerState {
    pub fn neutral() -> Self {
        Self {
            left_stick_x: 0.0,
            left_stick_y: 0.0,
            right_stick_x: 0.0,
            right_stick_y: 0.0,
            pressed_buttons: HashSet::new(),
            sequence_number: 0,
            timestamp_ms: 0,
        }
    }

    pub fn reset(&mut self) {
        self.left_stick_x = 0.0;
        self.left_stick_y = 0.0;
        self.right_stick_x = 0.0;
        self.right_stick_y = 0.0;
        self.pressed_buttons.clear();
    }

    /// Sets left stick with strict finite check and clamping [-1.0, 1.0]
    pub fn set_left_stick(&mut self, x: f32, y: f32) {
        self.left_stick_x = if x.is_finite() { x.clamp(-1.0, 1.0) } else { 0.0 };
        self.left_stick_y = if y.is_finite() { y.clamp(-1.0, 1.0) } else { 0.0 };
    }

    /// Sets right stick with strict finite check and clamping [-1.0, 1.0]
    pub fn set_right_stick(&mut self, x: f32, y: f32) {
        self.right_stick_x = if x.is_finite() { x.clamp(-1.0, 1.0) } else { 0.0 };
        self.right_stick_y = if y.is_finite() { y.clamp(-1.0, 1.0) } else { 0.0 };
    }

    pub fn press_button(&mut self, button: String) {
        if let Some(canonical) = canonicalize_button(&button) {
            self.pressed_buttons.insert(canonical.to_string());
        }
    }

    pub fn release_button(&mut self, button: &str) {
        if let Some(canonical) = canonicalize_button(button) {
            self.pressed_buttons.remove(canonical);
        }
    }

    pub fn is_pressed(&self, button: &str) -> bool {
        if let Some(canonical) = canonicalize_button(button) {
            self.pressed_buttons.contains(canonical)
        } else {
            false
        }
    }

    /// Applies a validated input packet. Discards stale out-of-order sequence packets.
    pub fn apply_input(
        &mut self,
        seq: u64,
        ts: u64,
        left_x: Option<f32>,
        left_y: Option<f32>,
        right_x: Option<f32>,
        right_y: Option<f32>,
        buttons: &[String],
    ) -> bool {
        // Drop out-of-order packets if seq is older than current sequence number
        if seq < self.sequence_number {
            return false;
        }

        self.sequence_number = seq;
        self.timestamp_ms = ts;

        if let (Some(x), Some(y)) = (left_x, left_y) {
            self.set_left_stick(x, y);
        }
        if let (Some(x), Some(y)) = (right_x, right_y) {
            self.set_right_stick(x, y);
        }

        self.pressed_buttons.clear();
        for btn in buttons {
            if let Some(canonical) = canonicalize_button(btn) {
                self.pressed_buttons.insert(canonical.to_string());
            }
        }

        true
    }
}
