use serde::{Deserialize, Serialize};
use std::collections::HashSet;

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

    pub fn set_left_stick(&mut self, x: f32, y: f32) {
        self.left_stick_x = x.clamp(-1.0, 1.0);
        self.left_stick_y = y.clamp(-1.0, 1.0);
    }

    pub fn set_right_stick(&mut self, x: f32, y: f32) {
        self.right_stick_x = x.clamp(-1.0, 1.0);
        self.right_stick_y = y.clamp(-1.0, 1.0);
    }

    pub fn press_button(&mut self, button: String) {
        self.pressed_buttons.insert(button);
    }

    pub fn release_button(&mut self, button: &str) {
        self.pressed_buttons.remove(button);
    }

    pub fn is_pressed(&self, button: &str) -> bool {
        self.pressed_buttons.contains(button)
    }
}
