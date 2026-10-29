use receiver::server::ReceiverServer;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let port: u16 = if args.len() > 1 {
        args[1].parse().unwrap_or(8080)
    } else {
        8080
    };

    let (server, _pairing_mgr, _controller_st) = ReceiverServer::new(port);

    if let Err(e) = server.run().await {
        eprintln!("[FATAL] Server terminated with error: {}", e);
    }

    Ok(())
}
