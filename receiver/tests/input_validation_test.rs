use receiver::controller_state::{canonicalize_button, ControllerState};

#[test]
fn test_button_canonicalization() {
    // Face button aliases
    assert_eq!(canonicalize_button("cross"), Some("CROSS"));
    assert_eq!(canonicalize_button("a"), Some("CROSS"));
    assert_eq!(canonicalize_button("circle"), Some("CIRCLE"));
    assert_eq!(canonicalize_button("b"), Some("CIRCLE"));
    assert_eq!(canonicalize_button("triangle"), Some("TRIANGLE"));
    assert_eq!(canonicalize_button("y"), Some("TRIANGLE"));
    assert_eq!(canonicalize_button("square"), Some("SQUARE"));
    assert_eq!(canonicalize_button("x"), Some("SQUARE"));

    // Shoulders & triggers
    assert_eq!(canonicalize_button("l1"), Some("L1"));
    assert_eq!(canonicalize_button("lb"), Some("L1"));
    assert_eq!(canonicalize_button("l2"), Some("L2"));
    assert_eq!(canonicalize_button("lt"), Some("L2"));
    assert_eq!(canonicalize_button("r1"), Some("R1"));
    assert_eq!(canonicalize_button("rb"), Some("R1"));
    assert_eq!(canonicalize_button("r2"), Some("R2"));
    assert_eq!(canonicalize_button("rt"), Some("R2"));

    // D-Pad
    assert_eq!(canonicalize_button("dpad_up"), Some("DPAD_UP"));
    assert_eq!(canonicalize_button("up"), Some("DPAD_UP"));
    assert_eq!(canonicalize_button("dpad_down"), Some("DPAD_DOWN"));
    assert_eq!(canonicalize_button("down"), Some("DPAD_DOWN"));
    assert_eq!(canonicalize_button("dpad_left"), Some("DPAD_LEFT"));
    assert_eq!(canonicalize_button("left"), Some("DPAD_LEFT"));
    assert_eq!(canonicalize_button("dpad_right"), Some("DPAD_RIGHT"));
    assert_eq!(canonicalize_button("right"), Some("DPAD_RIGHT"));

    // System
    assert_eq!(canonicalize_button("share"), Some("SHARE"));
    assert_eq!(canonicalize_button("view"), Some("SHARE"));
    assert_eq!(canonicalize_button("select"), Some("SHARE"));
    assert_eq!(canonicalize_button("options"), Some("OPTIONS"));
    assert_eq!(canonicalize_button("menu"), Some("OPTIONS"));
    assert_eq!(canonicalize_button("start"), Some("OPTIONS"));
    assert_eq!(canonicalize_button("guide"), Some("GUIDE"));
    assert_eq!(canonicalize_button("ps"), Some("GUIDE"));

    // Invalid buttons
    assert_eq!(canonicalize_button("unknown_key"), None);
    assert_eq!(canonicalize_button("foo"), None);
}

#[test]
fn test_coordinate_clamping_and_nan_safety() {
    let mut state = ControllerState::neutral();

    // Out of bounds coordinates clamped to [-1.0, 1.0]
    state.set_left_stick(2.5, -4.0);
    assert_eq!(state.left_stick_x, 1.0);
    assert_eq!(state.left_stick_y, -1.0);

    state.set_right_stick(-1.5, 3.0);
    assert_eq!(state.right_stick_x, -1.0);
    assert_eq!(state.right_stick_y, 1.0);

    // NaN / Infinity safety: reset to neutral 0.0
    state.set_left_stick(f32::NAN, f32::INFINITY);
    assert_eq!(state.left_stick_x, 0.0);
    assert_eq!(state.left_stick_y, 0.0);

    state.set_right_stick(f32::NEG_INFINITY, f32::NAN);
    assert_eq!(state.right_stick_x, 0.0);
    assert_eq!(state.right_stick_y, 0.0);
}

#[test]
fn test_sequence_monotonicity_and_apply_input() {
    let mut state = ControllerState::neutral();

    let buttons = vec!["cross".to_string(), "r1".to_string(), "bogus_btn".to_string()];
    let ok = state.apply_input(10, 1000, Some(0.5), Some(-0.5), None, None, &buttons);
    assert!(ok);
    assert_eq!(state.sequence_number, 10);
    assert_eq!(state.left_stick_x, 0.5);
    assert_eq!(state.left_stick_y, -0.5);
    assert!(state.is_pressed("CROSS"));
    assert!(state.is_pressed("R1"));
    assert!(!state.is_pressed("bogus_btn"));

    // Out-of-order packet (seq 8 < 10) must be rejected
    let stale_buttons = vec!["circle".to_string()];
    let rejected = state.apply_input(8, 1001, Some(0.0), Some(0.0), None, None, &stale_buttons);
    assert!(!rejected, "Out-of-order packet must be dropped");
    assert_eq!(state.sequence_number, 10);
    assert!(state.is_pressed("CROSS")); // Retains previous valid state

    // Newer packet (seq 11 > 10) must be accepted
    let new_buttons = vec!["circle".to_string()];
    let accepted = state.apply_input(11, 1002, Some(0.0), Some(0.0), None, None, &new_buttons);
    assert!(accepted);
    assert_eq!(state.sequence_number, 11);
    assert!(!state.is_pressed("CROSS"));
    assert!(state.is_pressed("CIRCLE"));
}

#[test]
fn test_state_reset_to_neutral() {
    let mut state = ControllerState::neutral();
    state.apply_input(1, 100, Some(0.9), Some(-0.9), Some(-0.8), Some(0.8), &["cross".to_string(), "triangle".to_string()]);

    assert!(state.is_pressed("CROSS"));
    assert!(state.is_pressed("TRIANGLE"));

    state.reset();
    assert_eq!(state.left_stick_x, 0.0);
    assert_eq!(state.left_stick_y, 0.0);
    assert_eq!(state.right_stick_x, 0.0);
    assert_eq!(state.right_stick_y, 0.0);
    assert!(state.pressed_buttons.is_empty());
}
