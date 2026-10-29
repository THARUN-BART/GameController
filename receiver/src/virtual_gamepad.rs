use crate::controller_state::ControllerState;
use std::thread::JoinHandle;
use tokio::sync::broadcast;
use vigem_client::{Client, TargetId, XButtons, XGamepad, Xbox360Wired};

/// Manages the Windows ViGEmBus virtual gamepad backend.
/// Creates a virtual Xbox 360 controller recognized by all Windows games,
/// and streams force feedback / rumble notifications to connected clients.
pub struct VirtualGamepadManager {
    target: Option<Xbox360Wired<Client>>,
    is_active: bool,
    rumble_tx: broadcast::Sender<(u8, u8)>,
    _notification_thread: Option<JoinHandle<()>>,
}

impl VirtualGamepadManager {
    /// Attempts to connect to the ViGEmBus kernel driver and spawn an Xbox 360 controller.
    /// If the driver is not installed on the PC, reports a helpful guide and runs safely without crashing.
    pub fn new() -> Self {
        let (rumble_tx, _) = broadcast::channel(32);

        match Client::connect() {
            Ok(client) => {
                let id = TargetId::XBOX360_WIRED;
                let mut target = Xbox360Wired::new(client, id);
                match target.plugin() {
                    Ok(_) => {
                        let _ = target.wait_ready();
                        println!("[VIGEM] Successfully created and plugged in Virtual Xbox 360 Controller!");

                        // Register incoming force feedback / rumble notification listener
                        let tx = rumble_tx.clone();
                        let notification_thread = match target.request_notification() {
                            Ok(req) => {
                                println!("[VIGEM] Haptic rumble notification listener active.");
                                let handle = req.spawn_thread(move |_, data| {
                                    let _ = tx.send((data.large_motor, data.small_motor));
                                });
                                Some(handle)
                            }
                            Err(e) => {
                                eprintln!("[VIGEM WARN] Could not hook rumble notification: {}", e);
                                None
                            }
                        };

                        Self {
                            target: Some(target),
                            is_active: true,
                            rumble_tx,
                            _notification_thread: notification_thread,
                        }
                    }
                    Err(e) => {
                        eprintln!("[VIGEM] Connected to ViGEmBus, but failed to plug in virtual controller: {}", e);
                        Self {
                            target: None,
                            is_active: false,
                            rumble_tx,
                            _notification_thread: None,
                        }
                    }
                }
            }
            Err(e) => {
                println!("\n==================================================================");
                println!(" [VIGEM NOTE] ViGEmBus kernel driver not detected ({})", e);
                println!(" Windows games use ViGEmBus to recognize the virtual controller.");
                println!(" Download & install the ViGEmBus driver from:");
                println!(" https://github.com/nefarius/ViGEmBus/releases");
                println!(" (LAN Gamepad will still receive and validate all network inputs)");
                println!("==================================================================\n");
                Self {
                    target: None,
                    is_active: false,
                    rumble_tx,
                    _notification_thread: None,
                }
            }
        }
    }

    pub fn is_active(&self) -> bool {
        self.is_active
    }

    /// Subscribes a client to incoming game rumble / force feedback motor events.
    pub fn subscribe_rumble(&self) -> broadcast::Receiver<(u8, u8)> {
        self.rumble_tx.subscribe()
    }

    /// Dispatches the normalized ControllerState directly to the Windows virtual gamepad.
    pub fn update(&mut self, state: &ControllerState) {
        let target = match self.target.as_mut() {
            Some(t) => t,
            None => return,
        };

        let mut report = XGamepad::default();

        // 1. Analog Sticks: [-1.0, 1.0] -> [-32768, 32767]
        report.thumb_lx = (state.left_stick_x * 32767.0).clamp(-32768.0, 32767.0) as i16;
        report.thumb_ly = (state.left_stick_y * 32767.0).clamp(-32768.0, 32767.0) as i16;
        report.thumb_rx = (state.right_stick_x * 32767.0).clamp(-32768.0, 32767.0) as i16;
        report.thumb_ry = (state.right_stick_y * 32767.0).clamp(-32768.0, 32767.0) as i16;

        // 2. Triggers: L2 / R2 (0 to 255)
        report.left_trigger = if state.is_pressed("L2") { 255 } else { 0 };
        report.right_trigger = if state.is_pressed("R2") { 255 } else { 0 };

        // 3. Digital Buttons bitmask
        let mut raw_mask: u16 = 0;
        if state.is_pressed("CROSS") { raw_mask |= XButtons::A; }
        if state.is_pressed("CIRCLE") { raw_mask |= XButtons::B; }
        if state.is_pressed("SQUARE") { raw_mask |= XButtons::X; }
        if state.is_pressed("TRIANGLE") { raw_mask |= XButtons::Y; }
        if state.is_pressed("L1") { raw_mask |= XButtons::LB; }
        if state.is_pressed("R1") { raw_mask |= XButtons::RB; }
        if state.is_pressed("L3") { raw_mask |= XButtons::LTHUMB; }
        if state.is_pressed("R3") { raw_mask |= XButtons::RTHUMB; }
        if state.is_pressed("DPAD_UP") { raw_mask |= XButtons::UP; }
        if state.is_pressed("DPAD_DOWN") { raw_mask |= XButtons::DOWN; }
        if state.is_pressed("DPAD_LEFT") { raw_mask |= XButtons::LEFT; }
        if state.is_pressed("DPAD_RIGHT") { raw_mask |= XButtons::RIGHT; }
        if state.is_pressed("OPTIONS") { raw_mask |= XButtons::START; }
        if state.is_pressed("SHARE") { raw_mask |= XButtons::BACK; }
        if state.is_pressed("GUIDE") { raw_mask |= XButtons::GUIDE; }

        report.buttons = XButtons { raw: raw_mask };

        let _ = target.update(&report);
    }

    /// Resets the virtual gamepad to neutral state
    pub fn reset(&mut self) {
        if let Some(target) = self.target.as_mut() {
            let report = XGamepad::default();
            let _ = target.update(&report);
        }
    }
}

impl Drop for VirtualGamepadManager {
    fn drop(&mut self) {
        if let Some(mut target) = self.target.take() {
            let _ = target.unplug();
            println!("[VIGEM] Virtual controller unplugged cleanly.");
        }
    }
}
