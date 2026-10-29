use receiver::controller_state::ControllerState;
use receiver::virtual_gamepad::VirtualGamepadManager;

#[test]
fn test_virtual_gamepad_lifecycle_and_update() {
    let mut manager = VirtualGamepadManager::new();

    // Verify it initializes without panic (either active if driver installed or graceful fallback)
    let _active = manager.is_active();

    // Feed a state with deflected sticks and pressed buttons
    let mut state = ControllerState::neutral();
    state.set_left_stick(0.75, -0.75);
    state.set_right_stick(-0.5, 0.5);
    state.press_button("CROSS".to_string());
    state.press_button("R1".to_string());
    state.press_button("L2".to_string());

    // Update virtual gamepad target
    manager.update(&state);

    // Reset virtual gamepad
    manager.reset();
}
