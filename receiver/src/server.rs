use crate::controller_state::ControllerState;
use crate::pairing::PairingManager;
use futures_util::StreamExt;
use local_ip_address::local_ip;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio_tungstenite::accept_async;

pub struct ReceiverServer {
    pairing_manager: Arc<Mutex<PairingManager>>,
    controller_state: Arc<Mutex<ControllerState>>,
    port: u16,
}

impl ReceiverServer {
    pub fn new(port: u16) -> (Self, Arc<Mutex<PairingManager>>, Arc<Mutex<ControllerState>>) {
        let host_ip = Self::discover_lan_ip();
        let pc_name = hostname::get()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|_| "Windows-PC".to_string());

        let pairing_mgr = Arc::new(Mutex::new(PairingManager::new(host_ip, port, pc_name)));
        let controller_st = Arc::new(Mutex::new(ControllerState::neutral()));

        let server = Self {
            pairing_manager: Arc::clone(&pairing_mgr),
            controller_state: Arc::clone(&controller_st),
            port,
        };

        (server, pairing_mgr, controller_st)
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

    /// Starts the WebSocket TCP server and displays the QR pairing display in the terminal
    pub async fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        let bind_addr: SocketAddr = format!("0.0.0.0:{}", self.port).parse()?;
        let listener = TcpListener::bind(bind_addr).await?;

        // Display the interactive PC pairing banner & terminal QR code
        self.display_pairing_screen().await?;

        println!("[SERVER] WebSocket server listening on {}", bind_addr);
        println!("[SERVER] Waiting for mobile gamepad to scan and connect...\n");

        loop {
            match listener.accept().await {
                Ok((stream, peer_addr)) => {
                    println!("[NETWORK] Incoming connection from: {}", peer_addr);
                    let pairing_mgr = Arc::clone(&self.pairing_manager);
                    let controller_st = Arc::clone(&self.controller_state);

                    tokio::spawn(async move {
                        Self::handle_connection(stream, peer_addr, pairing_mgr, controller_st).await;
                    });
                }
                Err(e) => {
                    eprintln!("[ERROR] Error accepting connection: {}", e);
                }
            }
        }
    }

    /// Prints a sleek ASCII terminal display with the rendered QR code and connection instructions
    pub async fn display_pairing_screen(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mgr = self.pairing_manager.lock().await;
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
        println!("------------------------------------------------------------------");
        println!(" Scan the QR code below using the LAN Gamepad Android app:\n");

        // Print the high-contrast dense Unicode QR code directly into stdout
        for line in qr_art.lines() {
            println!("    {}", line);
        }

        println!("\n------------------------------------------------------------------");
        println!(" Press Ctrl+C in this terminal to stop the receiver.");
        println!("==================================================================\n");

        Ok(())
    }

    async fn handle_connection(
        stream: TcpStream,
        peer_addr: SocketAddr,
        _pairing_mgr: Arc<Mutex<PairingManager>>,
        controller_st: Arc<Mutex<ControllerState>>,
    ) {
        let ws_stream = match accept_async(stream).await {
            Ok(ws) => {
                println!("[WEBSOCKET] Handshake established with {}", peer_addr);
                ws
            }
            Err(e) => {
                eprintln!("[ERROR] WebSocket handshake failed with {}: {}", peer_addr, e);
                return;
            }
        };

        let (_write, mut read) = ws_stream.split();

        while let Some(msg) = read.next().await {
            match msg {
                Ok(tokio_tungstenite::tungstenite::Message::Text(text)) => {
                    println!("[MSG] Received from {}: {}", peer_addr, text);
                }
                Ok(tokio_tungstenite::tungstenite::Message::Close(_)) => {
                    println!("[WEBSOCKET] Client {} disconnected cleanly.", peer_addr);
                    break;
                }
                Ok(_) => {}
                Err(e) => {
                    eprintln!("[ERROR] WebSocket connection error with {}: {}", peer_addr, e);
                    break;
                }
            }
        }

        // Safety guarantee: reset all inputs upon client disconnect
        let mut state = controller_st.lock().await;
        state.reset();
        println!("[CONTROLLER] Controller state reset to neutral for {}", peer_addr);
    }
}
