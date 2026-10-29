use crate::controller_state::ControllerState;
use crate::pairing::PairingManager;
use crate::protocol::{ClientMessage, ServerMessage, PROTOCOL_VERSION};
use crate::virtual_gamepad::VirtualGamepadManager;
use futures_util::{SinkExt, StreamExt};
use local_ip_address::local_ip;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio::time::{timeout, Duration};
use tokio_tungstenite::accept_async;
use tokio_tungstenite::tungstenite::Message;

pub struct ReceiverServer {
    pairing_manager: Arc<Mutex<PairingManager>>,
    controller_state: Arc<Mutex<ControllerState>>,
    virtual_gamepad: Arc<Mutex<VirtualGamepadManager>>,
    port: u16,
}

impl ReceiverServer {
    pub fn new(port: u16) -> (Self, Arc<Mutex<PairingManager>>, Arc<Mutex<ControllerState>>, Arc<Mutex<VirtualGamepadManager>>) {
        let host_ip = Self::discover_lan_ip();
        let pc_name = hostname::get()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|_| "Windows-PC".to_string());

        let pairing_mgr = Arc::new(Mutex::new(PairingManager::new(host_ip, port, pc_name)));
        let controller_st = Arc::new(Mutex::new(ControllerState::neutral()));
        let virtual_pad = Arc::new(Mutex::new(VirtualGamepadManager::new()));

        let server = Self {
            pairing_manager: Arc::clone(&pairing_mgr),
            controller_state: Arc::clone(&controller_st),
            virtual_gamepad: Arc::clone(&virtual_pad),
            port,
        };

        (server, pairing_mgr, controller_st, virtual_pad)
    }

    pub fn virtual_gamepad(&self) -> Arc<Mutex<VirtualGamepadManager>> {
        Arc::clone(&self.virtual_gamepad)
    }

    /// Discovers active local Wi-Fi / Ethernet LAN IPv4 address
    pub fn discover_lan_ip() -> String {
        match local_ip() {
            Ok(ip) => ip.to_string(),
            Err(e) => {
                eprintln!("[WARN] Could not automatically discover LAN IP: {}. Falling back to 127.0.0.1", e);
                "127.0.0.1".to_string()
            }
        }
    }

    pub fn pairing_manager(&self) -> Arc<Mutex<PairingManager>> {
        Arc::clone(&self.pairing_manager)
    }

    pub fn controller_state(&self) -> Arc<Mutex<ControllerState>> {
        Arc::clone(&self.controller_state)
    }

    /// Starts the WebSocket TCP server and displays the QR pairing display in the terminal
    pub async fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        let bind_addr: SocketAddr = format!("0.0.0.0:{}", self.port).parse()?;
        let listener = TcpListener::bind(bind_addr).await?;

        // Display the interactive PC pairing banner & terminal QR code
        self.display_pairing_screen().await?;

        println!("[SERVER] WebSocket server listening on {}", bind_addr);
        println!("[SERVER] Waiting for mobile gamepad to scan and connect...\n");

        self.run_on_listener(listener).await
    }

    /// Runs the accept loop on an already bound TcpListener (useful for testing and custom bindings)
    pub async fn run_on_listener(&self, listener: TcpListener) -> Result<(), Box<dyn std::error::Error>> {
        loop {
            match listener.accept().await {
                Ok((stream, peer_addr)) => {
                    println!("[NETWORK] Incoming connection from: {}", peer_addr);
                    let pairing_mgr = Arc::clone(&self.pairing_manager);
                    let controller_st = Arc::clone(&self.controller_state);
                    let virtual_pad = Arc::clone(&self.virtual_gamepad);

                    tokio::spawn(async move {
                        Self::handle_connection(stream, peer_addr, pairing_mgr, controller_st, virtual_pad).await;
                    });
                }
                Err(e) => {
                    eprintln!("[ERROR] Error accepting connection: {}", e);
                    break;
                }
            }
        }
        Ok(())
    }

    /// Prints a sleek ASCII terminal display with the rendered QR code and connection instructions
    pub async fn display_pairing_screen(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mgr = self.pairing_manager.lock().await;
        let vpad = self.virtual_gamepad.lock().await;
        let qr_art = mgr.render_qr_terminal().map_err(|e| e)?;
        let host = mgr.host();
        let port = mgr.port();
        let name = mgr.server_name();
        let token = mgr.current_token();
        let remaining = mgr.remaining_seconds();

        println!("\n==================================================================");
        println!("               LAN GAMEPAD - WINDOWS RECEIVER                     ");
        println!("==================================================================");
        println!(" PC Name      : {}", name);
        println!(" LAN Address  : {}:{}", host, port);
        println!(" WebSocket URL: ws://{}:{}", host, port);
        println!(" Pairing Token: {} (Expires in {}s)", token, remaining);
        println!(" Game Backend : {}", if vpad.is_active() { "Virtual Xbox 360 Controller (Ready for Games)" } else { "Standalone Network Feed (ViGEmBus not active)" });
        println!("------------------------------------------------------------------");
        println!(" Scan the QR code below using the LAN Gamepad Android app:\n");

        // Print the high-contrast dense Unicode QR code directly into stdout
        for line in qr_art.lines() {
            println!("  {}", line);
        }

        println!("\n------------------------------------------------------------------");
        println!(" Press Ctrl+C in this terminal to stop the receiver.");
        println!("==================================================================\n");

        Ok(())
    }

    async fn handle_connection(
        stream: TcpStream,
        peer_addr: SocketAddr,
        pairing_mgr: Arc<Mutex<PairingManager>>,
        controller_st: Arc<Mutex<ControllerState>>,
        virtual_pad: Arc<Mutex<VirtualGamepadManager>>,
    ) {
        let ws_stream = match accept_async(stream).await {
            Ok(ws) => {
                println!("[WEBSOCKET] TCP handshake established with {}", peer_addr);
                ws
            }
            Err(e) => {
                eprintln!("[ERROR] WebSocket handshake failed with {}: {}", peer_addr, e);
                return;
            }
        };

        let (mut write, mut read) = ws_stream.split();

        // 1. Enforce Authenticated Pairing Handshake with a 10s timeout
        println!("[AUTH] Awaiting pairing credentials from {}...", peer_addr);
        let first_msg_res = timeout(Duration::from_secs(10), read.next()).await;

        let client_msg = match first_msg_res {
            Ok(Some(Ok(Message::Text(text)))) => {
                match serde_json::from_str::<ClientMessage>(&text) {
                    Ok(msg) => msg,
                    Err(e) => {
                        eprintln!("[AUTH] Invalid JSON from {}: {}", peer_addr, e);
                        let err_resp = ServerMessage::Error {
                            code: 400,
                            message: format!("Malformed request JSON: {}", e),
                        };
                        let _ = write.send(Message::Text(serde_json::to_string(&err_resp).unwrap().into())).await;
                        let _ = write.close().await;
                        return;
                    }
                }
            }
            Ok(Some(Ok(Message::Close(_)))) => {
                println!("[AUTH] Client {} closed connection before pairing.", peer_addr);
                return;
            }
            Ok(Some(Err(e))) => {
                eprintln!("[AUTH] WebSocket receive error from {}: {}", peer_addr, e);
                return;
            }
            Ok(None) => {
                println!("[AUTH] Stream ended before pairing from {}", peer_addr);
                return;
            }
            Err(_) => {
                eprintln!("[AUTH] Pairing handshake timed out (10s) for {}", peer_addr);
                let err_resp = ServerMessage::Error {
                    code: 408,
                    message: "Pairing handshake timed out".to_string(),
                };
                let _ = write.send(Message::Text(serde_json::to_string(&err_resp).unwrap().into())).await;
                let _ = write.close().await;
                return;
            }
            _ => {
                eprintln!("[AUTH] Non-text handshake message from {}", peer_addr);
                let _ = write.close().await;
                return;
            }
        };

        // 2. Validate Pairing Credentials
        let client_name = match client_msg {
            ClientMessage::Pair { token, client_name, client_version } => {
                let mgr = pairing_mgr.lock().await;
                let server_name = mgr.server_name().to_string();

                if client_version != PROTOCOL_VERSION {
                    eprintln!(
                        "[AUTH] Protocol version mismatch from {}: got {}, expected {}",
                        peer_addr, client_version, PROTOCOL_VERSION
                    );
                    let rej = ServerMessage::PairAck {
                        success: false,
                        message: format!("Protocol version mismatch. Server requires v{}", PROTOCOL_VERSION),
                        server_name,
                        version: PROTOCOL_VERSION,
                    };
                    let _ = write.send(Message::Text(serde_json::to_string(&rej).unwrap().into())).await;
                    let _ = write.close().await;
                    return;
                }

                if let Err(err_reason) = mgr.validate_token(&token) {
                    eprintln!("[AUTH] Pairing rejected for {}: {}", peer_addr, err_reason);
                    let rej = ServerMessage::PairAck {
                        success: false,
                        message: err_reason.to_string(),
                        server_name,
                        version: PROTOCOL_VERSION,
                    };
                    let _ = write.send(Message::Text(serde_json::to_string(&rej).unwrap().into())).await;
                    let _ = write.close().await;
                    return;
                }

                // Check and acquire single-client session lock
                drop(mgr);
                let session_acquired = {
                    let mut mgr = pairing_mgr.lock().await;
                    mgr.acquire_session(peer_addr)
                };

                if !session_acquired {
                    eprintln!(
                        "[AUTH] Rejected connection from {}: Receiver is already engaged with another active gamepad session.",
                        peer_addr
                    );
                    let rej = ServerMessage::PairAck {
                        success: false,
                        message: "Receiver is currently in use by another gamepad session.".to_string(),
                        server_name,
                        version: PROTOCOL_VERSION,
                    };
                    let _ = write.send(Message::Text(serde_json::to_string(&rej).unwrap().into())).await;
                    let _ = write.close().await;
                    return;
                }

                // Authentication Successful!
                println!(
                    "[AUTH] Client '{}' ({}) authenticated successfully!",
                    client_name, peer_addr
                );
                let ack = ServerMessage::PairAck {
                    success: true,
                    message: "Pairing authenticated successfully".to_string(),
                    server_name,
                    version: PROTOCOL_VERSION,
                };
                if let Err(e) = write.send(Message::Text(serde_json::to_string(&ack).unwrap().into())).await {
                    eprintln!("[AUTH] Failed to send PairAck to {}: {}", peer_addr, e);
                    let mut mgr = pairing_mgr.lock().await;
                    mgr.release_session(peer_addr);
                    return;
                }
                client_name
            }
            _ => {
                eprintln!("[AUTH] First message was not 'pair' from {}", peer_addr);
                let err_resp = ServerMessage::Error {
                    code: 401,
                    message: "First message must be pairing handshake ('pair')".to_string(),
                };
                let _ = write.send(Message::Text(serde_json::to_string(&err_resp).unwrap().into())).await;
                let _ = write.close().await;
                return;
            }
        };

        // 3. Authenticated Session Loop with Inactivity Watchdog
        println!("[SESSION] Session active for '{}' ({})", client_name, peer_addr);

        const WATCHDOG_TIMEOUT_SECS: u64 = 4;
        let mut inactive_watchdog_tripped = false;

        loop {
            let next_item = timeout(Duration::from_secs(WATCHDOG_TIMEOUT_SECS), read.next()).await;

            match next_item {
                Err(_) => {
                    // 4 seconds without any input or ping from client -> neutralize controller
                    if !inactive_watchdog_tripped {
                        println!(
                            "[WATCHDOG] Inactive for >{}s from '{}' ({}): Gamepad neutralized for game safety.",
                            WATCHDOG_TIMEOUT_SECS, client_name, peer_addr
                        );
                        let mut state = controller_st.lock().await;
                        state.reset();
                        let mut vpad = virtual_pad.lock().await;
                        vpad.reset();
                        inactive_watchdog_tripped = true;
                    }
                    continue;
                }
                Ok(None) => {
                    println!("[SESSION] Client stream ended for '{}' ({})", client_name, peer_addr);
                    break;
                }
                Ok(Some(msg)) => {
                    inactive_watchdog_tripped = false;
                    match msg {
                        Ok(Message::Text(text)) => {
                            match serde_json::from_str::<ClientMessage>(&text) {
                                Ok(ClientMessage::Ping { ts }) => {
                                    let now_ms = SystemTime::now()
                                        .duration_since(UNIX_EPOCH)
                                        .unwrap_or_default()
                                        .as_millis() as u64;
                                    let pong = ServerMessage::Pong {
                                        client_ts: ts,
                                        server_ts: now_ms,
                                    };
                                    if let Ok(json) = serde_json::to_string(&pong) {
                                        if let Err(e) = write.send(Message::Text(json.into())).await {
                                            eprintln!("[WEBSOCKET] Failed to send Pong to {}: {}", peer_addr, e);
                                            break;
                                        }
                                    }
                                }
                                Ok(ClientMessage::Input {
                                    seq,
                                    ts,
                                    left_stick,
                                    right_stick,
                                    buttons,
                                }) => {
                                    let left_x = left_stick.as_ref().map(|s| s.x);
                                    let left_y = left_stick.as_ref().map(|s| s.y);
                                    let right_x = right_stick.as_ref().map(|s| s.x);
                                    let right_y = right_stick.as_ref().map(|s| s.y);

                                    let mut state = controller_st.lock().await;
                                    let accepted = state.apply_input(
                                        seq,
                                        ts,
                                        left_x,
                                        left_y,
                                        right_x,
                                        right_y,
                                        &buttons,
                                    );

                                    if accepted {
                                        let mut vpad = virtual_pad.lock().await;
                                        vpad.update(&state);

                                        if seq % 240 == 0 && seq > 0 {
                                            println!(
                                                "[INPUT] Packet #{} from '{}': buttons={:?}, L=({:.2},{:.2}), R=({:.2},{:.2})",
                                                seq,
                                                client_name,
                                                state.pressed_buttons,
                                                state.left_stick_x,
                                                state.left_stick_y,
                                                state.right_stick_x,
                                                state.right_stick_y
                                            );
                                        }
                                    }
                                }
                                Ok(ClientMessage::Disconnect { reason }) => {
                                    println!(
                                        "[SESSION] Client '{}' ({}) disconnected intentionally: {:?}",
                                        client_name, peer_addr, reason
                                    );
                                    break;
                                }
                                Ok(ClientMessage::Pair { .. }) => {
                                    // Already paired; respond with ack
                                    let mgr = pairing_mgr.lock().await;
                                    let ack = ServerMessage::PairAck {
                                        success: true,
                                        message: "Already authenticated".to_string(),
                                        server_name: mgr.server_name().to_string(),
                                        version: PROTOCOL_VERSION,
                                    };
                                    let _ = write.send(Message::Text(serde_json::to_string(&ack).unwrap().into())).await;
                                }
                                Err(e) => {
                                    eprintln!("[SESSION] Invalid message format from {}: {}", peer_addr, e);
                                }
                            }
                        }
                        Ok(Message::Close(_)) => {
                            println!("[SESSION] Client '{}' ({}) disconnected cleanly.", client_name, peer_addr);
                            break;
                        }
                        Ok(_) => {}
                        Err(e) => {
                            eprintln!("[SESSION] Connection error with '{}' ({}): {}", client_name, peer_addr, e);
                            break;
                        }
                    }
                }
            }
        }

        // 4. Safety Guarantee & Session Cleanup
        let should_neutralize = {
            let mut mgr = pairing_mgr.lock().await;
            mgr.release_session(peer_addr);
            !mgr.is_session_active()
        };

        if should_neutralize {
            let mut state = controller_st.lock().await;
            state.reset();
            let mut vpad = virtual_pad.lock().await;
            vpad.reset();
            println!(
                "[CONTROLLER] Controller state neutralized and session released for '{}' ({}).",
                client_name, peer_addr
            );
        } else {
            println!(
                "[SESSION] Cleaned up previous session for '{}' ({}) while active session continues.",
                client_name, peer_addr
            );
        }
    }
}
